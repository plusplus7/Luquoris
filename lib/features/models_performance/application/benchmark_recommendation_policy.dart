import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';

/// Applies versioned short-check thresholds without side effects.
final class BenchmarkRecommendationPolicy {
  /// Creates the version-1 recommendation policy.
  const BenchmarkRecommendationPolicy();

  /// Validates [report] and recommends the best eligible conservative mode.
  Result<BenchmarkRecommendation, BenchmarkFailure> recommend(
    PerformanceBenchmarkReport report,
  ) {
    if (!_validReport(report)) {
      return const Err<BenchmarkRecommendation, BenchmarkFailure>(
        BenchmarkInvalidOutput(),
      );
    }
    final byMode = <PerformanceMode, BenchmarkModeMeasurement>{
      for (final measurement in report.measurements)
        measurement.mode: measurement,
    };
    final candidates =
        <
          (
            PerformanceMode,
            bool Function(BenchmarkModeMeasurement),
            String,
          )
        >[
          (
            PerformanceMode.balanced,
            _balancedEligible,
            'benchmark_balanced_eligible',
          ),
          (
            PerformanceMode.powerSaving,
            _powerSavingEligible,
            'benchmark_power_saving_eligible',
          ),
          (
            PerformanceMode.postSession,
            _postSessionEligible,
            'benchmark_post_session_eligible',
          ),
        ];
    for (final (mode, isEligible, reasonCode) in candidates) {
      final measurement = byMode[mode];
      if (measurement != null && isEligible(measurement)) {
        return Ok<BenchmarkRecommendation, BenchmarkFailure>(
          BenchmarkRecommendation(
            mode: mode,
            reasonCodes: <String>[reasonCode],
            shortCheckOnly: true,
            evidence: measurement,
          ),
        );
      }
    }
    return Ok<BenchmarkRecommendation, BenchmarkFailure>(
      BenchmarkRecommendation(
        mode: PerformanceMode.recordingOnly,
        reasonCodes: const <String>['benchmark_no_ai_mode_eligible'],
        shortCheckOnly: true,
      ),
    );
  }
}

bool _validReport(PerformanceBenchmarkReport report) {
  if ((report.schemaVersion != 1 && report.schemaVersion != 2) ||
      report.policyVersion != 1 ||
      report.definition != firstRunBenchmarkDefinition ||
      report.engineId.trim().isEmpty ||
      report.engineVersion.trim().isEmpty ||
      report.modelId.trim().isEmpty ||
      report.modelVersion.trim().isEmpty ||
      report.configurationId.trim().isEmpty) {
    return false;
  }
  if (report.schemaVersion == 1 && report.resourceMetrics != null) {
    return false;
  }
  if (report.schemaVersion == 2 &&
      (report.resourceMetrics == null ||
          !_validResourceMetrics(report.resourceMetrics!))) {
    return false;
  }
  final modes = <PerformanceMode>{};
  for (final measurement in report.measurements) {
    if (!modes.add(measurement.mode) || !_validMeasurement(measurement)) {
      return false;
    }
  }
  return true;
}

bool _validMeasurement(BenchmarkModeMeasurement measurement) {
  final realTimeFactor = measurement.realTimeFactor;
  if (realTimeFactor != null &&
      (!realTimeFactor.isFinite || realTimeFactor < 0)) {
    return false;
  }
  final latency = measurement.firstTextLatency;
  if (latency != null && latency.isNegative) return false;
  final maximumBacklog = measurement.maximumBacklog;
  if (maximumBacklog != null &&
      (maximumBacklog < 0 || maximumBacklog > 9223372036854775807)) {
    return false;
  }
  return measurement.blockingReasonCodes.every(
    (reason) => reason.trim().isNotEmpty,
  );
}

bool _validResourceMetrics(BenchmarkResourceMetrics metrics) {
  final core = <Object?>[
    metrics.wallDuration,
    metrics.processCpuTime,
    metrics.maxSampledPssBytes,
    metrics.worstThermalState,
  ];
  final present = core.where((value) => value != null).length;
  if (present != 0 && present != core.length) return false;
  if (metrics.wallDuration case final value?) {
    if (value <= Duration.zero) return false;
  }
  if (metrics.processCpuTime case final value?) {
    if (value.isNegative) return false;
  }
  if (metrics.maxSampledPssBytes case final value?) {
    if (value < 0 || value > 9223372036854775807) return false;
  }
  if (metrics.deviceEnergyUsedNanowattHours case final value?) {
    if (present == 0 || value < 0 || value > 9223372036854775807) {
      return false;
    }
  }
  if (metrics.unavailableReasonCodes.any(
    (reason) => reason.trim().isEmpty,
  )) {
    return false;
  }
  if (present == 0) return metrics.unavailableReasonCodes.isNotEmpty;
  return metrics.deviceEnergyUsedNanowattHours != null ||
      metrics.unavailableReasonCodes.isNotEmpty;
}

bool _baseEligible(BenchmarkModeMeasurement measurement) =>
    measurement.status == BenchmarkMeasurementStatus.measured &&
    measurement.blockingReasonCodes.isEmpty;

bool _balancedEligible(BenchmarkModeMeasurement measurement) => _liveEligible(
  measurement,
  maximumRealTimeFactor: 0.8,
  maximumFirstTextLatency: const Duration(seconds: 5),
);

bool _powerSavingEligible(BenchmarkModeMeasurement measurement) =>
    _liveEligible(
      measurement,
      maximumRealTimeFactor: 1.2,
      maximumFirstTextLatency: const Duration(seconds: 12),
    );

bool _liveEligible(
  BenchmarkModeMeasurement measurement, {
  required double maximumRealTimeFactor,
  required Duration maximumFirstTextLatency,
}) {
  final realTimeFactor = measurement.realTimeFactor;
  final latency = measurement.firstTextLatency;
  return _baseEligible(measurement) &&
      realTimeFactor != null &&
      realTimeFactor <= maximumRealTimeFactor &&
      latency != null &&
      latency <= maximumFirstTextLatency;
}

bool _postSessionEligible(BenchmarkModeMeasurement measurement) {
  final realTimeFactor = measurement.realTimeFactor;
  return _baseEligible(measurement) &&
      realTimeFactor != null &&
      realTimeFactor <= 1;
}
