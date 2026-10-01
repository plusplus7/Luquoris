import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';

void main() {
  test(
    'unavailable runner fails closed without fabricated measurements',
    () async {
      const runner = UnavailablePerformanceBenchmarkRunner();

      expect(
        runner.availability,
        const BenchmarkUnavailable('benchmark_runtime_not_installed'),
      );
      final events = await runner.run(firstRunBenchmarkDefinition).toList();

      expect(events, hasLength(1));
      final event = events.single as BenchmarkRunFailed;
      expect(event.failure, isA<BenchmarkRuntimeFailure>());
      expect(event.failure.code, 'benchmark_runtime_not_installed');
    },
  );
}
