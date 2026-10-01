import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_controller.dart';

import '../../support/fakes/fake_performance_benchmark_runner.dart';

void main() {
  test('build reflects unavailable and ready runners', () {
    final unavailable = _container(
      FakePerformanceBenchmarkRunner(
        availability: const BenchmarkUnavailable('runtime_missing'),
      ),
    );
    final ready = _container(FakePerformanceBenchmarkRunner());

    expect(
      unavailable.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceUnavailable('runtime_missing'),
    );
    expect(
      ready.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceReady(),
    );
  });

  test('start supplies fixed definition and coalesces duplicate starts', () {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    final container = _container(runner);
    container.read(modelsPerformanceControllerProvider.notifier)
      ..start()
      ..start();

    expect(runner.runCalls, 1);
    expect(runner.definitions, [firstRunBenchmarkDefinition]);
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceRunning(0),
    );
  });

  test('monotonic progress completes with report and recommendation', () {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    final container = _container(runner);
    final controller = container.read(
      modelsPerformanceControllerProvider.notifier,
    );
    final report = _report();

    controller.start();
    run.add(const BenchmarkProgressed(0.25));
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceRunning(0.25),
    );
    run
      ..add(const BenchmarkProgressed(1))
      ..add(BenchmarkSucceeded(report));

    final state = container.read(modelsPerformanceControllerProvider);
    expect(
      state,
      isA<ModelsPerformanceCompleted>()
          .having((value) => value.report, 'report', same(report))
          .having(
            (value) => value.recommendation.mode,
            'mode',
            PerformanceMode.balanced,
          ),
    );
  });

  test('retry clears completed and failed output before each new run', () {
    final runs = <_ControlledRun>[
      _ControlledRun(),
      _ControlledRun(),
      _ControlledRun(),
    ];
    var index = 0;
    final runner = FakePerformanceBenchmarkRunner(
      onRun: (_) => runs[index++].stream,
    );
    final container = _container(runner);
    final controller = container.read(
      modelsPerformanceControllerProvider.notifier,
    );
    final start = controller.start;

    start();
    runs[0].add(BenchmarkSucceeded(_report()));
    expect(
      container.read(modelsPerformanceControllerProvider),
      isA<ModelsPerformanceCompleted>(),
    );

    start();
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceRunning(0),
    );
    runs[1].add(
      const BenchmarkRunFailed(BenchmarkEngineFailure('engine_stopped')),
    );
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceFailed(BenchmarkEngineFailure('engine_stopped')),
    );

    start();
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceRunning(0),
    );
    expect(runner.runCalls, 3);
  });

  test(
    'explicit cancellation cancels once and ignores late completion',
    () async {
      final run = _ControlledRun();
      final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
      final container = _container(runner);
      final controller = container.read(
        modelsPerformanceControllerProvider.notifier,
      );

      await (controller..start()).cancel();
      run.add(BenchmarkSucceeded(_report()));

      expect(run.cancelCalls, 1);
      expect(
        container.read(modelsPerformanceControllerProvider),
        const ModelsPerformanceCancelled(),
      );
    },
  );

  test('provider disposal cancels once and ignores late events', () async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    final states = <ModelsPerformanceState>[];
    final container = ProviderContainer.test(
      overrides: [
        performanceBenchmarkRunnerProvider.overrideWithValue(runner),
      ],
    );
    final subscription = container.listen(
      modelsPerformanceControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
    container.read(modelsPerformanceControllerProvider.notifier).start();

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    final stateCountAfterDispose = states.length;
    run.add(BenchmarkSucceeded(_report()));

    expect(run.cancelCalls, 1);
    expect(states, hasLength(stateCountAfterDispose));
    container.dispose();
  });

  for (final invalidSequence in <List<double>>[
    [0.5, 0.4],
    [-0.1],
    [1.1],
    [double.nan],
    [double.infinity],
  ]) {
    test('rejects invalid progress sequence $invalidSequence', () {
      final run = _ControlledRun();
      final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
      final container = _container(runner);
      container.read(modelsPerformanceControllerProvider.notifier).start();

      for (final progress in invalidSequence) {
        run.add(BenchmarkProgressed(progress));
      }

      expect(
        container.read(modelsPerformanceControllerProvider),
        const ModelsPerformanceFailed(BenchmarkInvalidOutput()),
      );
    });
  }

  test('closing without a terminal event is invalid output', () async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    final container = _container(runner);
    container.read(modelsPerformanceControllerProvider.notifier).start();

    await run.close();

    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceFailed(BenchmarkInvalidOutput()),
    );
  });

  test(
    'a second terminal event replaces stale success with invalid output',
    () {
      final run = _ControlledRun();
      final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
      final container = _container(runner);
      container.read(modelsPerformanceControllerProvider.notifier).start();

      run.add(BenchmarkSucceeded(_report()));
      expect(
        container.read(modelsPerformanceControllerProvider),
        isA<ModelsPerformanceCompleted>(),
      );
      run.add(BenchmarkSucceeded(_report()));

      expect(
        container.read(modelsPerformanceControllerProvider),
        const ModelsPerformanceFailed(BenchmarkInvalidOutput()),
      );
    },
  );

  test('runner exceptions become privacy-safe runtime failures', () async {
    final synchronous = _container(
      FakePerformanceBenchmarkRunner(
        onRun: (_) => throw StateError('private implementation detail'),
      ),
    );
    synchronous.read(modelsPerformanceControllerProvider.notifier).start();
    expect(
      synchronous.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceFailed(
        BenchmarkRuntimeFailure('benchmark_runner_exception'),
      ),
    );

    final run = _ControlledRun();
    final asynchronous = _container(
      FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
    );
    asynchronous.read(modelsPerformanceControllerProvider.notifier).start();
    run.addError(StateError('another private detail'));
    await Future<void>.delayed(Duration.zero);

    expect(
      asynchronous.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceFailed(
        BenchmarkRuntimeFailure('benchmark_runner_exception'),
      ),
    );
  });
}

ProviderContainer _container(FakePerformanceBenchmarkRunner runner) {
  final container = ProviderContainer.test(
    overrides: [
      performanceBenchmarkRunnerProvider.overrideWithValue(runner),
    ],
  );
  addTearDown(container.dispose);
  container.listen(
    modelsPerformanceControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  return container;
}

final class _ControlledRun {
  int cancelCalls = 0;

  late final StreamController<PerformanceBenchmarkEvent> _controller =
      StreamController<PerformanceBenchmarkEvent>(
        sync: true,
        onCancel: () {
          cancelCalls += 1;
        },
      );

  Stream<PerformanceBenchmarkEvent> get stream => _controller.stream;

  void add(PerformanceBenchmarkEvent event) => _controller.add(event);

  void addError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

PerformanceBenchmarkReport _report() => PerformanceBenchmarkReport(
  schemaVersion: 1,
  policyVersion: 1,
  definition: firstRunBenchmarkDefinition,
  engineId: 'engine',
  engineVersion: '1',
  modelId: 'model',
  modelVersion: '1',
  configurationId: 'cpu-baseline',
  measurements: [
    BenchmarkModeMeasurement(
      mode: PerformanceMode.balanced,
      status: BenchmarkMeasurementStatus.measured,
      realTimeFactor: 0.5,
      firstTextLatency: const Duration(seconds: 2),
    ),
  ],
);
