import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:loquiris/data/files/private_meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_backup_record_repository.dart';
import 'package:loquiris/data/repositories/drift_export_record_repository.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/export_backup/application/backup_service_provider.dart';
import 'package:loquiris/features/export_backup/application/drift_backup_snapshot_planner.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/application/local_benchmark_report_exporter.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';
import 'package:loquiris/features/export_backup/application/restore_service_provider.dart';
import 'package:loquiris/features/models_performance/application/asset_bundle_model_artifact_source.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/native/method_channel_backup_gateway.dart';
import 'package:loquiris/native/method_channel_export_destination_gateway.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/native/method_channel_session_playback_service.dart';
import 'package:loquiris/native/method_channel_storage_metrics_service.dart';
import 'package:loquiris/native/method_channel_thermal_and_performance_monitor.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/native/recording_recovery_gateway.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide work that must react to process lifecycle transitions.
abstract interface class AppLifecycleActions {
  /// Flushes pending durable state before the process can be killed.
  Future<void> flush();

  /// Refreshes time-sensitive state after returning to the foreground.
  void refresh();
}

final class _NoopAppLifecycleActions implements AppLifecycleActions {
  const _NoopAppLifecycleActions();

  @override
  Future<void> flush() async {}

  @override
  void refresh() {}
}

/// Lifecycle actions installed by the composition root.
final appLifecycleActionsProvider = Provider<AppLifecycleActions>(
  (ref) => throw UnimplementedError('AppLifecycleActions is not installed'),
);

/// Local diagnostic sink installed before application infrastructure opens.
final diagnosticLogSinkProvider = Provider<DiagnosticLogSink>(
  (ref) => throw UnimplementedError('DiagnosticLogSink is not installed'),
);

final _applicationDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase is not installed'),
);

/// Dependencies constructed before the Flutter widget tree starts.
final class AppDependencies {
  /// Creates production dependencies and explicit provider [overrides].
  AppDependencies({
    required this.diagnosticLogSink,
    required this.lifecycleActions,
    List<Override> overrides = const [],
  }) : overrides = List.unmodifiable(overrides);

  /// Creates isolated dependencies for widget and integration tests.
  factory AppDependencies.test({List<Override> overrides = const []}) {
    return AppDependencies(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      lifecycleActions: const _NoopAppLifecycleActions(),
      overrides: overrides,
    );
  }

  /// App-private, structured diagnostic sink.
  final DiagnosticLogSink diagnosticLogSink;

  /// Root lifecycle coordinator.
  final AppLifecycleActions lifecycleActions;

  /// Concrete boundary implementations installed at the root scope.
  final List<Override> overrides;
}

