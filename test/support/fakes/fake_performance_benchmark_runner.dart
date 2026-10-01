import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';

/// Configurable fixed-audio runner used by controller and widget tests.
final class FakePerformanceBenchmarkRunner
    implements PerformanceBenchmarkRunner {
  /// Creates a fake with explicit availability and event factory.
  FakePerformanceBenchmarkRunner({
    this.availability = const BenchmarkAvailable(),
    Stream<PerformanceBenchmarkEvent> Function(BenchmarkDefinition)? onRun,
  }) : onRun = onRun ?? _emptyRun;

  @override
  BenchmarkAvailability availability;

  /// Current event factory, replaceable between test runs.
  Stream<PerformanceBenchmarkEvent> Function(BenchmarkDefinition) onRun;

  /// Exact benchmark definitions supplied by consumers.
  final List<BenchmarkDefinition> definitions = <BenchmarkDefinition>[];

  /// Number of runs requested through the boundary.
  int get runCalls => definitions.length;

  @override
  Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition) {
    definitions.add(definition);
    return onRun(definition);
  }
}

Stream<PerformanceBenchmarkEvent> _emptyRun(BenchmarkDefinition definition) =>
    const Stream<PerformanceBenchmarkEvent>.empty();
