import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Purely derives resource deltas from two validated point samples.
final class BenchmarkMetricsCollector {
  /// Creates the stateless collector.
  const BenchmarkMetricsCollector();

  /// Aggregates [start] and [end] without clamping invalid deltas.
  BenchmarkResourceMetrics collect(
    DevicePerformanceSnapshot start,
    DevicePerformanceSnapshot end,
  ) {
    if (!_validSnapshot(start) ||
        !_validSnapshot(end) ||
        end.observedAtMonotonic <= start.observedAtMonotonic ||
        end.processCpuTime < start.processCpuTime) {
      return unavailable(performanceMetricsInvalidDeltaCode);
    }

    final energy = _energy(start, end);
    return BenchmarkResourceMetrics(
      wallDuration: end.observedAtMonotonic - start.observedAtMonotonic,
      processCpuTime: end.processCpuTime - start.processCpuTime,
      maxSampledPssBytes: start.processPssBytes > end.processPssBytes
          ? start.processPssBytes
          : end.processPssBytes,
      worstThermalState: _worstThermal(
        start.thermalState,
        end.thermalState,
      ),
      deviceEnergyUsedNanowattHours: energy.value,
      unavailableReasonCodes: energy.reason == null
          ? const <String>[]
          : <String>[energy.reason!],
    );
  }

  /// Creates an unavailable metric envelope with one stable [reasonCode].
  BenchmarkResourceMetrics unavailable(String reasonCode) =>
      BenchmarkResourceMetrics(unavailableReasonCodes: <String>[reasonCode]);
}

const _maxSignedInt64 = 9223372036854775807;

bool _validSnapshot(DevicePerformanceSnapshot snapshot) =>
    !snapshot.observedAtMonotonic.isNegative &&
    !snapshot.processCpuTime.isNegative &&
    snapshot.processPssBytes >= 0 &&
    snapshot.processPssBytes <= _maxSignedInt64 &&
    (snapshot.remainingDeviceEnergyNanowattHours == null ||
        snapshot.remainingDeviceEnergyNanowattHours! >= 0) &&
    (snapshot.remainingDeviceEnergyNanowattHours == null ||
        snapshot.remainingDeviceEnergyNanowattHours! <= _maxSignedInt64);

({int? value, String? reason}) _energy(
  DevicePerformanceSnapshot start,
  DevicePerformanceSnapshot end,
) {
  final startValue = start.remainingDeviceEnergyNanowattHours;
  final endValue = end.remainingDeviceEnergyNanowattHours;
  if (startValue == null || endValue == null) {
    return (value: null, reason: deviceEnergyCounterUnavailableCode);
  }
  if (start.isCharging || end.isCharging) {
    return (value: null, reason: deviceEnergyMeasurementChargingCode);
  }
  if (endValue > startValue) {
    return (value: null, reason: deviceEnergyCounterIncreasedCode);
  }
  return (value: startValue - endValue, reason: null);
}

ThermalState _worstThermal(ThermalState start, ThermalState end) {
  if (start == ThermalState.unknown) return end;
  if (end == ThermalState.unknown) return start;
  return _thermalRank(start) >= _thermalRank(end) ? start : end;
}

int _thermalRank(ThermalState state) => switch (state) {
  ThermalState.nominal => 0,
  ThermalState.warm => 1,
  ThermalState.hot => 2,
  ThermalState.critical => 3,
  ThermalState.unknown => -1,
};