/// Constructs application infrastructure without loading optional AI engines.
Future<AppDependencies> bootstrap({
  required DiagnosticLogSink diagnosticLogSink,
  Future<AppDatabase> Function() openDatabase = openApplicationDatabase,
  Future<Directory> Function() resolveSupportDirectory =
      getApplicationSupportDirectory,
  bool cleanIncompleteBackups = true,
  RecordingRecoveryGateway recoveryGateway =
      const MethodChannelRecordingRecoveryGateway(),
  int Function()? observedAtUtcMs,
  AssetBundle? modelAssetBundle,
}) async {
  final database = await openDatabase();
  final startupObservedAtUtcMs =
      observedAtUtcMs?.call() ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final sessionRepository = DriftSessionRepository(
    database,
    audioStore: PrivateMeetingAudioStore(resolveSupportDirectory),
    diagnosticSink: diagnosticLogSink,
  );
  final exportRecordRepository = DriftExportRecordRepository(
    database,
    diagnosticSink: diagnosticLogSink,
  );
  final backupRecordRepository = DriftBackupRecordRepository(
    database,
    diagnosticSink: diagnosticLogSink,
  );
  final modelRepository = DriftModelRepository(
    database,
    diagnosticSink: diagnosticLogSink,
  );
  final modelBundle = modelAssetBundle ?? rootBundle;
  final modelCatalog = await AssetBundleModelManifestCatalog(
    bundle: modelBundle,
  ).load();
  final registeredManifests = <BundledModelManifest>[];
  if (modelCatalog case Ok(:final value)) {
    for (final manifest in value) {
      final registered = await modelRepository.registerBundled(
        manifest.toInstalledModel(),
        observedAtUtcMs: startupObservedAtUtcMs,
      );
      if (registered case Ok()) registeredManifests.add(manifest);
    }
  }
  final transcriptionManifest = registeredManifests
      .where((manifest) => manifest.id == 'whisper-base-q5_1')
      .firstOrNull;
  final modelManager = RuntimeModelManager(
    manifests: registeredManifests,
    artifactSource: AssetBundleModelArtifactSource(bundle: modelBundle),
  );
  final exportDestinationGateway = MethodChannelExportDestinationGateway(
    diagnosticSink: diagnosticLogSink,
  );
  await exportRecordRepository.failInterruptedPending(
    updatedAtUtcMs: startupObservedAtUtcMs,
  );
  await backupRecordRepository.failInterruptedPending(
    updatedAtUtcMs: startupObservedAtUtcMs,
  );
  if (cleanIncompleteBackups) {
    await PrivateBackupStartupCleaner(
      resolveSupportDirectory,
      database,
    ).clean();
  }
  final inventory = await recoveryGateway.scan();
  switch (inventory) {
    case Ok(:final value):
      if (value.issueCodes.isNotEmpty) {
        diagnosticLogSink.record(
          const DiagnosticEvent(
            code: DiagnosticCode.startupRecoveryFailed,
            errorType: _NativeRecoveryInventoryIssue,
          ),
        );
      }
      final reconciliation = await sessionRepository.reconcileRecovery(
        value.sessions,
        observedAtUtcMs: startupObservedAtUtcMs,
        liveMeetingIds: value.liveMeetingIds,
        invalidStorageKeys: value.invalidStorageKeys,
      );
      if (reconciliation case Err(:final failure)) {
        diagnosticLogSink.record(
          DiagnosticEvent(
            code: DiagnosticCode.startupRecoveryFailed,
            errorType: failure.runtimeType,
          ),
        );
      }
    case Err(:final failure):
      diagnosticLogSink.record(
        DiagnosticEvent(
          code: DiagnosticCode.startupRecoveryFailed,
          errorType: failure.runtimeType,
        ),
      );
  }
  return AppDependencies(
    diagnosticLogSink: diagnosticLogSink,
    lifecycleActions: const _NoopAppLifecycleActions(),
    overrides: [
      thermalAndPerformanceMonitorProvider.overrideWith(
        (ref) => const MethodChannelThermalAndPerformanceMonitor(),
      ),
      performanceBenchmarkRunnerProvider.overrideWith(
        (ref) => const UnavailablePerformanceBenchmarkRunner(),
      ),
      benchmarkReportExporterProvider.overrideWith(
        (ref) => LocalBenchmarkReportExporter(
          destinationGateway: exportDestinationGateway,
        ),
      ),
      audioCaptureServiceProvider.overrideWith(
        (ref) => NativeAudioCaptureService(
          const MethodChannelRecordingControlGateway(),
        ),
      ),
      sessionPlaybackServiceProvider.overrideWith(
        (ref) => const MethodChannelSessionPlaybackService(),
      ),
      storageMetricsServiceProvider.overrideWith(
        (ref) => const MethodChannelStorageMetricsService(),
      ),
      rebuildableCacheServiceProvider.overrideWith(
        (ref) => const MethodChannelStorageMetricsService(),
      ),
      _applicationDatabaseProvider.overrideWith((ref) {
        ref.onDispose(database.close);
        return database;
      }),
      sessionRepositoryProvider.overrideWith((ref) {
        ref.watch(_applicationDatabaseProvider);
        return sessionRepository;
      }),
      transcriptRepositoryProvider.overrideWith(
        (ref) => DriftTranscriptRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
      transcriptionJobRepositoryProvider.overrideWith(
        (ref) => DriftTranscriptionJobRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
      modelRepositoryProvider.overrideWithValue(modelRepository),
      modelManagerProvider.overrideWithValue(modelManager),
      transcriptionEngineProvider.overrideWith(
        (ref) => MethodChannelTranscriptionEngine(),
      ),
      if (transcriptionManifest != null)
        transcriptionModelManifestProvider.overrideWithValue(
          transcriptionManifest,
        ),
      revisionRepositoryProvider.overrideWith(
        (ref) => DriftRevisionRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
      exportServiceProvider.overrideWith(
        (ref) => LocalExportService(
          sessionRepository: ref.watch(sessionRepositoryProvider),
          transcriptRepository: ref.watch(transcriptRepositoryProvider),
          destinationGateway: exportDestinationGateway,
          exportRecordRepository: exportRecordRepository,
          nowUtcMs: () => DateTime.now().toUtc().millisecondsSinceEpoch,
          latestFailedExport: exportRecordRepository.latestFailedForMeeting,
        ),
      ),
      backupServiceProvider.overrideWith(
        (ref) => LocalBackupService(
          snapshotPlanner: DriftBackupSnapshotPlanner(
            ref.watch(_applicationDatabaseProvider),
            resolveSupportDirectory,
          ),
          gateway: MethodChannelBackupGateway(
            diagnosticSink: diagnosticLogSink,
          ),
          recordRepository: backupRecordRepository,
          artifactCleaner: PrivateBackupArtifactCleaner(
            resolveSupportDirectory,
          ),
          schemaVersion: database.schemaVersion,
          nowUtcMs: () => DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      ),
      restoreServiceProvider.overrideWith(
        (ref) => LocalRestoreService(
          liveDatabase: ref.watch(_applicationDatabaseProvider),
          gateway: MethodChannelBackupGateway(
            diagnosticSink: diagnosticLogSink,
          ),
          resolveBaseDirectory: resolveSupportDirectory,
        ),
      ),
      exportFailureHistoryProvider.overrideWith(
        (ref) {
          final service = ref.watch(exportServiceProvider);
          return service is LocalExportService
              ? service.latestFailureForMeeting
              : (meetingId) async => const Ok(null);
        },
      ),
    ],
  );
}

/// Builds the single dependency-injection root used by production and tests.
Widget buildLoquirisRoot({
  required AppDependencies dependencies,
  required Widget child,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      diagnosticLogSinkProvider.overrideWithValue(
        dependencies.diagnosticLogSink,
      ),
      appLifecycleActionsProvider.overrideWithValue(
        dependencies.lifecycleActions,
      ),
      ...dependencies.overrides,
    ],
    child: child,
  );
}

/// Owns the one application lifecycle observer.
mixin RootLifecycleObserver<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final WidgetsBindingObserver _observer = _RootObserver(
    onStateChanged: _onLifecycleStateChanged,
  );

  /// Registers the root lifecycle observer.
  void registerRootLifecycleObserver() {
    WidgetsBinding.instance.addObserver(_observer);
  }

  /// Removes the root lifecycle observer.
  void unregisterRootLifecycleObserver() {
    WidgetsBinding.instance.removeObserver(_observer);
  }

  void _onLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_flushDurableState());
      case AppLifecycleState.resumed:
        ref.read(appLifecycleActionsProvider).refresh();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _flushDurableState() async {
    try {
      await ref.read(appLifecycleActionsProvider).flush();
    } on Object catch (error) {
      ref
          .read(diagnosticLogSinkProvider)
          .record(
            DiagnosticEvent(
              code: DiagnosticCode.lifecycleFlushFailed,
              errorType: error.runtimeType,
            ),
          );
    }
  }
}

final class _NativeRecoveryInventoryIssue {}

final class _RootObserver with WidgetsBindingObserver {
  _RootObserver({required this.onStateChanged});

  final void Function(AppLifecycleState state) onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
