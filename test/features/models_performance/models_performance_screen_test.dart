import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_screen.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/theme/app_theme.dart';

import '../../support/fakes/fake_performance_benchmark_runner.dart';

void main() {
  testWidgets('renders the unavailable state without a fake start action', (
    tester,
  ) async {
    final runner = FakePerformanceBenchmarkRunner(
      availability: const BenchmarkUnavailable(
        'benchmark_runtime_not_installed',
      ),
    );

    await tester.pumpWidget(_app(runner));
    await tester.pump();

    expect(find.text('Performance check unavailable'), findsOneWidget);
    expect(find.textContaining('not installed'), findsOneWidget);
    expect(find.byKey(const Key('benchmark-start')), findsNothing);
  });

  testWidgets('ready start is explicit and duplicate taps run only once', (
    tester,
  ) async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    expect(find.textContaining('bundled 45-second'), findsOneWidget);
    expect(find.textContaining('microphone'), findsOneWidget);
    final start = find.byKey(const Key('benchmark-start'));
    await tester.tap(start);
    await tester.tap(start);
    await tester.pump();

    expect(runner.runCalls, 1);
    expect(find.byKey(const Key('benchmark-start')), findsNothing);
    expect(find.byKey(const Key('benchmark-cancel')), findsOneWidget);
  });

  testWidgets('running state shows progress and can be cancelled', (
    tester,
  ) async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    await tester.tap(find.byKey(const Key('benchmark-start')));
    run.add(const BenchmarkProgressed(0.42));
    await tester.pump();

    expect(find.byKey(const Key('benchmark-progress')), findsOneWidget);
    expect(find.text('42% complete'), findsOneWidget);
    await tester.tap(find.byKey(const Key('benchmark-cancel')));
    await tester.pump();

    expect(find.text('Check cancelled'), findsOneWidget);
    expect(find.byKey(const Key('benchmark-start')), findsOneWidget);
  });

  testWidgets('completed result is advisory and never applies settings', (
    tester,
  ) async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    await tester.tap(find.byKey(const Key('benchmark-start')));
    run.add(BenchmarkSucceeded(_report()));
    await tester.pump();

    expect(find.text('Recommended mode'), findsOneWidget);
    expect(find.text('Balanced'), findsWidgets);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Unmeasured'), findsOneWidget);
    expect(
      find.text(
        'This recommendation comes from a short check, not a long-session '
        'guarantee. Review it before choosing a mode.',
      ),
      findsOneWidget,
    );
    expect(find.text('Real-time factor: 0.5×'), findsOneWidget);
    expect(find.text('First text latency: 2000 ms'), findsOneWidget);
    expect(find.byKey(const Key('benchmark-rerun')), findsOneWidget);
    expect(find.byKey(const Key('benchmark-apply')), findsNothing);
    expect(find.textContaining('Apply recommendation'), findsNothing);
  });

  testWidgets('typed failure is retryable without stale recommendation', (
    tester,
  ) async {
    final runs = [_ControlledRun(), _ControlledRun()];
    var index = 0;
    final runner = FakePerformanceBenchmarkRunner(
      onRun: (_) => runs[index++].stream,
    );
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    await tester.tap(find.byKey(const Key('benchmark-start')));
    runs[0].add(
      const BenchmarkRunFailed(BenchmarkInvalidOutput()),
    );
    await tester.pump();

    expect(find.text('Check could not finish'), findsOneWidget);
    expect(find.textContaining('invalid output'), findsOneWidget);
    expect(find.text('Recommended mode'), findsNothing);
    await tester.tap(find.byKey(const Key('benchmark-retry')));
    await tester.pump();

    expect(runner.runCalls, 2);
    expect(find.byKey(const Key('benchmark-progress')), findsOneWidget);
    expect(find.text('Recommended mode'), findsNothing);
  });

  testWidgets('rerun starts cleanly and never reads audio capture', (
    tester,
  ) async {
    final runs = [_ControlledRun(), _ControlledRun()];
    var index = 0;
    final runner = FakePerformanceBenchmarkRunner(
      onRun: (_) => runs[index++].stream,
    );
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    await tester.tap(find.byKey(const Key('benchmark-start')));
    runs[0].add(BenchmarkSucceeded(_report()));
    await tester.pump();
    final rerun = find.byKey(const Key('benchmark-rerun'));
    await tester.ensureVisible(rerun);
    await tester.tap(rerun);
    await tester.pump();

    expect(runner.runCalls, 2);
    expect(find.byKey(const Key('benchmark-progress')), findsOneWidget);
    expect(find.text('Recommended mode'), findsNothing);
  });
}

Widget _app(
  FakePerformanceBenchmarkRunner runner, {
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    performanceBenchmarkRunnerProvider.overrideWithValue(runner),
    audioCaptureServiceProvider.overrideWith(
      (ref) => throw StateError('benchmark screen read audio capture'),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLoquirisTheme(Brightness.light),
    home: const ModelsPerformanceScreen(),
  ),
);

final class _ControlledRun {
  late final StreamController<PerformanceBenchmarkEvent> _controller =
      StreamController<PerformanceBenchmarkEvent>(sync: true);

  Stream<PerformanceBenchmarkEvent> get stream => _controller.stream;

  void add(PerformanceBenchmarkEvent event) => _controller.add(event);
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
    BenchmarkModeMeasurement(
      mode: PerformanceMode.powerSaving,
      status: BenchmarkMeasurementStatus.failed,
      blockingReasonCodes: const ['benchmark_engine_failed'],
    ),
    BenchmarkModeMeasurement(
      mode: PerformanceMode.postSession,
      status: BenchmarkMeasurementStatus.unmeasured,
    ),
  ],
);
