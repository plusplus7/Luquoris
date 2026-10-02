import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_metrics_collector.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Adds optional before/after resource observations to delegate successes.
final class MetricsCapturingPerformanceBenchmarkRunner
    implements PerformanceBenchmarkRunner {
  /// Creates a decorator around one available benchmark [delegate].
  const MetricsCapturingPerformanceBenchmarkRunner({
    required PerformanceBenchmarkRunner delegate,
    required ThermalAndPerformanceMonitor monitor,
    BenchmarkMetricsCollector collector = const BenchmarkMetricsCollector(),
  }) : this._(delegate, monitor, collector);

  const MetricsCapturingPerformanceBenchmarkRunner._(
    this._delegate,
    this._monitor,
    this._collector,
  );

  final PerformanceBenchmarkRunner _delegate;
  final ThermalAndPerformanceMonitor _monitor;
  final BenchmarkMetricsCollector _collector;

  @override
  BenchmarkAvailability get availability => _delegate.availability;

  @override
  Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition) async* {
    final start = await _current();
    await for (final event in _delegate.run(definition)) {
      if (event case BenchmarkSucceeded(:final report)) {
        final metrics = switch (start) {
          Err<DevicePerformanceSnapshot, PerformanceFailure>() =>
            _collector.unavailable(performanceMetricsStartUnavailableCode),
          Ok<DevicePerformanceSnapshot, PerformanceFailure>(:final value) =>
            await _metricsAfterSuccess(value),
        };
        yield BenchmarkSucceeded(
          report.copyWith(schemaVersion: 2, resourceMetrics: metrics),
        );
      } else {
        yield event;
      }
    }
  }

  Future<BenchmarkResourceMetrics> _metricsAfterSuccess(
    DevicePerformanceSnapshot start,
  ) async => switch (await _current()) {
    Ok<DevicePerformanceSnapshot, PerformanceFailure>(:final value) =>
      _collector.collect(start, value),
    Err<DevicePerformanceSnapshot, PerformanceFailure>() =>
      _collector.unavailable(performanceMetricsEndUnavailableCode),
  };

  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>>
  _current() async {
    try {
      return await _monitor.current();
    } on Object {
      return const Err(
        PerformanceUnavailable('performance_metrics_monitor_exception'),
      );
    }
  }
}
