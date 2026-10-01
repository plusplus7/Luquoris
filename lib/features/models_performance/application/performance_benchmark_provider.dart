import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';

/// Fixed-audio benchmark boundary; bootstrap must override this provider.
final performanceBenchmarkRunnerProvider = Provider<PerformanceBenchmarkRunner>(
  (ref) =>
      throw UnimplementedError('PerformanceBenchmarkRunner is not installed'),
);
