import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_controller.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

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

  test(
    'completed report exports with fresh uuid and fixed utc clock',
    () async {
      final exporter = _FakeBenchmarkReportExporter();
      final report = _report();
      final instant = DateTime.utc(2026, 10, 2, 3, 4, 5);
      final (:container, :controller) = _completedContainer(
        exporter: exporter,
        report: report,
        operationId: 'fresh-operation-id',
        clock: Clock.fixed(instant),
      );

      await controller.exportReport();

      expect(exporter.calls, hasLength(1));
      expect(exporter.calls.single.report, same(report));
      expect(exporter.calls.single.operationId, 'fresh-operation-id');
      expect(exporter.calls.single.createdAtUtc, instant);
      expect(exporter.calls.single.createdAtUtc.isUtc, isTrue);
      expect(
        container.read(modelsPerformanceControllerProvider),
        isA<ModelsPerformanceCompleted>()
            .having((state) => state.isExporting, 'isExporting', isFalse)
            .having(
              (state) => state.exportReceipt?.fileName,
              'fileName',
              'benchmark-report.json',
            )
            .having((state) => state.exportFailureCode, 'failure', isNull),
      );
    },
  );

  test('duplicate export requests coalesce to one call', () async {
    final pending = Completer<Result<ExportReceipt, ExportFailure>>();
    final exporter = _FakeBenchmarkReportExporter(
      onExport: (_) => pending.future,
    );
    final (:container, :controller) = _completedContainer(exporter: exporter);

    final first = controller.exportReport();
    final second = controller.exportReport();

    expect(exporter.calls, hasLength(1));
    expect(
      container.read(modelsPerformanceControllerProvider),
      isA<ModelsPerformanceCompleted>().having(
        (state) => state.isExporting,
        'isExporting',
        isTrue,
      ),
    );
    pending.complete(Ok(_receipt()));
    await Future.wait([first, second]);
    expect(exporter.calls, hasLength(1));
  });

  test('export outside completed state is ignored', () async {
    final exporter = _FakeBenchmarkReportExporter();
    final container = _container(
      FakePerformanceBenchmarkRunner(),
      exporter: exporter,
    );

    await container
        .read(modelsPerformanceControllerProvider.notifier)
        .exportReport();

    expect(exporter.calls, isEmpty);
    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceReady(),
    );
  });

  test(
    'success cancellation and failure retain exact report and recommendation',
    () async {
      final outcomes = <Result<ExportReceipt, ExportFailure>>[
        Ok(_receipt()),
        const Err(ExportUnavailable('export_cancelled')),
        const Err(ExportUnavailable('destination_unavailable')),
      ];

      for (final outcome in outcomes) {
        final exporter = _FakeBenchmarkReportExporter(
          onExport: (_) async => outcome,
        );
        final report = _report();
        final (:container, :controller) = _completedContainer(
          exporter: exporter,
          report: report,
        );
        final before =
            container.read(modelsPerformanceControllerProvider)
                as ModelsPerformanceCompleted;

        await controller.exportReport();

        final after =
            container.read(modelsPerformanceControllerProvider)
                as ModelsPerformanceCompleted;
        expect(after.report, same(before.report));
        expect(after.recommendation, same(before.recommendation));
        expect(after.isExporting, isFalse);
        switch (outcome) {
          case Ok(:final value):
            expect(after.exportReceipt, same(value));
            expect(after.exportFailureCode, isNull);
          case Err(:final failure):
            expect(after.exportReceipt, isNull);
            expect(after.exportFailureCode, failure.code);
        }
      }
    },
  );

  test('rerun clears prior export outcome', () async {
    final runs = [_ControlledRun(), _ControlledRun()];
    var index = 0;
    final exporter = _FakeBenchmarkReportExporter();
    final container = _container(
      FakePerformanceBenchmarkRunner(onRun: (_) => runs[index++].stream),
      exporter: exporter,
    );
    final controller = container.read(
      modelsPerformanceControllerProvider.notifier,
    );
    final start = controller.start;

    start();
    runs.first.add(BenchmarkSucceeded(_report()));
    await controller.exportReport();
    expect(
      container.read(modelsPerformanceControllerProvider),
      isA<ModelsPerformanceCompleted>().having(
        (state) => state.exportReceipt,
        'receipt',
        isNotNull,
      ),
    );

    start();

    expect(
      container.read(modelsPerformanceControllerProvider),
      const ModelsPerformanceRunning(0),
    );
  });

  test('disposed controller ignores late export completion', () async {
    final pending = Completer<Result<ExportReceipt, ExportFailure>>();
    final exporter = _FakeBenchmarkReportExporter(
      onExport: (_) => pending.future,
    );
    final run = _ControlledRun();
    final container = ProviderContainer.test(
      overrides: [
        performanceBenchmarkRunnerProvider.overrideWithValue(
          FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
        ),
        benchmarkReportExporterProvider.overrideWithValue(exporter),
        benchmarkExportOperationIdProvider.overrideWithValue(() => 'late'),
        clockProvider.overrideWithValue(Clock.fixed(DateTime.utc(2026))),
      ],
    );
    final states = <ModelsPerformanceState>[];
    final subscription = container.listen(
      modelsPerformanceControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
    final controller = container.read(
      modelsPerformanceControllerProvider.notifier,
    );
    final start = controller.start;
    start();
    run.add(BenchmarkSucceeded(_report()));
    final export = controller.exportReport();

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    final stateCountAfterDispose = states.length;
    pending.complete(Ok(_receipt()));
    await export;

    expect(states, hasLength(stateCountAfterDispose));
    container.dispose();
  });
}

