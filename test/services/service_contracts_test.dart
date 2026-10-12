import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';

void main() {
  group('service fakes', () {
    test('collection-valued contracts defensively copy their inputs', () {
      final paths = ['one.pcm'];
      final input = AudioInput(sessionId: 'session-1', segmentPaths: paths);
      paths.add('two.pcm');

      expect(input.segmentPaths, ['one.pcm']);
      expect(() => input.segmentPaths.add('three.pcm'), throwsUnsupportedError);
      expect(
        () => ModelInventory(models: []).models.add(
          const ModelDescriptor(id: 'id', version: 'v1', bytes: 1),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => SessionCollection(sessions: const []).sessions.add(
          const SessionSummary(id: 'id', title: 'title'),
        ),
        throwsUnsupportedError,
      );
    });

    test('capture records commands and exposes configured failures', () async {
      final fake = FakeAudioCaptureService();
      addTearDown(fake.dispose);
      const request = AudioCaptureRequest(sessionId: 'session-1');

      expect(
        await fake.start(request),
        isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>(),
      );
      expect(fake.startRequests, [request]);

      fake.pauseResult = const Err(AudioCaptureUnavailable('audio_focus_lost'));
      expect(
        await fake.pause(),
        isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>(),
      );
    });

    test('analysis fakes record requests and expose failures', () async {
      final transcription = FakeTranscriptionEngine()
        ..result = const Err(TranscriptionUnavailable('model_missing'));
      final language = FakeLanguageIdentificationEngine();
      final speakers = FakeSpeakerDiarizationEngine();
      addTearDown(transcription.dispose);
      final audio = AudioInput(
        sessionId: 'session-1',
        segmentPaths: ['one.pcm'],
      );

      expect(
        await transcription.transcribe(
          TranscriptionRequest(runId: 'run-1', audio: audio),
        ),
        isA<Err<TranscriptionOutput, TranscriptionFailure>>(),
      );
      await language.identify(
        LanguageIdentificationRequest(
          segmentId: 'segment-1',
          start: Duration.zero,
          end: const Duration(seconds: 1),
          audio: audio,
        ),
      );
      await speakers.analyze(SpeakerDiarizationRequest(audio: audio));

      expect(transcription.requests, hasLength(1));
      expect(language.requests, hasLength(1));
      expect(speakers.requests, hasLength(1));
    });

    test('transcription job fake records durable state changes', () async {
      final fake = FakeTranscriptionJobRepository();
      addTearDown(fake.dispose);
      const provenance = InferenceProvenance(
        engineId: 'whisper.cpp',
        engineVersion: '1',
        modelId: 'model-1',
        modelVersion: '1',
        modelSha256: 'hash',
        parametersJson: '{"parameterVersion":1}',
      );
      const run = TranscriptRun(
        id: 'run-1',
        meetingId: 'meeting-1',
        provenance: provenance,
        createdAtUtcMs: 1,
        state: AnalysisQueued(),
      );
      const job = ProcessingJob(
        id: 'job-1',
        meetingId: 'meeting-1',
        kind: ProcessingJobKind.transcription,
        createdAtUtcMs: 1,
        state: ProcessingQueued(),
        targetRunId: 'run-1',
        modelId: 'model-1',
      );

      expect(
        await fake.enqueue(job, run, storedAtUtcMs: 1),
        isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(
        (await fake.start(job.id, startedAtUtcMs: 2)
                as Ok<ProcessingJob, AnalysisRepositoryFailure>)
            .value
            .state,
        const ProcessingRunning(progress: 0),
      );
      expect(
        await fake.saveProgress(
          job.id,
          progress: 0.5,
          checkpoint: const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 5),
            parameterVersion: 1,
          ),
          storedAtUtcMs: 3,
        ),
        isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
      );

      expect(fake.enqueueCalls.single.job, job);
      expect(fake.startCalls.single.jobId, job.id);
      expect(fake.progressCalls.single.progress, 0.5);
      expect(
        (await fake.load(job.id)
                as Ok<ProcessingJob, AnalysisRepositoryFailure>)
            .value
            .transcriptionCheckpoint,
        const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 5),
          parameterVersion: 1,
        ),
      );
    });

    test('transcription checkpoints reject non-allowlisted shapes', () {
      expect(
        TranscriptionCheckpoint.tryParse(
          '{"completedMediaUs":5,"parameterVersion":1}',
        ),
        const TranscriptionCheckpoint(
          completedMedia: Duration(microseconds: 5),
          parameterVersion: 1,
        ),
      );
      expect(
        TranscriptionCheckpoint.tryParse(
          '{"completedMediaUs":5,"parameterVersion":1,"text":"secret"}',
        ),
        isNull,
      );
      expect(TranscriptionCheckpoint.tryParse('not-json'), isNull);
    });

    test('every fake exposes a typed failure path', () async {
      final audio = AudioInput(
        sessionId: 'session-1',
        segmentPaths: ['one.pcm'],
      );
      final language = FakeLanguageIdentificationEngine()
        ..result = const Err(
          LanguageIdentificationUnavailable('classifier_unavailable'),
        );
      final speakers = FakeSpeakerDiarizationEngine()
        ..result = const Err(SpeakerDiarizationUnavailable('model_missing'));
      final models = FakeModelManager()
        ..listResult = const Err(ModelUnavailable('manifest_invalid'));
      final performance = FakeThermalAndPerformanceMonitor()
        ..result = const Err(PerformanceUnavailable('metric_unavailable'));
      final sessions = FakeSessionRepository()
        ..listResult = const Err(
          SessionRepositoryUnavailable('database_unavailable'),
        );
      expect(
        await language.identify(
          LanguageIdentificationRequest(
            segmentId: 'segment-1',
            start: Duration.zero,
            end: const Duration(seconds: 1),
            audio: audio,
          ),
        ),
        isA<Err<LanguageIdentification, LanguageIdentificationFailure>>(),
      );
      expect(
        await speakers.analyze(SpeakerDiarizationRequest(audio: audio)),
        isA<Err<SpeakerDiarizationOutput, SpeakerDiarizationFailure>>(),
      );
      expect(
        await models.listInstalled(),
        isA<Err<ModelInventory, ModelFailure>>(),
      );
      expect(
        await performance.current(),
        isA<Err<DevicePerformanceSnapshot, PerformanceFailure>>(),
      );
      expect(
        await sessions.list(),
        isA<Err<SessionCollection, SessionRepositoryFailure>>(),
      );
    });

    test('capture fake emits live snapshots', () async {
      final capture = FakeAudioCaptureService();
      addTearDown(capture.dispose);
      final captureExpectation = expectLater(
        capture.snapshots,
        emits(
          isA<AudioCaptureSnapshot>().having(
            (snapshot) => snapshot.state,
            'state',
            AudioCaptureState.pausedByInterruption,
          ),
        ),
      );
      capture.emitSnapshot(
        const AudioCaptureSnapshot(
          state: AudioCaptureState.pausedByInterruption,
          elapsed: Duration(seconds: 3),
          bytesWritten: 16,
        ),
      );
      await captureExpectation;
    });

    test(
      'transcription exposes incremental draft progress and backlog',
      () async {
        final transcription = FakeTranscriptionEngine();
        addTearDown(transcription.dispose);
        const event = TranscriptionDraftUpdated(
          runId: 'run-1',
          chunk: TranscriptChunk(
            segmentId: 'segment-1',
            start: Duration.zero,
            end: Duration(seconds: 1),
            rawText: 'hello',
            displayText: 'hello',
            stability: TranscriptStability.unstable,
          ),
          backlog: Duration(seconds: 2),
        );
        final expectation = expectLater(
          transcription.eventsFor('run-1'),
          emits(same(event)),
        );

        transcription.emit(event);

        await expectation;
      },
    );

    test('storage and device fakes expose successful values', () async {
      final models = FakeModelManager();
      final performance = FakeThermalAndPerformanceMonitor();
      final sessions = FakeSessionRepository();
      final exports = FakeExportService()
        ..result = const Err(ExportUnavailable('destination_unavailable'));

      expect(
        await models.listInstalled(),
        isA<Ok<ModelInventory, ModelFailure>>(),
      );
      expect(
        await performance.current(),
        isA<Ok<DevicePerformanceSnapshot, PerformanceFailure>>(),
      );
      expect(performance.currentCalls, 1);
      expect(
        await sessions.list(),
        isA<Ok<SessionCollection, SessionRepositoryFailure>>(),
      );
      expect(
        await exports.export(
          const ExportRequest(
            operationId: 'export-test',
            createdAtUtcMs: 1,
            sessionId: 'session-1',
            format: ExportFormat.text,
          ),
        ),
        isA<Err<ExportReceipt, ExportFailure>>(),
      );
    });

    test(
      'snapshot stores monotonic cpu pss thermal energy and charging values',
      () {
        final snapshot = DevicePerformanceSnapshot(
          observedAtMonotonic: const Duration(milliseconds: 1000),
          processCpuTime: const Duration(milliseconds: 400),
          processPssBytes: 10000,
          thermalState: ThermalState.warm,
          remainingDeviceEnergyNanowattHours: 9000,
          isCharging: false,
        );

        expect(snapshot.observedAtMonotonic, const Duration(seconds: 1));
        expect(snapshot.processCpuTime, const Duration(milliseconds: 400));
        expect(snapshot.processPssBytes, 10000);
        expect(snapshot.thermalState, ThermalState.warm);
        expect(snapshot.remainingDeviceEnergyNanowattHours, 9000);
        expect(snapshot.isCharging, isFalse);
      },
    );

    test('snapshot constructor rejects negative and accepts int64 bounds', () {
      DevicePerformanceSnapshot build({
        Duration observedAtMonotonic = Duration.zero,
        Duration processCpuTime = Duration.zero,
        int processPssBytes = 0,
        int? remainingDeviceEnergyNanowattHours,
      }) => DevicePerformanceSnapshot(
        observedAtMonotonic: observedAtMonotonic,
        processCpuTime: processCpuTime,
        processPssBytes: processPssBytes,
        thermalState: ThermalState.nominal,
        remainingDeviceEnergyNanowattHours: remainingDeviceEnergyNanowattHours,
        isCharging: false,
      );

      expect(
        () => build(observedAtMonotonic: const Duration(microseconds: -1)),
        throwsAssertionError,
      );
      expect(
        () => build(processCpuTime: const Duration(microseconds: -1)),
        throwsAssertionError,
      );
      expect(() => build(processPssBytes: -1), throwsAssertionError);
      expect(
        () => build(processPssBytes: 9223372036854775807),
        returnsNormally,
      );
      expect(
        () => build(remainingDeviceEnergyNanowattHours: -1),
        throwsAssertionError,
      );
      expect(
        () => build(
          remainingDeviceEnergyNanowattHours: 9223372036854775807,
        ),
        returnsNormally,
      );
    });
  });

  test(
    'providers fail closed until production implementations are installed',
    () {
      final container = ProviderContainer.test();
      final throwsMissingImplementation = throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'wrapped exception',
          isA<UnimplementedError>(),
        ),
      );

      for (final read in <Object? Function()>[
        () => container.read(audioCaptureServiceProvider),
        () => container.read(transcriptionEngineProvider),
        () => container.read(languageIdentificationEngineProvider),
        () => container.read(speakerDiarizationEngineProvider),
        () => container.read(modelManagerProvider),
        () => container.read(thermalAndPerformanceMonitorProvider),
        () => container.read(sessionRepositoryProvider),
        () => container.read(transcriptionJobRepositoryProvider),
        () => container.read(exportServiceProvider),
      ]) {
        expect(read, throwsMissingImplementation);
      }
    },
  );

  test('providers can be overridden headlessly, including a fixed clock', () {
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    final instant = DateTime.utc(2026, 9, 28, 12);
    final container = ProviderContainer.test(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        clockProvider.overrideWithValue(Clock.fixed(instant)),
      ],
    );

    expect(container.read(audioCaptureServiceProvider), same(capture));
    expect(container.read(clockProvider).now(), instant);
  });
}
