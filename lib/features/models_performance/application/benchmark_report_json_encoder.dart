import 'dart:convert';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Converts a validated benchmark report into deterministic allowlisted JSON.
final class BenchmarkReportJsonEncoder {
  /// Creates the stateless encoder.
  const BenchmarkReportJsonEncoder();

  static const int _maximumSigned64 = 9223372036854775807;
  static final RegExp _identity = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
  static final RegExp _reasonCode = RegExp(r'^[a-z0-9_]{1,128}$');

  /// Validates and encodes [report] without mutating its collections.
  Result<String, ExportFailure> encode(PerformanceBenchmarkReport report) {
    if (!_validReport(report)) return _invalid();

    final measurements = [...report.measurements]
      ..sort((left, right) => left.mode.index.compareTo(right.mode.index));
    final resources = report.resourceMetrics;
    final output = <String, Object?>{
      'schemaVersion': report.schemaVersion,
      'policyVersion': report.policyVersion,
      'benchmark': <String, Object?>{
        'id': report.definition.id,
        'sha256': report.definition.sha256,
        'bytes': report.definition.bytes,
        'mediaDurationMilliseconds':
            report.definition.mediaDuration.inMilliseconds,
      },
      'execution': <String, Object?>{
        'engineId': report.engineId,
        'engineVersion': report.engineVersion,
        'modelId': report.modelId,
        'modelVersion': report.modelVersion,
        'configurationId': report.configurationId,
      },
      'measurements': <Object?>[
        for (final measurement in measurements)
          <String, Object?>{
            'mode': measurement.mode.name,
            'status': measurement.status.name,
            'realTimeFactor': measurement.realTimeFactor,
            'firstTextLatencyMilliseconds':
                measurement.firstTextLatency?.inMilliseconds,
            'maximumBacklog': measurement.maximumBacklog,
            'blockingReasonCodes': [...measurement.blockingReasonCodes]..sort(),
          },
      ],
      'resources': <String, Object?>{
        'wallDurationMilliseconds': resources?.wallDuration?.inMilliseconds,
        'processCpuTimeMilliseconds': resources?.processCpuTime?.inMilliseconds,
        'maxSampledPssBytes': resources?.maxSampledPssBytes,
        'worstThermalState': resources?.worstThermalState?.name,
        'deviceEnergyUsedNanowattHours':
            resources?.deviceEnergyUsedNanowattHours,
        'unavailableReasonCodes': resources == null
            ? <String>[]
            : ([...resources.unavailableReasonCodes]..sort()),
      },
    };
    return Ok(jsonEncode(output));
  }

  bool _validReport(PerformanceBenchmarkReport report) {
    if ((report.schemaVersion != 1 && report.schemaVersion != 2) ||
        report.policyVersion != 1 ||
        report.definition != firstRunBenchmarkDefinition ||
        !_identity.hasMatch(report.engineId) ||
        !_identity.hasMatch(report.engineVersion) ||
        !_identity.hasMatch(report.modelId) ||
        !_identity.hasMatch(report.modelVersion) ||
        !_identity.hasMatch(report.configurationId)) {
      return false;
    }
    if (report.schemaVersion == 1 && report.resourceMetrics != null) {
      return false;
    }
    if (report.schemaVersion == 2 &&
        (report.resourceMetrics == null ||
            !_validResources(report.resourceMetrics!))) {
      return false;
    }
    final modes = <Object>{};
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
    if (maximumBacklog != null && !_validSigned64(maximumBacklog)) {
      return false;
    }
    return measurement.blockingReasonCodes.every(_reasonCode.hasMatch);
  }

  bool _validResources(BenchmarkResourceMetrics resources) {
    final core = <Object?>[
      resources.wallDuration,
      resources.processCpuTime,
      resources.maxSampledPssBytes,
      resources.worstThermalState,
    ];
    final present = core.where((value) => value != null).length;
    if (present != 0 && present != core.length) return false;
    if (resources.wallDuration case final value?) {
      if (value <= Duration.zero) return false;
    }
    if (resources.processCpuTime case final value?) {
      if (value.isNegative) return false;
    }
    if (resources.maxSampledPssBytes case final value?) {
      if (!_validSigned64(value)) return false;
    }
    if (resources.deviceEnergyUsedNanowattHours case final value?) {
      if (present == 0 || !_validSigned64(value)) return false;
    }
    if (!resources.unavailableReasonCodes.every(_reasonCode.hasMatch)) {
      return false;
    }
    if (present == 0) return resources.unavailableReasonCodes.isNotEmpty;
    return resources.deviceEnergyUsedNanowattHours != null ||
        resources.unavailableReasonCodes.isNotEmpty;
  }

  bool _validSigned64(int value) => value >= 0 && value <= _maximumSigned64;

  Result<String, ExportFailure> _invalid() => const Err(
    ExportUnavailable('benchmark_report_invalid'),
  );
}
