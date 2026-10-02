import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:meta/meta.dart';

/// A start snapshot could not be read.
const performanceMetricsStartUnavailableCode =
    'performance_metrics_start_unavailable';

/// An end snapshot could not be read.
const performanceMetricsEndUnavailableCode =
    'performance_metrics_end_unavailable';

/// Two snapshots could not produce valid non-negative deltas.
const performanceMetricsInvalidDeltaCode = 'performance_metrics_invalid_delta';

/// The platform did not expose both remaining-energy counters.
const deviceEnergyCounterUnavailableCode = 'device_energy_counter_unavailable';

/// Charging made a remaining-energy delta unsuitable for reporting.
const deviceEnergyMeasurementChargingCode =
    'device_energy_measurement_charging';

/// The remaining-energy counter increased between observations.
const deviceEnergyCounterIncreasedCode = 'device_energy_counter_increased';

/// Immutable resource observations derived from a benchmark's two samples.
@immutable
final class BenchmarkResourceMetrics extends ValueObject {
  /// Creates measured or explicitly unavailable resource metrics.
  BenchmarkResourceMetrics({
    this.wallDuration,
    this.processCpuTime,
    this.maxSampledPssBytes,
    this.worstThermalState,
    this.deviceEnergyUsedNanowattHours,
    List<String> unavailableReasonCodes = const <String>[],
  }) : unavailableReasonCodes = List<String>.unmodifiable(
         unavailableReasonCodes,
       );

  /// Positive elapsed monotonic time between the two samples.
  final Duration? wallDuration;

  /// Non-negative process CPU-time delta between the two samples.
  final Duration? processCpuTime;

  /// Greater of the start and end PSS point samples, not a runtime peak.
  final int? maxSampledPssBytes;

  /// More severe known thermal state across the two samples.
  final ThermalState? worstThermalState;

  /// Optional device-level remaining-energy delta.
  final int? deviceEnergyUsedNanowattHours;

  /// Stable reasons explaining unavailable resource values.
  final List<String> unavailableReasonCodes;

  @override
  List<Object?> get equalityValues => <Object?>[
    wallDuration,
    processCpuTime,
    maxSampledPssBytes,
    worstThermalState,
    deviceEnergyUsedNanowattHours,
    unavailableReasonCodes.length,
    ...unavailableReasonCodes,
  ];
}
