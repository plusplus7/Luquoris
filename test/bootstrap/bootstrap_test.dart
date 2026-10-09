import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/data/database/app_database.dart' hide Meeting;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/export_backup/application/local_benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/native/method_channel_thermal_and_performance_monitor.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';

void main() {
  testWidgets('production bootstrap installs local session persistence', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final dependencies = await bootstrap(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      openDatabase: () async => database,
      modelAssetBundle: _modelAssetBundle(),
    );

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: Consumer(
          builder: (context, ref, child) {
            final installed =
                ref.read(sessionRepositoryProvider) is DriftSessionRepository &&
                ref.read(transcriptRepositoryProvider)
                    is DriftTranscriptRepository &&
                ref.read(transcriptionJobRepositoryProvider)
                    is DriftTranscriptionJobRepository &&
                ref.read(modelRepositoryProvider) is DriftModelRepository &&
                ref.read(modelManagerProvider) is RuntimeModelManager &&
                ref.read(transcriptionEngineProvider)
                    is MethodChannelTranscriptionEngine &&
                ref.read(revisionRepositoryProvider) is DriftRevisionRepository;
            final benchmarkInstalled =
                ref.read(performanceBenchmarkRunnerProvider)
                    is UnavailablePerformanceBenchmarkRunner;
            final performanceMonitorInstalled =
                ref.read(thermalAndPerformanceMonitorProvider)
                    is MethodChannelThermalAndPerformanceMonitor;
            final benchmarkExporterInstalled =
                ref.read(benchmarkReportExporterProvider)
                    is LocalBenchmarkReportExporter;
            return Text(
              installed &&
                      benchmarkInstalled &&
                      performanceMonitorInstalled &&
                      benchmarkExporterInstalled
                  ? 'installed'
                  : 'missing',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );

    expect(find.text('installed'), findsOneWidget);
    expect(
      await database
          .customSelect('SELECT COUNT(*) AS count FROM model_manifests')
          .map(
            (row) => row.read<int>('count'),
          )
          .getSingle(),
      1,
    );
  });

  testWidgets('root scope installs explicit test overrides', (tester) async {
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    final dependencies = AppDependencies.test(
      overrides: [audioCaptureServiceProvider.overrideWithValue(capture)],
    );

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: Consumer(
          builder: (context, ref, child) {
            return Text(
              identical(ref.read(audioCaptureServiceProvider), capture)
                  ? 'overridden'
                  : 'wrong',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );

    expect(find.text('overridden'), findsOneWidget);
  });

  testWidgets('Loquiris app renders the offline shell', (tester) async {
    final capture = FakeAudioCaptureService();
    final jobs = FakeTranscriptionJobRepository();
    addTearDown(capture.dispose);
    addTearDown(jobs.dispose);
    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: AppDependencies.test(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(
              FakeSessionRepository(),
            ),
            transcriptionJobRepositoryProvider.overrideWithValue(jobs),
          ],
        ),
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No meetings yet'), findsOneWidget);
    expect(find.text('Start a recording'), findsOneWidget);
  });

  testWidgets('root observer flushes on pause and refreshes on resume', (
    tester,
  ) async {
    final lifecycle = _RecordingLifecycleActions();
    final capture = FakeAudioCaptureService();
    final jobs = FakeTranscriptionJobRepository();
    addTearDown(capture.dispose);
    addTearDown(jobs.dispose);
    final dependencies = AppDependencies(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      lifecycleActions: lifecycle,
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        transcriptionJobRepositoryProvider.overrideWithValue(jobs),
      ],
    );
    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: const LoquirisApp(),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    expect(lifecycle.flushCalls, 1);
    expect(lifecycle.refreshCalls, 1);
  });

  testWidgets('app forwards authoritative finalization to transcription', (
    tester,
  ) async {
    final capture = FakeAudioCaptureService();
    final jobs = FakeTranscriptionJobRepository();
    final repository = FakeSessionRepository()
      ..savedMeetings.add(
        const Meeting(
          id: 'meeting-1',
          title: 'Meeting',
          createdAtUtcMs: 1,
          mediaDuration: Duration.zero,
          lifecycle: MeetingLifecycle.preparing,
          languageMode: MeetingLanguageMode.mixed,
        ),
      );
    final finalizedMeetingIds = <String>[];
    addTearDown(capture.dispose);
    addTearDown(jobs.dispose);

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: AppDependencies.test(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(repository),
            transcriptionJobRepositoryProvider.overrideWithValue(jobs),
            transcriptionFinalizationHandlerProvider.overrideWithValue(
              finalizedMeetingIds.add,
            ),
          ],
        ),
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();

    capture.emitSnapshot(
      const AudioCaptureSnapshot(
        sessionId: 'meeting-1',
        state: AudioCaptureState.finalized,
        elapsed: Duration(minutes: 5),
        bytesWritten: 2400,
        revision: 10,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.synchronizedRecordingProgress, hasLength(1));
    expect(finalizedMeetingIds, <String>['meeting-1']);
  });
}

AssetBundle _modelAssetBundle() => _MemoryAssetBundle(<String, Uint8List>{
  'build/generated/model_assets/model_manifests/index.json': _jsonBytes(
    <String, Object?>{
      'schemaVersion': 1,
      'manifests': <Object?>[
        'model_manifests/whisper-base-q5_1.json',
      ],
    },
  ),
  'build/generated/model_assets/model_manifests/whisper-base-q5_1.json':
      _jsonBytes(<String, Object?>{
        'schemaVersion': 1,
        'id': 'whisper-base-q5_1',
        'version': 'model-commit',
        'source': 'https://example.test/model.bin',
        'artifactPath': 'models/whisper-base-q5_1/model.bin',
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
      }),
});

Uint8List _jsonBytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

final class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('asset missing');
    return ByteData.sublistView(bytes);
  }
}

final class _RecordingLifecycleActions implements AppLifecycleActions {
  int flushCalls = 0;
  int refreshCalls = 0;

  @override
  Future<void> flush() async {
    flushCalls += 1;
  }

  @override
  void refresh() {
    refreshCalls += 1;
  }
}
