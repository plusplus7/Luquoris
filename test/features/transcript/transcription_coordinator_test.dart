import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/application/transcription_ids.dart';
import 'package:loquiris/features/transcript/application/transcription_parameters.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  group('deterministic transcription identity', () {
    test('uses UUID-v5 inputs and media boundaries, never native labels', () {
      final parameters = _parameters(
        meeting: _meeting('meeting-1'),
        manifest: _manifest(),
      );

      final jobId = transcriptionJobId(
        meetingId: 'meeting-1',
        parameters: parameters,
      );
      final sameJobId = transcriptionJobId(
        meetingId: 'meeting-1',
        parameters: parameters,
      );
      final runId = transcriptionRunId(
        meetingId: 'meeting-1',
        parameters: parameters,
      );
      final segmentId = transcriptionSegmentId(
        runId: runId,
        start: const Duration(milliseconds: 250),
        end: const Duration(milliseconds: 800),
      );

      expect(jobId, sameJobId);
      expect(jobId, isNot(runId));
      expect(jobId, matches(_uuidV5));
      expect(runId, matches(_uuidV5));
      expect(segmentId, matches(_uuidV5));
      expect(
        transcriptionSegmentId(
          runId: runId,
          start: const Duration(milliseconds: 251),
          end: const Duration(milliseconds: 800),
        ),
        isNot(segmentId),
      );
    });

    test(
      'canonical parameters retain requested timing and fixed provenance',
      () {
        final parameters = _parameters(
          meeting: _meeting(
            'meeting-1',
            mode: MeetingTranscriptionMode.nearRealTime,
          ),
          manifest: _manifest(),
        );

        expect(parameters.parameterVersion, 1);
        expect(parameters.engineId, 'whisper_cpp');
        expect(parameters.engineVersion, '1.9.4');
        expect(parameters.executionMode, PerformanceMode.postSession);
        expect(
          parameters.canonicalJson,
          '{"executionMode":"postSession","languageHint":"mixed",'
          '"parameterVersion":1,"requestedTiming":"nearRealTime"}',
        );
      },
    );
  });

  group('TranscriptionCoordinator', () {
    test(
      'schedules and launches exactly once after finalized persistence',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        await harness.start();

        await Future.wait(<Future<void>>[
          harness.coordinator.scheduleFinalized('meeting-1'),
          harness.coordinator.scheduleFinalized('meeting-1'),
        ]);

        expect(harness.jobs.enqueueCalls, hasLength(1));
        expect(harness.jobs.startCalls, hasLength(1));
        expect(harness.engine.requests, hasLength(1));
        expect(harness.jobs.completionCalls, hasLength(1));
        expect(
          harness.jobs.jobs.values.single.state,
          const ProcessingSucceeded(),
        );
      },
    );

    test(
      'recording-only execution policy creates no durable or native work',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);
        await harness.start();

        await harness.coordinator.scheduleFinalized(
          'meeting-1',
          executionMode: PerformanceMode.recordingOnly,
        );

        expect(harness.sessions.loadDetailCalls, isEmpty);
        expect(harness.jobs.enqueueCalls, isEmpty);
        expect(harness.engine.requests, isEmpty);
      },
    );

    test(
      'near-real-time meetings always receive a complete post-session pass',
      () async {
        final harness = _Harness(
          meeting: _meeting(
            'meeting-1',
            mode: MeetingTranscriptionMode.nearRealTime,
          ),
        );
        addTearDown(harness.dispose);
        await harness.start();

        await harness.coordinator.scheduleFinalized('meeting-1');

        expect(harness.engine.requests, hasLength(1));
        expect(
          harness.engine.requests.single.audio.segmentPaths,
          <String>[
            'recordings/meeting-1/segment-00000.aac',
            'recordings/meeting-1/segment-00001.aac',
          ],
        );
        final parametersJson =
            harness.jobs.enqueueCalls.single.run.provenance.parametersJson;
        expect(parametersJson, contains('"requestedTiming":"nearRealTime"'));
        expect(parametersJson, contains('"executionMode":"postSession"'));
      },
    );

    test(
      'observed finalization waits for the durable meeting projection',
      () async {
        final recording = _meeting('meeting-1').copyWith(
          lifecycle: MeetingLifecycle.recording,
        );
        final harness = _Harness(meeting: recording);
        addTearDown(harness.dispose);
        await harness.start();

        harness.coordinator.recordingFinalized('meeting-1');
        await pumpEventQueue();
        expect(harness.jobs.enqueueCalls, isEmpty);

        harness.sessions.details['meeting-1'] = _detail(
          recording.copyWith(lifecycle: MeetingLifecycle.finalized),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await harness.coordinator.waitForIdle();

        expect(harness.jobs.enqueueCalls, hasLength(1));
        expect(harness.engine.requests, hasLength(1));
      },
    );

    test(
      'model verification failure is contained and later work still runs',
      () async {
        final harness = _Harness();
        harness.sessions.details['meeting-2'] = _detail(_meeting('meeting-2'));
        harness.models.verifyResult = const Err(
          ModelUnavailable('model_sha256_mismatch'),
        );
        addTearDown(harness.dispose);
        await harness.start();

        await harness.coordinator.scheduleFinalized('meeting-1');

        expect(harness.engine.requests, isEmpty);
        expect(
          harness.jobs.failureCalls.single.failureCode,
          'model_sha256_mismatch',
        );
        harness.models.verifyResult = const Ok(
          ModelDescriptor(
            id: transcriptionModelId,
            version: 'model-commit',
            bytes: 3,
          ),
        );

        await harness.coordinator.scheduleFinalized('meeting-2');

        expect(harness.engine.requests, hasLength(1));
        expect(harness.engine.requests.single.audio.sessionId, 'meeting-2');
        expect(harness.jobs.completionCalls, hasLength(1));
      },
    );

    test(
      'persists monotonic progress, stable segments, and first selection',
      () async {
        final harness = _Harness();
        harness.engine.onTranscribe = (request) {
          harness.engine.emit(
            TranscriptionProgressUpdated(
              runId: request.runId,
              fraction: 0.5,
              remaining: const Duration(seconds: 2),
            ),
          );
        };
        harness.engine.results.add(
          Ok(
            TranscriptionOutput(
              engineVersion: '1.9.4',
              chunks: const <TranscriptChunk>[
                TranscriptChunk(
                  segmentId: 'native-label-is-not-persisted',
                  start: Duration(milliseconds: 200),
                  end: Duration(milliseconds: 800),
                  rawText: ' raw ',
                  displayText: 'raw',
                  stability: TranscriptStability.stable,
                ),
              ],
            ),
          ),
        );
        addTearDown(harness.dispose);
        await harness.start();

        await harness.coordinator.scheduleFinalized('meeting-1');

        expect(harness.jobs.progressCalls, hasLength(1));
        expect(harness.jobs.progressCalls.single.progress, 0.5);
        expect(
          harness.jobs.progressCalls.single.checkpoint.completedMedia,
          const Duration(seconds: 5),
        );
        final completion = harness.jobs.completionCalls.single;
        expect(completion.run.state, isA<AnalysisCompleted>());
        expect(completion.segments, hasLength(1));
        expect(
          completion.segments.single.id,
          isNot('native-label-is-not-persisted'),
        );
        expect(completion.segments.single.rawModelText, ' raw ');
        expect(completion.segments.single.displayedText, 'raw');
        expect(
          completion.segments.single.revisionState,
          TranscriptRevisionState.machine,
        );

        final parallelRun = TranscriptRun(
          id: 'parallel-run',
          meetingId: 'meeting-1',
          provenance: completion.run.provenance,
          createdAtUtcMs: 101,
          state: const AnalysisQueued(),
        );
        final parallelJob = ProcessingJob(
          id: 'parallel-job',
          meetingId: 'meeting-1',
          kind: ProcessingJobKind.transcription,
          createdAtUtcMs: 101,
          state: const ProcessingQueued(),
          targetRunId: parallelRun.id,
          modelId: transcriptionModelId,
        );
        expect(
          await harness.jobs.enqueue(
            parallelJob,
            parallelRun,
            storedAtUtcMs: 101,
          ),
          isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
        );
        expect(
          await harness.jobs.start(
            parallelJob.id,
            startedAtUtcMs: 102,
          ),
          isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
        );
        final parallelCompletion = await harness.jobs.complete(
          parallelJob.id,
          parallelRun.copyWith(
            state: const AnalysisCompleted(
              startedAtUtcMs: 102,
              endedAtUtcMs: 103,
            ),
          ),
          <TranscriptSegment>[
            TranscriptSegment(
              id: 'parallel-segment',
              transcriptRunId: parallelRun.id,
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 2),
              rawModelText: 'parallel',
              displayedText: 'parallel',
              revisionState: TranscriptRevisionState.machine,
            ),
          ],
          storedAtUtcMs: 103,
        );
        expect(
          (parallelCompletion
                  as Ok<TranscriptVersion, AnalysisRepositoryFailure>)
              .value
              .isCurrent,
          isFalse,
        );
      },
    );

    test(
      'retry requeues the same deterministic job and completes it',
      () async {
        final harness = _Harness();
        harness.engine.results
          ..add(
            const Err(TranscriptionUnavailable('transcription_native_failed')),
          )
          ..add(Ok(TranscriptionOutput(engineVersion: '1.9.4', chunks: [])));
        addTearDown(harness.dispose);
        await harness.start();

        await harness.coordinator.scheduleFinalized('meeting-1');
        final jobId = harness.jobs.jobs.keys.single;
        expect(
          harness.jobs.jobs[jobId]?.state,
          const ProcessingFailed(failureCode: 'transcription_native_failed'),
        );

        await harness.coordinator.retry(jobId);

        expect(harness.jobs.retryCalls, hasLength(1));
        expect(harness.jobs.startCalls, hasLength(2));
        expect(
          harness.engine.requests.map((request) => request.runId).toSet(),
          hasLength(1),
        );
        expect(harness.jobs.jobs[jobId]?.state, const ProcessingSucceeded());
      },
    );

    test(
      'startup recovers orphaned running work before accepting new launches',
      () async {
        final manifest = _manifest();
        final meeting = _meeting('meeting-1');
        final parameters = _parameters(meeting: meeting, manifest: manifest);
        final runId = transcriptionRunId(
          meetingId: meeting.id,
          parameters: parameters,
        );
        final jobId = transcriptionJobId(
          meetingId: meeting.id,
          parameters: parameters,
        );
        final harness = _Harness(meeting: meeting, manifest: manifest);
        harness.jobs.jobs[jobId] = ProcessingJob(
          id: jobId,
          meetingId: meeting.id,
          kind: ProcessingJobKind.transcription,
          createdAtUtcMs: meeting.createdAtUtcMs,
          state: const ProcessingRunning(progress: 0.4),
          targetRunId: runId,
          modelId: manifest.id,
          checkpoint: const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 4),
            parameterVersion: 1,
          ).toStorageJson(),
        );
        harness.jobs.runs[runId] = TranscriptRun(
          id: runId,
          meetingId: meeting.id,
          provenance: parameters.provenance,
          createdAtUtcMs: meeting.createdAtUtcMs,
          state: const AnalysisRunning(startedAtUtcMs: 99, progress: 0.4),
        );
        addTearDown(harness.dispose);

        final startup = harness.start();
        final newLaunch = harness.coordinator.scheduleFinalized('meeting-2');
        await startup;
        await harness.coordinator.waitForIdle();
        await newLaunch;

        expect(harness.jobs.recoveryCalls, <int>[100]);
        expect(harness.engine.requests.first.audio.sessionId, 'meeting-1');
        expect(harness.jobs.jobs[jobId]?.state, const ProcessingSucceeded());
      },
    );

    test(
      'startup recomputes with durable language provenance after meeting edits',
      () async {
        final manifest = _manifest();
        final originalMeeting = _meeting(
          'meeting-1',
          language: MeetingLanguageMode.english,
        );
        final parameters = _parameters(
          meeting: originalMeeting,
          manifest: manifest,
        );
        final runId = transcriptionRunId(
          meetingId: originalMeeting.id,
          parameters: parameters,
        );
        final jobId = transcriptionJobId(
          meetingId: originalMeeting.id,
          parameters: parameters,
        );
        final harness = _Harness(
          meeting: originalMeeting.copyWith(
            languageMode: MeetingLanguageMode.chinese,
          ),
          manifest: manifest,
        );
        harness.jobs.jobs[jobId] = ProcessingJob(
          id: jobId,
          meetingId: originalMeeting.id,
          kind: ProcessingJobKind.transcription,
          createdAtUtcMs: originalMeeting.createdAtUtcMs,
          state: const ProcessingPaused(reasonCode: 'process_restarted'),
          targetRunId: runId,
          modelId: manifest.id,
          checkpoint: const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 4),
            parameterVersion: 1,
          ).toStorageJson(),
        );
        harness.jobs.runs[runId] = TranscriptRun(
          id: runId,
          meetingId: originalMeeting.id,
          provenance: parameters.provenance,
          createdAtUtcMs: originalMeeting.createdAtUtcMs,
          state: const AnalysisQueued(),
        );
        addTearDown(harness.dispose);

        await harness.start();
        await harness.coordinator.waitForIdle();

        expect(
          harness.engine.requests.single.languageHint,
          MeetingLanguageMode.english,
        );
        expect(harness.jobs.jobs[jobId]?.state, const ProcessingSucceeded());
      },
    );

    test('completion rejection becomes a durable terminal failure', () async {
      final harness = _Harness();
      harness.jobs.completionFailure = const AnalysisConflict();
      addTearDown(harness.dispose);
      await harness.start();

      await harness.coordinator.scheduleFinalized('meeting-1');

      expect(harness.jobs.completionCalls, hasLength(1));
      expect(
        harness.jobs.failureCalls.last.failureCode,
        'transcription_persistence_failed',
      );
      expect(
        harness.jobs.jobs.values.single.state,
        const ProcessingFailed(
          failureCode: 'transcription_persistence_failed',
        ),
      );
    });

    test('persists a partial-input warning on successful output', () async {
      final harness = _Harness();
      harness.engine.results.add(
        Ok(
          TranscriptionOutput(
            engineVersion: '1.9.4',
            chunks: const [],
            warningCode: 'transcription_audio_uncommitted_tail',
          ),
        ),
      );
      addTearDown(harness.dispose);
      await harness.start();

      await harness.coordinator.scheduleFinalized('meeting-1');

      expect(
        harness.jobs.jobs.values.single.state,
        const ProcessingSucceededWithWarning(
          warningCode: 'transcription_audio_uncommitted_tail',
        ),
      );
    });

    test('allows only one native base-model inference at a time', () async {
      final engine = _ControlledTranscriptionEngine(gated: true);
      final harness = _Harness(engine: engine);
      harness.sessions.details['meeting-2'] = _detail(_meeting('meeting-2'));
      addTearDown(harness.dispose);
      await harness.start();

      final first = harness.coordinator.scheduleFinalized('meeting-1');
      final second = harness.coordinator.scheduleFinalized('meeting-2');
      await pumpEventQueue();

      expect(engine.requests, hasLength(1));
      expect(engine.maximumActive, 1);
      engine.releaseNext();
      await pumpEventQueue();
      expect(engine.requests, hasLength(2));
      expect(engine.maximumActive, 1);
      engine.releaseNext();

      await Future.wait(<Future<void>>[first, second]);
      expect(engine.active, 0);
    });

    test('rejects output from an unexpected native engine version', () async {
      final harness = _Harness();
      harness.engine.results.add(
        Ok(TranscriptionOutput(engineVersion: '1.9.5', chunks: [])),
      );
      addTearDown(harness.dispose);
      await harness.start();

      await harness.coordinator.scheduleFinalized('meeting-1');

      expect(harness.jobs.completionCalls, isEmpty);
      expect(
        harness.jobs.failureCalls.single.failureCode,
        'transcription_engine_version_mismatch',
      );
    });
  });
}

