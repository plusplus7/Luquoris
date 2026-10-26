import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  test(
    'projects durable progress and the selected stable transcript',
    () async {
      final jobs = FakeTranscriptionJobRepository();
      final transcripts = _TranscriptRepository(_document());
      addTearDown(jobs.dispose);
      await jobs.enqueue(_job(), _run(), storedAtUtcMs: 1);
      final container = ProviderContainer.test(
        overrides: [
          transcriptionJobRepositoryProvider.overrideWithValue(jobs),
          transcriptRepositoryProvider.overrideWithValue(transcripts),
        ],
      );
      addTearDown(container.dispose);
      final states = <MeetingTranscriptionState>[];
      container.listen(
        meetingTranscriptionControllerProvider('meeting-1'),
        (previous, next) {
          final value = next.value;
          if (value != null) states.add(value);
        },
        fireImmediately: true,
      );

      final queued = await container.read(
        meetingTranscriptionControllerProvider('meeting-1').future,
      );
      expect(queued.latestJob?.state, isA<ProcessingQueued>());

      await jobs.start('job-1', startedAtUtcMs: 2);
      await jobs.saveProgress(
        'job-1',
        progress: 0.42,
        checkpoint: const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 4),
          parameterVersion: 1,
        ),
        storedAtUtcMs: 3,
      );
      await _waitUntil(
        () => states.any(
          (state) => switch (state.latestJob?.state) {
            ProcessingRunning(:final progress) => progress == 0.42,
            _ => false,
          },
        ),
      );

      transcripts.document = _document(completed: true);
      await jobs.complete(
        'job-1',
        _run(
          state: const AnalysisCompleted(
            startedAtUtcMs: 2,
            endedAtUtcMs: 4,
          ),
        ),
        const [_segment],
        storedAtUtcMs: 4,
      );
      await _waitUntil(
        () => states.any(
          (state) =>
              state.document?.currentVersion?.segments.single.displayedText ==
              'Stable text',
        ),
      );
    },
  );

  test('coalesces repeat retry requests while one retry is pending', () async {
    final jobs = FakeTranscriptionJobRepository();
    final transcripts = _TranscriptRepository(_document());
    final retryGate = Completer<void>();
    var retryCalls = 0;
    addTearDown(jobs.dispose);
    await jobs.enqueue(
      _job(
        state: const ProcessingFailed(
          failureCode: 'model_sha256_mismatch',
        ),
      ),
      _run(
        state: const AnalysisFailed(
          startedAtUtcMs: 1,
          endedAtUtcMs: 2,
          progress: 0,
          failureCode: 'model_sha256_mismatch',
        ),
      ),
      storedAtUtcMs: 1,
    );
    final container = ProviderContainer.test(
      overrides: [
        transcriptionJobRepositoryProvider.overrideWithValue(jobs),
        transcriptRepositoryProvider.overrideWithValue(transcripts),
        transcriptionRetryHandlerProvider.overrideWithValue((jobId) async {
          retryCalls += 1;
          await retryGate.future;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      meetingTranscriptionControllerProvider('meeting-1'),
      (previous, next) {},
      fireImmediately: true,
    );
    await container.read(
      meetingTranscriptionControllerProvider('meeting-1').future,
    );
    final notifier = container.read(
      meetingTranscriptionControllerProvider('meeting-1').notifier,
    );

    final first = notifier.retry('job-1');
    final second = notifier.retry('job-1');
    expect(retryCalls, 1);
    expect(
      container
          .read(meetingTranscriptionControllerProvider('meeting-1'))
          .requireValue
          .retryingJobIds,
      contains('job-1'),
    );

    retryGate.complete();
    await Future.wait([first, second]);
    expect(retryCalls, 1);
    expect(
      container
          .read(meetingTranscriptionControllerProvider('meeting-1'))
          .requireValue
          .retryingJobIds,
      isEmpty,
    );
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not reached');
}

ProcessingJob _job({ProcessingState state = const ProcessingQueued()}) =>
    ProcessingJob(
      id: 'job-1',
      meetingId: 'meeting-1',
      kind: ProcessingJobKind.transcription,
      createdAtUtcMs: 1,
      state: state,
      targetRunId: 'run-1',
      modelId: 'model-1',
    );

TranscriptRun _run({AnalysisState state = const AnalysisQueued()}) =>
    TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: const InferenceProvenance(
        engineId: 'engine-1',
        engineVersion: '1',
        modelId: 'model-1',
        modelVersion: '1',
        modelSha256: 'hash',
        parametersJson: '{}',
      ),
      createdAtUtcMs: 1,
      state: state,
    );

const _segment = TranscriptSegment(
  id: 'segment-1',
  transcriptRunId: 'run-1',
  start: Duration.zero,
  end: Duration(seconds: 2),
  rawModelText: 'Stable text',
  displayedText: 'Stable text',
  revisionState: TranscriptRevisionState.machine,
);

TranscriptEditorDocument _document({bool completed = false}) =>
    TranscriptEditorDocument(
      meetingId: 'meeting-1',
      lifecycle: MeetingLifecycle.finalized,
      currentVersion: completed
          ? TranscriptVersion(
              run: _run(
                state: const AnalysisCompleted(
                  startedAtUtcMs: 2,
                  endedAtUtcMs: 4,
                ),
              ),
              segments: const [_segment],
              isCurrent: true,
            )
          : null,
      languagesBySegmentId: const {},
      speakersById: const {},
      revisions: const [],
    );

final class _TranscriptRepository implements TranscriptRepository {
  _TranscriptRepository(this.document);

  TranscriptEditorDocument document;

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
  listVersions(String meetingId) async => Ok([?document.currentVersion]);

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
  }) async =>
      Ok(TranscriptVersion(run: run, segments: segments, isCurrent: false));
}
