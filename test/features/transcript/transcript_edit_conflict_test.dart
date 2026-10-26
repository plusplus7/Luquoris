import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/transcript_editor_controller.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

void main() {
  test(
    'stale transcript edit conflict preserves the selected version',
    () async {
      final transcripts = _StableTranscriptRepository(_document());
      final revisions = _ConflictingRevisionRepository();
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          revisionRepositoryProvider.overrideWithValue(revisions),
        ],
      );
      final provider = transcriptEditorControllerProvider('meeting-1');

      await container.read(provider.future);
      await container
          .read(provider.notifier)
          .correctText('segment-1', 'Stale correction');

      final state = container.read(provider).requireValue;
      expect(revisions.attempted, hasLength(1));
      expect(state.failureCode, 'analysis_conflict');
      expect(state.isSaving, isFalse);
      expect(state.committedButRefreshFailed, isFalse);
      expect(
        state.document.currentVersion!.segments.single.displayedText,
        'Machine text',
      );
      expect(state.document.revisions, isEmpty);
    },
  );
}

TranscriptEditorDocument _document() => TranscriptEditorDocument(
  meetingId: 'meeting-1',
  lifecycle: MeetingLifecycle.finalized,
  currentVersion: TranscriptVersion(
    run: const TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: InferenceProvenance(
        engineId: 'engine',
        engineVersion: '1',
        modelId: 'model',
        modelVersion: '1',
        modelSha256: 'hash',
        parametersJson: '{}',
      ),
      createdAtUtcMs: 1,
      state: AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2),
    ),
    segments: const [
      TranscriptSegment(
        id: 'segment-1',
        transcriptRunId: 'run-1',
        start: Duration.zero,
        end: Duration(seconds: 1),
        rawModelText: 'Machine text',
        displayedText: 'Machine text',
        revisionState: TranscriptRevisionState.machine,
      ),
    ],
    isCurrent: true,
  ),
  languagesBySegmentId: const {},
  speakersById: const {},
  revisions: const [],
);

final class _StableTranscriptRepository implements TranscriptRepository {
  const _StableTranscriptRepository(this.document);

  final TranscriptEditorDocument document;

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async => Ok(document);

  @override
  Stream<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  watchVersions(String meetingId) async* {
    yield await listVersions(meetingId);
  }

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async => Ok([document.currentVersion!]);

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectReadableVersion(
    TranscriptRun expectedRun,
    TranscriptProcessingInfo? expectedProcessing, {
    required int selectedAtUtcMs,
  }) => selectCurrent(
    expectedRun.meetingId,
    expectedRun.id,
    selectedAtUtcMs: selectedAtUtcMs,
  );

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  }) async => const Ok(null);

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  }) async => Ok(
    TranscriptVersion(run: run, segments: segments, isCurrent: false),
  );
}

final class _ConflictingRevisionRepository implements RevisionRepository {
  final List<Revision> attempted = [];

  @override
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(
    Revision revision,
  ) async {
    attempted.add(revision);
    return const Err(AnalysisConflict());
  }

  @override
  Future<Result<List<Revision>, AnalysisRepositoryFailure>> listMeeting(
    String meetingId,
  ) async => const Ok([]);

  @override
  Future<Result<SpeakerAssignment, AnalysisRepositoryFailure>>
  materializeSpeakerAssignment(SpeakerAssignment rawAssignment) async =>
      Ok(rawAssignment);

  @override
  Future<Result<Speaker, AnalysisRepositoryFailure>> materializeSpeaker(
    Speaker rawSpeaker,
  ) async => Ok(rawSpeaker);
}
