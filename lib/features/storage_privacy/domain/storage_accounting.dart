import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:meta/meta.dart';

/// Raw, non-overlapping totals reported for this application by Android.
@immutable
final class PlatformStorageMetrics {
  /// Creates a validated platform storage observation.
  const PlatformStorageMetrics({
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
    required this.availableBytes,
  }) : assert(appBytes >= 0, 'appBytes must be non-negative'),
       assert(dataBytes >= 0, 'dataBytes must be non-negative'),
       assert(cacheBytes >= 0, 'cacheBytes must be non-negative'),
       assert(availableBytes >= 0, 'availableBytes must be non-negative');

  /// Installed APK, native libraries, and compiled application code.
  final int appBytes;

  /// Private application data, including cache.
  final int dataBytes;

  /// Rebuildable private data included in [dataBytes].
  final int cacheBytes;

  /// Bytes Android reports as available to this application.
  final int availableBytes;
}

/// Recoverable failures produced by the native metrics boundary.
sealed class StorageMetricsFailure implements Failure {
  const StorageMetricsFailure(this.code);

  @override
  final String code;
}

/// Android storage metrics could not be measured safely.
final class StorageMetricsUnavailable extends StorageMetricsFailure {
  /// Creates a failure with a stable, privacy-safe [code].
  const StorageMetricsUnavailable(super.code);
}

/// Native boundary for measuring storage owned by this application.
// The interface is intentional: platform work must remain injectable.
// ignore: one_member_abstracts
abstract interface class StorageMetricsService {
  /// Measures current application and device-space totals.
  Future<Result<PlatformStorageMetrics, StorageMetricsFailure>> measure();
}

/// Explainable storage categories shown to the user.
@immutable
final class StorageAccountingSnapshot {
  /// Creates an immutable storage accounting observation.
  const StorageAccountingSnapshot({
    required this.applicationAndModelsBytes,
    required this.bundledModelBytes,
    required this.activeMeetingBytes,
    required this.rebuildableCacheBytes,
    required this.trashBytes,
    required this.availableDeviceBytes,
  });

  /// Application code plus private data not assigned to another category.
  final int applicationAndModelsBytes;

  /// Manifest-declared model bytes, already included in the category above.
  final int bundledModelBytes;

  /// Authoritative committed audio outside local trash.
  final int activeMeetingBytes;

  /// Rebuildable cache included in Android's private-data total.
  final int rebuildableCacheBytes;

  /// Authoritative committed audio retained in local trash.
  final int trashBytes;

  /// Space Android reports as available to this application.
  final int availableDeviceBytes;
}

/// Recoverable failure while assembling explainable storage accounting.
final class StorageAccountingFailure implements Failure {
  /// Creates an accounting failure preserving its originating stable [code].
  const StorageAccountingFailure(this.code);

  @override
  final String code;
}
