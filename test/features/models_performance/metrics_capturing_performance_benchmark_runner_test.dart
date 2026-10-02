import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/metrics_capturing_performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

import '../../support/fakes/fake_performance_benchmark_runner.dart';

void main() {
  test(
    'decorator reads exactly before and after and attaches schema two metrics',
    () async {
      final sourceReport = _report();
      final delegate = FakePerformanceBenchmarkRunner(
        onRun: (_) => Stream.fromIterable([
          const BenchmarkProgressed(0.5),
          BenchmarkSucceeded(sourceReport),
        ]),
      );
      final monitor = _SequencedMonitor([
        Ok(_start()),
        Ok(_end()),
      ]);
      final runner = MetricsCapturingPerformanceBenchmarkRunner(
        delegate: delegate,
        monitor: monitor,
      );

      final events = await runner.run(firstRunBenchmarkDefinition).toList();

      expect(runner.availability, const BenchmarkAvailable());
      expect(monitor.currentCalls, 2);
      expect(events.first, const BenchmarkProgressed(0.5));
      final report = (events.last as BenchmarkSucceeded).report;
      expect(report.schemaVersion, 2);
      expect(report.policyVersion, sourceReport.policyVersion);
      expect(report.definition, same(sourceReport.definition));
      expect(report.engineId, sourceReport.engineId);
      expect(report.engineVersion, sourceReport.engineVersion);
      expect(report.modelId, sourceReport.modelId);
      expect(report.modelVersion, sourceReport.modelVersion);
      expect(report.configurationId, sourceReport.configurationId);
      expect(report.measurements, sourceReport.measurements);
      expect(report.measurements.single.maximumBacklog, 3);
      expect(report.resourceMetrics?.wallDuration, const Duration(seconds: 1));
      expect(
        report.resourceMetrics?.processCpuTime,
        const Duration(milliseconds: 300),
      );
      expect(report.resourceMetrics?.maxSampledPssBytes, 12000);
      expect(report.resourceMetrics?.worstThermalState, ThermalState.hot);
      expect(report.resourceMetrics?.deviceEnergyUsedNanowattHours, 600);
    },
  );

  test('progress and delegate failure pass through unchanged', () async {
    const progress = BenchmarkProgressed(0.25);
    const failure = BenchmarkRunFailed(
      BenchmarkEngineFailure('benchmark_engine_stopped'),
    );
    final delegate = FakePerformanceBenchmarkRunner(
      onRun: (_) => Stream.fromIterable(const [progress, failure]),
    );
    final monitor = _SequencedMonitor([Ok(_start())]);
    final runner = MetricsCapturingPerformanceBenchmarkRunner(
      delegate: delegate,
      monitor: monitor,
    );

    final events = await runner.run(firstRunBenchmarkDefinition).toList();

    expect(events, const [progress, failure]);
    expect(monitor.currentCalls, 1);
  });

  test(
    'start failure preserves success and skips the unusable end read',
    () async {
      final sourceReport = _report();
      final delegate = FakePerformanceBenchmarkRunner(
        onRun: (_) => Stream.value(BenchmarkSucceeded(sourceReport)),
      );
      final monitor = _SequencedMonitor(const [
        Err(PerformanceUnavailable('performance_metrics_channel_unavailable')),
      ]);
      final runner = MetricsCapturingPerformanceBenchmarkRunner(
        delegate: delegate,
        monitor: monitor,
      );

      final events = await runner.run(firstRunBenchmarkDefinition).toList();

      expect(monitor.currentCalls, 1);
      final report = (events.single as BenchmarkSucceeded).report;
      expect(report.schemaVersion, 2);
      expect(report.measurements, sourceReport.measurements);
      _expectUnavailable(
        report.resourceMetrics,
        performanceMetricsStartUnavailableCode,
      );
    },
  );

  test('end failure preserves success with an unavailable reason', () async {
    final sourceReport = _report();
    final delegate = FakePerformanceBenchmarkRunner(
      onRun: (_) => Stream.value(BenchmarkSucceeded(sourceReport)),
    );
    final monitor = _SequencedMonitor([
      Ok(_start()),
      const Err(
        PerformanceUnavailable('performance_metrics_channel_unavailable'),
      ),
    ]);
    final runner = MetricsCapturingPerformanceBenchmarkRunner(
      delegate: delegate,
      monitor: monitor,
    );

    final events = await runner.run(firstRunBenchmarkDefinition).toList();

    expect(monitor.currentCalls, 2);
    final report = (events.single as BenchmarkSucceeded).report;
    expect(report.schemaVersion, 2);
    expect(report.measurements, sourceReport.measurements);
    _expectUnavailable(
      report.resourceMetrics,
      performanceMetricsEndUnavailableCode,
    );
  });

  test('delegate stream error is not converted by metric capture', () async {
    final error = StateError('delegate failure');
    final delegate = FakePerformanceBenchmarkRunner(
      onRun: (_) => Stream<PerformanceBenchmarkEvent>.error(error),
    );
    final monitor = _SequencedMonitor([Ok(_start())]);
    final runner = MetricsCapturingPerformanceBenchmarkRunner(
      delegate: delegate,
      monitor: monitor,
    );

    await expectLater(
      runner.run(firstRunBenchmarkDefinition),
      emitsError(same(error)),
    );
    expect(monitor.currentCalls, 1);
  });

  test(
    'unavailable production runner is never decorated or monitored',
    () async {
      const runner = UnavailablePerformanceBenchmarkRunner();
      final monitor = _SequencedMonitor(const []);

      final events = await runner.run(firstRunBenchmarkDefinition).toList();

      expect(runner.availability, isA<BenchmarkUnavailable>());
      expect(events.single, isA<BenchmarkRunFailed>());
      expect(monitor.currentCalls, 0);
    },
  );
}

void _expectUnavailable(
  BenchmarkResourceMetrics? metrics,
  String reasonCode,
) {
  expect(metrics, isNotNull);
  expect(metrics?.wallDuration, isNull);
  expect(metrics?.processCpuTime, isNull);
  expect(metrics?.maxSampledPssBytes, isNull);
  expect(metrics?.worstThermalState, isNull);
  expect(metrics?.deviceEnergyUsedNanowattHours, isNull);
  expect(metrics?.unavailableReasonCodes, [reasonCode]);
}

final class _SequencedMonitor implements ThermalAndPerformanceMonitor {
  _SequencedMonitor(this._results);

  final List<Result<DevicePerformanceSnapshot, PerformanceFailure>> _results;
  int currentCalls = 0;

  @override
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>>
  current() async {
    final result = _results[currentCalls];
    currentCalls += 1;
    return result;
  }
}

DevicePerformanceSnapshot _start() => DevicePerformanceSnapshot(
  observedAtMonotonic: const Duration(seconds: 1),
  processCpuTime: const Duration(milliseconds: 400),
  processPssBytes: 10000,
  thermalState: ThermalState.warm,
  remainingDeviceEnergyNanowattHours: 9000,
  isCharging: false,
);

DevicePerformanceSnapshot _end() => DevicePerformanceSnapshot(
  observedAtMonotonic: const Duration(seconds: 2),
  processCpuTime: const Duration(milliseconds: 700),
  processPssBytes: 12000,
  thermalState: ThermalState.hot,
  remainingDeviceEnergyNanowattHours: 8400,
  isCharging: false,
);

PerformanceBenchmarkReport _report() => PerformanceBenchmarkReport(
  schemaVersion: 1,
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
      maximumBacklog: 3,
    ),
  ],
);