ProviderContainer _container(
  FakePerformanceBenchmarkRunner runner, {
  BenchmarkReportExporter? exporter,
}) {
  final container = ProviderContainer.test(
    overrides: [
      performanceBenchmarkRunnerProvider.overrideWithValue(runner),
      if (exporter != null)
        benchmarkReportExporterProvider.overrideWithValue(exporter),
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

({
  ProviderContainer container,
  ModelsPerformanceController controller,
})
_completedContainer({
  required _FakeBenchmarkReportExporter exporter,
  PerformanceBenchmarkReport? report,
  String operationId = 'operation-id',
  Clock? clock,
}) {
  final run = _ControlledRun();
  final container = ProviderContainer.test(
    overrides: [
      performanceBenchmarkRunnerProvider.overrideWithValue(
        FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
      ),
      benchmarkReportExporterProvider.overrideWithValue(exporter),
      benchmarkExportOperationIdProvider.overrideWithValue(() => operationId),
      clockProvider.overrideWithValue(clock ?? Clock.fixed(DateTime.utc(2026))),
    ],
  );
  addTearDown(container.dispose);
  container.listen(
    modelsPerformanceControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  final controller = container.read(
    modelsPerformanceControllerProvider.notifier,
  )..start();
  run.add(BenchmarkSucceeded(report ?? _report()));
  return (container: container, controller: controller);
}

final class _ExportCall {
  const _ExportCall({
    required this.report,
    required this.operationId,
    required this.createdAtUtc,
  });

  final PerformanceBenchmarkReport report;
  final String operationId;
  final DateTime createdAtUtc;
}

final class _FakeBenchmarkReportExporter implements BenchmarkReportExporter {
  _FakeBenchmarkReportExporter({
    Future<Result<ExportReceipt, ExportFailure>> Function(_ExportCall call)?
    onExport,
  }) : _onExport = onExport ?? ((_) async => Ok(_receipt()));

  final Future<Result<ExportReceipt, ExportFailure>> Function(_ExportCall call)
  _onExport;
  final List<_ExportCall> calls = [];

  @override
  Future<Result<ExportReceipt, ExportFailure>> export({
    required PerformanceBenchmarkReport report,
    required String operationId,
    required DateTime createdAtUtc,
  }) {
    final call = _ExportCall(
      report: report,
      operationId: operationId,
      createdAtUtc: createdAtUtc,
    );
    calls.add(call);
    return _onExport(call);
  }
}

ExportReceipt _receipt() => ExportReceipt(
  fileName: 'benchmark-report.json',
  bytesWritten: 256,
);

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
