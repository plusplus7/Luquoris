import 'dart:math' as math;

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Reads one native application-storage observation.
typedef PlatformStorageMetricsReader =
    Future<Result<PlatformStorageMetrics, StorageMetricsFailure>> Function();

/// Reads authoritative meeting audio grouped by lifecycle.
typedef SessionStorageReader =
    Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
    Function();

/// Reads manifests for models installed with the application.
typedef InstalledModelsReader =
    Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>> Function();

/// Reconciles native totals with authoritative local ownership records.
final class StorageAccountingLoader {
  /// Creates a loader from independently injectable read boundaries.
  const StorageAccountingLoader({
    required this.readPlatformMetrics,
    required this.readSessionStorage,
    required this.readInstalledModels,
  });

  /// Native application and available-space reader.
  final PlatformStorageMetricsReader readPlatformMetrics;

  /// Canonical meeting-audio reader.
  final SessionStorageReader readSessionStorage;

  /// Installed-model manifest reader.
  final InstalledModelsReader readInstalledModels;

  /// Loads every source concurrently and produces non-negative categories.
  Future<Result<StorageAccountingSnapshot, StorageAccountingFailure>>
  load() async {
    final metricsFuture = readPlatformMetrics();
    final sessionsFuture = readSessionStorage();
    final modelsFuture = readInstalledModels();

    final metricsResult = await metricsFuture;
    final sessionsResult = await sessionsFuture;
    final modelsResult = await modelsFuture;

    late final PlatformStorageMetrics metrics;
    switch (metricsResult) {
      case Ok(:final value):
        metrics = value;
      case Err(:final failure):
        return Err(StorageAccountingFailure(failure.code));
    }
    late final SessionStorageAccounting sessions;
    switch (sessionsResult) {
      case Ok(:final value):
        sessions = value;
      case Err(:final failure):
        return Err(StorageAccountingFailure(failure.code));
    }
    late final List<InstalledModel> models;
    switch (modelsResult) {
      case Ok(:final value):
        models = value;
      case Err(:final failure):
        return Err(StorageAccountingFailure(failure.code));
    }

    final explainedPrivateBytes =
        metrics.cacheBytes + sessions.totalMeetingBytes;
    final residualPrivateBytes = math.max(
      0,
      metrics.dataBytes - explainedPrivateBytes,
    );
    return Ok(
      StorageAccountingSnapshot(
        applicationAndModelsBytes: metrics.appBytes + residualPrivateBytes,
        bundledModelBytes: models.fold<int>(
          0,
          (total, model) => total + model.bytes,
        ),
        activeMeetingBytes: sessions.activeMeetingBytes,
        rebuildableCacheBytes: metrics.cacheBytes,
        trashBytes: sessions.trashBytes,
        availableDeviceBytes: metrics.availableBytes,
      ),
    );
  }
}