final RegExp _uuidV5 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class _Harness {
  _Harness({
    Meeting? meeting,
    BundledModelManifest? manifest,
    _ControlledTranscriptionEngine? engine,
  }) : manifest = manifest ?? _manifest(),
       engine = engine ?? _ControlledTranscriptionEngine() {
    final selectedMeeting = meeting ?? _meeting('meeting-1');
    sessions.details[selectedMeeting.id] = _detail(selectedMeeting);
    sessions.details['meeting-2'] ??= _detail(_meeting('meeting-2'));
    models.verifyResult = Ok(
      ModelDescriptor(
        id: this.manifest.id,
        version: this.manifest.version,
        bytes: this.manifest.bytes,
      ),
    );
    container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.fromMillisecondsSinceEpoch(100, isUtc: true)),
        ),
        sessionRepositoryProvider.overrideWithValue(sessions),
        transcriptionJobRepositoryProvider.overrideWithValue(jobs),
        transcriptionEngineProvider.overrideWithValue(this.engine),
        modelManagerProvider.overrideWithValue(models),
        transcriptionModelManifestProvider.overrideWithValue(this.manifest),
      ],
    );
  }

  final _DetailSessionRepository sessions = _DetailSessionRepository();
  final FakeTranscriptionJobRepository jobs = FakeTranscriptionJobRepository();
  final FakeModelManager models = FakeModelManager();
  final BundledModelManifest manifest;
  final _ControlledTranscriptionEngine engine;
  late final ProviderContainer container;

  TranscriptionCoordinator get coordinator =>
      container.read(transcriptionCoordinatorProvider.notifier);

  Future<void> start() =>
      container.read(transcriptionCoordinatorProvider.future);

  Future<void> dispose() async {
    container.dispose();
    await engine.dispose();
    await jobs.dispose();
  }
}

