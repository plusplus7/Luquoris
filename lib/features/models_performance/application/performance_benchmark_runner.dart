import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:meta/meta.dart';

/// Executes the fixed bundled benchmark without accessing audio capture.
abstract interface class PerformanceBenchmarkRunner {
  /// Whether the local runtime can start a benchmark.
  BenchmarkAvailability get availability;

  /// Runs one benchmark using the exact supplied [definition].
  Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition);
}

/// Typed event emitted during one benchmark run.
@immutable
sealed class PerformanceBenchmarkEvent extends ValueObject {
  const PerformanceBenchmarkEvent();
}

/// Monotonic normalized benchmark progress.
final class BenchmarkProgressed extends PerformanceBenchmarkEvent {
  /// Creates a progress event validated by the presentation controller.
  const BenchmarkProgressed(this.progress);

  /// Completion fraction expected to remain between zero and one.
  final double progress;

  @override
  List<Object?> get equalityValues => <Object?>[progress];
}

/// One terminal successful benchmark report.
final class BenchmarkSucceeded extends PerformanceBenchmarkEvent {
  /// Creates a terminal success event.
  const BenchmarkSucceeded(this.report);

  /// Versioned measured report.
  final PerformanceBenchmarkReport report;

  @override
  List<Object?> get equalityValues => <Object?>[report];
}

/// One terminal typed benchmark failure.
final class BenchmarkRunFailed extends PerformanceBenchmarkEvent {
  /// Creates a terminal failure event.
  const BenchmarkRunFailed(this.failure);

  /// Privacy-safe benchmark failure.
  final BenchmarkFailure failure;

  @override
  List<Object?> get equalityValues => <Object?>[failure];
}

/// Honest production boundary used until the real engine is integrated.
final class UnavailablePerformanceBenchmarkRunner
    implements PerformanceBenchmarkRunner {
  /// Creates an unavailable runner.
  const UnavailablePerformanceBenchmarkRunner();

  static const _failure = BenchmarkRuntimeFailure(
    'benchmark_runtime_not_installed',
  );

  @override
  BenchmarkAvailability get availability =>
      const BenchmarkUnavailable('benchmark_runtime_not_installed');

  @override
  Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition) =>
      Stream<PerformanceBenchmarkEvent>.value(
        const BenchmarkRunFailed(_failure),
      );
}
