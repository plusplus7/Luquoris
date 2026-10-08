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
import 'package:loquiris/theme/app_theme.dart';

import '../support/fakes/fake_performance_benchmark_runner.dart';
import '../support/harness.dart';

void main() {
  testWidgets('compact 200 percent text stays scrollable and operable', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final runner = FakePerformanceBenchmarkRunner();

    await tester.pumpWidget(
      _app(
        runner,
        textScaler: const TextScaler.linear(2),
        boldText: true,
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('benchmark-start')));
    final start = find.bySemanticsLabel('Start performance check');
    final size = tester.getSize(start);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('running and terminal states expose restrained live regions', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);

    await tester.pumpWidget(_app(runner, accessibleNavigation: true));
    await tester.pump();
    final start = find.bySemanticsLabel('Start performance check');
    await tester.ensureVisible(start);
    await tester.tap(start);
    run.add(const BenchmarkProgressed(0.37));
    await tester.pump();

    final running = tester.getSemantics(
      find.bySemanticsLabel('Performance check running'),
    );
    expect(
      running,
      isSemantics(
        label: 'Performance check running',
        isLiveRegion: true,
      ),
    );
    final cancel = tester.getSemantics(
      find.bySemanticsLabel('Cancel performance check'),
    );
    expect(
      cancel,
      isSemantics(
        label: 'Cancel performance check',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    run.add(
      const BenchmarkRunFailed(BenchmarkEngineFailure('engine_failed')),
    );
    await tester.pump();
    final failed = tester.getSemantics(
      find.bySemanticsLabel('Performance check failed'),
    );
    expect(
      failed,
      isSemantics(
        label: 'Performance check failed',
        isLiveRegion: true,
      ),
    );
  });

  testWidgets('status rows use words and distinct icons, not color alone', (
    tester,
  ) async {
    final run = _ControlledRun();
    final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Start performance check'));
    run.add(
      BenchmarkSucceeded(
        PerformanceBenchmarkReport(
          schemaVersion: 1,
          policyVersion: 1,
          definition: firstRunBenchmarkDefinition,
          engineId: 'engine',
          engineVersion: '1',
          modelId: 'model',
          modelVersion: '1',
          configurationId: 'cpu',
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
            ),
            BenchmarkModeMeasurement(
              mode: PerformanceMode.postSession,
              status: BenchmarkMeasurementStatus.unmeasured,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Unmeasured'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  testWidgets(
    'export action is a labeled 48 dp secondary control at 200 percent text',
    (
      tester,
    ) async {
      tester.useDevice(TestDevice.compact);
      final run = _ControlledRun();
      final runner = FakePerformanceBenchmarkRunner(onRun: (_) => run.stream);
      await tester.pumpWidget(
        _app(
          runner,
          textScaler: const TextScaler.linear(2),
          boldText: true,
        ),
      );
      await tester.pump();
      final start = find.bySemanticsLabel('Start performance check');
      await tester.ensureVisible(start);
      await tester.tap(start);
      run.add(BenchmarkSucceeded(_report()));
      await tester.pump();

      final export = find.bySemanticsLabel('Export report');
      await tester.ensureVisible(export);
      final semantics = tester.getSemantics(export);
      final size = tester.getSize(export);

      expect(
        semantics,
        isSemantics(
          label: 'Export report',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: export, matching: find.byType(OutlinedButton)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(
  FakePerformanceBenchmarkRunner runner, {
  TextScaler textScaler = TextScaler.noScaling,
  bool boldText = false,
  bool accessibleNavigation = false,
}) => ProviderScope(
  overrides: [performanceBenchmarkRunnerProvider.overrideWithValue(runner)],
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: textScaler,
        boldText: boldText,
        accessibleNavigation: accessibleNavigation,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildLoquirisTheme(Brightness.light),
        home: const ModelsPerformanceScreen(),
      ),
    ),
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
  configurationId: 'cpu',
  measurements: [
    BenchmarkModeMeasurement(
      mode: PerformanceMode.balanced,
      status: BenchmarkMeasurementStatus.measured,
      realTimeFactor: 0.5,
      firstTextLatency: const Duration(seconds: 2),
    ),
  ],
);