final class _DetailSessionRepository implements SessionRepository {
  final Map<String, SessionDetail> details = <String, SessionDetail>{};
  final List<String> loadDetailCalls = <String>[];

  @override
  Future<Result<SessionDetail, SessionRepositoryFailure>> loadDetail(
    String meetingId,
  ) async {
    loadDetailCalls.add(meetingId);
    final detail = details[meetingId];
    return detail == null ? const Err(SessionNotFound()) : Ok(detail);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ControlledTranscriptionEngine implements TranscriptionEngine {
  _ControlledTranscriptionEngine({this.gated = false});

  final bool gated;
  final List<TranscriptionRequest> requests = <TranscriptionRequest>[];
  final List<Result<TranscriptionOutput, TranscriptionFailure>> results =
      <Result<TranscriptionOutput, TranscriptionFailure>>[];
  final StreamController<TranscriptionEvent> _events =
      StreamController<TranscriptionEvent>.broadcast(sync: true);
  final List<Completer<void>> _gates = <Completer<void>>[];
  void Function(TranscriptionRequest request)? onTranscribe;
  int active = 0;
  int maximumActive = 0;

  @override
  Stream<TranscriptionEvent> eventsFor(String runId) =>
      _events.stream.where((event) => event.runId == runId);

  void emit(TranscriptionEvent event) => _events.add(event);

  @override
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  ) async {
    requests.add(request);
    active += 1;
    if (active > maximumActive) maximumActive = active;
    onTranscribe?.call(request);
    if (gated) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    active -= 1;
    return results.isEmpty
        ? Ok(TranscriptionOutput(engineVersion: '1.9.4', chunks: []))
        : results.removeAt(0);
  }

  void releaseNext() {
    _gates.removeAt(0).complete();
  }

  @override
  Future<Result<void, TranscriptionFailure>> cancel(String runId) async =>
      const Ok(null);

  @override
  Future<Result<void, TranscriptionFailure>> startDraft(
    TranscriptionDraftRequest request,
  ) async => const Ok(null);

  @override
  Future<Result<void, TranscriptionFailure>> stopDraft(String runId) async =>
      const Ok(null);

  Future<void> dispose() => _events.close();
}

TranscriptionParameters _parameters({
  required Meeting meeting,
  required BundledModelManifest manifest,
  PerformanceMode executionMode = PerformanceMode.postSession,
}) => TranscriptionParameters.forMeeting(
  meeting: meeting,
  manifest: manifest,
  executionMode: executionMode,
);

BundledModelManifest _manifest() {
  final result = BundledModelManifest.tryParse(<String, Object?>{
    'schemaVersion': 1,
    'id': transcriptionModelId,
    'version': 'model-commit',
    'source': 'https://example.test/model.bin',
    'artifactPath': 'models/$transcriptionModelId/model.bin',
    'sha256':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'bytes': 3,
    'runtime': <String, Object?>{
      'engineId': 'whisper_cpp',
      'modelFormat': 'ggml',
    },
    'license': <String, Object?>{
      'id': 'MIT',
      'snapshotPath': 'models/licenses/model.txt',
    },
    'capabilities': <Object?>['transcription'],
    'enabledModes': <Object?>['postSession'],
  });
  return (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
}

Meeting _meeting(
  String id, {
  MeetingTranscriptionMode mode = MeetingTranscriptionMode.postSession,
  MeetingLanguageMode language = MeetingLanguageMode.mixed,
}) => Meeting(
  id: id,
  title: 'Private title',
  createdAtUtcMs: 7,
  mediaDuration: const Duration(seconds: 10),
  lifecycle: MeetingLifecycle.finalized,
  languageMode: language,
  transcriptionMode: mode,
);

SessionDetail _detail(Meeting meeting) => SessionDetail(
  meeting: meeting,
  segments: <AudioSegment>[
    _audioSegment(meeting.id, 0),
    _audioSegment(meeting.id, 1),
    AudioSegment(
      id: '${meeting.id}-missing',
      meetingId: meeting.id,
      sequence: 2,
      relativePath: _path('recordings/${meeting.id}/segment-00002.aac'),
      mediaStart: const Duration(seconds: 10),
      mediaDuration: Duration.zero,
      committedBytes: 0,
      state: AudioSegmentState.missing,
    ),
  ],
  events: <SessionEvent>[
    SessionEvent(
      id: '${meeting.id}-stopped',
      meetingId: meeting.id,
      sequence: 1,
      type: SessionEventType.stopped,
      wallClockUtcMs: 50,
      monotonicElapsed: const Duration(seconds: 12),
      mediaOffset: const Duration(seconds: 10),
    ),
  ],
  bookmarks: const <Bookmark>[],
  processingJobs: const <ProcessingJob>[],
  recoveryDiagnostics: const <SessionRecoveryDiagnostic>[],
);

AudioSegment _audioSegment(String meetingId, int sequence) => AudioSegment(
  id: '$meetingId-$sequence',
  meetingId: meetingId,
  sequence: sequence,
  relativePath: _path(
    'recordings/$meetingId/segment-${sequence.toString().padLeft(5, '0')}.aac',
  ),
  mediaStart: Duration(seconds: sequence * 5),
  mediaDuration: const Duration(seconds: 5),
  committedBytes: 100,
  state: AudioSegmentState.committed,
);

AppRelativePath _path(String value) =>
    (AppRelativePath.tryParse(value)
            as Ok<AppRelativePath, InvalidAppRelativePath>)
        .value;
