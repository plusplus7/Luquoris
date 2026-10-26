import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamNotifierProviderFamily;
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/features/transcript/presentation/transcript_editor_controller.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

/// One retained run with validated, optional paired-processing provenance.
final class TranscriptVersionChoice extends ValueObject {
  /// Creates a version choice without inferring a role for legacy runs.
  const TranscriptVersionChoice({
    required this.run,
    required this.isCurrent,
    required this.processing,
    this.metadataInvalid = false,
  });

  /// Immutable inference identity, timestamps, and model provenance.
  final TranscriptRun run;

  /// Creation instant projected to the local timezone for localized labels.
  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(run.createdAtUtcMs);

  /// Whether this is the durably selected transcript.
  final bool isCurrent;

  /// Explicit role and coverage, or null for an unextended legacy version.
  final TranscriptProcessingInfo? processing;

  /// Whether provenance validation failed, preventing selection.
  final bool metadataInvalid;

  /// Whether the run is closed and can safely become the displayed version.
  bool get canSelect =>
      !metadataInvalid &&
      (run.state is AnalysisCompleted ||
          (processing?.role == TranscriptProcessingRole.liveDraft &&
              run.state is AnalysisFailed));

  /// Whether a completed refinement awaits an explicit selection.
  bool get isReady =>
      !metadataInvalid &&
      !isCurrent &&
      processing?.role == TranscriptProcessingRole.refinement &&
      run.state is AnalysisCompleted;

  @override
  List<Object?> get equalityValues => [
    run,
    isCurrent,
    processing,
    metadataInvalid,
  ];
}

/// Retained versions plus one coalesced selection action and safe failure state.
final class TranscriptVersionChoicesState extends ValueObject {
  /// Freezes the current version choices.
  TranscriptVersionChoicesState({
    required List<TranscriptVersionChoice> choices,
    this.selectingRunId,
    this.selectionFailed = false,
  }) : choices = List.unmodifiable(choices);

  /// Retained versions, newest first, with independent processing roles.
  final List<TranscriptVersionChoice> choices;

  /// The explicit selection awaiting local commit, never an optimistic current.
  final String? selectingRunId;

  /// Whether the most recent explicit selection failed.
  final bool selectionFailed;

  @override
  List<Object?> get equalityValues => [
    selectingRunId,
    selectionFailed,
    ...choices,
  ];
}

/// Watches version readiness and persists only deliberate version choices.
final class TranscriptVersionChoicesController
    extends StreamNotifier<TranscriptVersionChoicesState> {
  /// Creates the route-scoped controller for one meeting.
  TranscriptVersionChoicesController(this.meetingId);

  /// Stable route-derived owner of every selectable run.
  final String meetingId;

  String? _selectingRunId;
  bool _selectionFailed = false;

  @override
  Stream<TranscriptVersionChoicesState> build() {
    final transcripts = ref.watch(transcriptRepositoryProvider);
    final processing = ref.watch(transcriptProcessingRepositoryProvider);
    return transcripts.watchVersions(meetingId).asyncMap((result) async {
      final versions = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.code),
      };
      final choices = <TranscriptVersionChoice>[];
      for (final version in versions) {
        final metadata = await processing.load(version.run.id);
        choices.add(
          TranscriptVersionChoice(
            run: version.run,
            isCurrent: version.isCurrent,
            processing: switch (metadata) {
              Ok(:final value) => value,
              Err() => null,
            },
            metadataInvalid: metadata.isErr,
          ),
        );
      }
      return TranscriptVersionChoicesState(
        choices: choices,
        selectingRunId: _selectingRunId,
        selectionFailed: _selectionFailed,
      );
    });
  }

  /// Selects a stable run identity without exposing a dropped callback future.
  void select(String runId) {
    final current = state.value;
    final choice = current?.choices
        .where((candidate) => candidate.run.id == runId)
        .firstOrNull;
    if (_selectingRunId != null ||
        choice == null ||
        !choice.canSelect ||
        choice.isCurrent) {
      return;
    }
    _selectingRunId = runId;
    _selectionFailed = false;
    state = AsyncData(
      TranscriptVersionChoicesState(
        choices: current!.choices,
        selectingRunId: runId,
      ),
    );
    // Retain only the in-flight commit so popping this route cannot skip refresh.
    final lifetime = ref.keepAlive();
    unawaited(_selectSafely(runId).whenComplete(lifetime.close));
  }

  Future<void> _selectSafely(String runId) async {
    try {
      final transcripts = ref.read(transcriptRepositoryProvider);
      final processing = ref.read(transcriptProcessingRepositoryProvider);
      final selectedAtUtcMs = ref
          .read(clockProvider)
          .now()
          .toUtc()
          .millisecondsSinceEpoch;
      // Resolve the ID again at action time; never trust a captured choice.
      final listed = await transcripts.listVersions(meetingId);
      final versions = switch (listed) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.code),
      };
      final version = versions
          .where((candidate) => candidate.run.id == runId)
          .firstOrNull;
      if (version == null) throw StateError('analysis_not_found');
      final metadata = await processing.load(runId);
      final choice = TranscriptVersionChoice(
        run: version.run,
        isCurrent: version.isCurrent,
        processing: switch (metadata) {
          Ok(:final value) => value,
          Err() => null,
        },
        metadataInvalid: metadata.isErr,
      );
      if (!choice.canSelect) throw StateError('analysis_conflict');
      final selected = await transcripts.selectReadableVersion(
        choice.run,
        choice.processing,
        selectedAtUtcMs: selectedAtUtcMs,
      );
      switch (selected) {
        case Ok():
          if (!ref.mounted) return;
          ref.invalidate(meetingTranscriptionControllerProvider(meetingId));
          ref.invalidate(transcriptEditorControllerProvider(meetingId));
        case Err():
          _selectionFailed = true;
      }
    } on Object {
      _selectionFailed = true;
    } finally {
      _selectingRunId = null;
      if (ref.mounted) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            TranscriptVersionChoicesState(
              choices: current.choices,
              selectionFailed: _selectionFailed,
            ),
          );
        }
      }
    }
  }
}

/// Route-scoped version choices; the repository owns all durable state.
final StreamNotifierProviderFamily<
  TranscriptVersionChoicesController,
  TranscriptVersionChoicesState,
  String
>
transcriptVersionChoicesControllerProvider = StreamNotifierProvider.autoDispose
    .family<
      TranscriptVersionChoicesController,
      TranscriptVersionChoicesState,
      String
    >(
      TranscriptVersionChoicesController.new,
    );
