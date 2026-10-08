import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_metrics_collector.dart';
import 'package:loquiris/features/models_performance/application/benchmark_recommendation_policy.dart';
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
  static const _policy = BenchmarkRecommendationPolicy();

  @override
  BenchmarkAvailability get availability => _delegate.availability;

  @override
  Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition) {
    late final StreamController<PerformanceBenchmarkEvent> controller;
    StreamSubscription<PerformanceBenchmarkEvent>? delegateSubscription;
    var cancelled = false;
    var listenerPaused = false;

    Future<void> cancelDelegate() async {
      cancelled = true;
      final subscription = delegateSubscription;
      delegateSubscription = null;
      await subscription?.cancel();
    }

    Future<void> closeWithError(Object error, StackTrace stackTrace) async {
      if (cancelled) return;
      controller.addError(error, stackTrace);
      await controller.close();
    }

    Future<void> addSuccess(
      StreamSubscription<PerformanceBenchmarkEvent> subscription,
      Result<DevicePerformanceSnapshot, PerformanceFailure> start,
      PerformanceBenchmarkReport report,
    ) async {
      if (_policy.recommend(report) case Err()) {
        if (!cancelled) {
          controller.add(
            const BenchmarkRunFailed(BenchmarkInvalidOutput()),
          );
          subscription.resume();
        }
        return;
      }
      final metrics = switch (start) {
        Err<DevicePerformanceSnapshot, PerformanceFailure>() =>
          _collector.unavailable(performanceMetricsStartUnavailableCode),
        Ok<DevicePerformanceSnapshot, PerformanceFailure>(:final value) =>
          await _metricsAfterSuccess(value),
      };
      if (!cancelled) {
        controller.add(
          BenchmarkSucceeded(
            report.copyWith(schemaVersion: 2, resourceMetrics: metrics),
          ),
        );
        subscription.resume();
      }
    }

    Future<void> startDelegate() async {
      final start = await _current();
      if (cancelled) return;
      late final Stream<PerformanceBenchmarkEvent> events;
      try {
        events = _delegate.run(definition);
      } on Object catch (error, stackTrace) {
        await closeWithError(error, stackTrace);
        return;
      }
      if (cancelled) return;
      final subscription = events.listen(null);
      delegateSubscription = subscription;
      if (listenerPaused) subscription.pause();
      subscription
        ..onData((event) {
          if (cancelled) return;
          if (event case BenchmarkSucceeded(:final report)) {
            subscription.pause();
            unawaited(addSuccess(subscription, start, report));
          } else {
            controller.add(event);
          }
        })
        ..onError((Object error, StackTrace stackTrace) {
          if (!cancelled) controller.addError(error, stackTrace);
        })
        ..onDone(() {
          delegateSubscription = null;
          if (!cancelled) unawaited(controller.close());
        });
    }

    controller = StreamController<PerformanceBenchmarkEvent>(
      sync: true,
      onListen: () => unawaited(startDelegate()),
      onPause: () {
        listenerPaused = true;
        delegateSubscription?.pause();
      },
      onResume: () {
        listenerPaused = false;
        delegateSubscription?.resume();
      },
      onCancel: cancelDelegate,
    );
    return controller.stream;
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
