import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// Loaded editor document plus one non-destructive save failure.
@immutable
final class TranscriptEditorViewState {
  /// Creates editor state.
  const TranscriptEditorViewState({
    required this.document,
    this.failureCode,
    this.committedButRefreshFailed = false,
    this.isSaving = false,
  });

  /// Current selected transcript and correction context.
  final TranscriptEditorDocument document;

  /// Privacy-safe repository failure from the latest save.
  final String? failureCode;

  /// Whether the correction committed before the editor refresh failed.
  final bool committedButRefreshFailed;

  /// Whether one correction transaction is in progress.
  final bool isSaving;

  /// Returns an updated state without discarding the loaded document.
  TranscriptEditorViewState copyWith({
    TranscriptEditorDocument? document,
    String? failureCode,
    bool clearFailure = false,
    bool? committedButRefreshFailed,
    bool? isSaving,
  }) => TranscriptEditorViewState(
    document: document ?? this.document,
    failureCode: clearFailure ? null : failureCode ?? this.failureCode,
    committedButRefreshFailed:
        !clearFailure &&
        (committedButRefreshFailed ?? this.committedButRefreshFailed),
    isSaving: isSaving ?? this.isSaving,
  );
}

/// Owns one saved meeting's basic text, language, and speaker corrections.
final class TranscriptEditorController
    extends AsyncNotifier<TranscriptEditorViewState> {
  /// Creates a controller for [meetingId].
  TranscriptEditorController(this.meetingId);

  /// Route-derived meeting identity.
  final String meetingId;

  static int _revisionSequence = 0;

  @override
  Future<TranscriptEditorViewState> build() async {
    ref.listen(meetingTranscriptionControllerProvider(meetingId), (
      previous,
      next,
    ) {
      final document = next.value?.document;
      if (document != null) _acceptStableDocument(document);
    });
    return TranscriptEditorViewState(document: await _loadDocument());
  }

  /// Stores a text correction while preserving raw model output.
  Future<void> correctText(String segmentId, String revisedText) async {
    final current = state.value;
    if (current == null || current.isSaving || !current.document.canEdit) {
      return;
    }
    final segment = current.document.currentVersion?.segments
        .where((candidate) => candidate.id == segmentId)
        .firstOrNull;
    if (segment == null || segment.displayedText == revisedText) return;
    await _apply(
      targetId: segmentId,
      change: TranscriptTextChange(
        previousText: segment.displayedText,
        revisedText: revisedText,
      ),
    );
  }

  /// Stores a manual segment-language correction.
  Future<void> correctLanguage(String segmentId, LanguageTag revised) async {
    final current = state.value;
    if (current == null || current.isSaving || !current.document.canEdit) {
      return;
    }
    final previous = current.document.languagesBySegmentId[segmentId]?.tag;
    if (previous == null || previous == revised) return;
    await _apply(
      targetId: segmentId,
      change: LanguageLabelChange(previous: previous, revised: revised),
    );
  }

  /// Stores a meeting-local speaker display-label correction.
  Future<void> renameSpeaker(String speakerId, String revisedLabel) async {
    final current = state.value;
    if (current == null || current.isSaving || !current.document.canEdit) {
      return;
    }
    final previous = current.document.speakersById[speakerId]?.label;
    final normalized = revisedLabel.trim();
    if (previous == null || normalized.isEmpty || previous == normalized) {
      return;
    }
    await _apply(
      targetId: speakerId,
      change: SpeakerLabelChange(previous: previous, revised: normalized),
    );
  }

  Future<void> _apply({
    required String targetId,
    required RevisionChange change,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isSaving: true, clearFailure: true));
    final now = ref.read(clockProvider).now().toUtc();
    final revision = Revision(
      id: '$meetingId:${now.microsecondsSinceEpoch}:${_revisionSequence++}',
      meetingId: meetingId,
      targetId: targetId,
      change: change,
      createdAtUtcMs: now.millisecondsSinceEpoch,
    );
    final revisionRepository = ref.read(revisionRepositoryProvider);
    final transcriptRepository = ref.read(transcriptRepositoryProvider);
    final result = await revisionRepository.apply(revision);
    if (!ref.mounted) return;
    switch (result) {
      case Ok():
        final committedDocument = _applyCommittedRevision(
          current.document,
          revision,
        );
        final refreshed = await transcriptRepository.loadEditor(meetingId);
        if (!ref.mounted) return;
        switch (refreshed) {
          case Ok(:final value):
            state = AsyncData(TranscriptEditorViewState(document: value));
          case Err(:final failure):
            state = AsyncData(
              current.copyWith(
                document: committedDocument,
                isSaving: false,
                failureCode: failure.code,
                committedButRefreshFailed: true,
              ),
            );
        }
      case Err(:final failure):
        state = AsyncData(
          current.copyWith(isSaving: false, failureCode: failure.code),
        );
    }
  }

  Future<TranscriptEditorDocument> _loadDocument() async => switch (await ref
      .read(transcriptRepositoryProvider)
      .loadEditor(meetingId)) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(failure.code),
  };

  void _acceptStableDocument(TranscriptEditorDocument document) {
    final current = state.value;
    final incomingRun = document.currentVersion?.run;
    if (current == null ||
        current.isSaving ||
        incomingRun?.state is! AnalysisCompleted ||
        current.document.currentVersion?.run.id == incomingRun?.id) {
      return;
    }
    state = AsyncData(
      current.copyWith(document: document, isSaving: false, clearFailure: true),
    );
  }
}

TranscriptEditorDocument _applyCommittedRevision(
  TranscriptEditorDocument document,
  Revision revision,
) {
  final current = document.currentVersion;
  final languages = Map<String, LanguageDecision>.of(
    document.languagesBySegmentId,
  );
  final speakers = Map<String, Speaker>.of(document.speakersById);
  var segments = current?.segments ?? const <TranscriptSegment>[];
  switch (revision.change) {
    case final TranscriptTextChange change:
      segments = segments
          .map(
            (segment) => segment.id == revision.targetId
                ? segment.copyWith(
                    displayedText: change.revisedText,
                    revisionState: TranscriptRevisionState.corrected,
                  )
                : segment,
          )
          .toList();
    case final LanguageLabelChange change:
      final previous = languages[revision.targetId];
      if (previous != null) {
        final decisionId = '${revision.id}:language';
        languages[revision.targetId] = LanguageDecision(
          id: decisionId,
          transcriptSegmentId: revision.targetId,
          tag: change.revised,
          source: LanguageDecisionSource.manual,
          confidence: null,
        );
        segments = segments
            .map(
              (segment) => segment.id == revision.targetId
                  ? segment.copyWith(languageDecisionId: decisionId)
                  : segment,
            )
            .toList();
      }
    case final SpeakerLabelChange change:
      final previous = speakers[revision.targetId];
      if (previous != null) {
        speakers[revision.targetId] = previous.copyWith(label: change.revised);
      }
    case SpeakerAssignmentChange():
      break;
  }
  return TranscriptEditorDocument(
    meetingId: document.meetingId,
    lifecycle: document.lifecycle,
    currentVersion: current == null
        ? null
        : TranscriptVersion(
            run: current.run,
            segments: segments,
            isCurrent: current.isCurrent,
          ),
    languagesBySegmentId: languages,
    speakersById: speakers,
    revisions: [...document.revisions, revision],
  );
}

/// Route-scoped transcript editor state.
final AsyncNotifierProviderFamily<
  TranscriptEditorController,
  TranscriptEditorViewState,
  String
>
transcriptEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TranscriptEditorController, TranscriptEditorViewState, String>(
      TranscriptEditorController.new,
    );
