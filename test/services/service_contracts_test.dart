import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
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
      addTearDown(performance.dispose);

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

    test('capture and performance fakes emit live snapshots', () async {
      final capture = FakeAudioCaptureService();
      final performance = FakeThermalAndPerformanceMonitor();
      addTearDown(capture.dispose);
      addTearDown(performance.dispose);
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
      final performanceExpectation = expectLater(
        performance.snapshots,
        emits(
          isA<DevicePerformanceSnapshot>().having(
            (snapshot) => snapshot.thermalState,
            'thermal state',
            ThermalState.hot,
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
      performance.emitSnapshot(
        const DevicePerformanceSnapshot(
          thermalState: ThermalState.hot,
          processMemoryBytes: 32,
        ),
      );

      await Future.wait([captureExpectation, performanceExpectation]);
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
      addTearDown(performance.dispose);

      expect(
        await models.listInstalled(),
        isA<Ok<ModelInventory, ModelFailure>>(),
      );
      expect(
        await performance.current(),
        isA<Ok<DevicePerformanceSnapshot, PerformanceFailure>>(),
      );
      expect(
        await sessions.list(),
        isA<Ok<SessionCollection, SessionRepositoryFailure>>(),
      );
      expect(
        await exports.export(
          const ExportRequest(
            sessionId: 'session-1',
            format: ExportFormat.text,
          ),
        ),
        isA<Err<ExportReceipt, ExportFailure>>(),
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
