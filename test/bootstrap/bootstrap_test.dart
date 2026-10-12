import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' hide Meeting;
import 'package:loquiris/data/files/private_meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/export_backup/application/backup_service_provider.dart';
import 'package:loquiris/features/export_backup/application/drift_backup_snapshot_planner.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/application/local_benchmark_report_exporter.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';
import 'package:loquiris/features/export_backup/application/restore_service_provider.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/recording/application/recording_inventory_synchronizer.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/native/method_channel_thermal_and_performance_monitor.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/native/recording_recovery_gateway.dart';
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
      cleanIncompleteBackups: false,
      modelAssetBundle: _modelAssetBundle(),
      recoveryGateway: _FakeRecordingRecoveryGateway(
        RecordingRecoveryInventory(
          sessions: const [],
          deletedIncompleteDerivedFiles: 0,
          issueCodes: const [],
        ),
      ),
    );

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: Consumer(
          builder: (context, ref, child) {
            final installed =
                ref.read(audioCaptureServiceProvider)
                    is NativeAudioCaptureService &&
                ref.read(sessionRepositoryProvider) is DriftSessionRepository &&
                ref.read(transcriptRepositoryProvider)
                    is DriftTranscriptRepository &&
                ref.read(transcriptionJobRepositoryProvider)
                    is DriftTranscriptionJobRepository &&
                ref.read(modelRepositoryProvider) is DriftModelRepository &&
                ref.read(modelManagerProvider) is RuntimeModelManager &&
                ref.read(transcriptionEngineProvider)
                    is MethodChannelTranscriptionEngine &&
                ref.read(revisionRepositoryProvider)
                    is DriftRevisionRepository &&
                ref.read(exportServiceProvider) is LocalExportService &&
                ref.read(backupServiceProvider) is LocalBackupService &&
                ref.read(restoreServiceProvider) is LocalRestoreService &&
                ref.read(benchmarkReportExporterProvider)
                    is LocalBenchmarkReportExporter;
            final benchmarkInstalled =
                ref.read(performanceBenchmarkRunnerProvider)
                    is UnavailablePerformanceBenchmarkRunner;
            final performanceMonitorInstalled =
                ref.read(thermalAndPerformanceMonitorProvider)
                    is MethodChannelThermalAndPerformanceMonitor;
            return Text(
              installed && benchmarkInstalled && performanceMonitorInstalled
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

  test('bootstrap reconciles native inventory before returning', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final recoveryGateway = _FakeRecordingRecoveryGateway(
      RecordingRecoveryInventory(
        sessions: [
          RecordingRecoverySessionEvidence(
            meetingId: 'recovered-meeting',
            storageKey: 'hash',
            segments: [
              SessionRecoverySegmentEvidence(
                sequence: 0,
                relativePath: _recoveryPath(
                  'recordings/hash/segment-00000.adts',
                ),
                mediaStart: Duration.zero,
                mediaDuration: const Duration(seconds: 2),
                committedBytes: 20,
                state: AudioSegmentState.committed,
              ),
            ],
          ),
        ],
        deletedIncompleteDerivedFiles: 0,
        issueCodes: const [],
      ),
    );

    await bootstrap(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      openDatabase: () async => database,
      cleanIncompleteBackups: false,
      recoveryGateway: recoveryGateway,
      observedAtUtcMs: () => 100,
    );

    final row = await database
        .customSelect(
          "SELECT lifecycle FROM meetings WHERE id = 'recovered-meeting'",
        )
        .getSingle();
    expect(row.read<String>('lifecycle'), 'recoverable');
  });

  test('bootstrap records privacy-safe native recovery issues', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final diagnostics = _RecordingDiagnosticSink();

    await bootstrap(
      diagnosticLogSink: diagnostics,
      openDatabase: () async => database,
      cleanIncompleteBackups: false,
      recoveryGateway: _FakeRecordingRecoveryGateway(
        RecordingRecoveryInventory(
          sessions: const [],
          deletedIncompleteDerivedFiles: 1,
          issueCodes: const ['manifest_invalid'],
        ),
      ),
      observedAtUtcMs: () => 100,
    );

    expect(
      diagnostics.events.map((event) => event.code),
      [DiagnosticCode.startupRecoveryFailed],
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
    expect(capture.currentCalls, 1);

    capture.emitSnapshot(
      const AudioCaptureSnapshot(
        sessionId: 'background-meeting',
        state: AudioCaptureState.recording,
        elapsed: Duration(seconds: 2),
        bytesWritten: 128,
        revision: 2,
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoquirisApp)),
    );
    expect(
      container
          .read(recordingControllerProvider)
          .requireValue
          .snapshot
          ?.revision,
      2,
    );
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
    final inventory = _ControlledRecordingInventorySynchronizer();
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
            recordingInventorySynchronizerProvider.overrideWithValue(
              inventory,
            ),
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
    await tester.pump();
    capture.emitSnapshot(
      const AudioCaptureSnapshot(
        sessionId: 'meeting-1',
        state: AudioCaptureState.finalized,
        elapsed: Duration(minutes: 5),
        bytesWritten: 2400,
        revision: 10,
      ),
    );
    await tester.pump();

    expect(inventory.calls, 1);
    expect(finalizedMeetingIds, isEmpty);

    inventory.complete(const Ok(null));
    await tester.pumpAndSettle();

    expect(repository.synchronizedRecordingProgress, hasLength(1));
    expect(inventory.calls, 1);
    expect(finalizedMeetingIds, <String>['meeting-1']);
  });

  test(
    'fresh finalization inventories Drift audio for transcription and backup',
    () async {
      const storageKey =
          '4fe1c071bc5c3a334a142da5de7ce6e370df307d6c63c689890a41f09ab6350c';
      final database = AppDatabase(NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'loquiris-fresh-finalization-',
      );
      final repository = DriftSessionRepository(
        database,
        audioStore: PrivateMeetingAudioStore(() async => directory),
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      final capture = FakeAudioCaptureService();
      final gateway = _FakeRecordingRecoveryGateway(
        RecordingRecoveryInventory(
          sessions: [
            RecordingRecoverySessionEvidence(
              meetingId: 'meeting-1',
              storageKey: storageKey,
              segments: [
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _recoveryPath(
                    'recordings/$storageKey/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(minutes: 5),
                  committedBytes: 2400,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
          ],
          deletedIncompleteDerivedFiles: 0,
          issueCodes: const [],
        ),
      );
      final synchronizer = NativeRecordingInventorySynchronizer(
        recoveryGateway: gateway,
        sessionRepository: repository,
        nowUtcMs: () => 3,
      );
      final container = ProviderContainer.test(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
          recordingInventorySynchronizerProvider.overrideWithValue(
            synchronizer,
          ),
        ],
      );
      final ready = Completer<void>();
      final subscription = container.listen(recordingControllerProvider, (
        previous,
        next,
      ) {
        final value = next.value;
        if (value?.snapshot?.state == AudioCaptureState.finalized &&
            value?.persistencePending == false &&
            !ready.isCompleted) {
          ready.complete();
        }
      });
      addTearDown(capture.dispose);
      addTearDown(subscription.close);
      addTearDown(container.dispose);
      addTearDown(database.close);
      addTearDown(() => directory.delete(recursive: true));
      await repository.saveMeeting(
        const Meeting(
          id: 'meeting-1',
          title: 'Meeting',
          createdAtUtcMs: 1,
          mediaDuration: Duration.zero,
          lifecycle: MeetingLifecycle.preparing,
          languageMode: MeetingLanguageMode.mixed,
        ),
      );

      await container.read(recordingControllerProvider.future);

      capture.emitSnapshot(
        const AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.finalized,
          elapsed: Duration(minutes: 5),
          bytesWritten: 2400,
          revision: 10,
        ),
      );
      await ready.future.timeout(const Duration(seconds: 5));
      final backup = await DriftBackupSnapshotPlanner(
        database,
        () async => directory,
      ).create('fresh_recording');

      expect(
        container.read(recordingControllerProvider).requireValue,
        isA<RecordingViewState>()
            .having((state) => state.persistencePending, 'pending', isFalse)
            .having((state) => state.persistenceFailure, 'failure', isNull),
      );
      expect(
        (backup as Ok<BackupSnapshotPlan, BackupFailure>)
            .value
            .audioPlan
            .single
            .relativePath,
        'recordings/$storageKey/segment-00000.adts',
      );
    },
  );
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

final class _FakeRecordingRecoveryGateway implements RecordingRecoveryGateway {
  _FakeRecordingRecoveryGateway(this.inventory);

  final RecordingRecoveryInventory inventory;

  @override
  Future<Result<RecordingRecoveryInventory, RecordingRecoveryFailure>>
  scan() async => Ok(inventory);
}

final class _ControlledRecordingInventorySynchronizer
    implements RecordingInventorySynchronizer {
  final Completer<Result<void, SessionRepositoryFailure>> _completion =
      Completer<Result<void, SessionRepositoryFailure>>();
  int calls = 0;

  @override
  Future<Result<void, SessionRepositoryFailure>> synchronize() {
    calls += 1;
    return _completion.future;
  }

  void complete(Result<void, SessionRepositoryFailure> result) {
    _completion.complete(result);
  }
}

AppRelativePath _recoveryPath(String value) =>
    AppRelativePath.tryParse(value).fold(
      (path) => path,
      (failure) => throw TestFailure('Invalid path: ${failure.code}'),
    );

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

final class _RecordingDiagnosticSink implements DiagnosticLogSink {
  final List<DiagnosticEvent> events = [];

  @override
  void record(DiagnosticEvent event) => events.add(event);
}
