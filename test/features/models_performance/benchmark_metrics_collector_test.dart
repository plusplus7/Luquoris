import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/application/benchmark_metrics_collector.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  const collector = BenchmarkMetricsCollector();

  test(
    'collector derives wall cpu maximum sampled pss and worst known thermal',
    () {
      final metrics = collector.collect(_start(), _end());

      expect(metrics.wallDuration, const Duration(milliseconds: 1500));
      expect(metrics.processCpuTime, const Duration(milliseconds: 450));
      expect(metrics.maxSampledPssBytes, 12000);
      expect(metrics.worstThermalState, ThermalState.hot);
      expect(metrics.unavailableReasonCodes, isEmpty);
    },
  );

  test(
    'collector emits device energy only for a falling discharging counter',
    () {
      final metrics = collector.collect(_start(), _end());

      expect(metrics.deviceEnergyUsedNanowattHours, 600);
      expect(metrics.unavailableReasonCodes, isEmpty);
    },
  );

  test(
    'missing charging and increasing energy keep core metrics with stable reasons',
    () {
      final cases = <(DevicePerformanceSnapshot, String)>[
        (
          _end(remainingDeviceEnergyNanowattHours: null),
          'device_energy_counter_unavailable',
        ),
        (
          _end(isCharging: true),
          'device_energy_measurement_charging',
        ),
        (
          _end(remainingDeviceEnergyNanowattHours: 9500),
          'device_energy_counter_increased',
        ),
      ];

      for (final (end, expectedReason) in cases) {
        final metrics = collector.collect(_start(), end);

        expect(metrics.wallDuration, const Duration(milliseconds: 1500));
        expect(metrics.processCpuTime, const Duration(milliseconds: 450));
        expect(metrics.maxSampledPssBytes, 12000);
        expect(metrics.worstThermalState, ThermalState.hot);
        expect(metrics.deviceEnergyUsedNanowattHours, isNull);
        expect(metrics.unavailableReasonCodes, [expectedReason]);
      }
    },
  );

  test(
    'unknown thermal never hides a known state and two unknown samples stay unknown',
    () {
      final known = collector.collect(
        _start(thermalState: ThermalState.unknown),
        _end(thermalState: ThermalState.warm),
      );
      final unknown = collector.collect(
        _start(thermalState: ThermalState.unknown),
        _end(thermalState: ThermalState.unknown),
      );

      expect(known.worstThermalState, ThermalState.warm);
      expect(unknown.worstThermalState, ThermalState.unknown);
    },
  );

  test(
    'reversed time and decreased cpu become unavailable without clamping',
    () {
      final reversed = collector.collect(
        _start(observedAtMonotonic: const Duration(milliseconds: 3000)),
        _end(),
      );
      final decreasedCpu = collector.collect(
        _start(processCpuTime: const Duration(milliseconds: 900)),
        _end(),
      );

      for (final metrics in [reversed, decreasedCpu]) {
        expect(metrics.wallDuration, isNull);
        expect(metrics.processCpuTime, isNull);
        expect(metrics.maxSampledPssBytes, isNull);
        expect(metrics.worstThermalState, isNull);
        expect(metrics.deviceEnergyUsedNanowattHours, isNull);
        expect(metrics.unavailableReasonCodes, [
          'performance_metrics_invalid_delta',
        ]);
      }
    },
  );

  test('schema two report equality includes backlog resources and reasons', () {
    final resources = BenchmarkResourceMetrics(
      wallDuration: const Duration(milliseconds: 1500),
      processCpuTime: const Duration(milliseconds: 450),
      maxSampledPssBytes: 12000,
      worstThermalState: ThermalState.hot,
      unavailableReasonCodes: const ['device_energy_counter_unavailable'],
    );
    final report = _report(resources: resources, maximumBacklog: 3);
    final equalReport = _report(
      resources: BenchmarkResourceMetrics(
        wallDuration: const Duration(milliseconds: 1500),
        processCpuTime: const Duration(milliseconds: 450),
        maxSampledPssBytes: 12000,
        worstThermalState: ThermalState.hot,
        unavailableReasonCodes: const ['device_energy_counter_unavailable'],
      ),
      maximumBacklog: 3,
    );

    expect(report, equalReport);
    expect(report, isNot(_report(resources: resources, maximumBacklog: 4)));
    expect(
      report,
      isNot(
        _report(
          resources: BenchmarkResourceMetrics(
            wallDuration: const Duration(milliseconds: 1500),
            processCpuTime: const Duration(milliseconds: 450),
            maxSampledPssBytes: 12000,
            worstThermalState: ThermalState.hot,
            unavailableReasonCodes: const [
              'device_energy_measurement_charging',
            ],
          ),
          maximumBacklog: 3,
        ),
      ),
    );
    expect(report.copyWith(), report);
  });
}

DevicePerformanceSnapshot _start({
  Duration observedAtMonotonic = const Duration(milliseconds: 1000),
  Duration processCpuTime = const Duration(milliseconds: 400),
  int processPssBytes = 10000,
  ThermalState thermalState = ThermalState.warm,
  int? remainingDeviceEnergyNanowattHours = 9000,
  bool isCharging = false,
}) => DevicePerformanceSnapshot(
  observedAtMonotonic: observedAtMonotonic,
  processCpuTime: processCpuTime,
  processPssBytes: processPssBytes,
  thermalState: thermalState,
  remainingDeviceEnergyNanowattHours: remainingDeviceEnergyNanowattHours,
  isCharging: isCharging,
);

DevicePerformanceSnapshot _end({
  Duration observedAtMonotonic = const Duration(milliseconds: 2500),
  Duration processCpuTime = const Duration(milliseconds: 850),
  int processPssBytes = 12000,
  ThermalState thermalState = ThermalState.hot,
  int? remainingDeviceEnergyNanowattHours = 8400,
  bool isCharging = false,
}) => DevicePerformanceSnapshot(
  observedAtMonotonic: observedAtMonotonic,
  processCpuTime: processCpuTime,
  processPssBytes: processPssBytes,
  thermalState: thermalState,
  remainingDeviceEnergyNanowattHours: remainingDeviceEnergyNanowattHours,
  isCharging: isCharging,
);

PerformanceBenchmarkReport _report({
  required BenchmarkResourceMetrics resources,
  required int maximumBacklog,
}) => PerformanceBenchmarkReport(
  schemaVersion: 2,
  policyVersion: 1,
  definition: firstRunBenchmarkDefinition,
  engineId: 'whisper.cpp',
  engineVersion: '1',
  modelId: 'base-q5',
  modelVersion: '1',
  configurationId: 'cpu-neon',
  measurements: [
    BenchmarkModeMeasurement(
      mode: PerformanceMode.balanced,
      status: BenchmarkMeasurementStatus.measured,
      realTimeFactor: 0.5,
      firstTextLatency: const Duration(seconds: 2),
      maximumBacklog: maximumBacklog,
    ),
  ],
  resourceMetrics: resources,
);
