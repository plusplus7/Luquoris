import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_screen.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';
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

  testWidgets('export action appears only for completed report', (
    tester,
  ) async {
    final runs = [_ControlledRun(), _ControlledRun()];
    var runIndex = 0;
    final runner = FakePerformanceBenchmarkRunner(
      onRun: (_) => runs[runIndex++].stream,
    );
    await tester.pumpWidget(_app(runner));
    await tester.pump();

    expect(find.byKey(const Key('benchmark-export')), findsNothing);
    await tester.tap(find.byKey(const Key('benchmark-start')));
    await tester.pump();
    expect(find.byKey(const Key('benchmark-export')), findsNothing);
    await tester.tap(find.byKey(const Key('benchmark-cancel')));
    await tester.pump();
    expect(find.byKey(const Key('benchmark-export')), findsNothing);

    await tester.tap(find.byKey(const Key('benchmark-start')));
    runs[1].add(const BenchmarkRunFailed(BenchmarkInvalidOutput()));
    await tester.pump();
    expect(find.byKey(const Key('benchmark-export')), findsNothing);

    await tester.pumpWidget(
      _app(
        FakePerformanceBenchmarkRunner(
          availability: const BenchmarkUnavailable('runtime_missing'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('benchmark-export')), findsNothing);

    final completedRun = _ControlledRun();
    await tester.pumpWidget(
      _app(
        FakePerformanceBenchmarkRunner(onRun: (_) => completedRun.stream),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('benchmark-start')));
    completedRun.add(BenchmarkSucceeded(_report()));
    await tester.pump();

    expect(find.byKey(const Key('benchmark-export')), findsOneWidget);
  });

  testWidgets(
    'export action disables while in flight and duplicate taps write once',
    (
      tester,
    ) async {
      final pending = Completer<Result<ExportReceipt, ExportFailure>>();
      final exporter = _FakeBenchmarkReportExporter(
        onExport: () => pending.future,
      );
      final run = _ControlledRun();
      await tester.pumpWidget(
        _app(
          FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
          exporter: exporter,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('benchmark-start')));
      run.add(BenchmarkSucceeded(_report()));
      await tester.pump();

      final export = find.byKey(const Key('benchmark-export'));
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.tap(export);
      await tester.pump();

      expect(exporter.calls, 1);
      expect(find.text('Exporting report…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: export,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );

      pending.complete(Ok(_receipt()));
      await tester.pump();
      expect(exporter.calls, 1);
    },
  );

  testWidgets(
    'success cancellation and failure show localized feedback without changing recommendation',
    (tester) async {
      final outcomes = <Result<ExportReceipt, ExportFailure>>[
        Ok(_receipt()),
        const Err(ExportUnavailable('export_cancelled')),
        const Err(ExportUnavailable('content://private/raw-exception')),
      ];
      final exporter = _FakeBenchmarkReportExporter(
        onExport: () async => outcomes.removeAt(0),
      );
      final run = _ControlledRun();
      await tester.pumpWidget(
        _app(
          FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
          exporter: exporter,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('benchmark-start')));
      run.add(BenchmarkSucceeded(_report()));
      await tester.pump();

      final export = find.byKey(const Key('benchmark-export'));
      for (final expectedFeedback in <String>[
        'Saved benchmark-report.json.',
        'Export cancelled. No file was saved.',
        'Report could not be exported. Try again.',
      ]) {
        await tester.ensureVisible(export);
        await tester.tap(export);
        await tester.pump();
        expect(find.text(expectedFeedback), findsOneWidget);
        expect(find.text('Recommended mode'), findsOneWidget);
        expect(find.text('Mode evidence'), findsOneWidget);
        expect(find.textContaining('content://'), findsNothing);
        expect(find.textContaining('raw-exception'), findsNothing);
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();
      }

      expect(exporter.calls, 3);
    },
  );

  testWidgets('repeated identical export failures each show feedback', (
    tester,
  ) async {
    final outcomes = <Result<ExportReceipt, ExportFailure>>[
      const Err(ExportUnavailable('export_cancelled')),
      const Err(ExportUnavailable('export_cancelled')),
      const Err(ExportUnavailable('destination_unavailable')),
      const Err(ExportUnavailable('destination_unavailable')),
    ];
    final exporter = _FakeBenchmarkReportExporter(
      onExport: () async => outcomes.removeAt(0),
    );
    final run = _ControlledRun();
    await tester.pumpWidget(
      _app(
        FakePerformanceBenchmarkRunner(onRun: (_) => run.stream),
        exporter: exporter,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('benchmark-start')));
    run.add(BenchmarkSucceeded(_report()));
    await tester.pump();

    final export = find.byKey(const Key('benchmark-export'));
    for (final expectedFeedback in <String>[
      'Export cancelled. No file was saved.',
      'Export cancelled. No file was saved.',
      'Report could not be exported. Try again.',
      'Report could not be exported. Try again.',
    ]) {
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.pump();
      expect(find.text(expectedFeedback), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }

    expect(exporter.calls, 4);
  });
}

Widget _app(
  FakePerformanceBenchmarkRunner runner, {
  Locale locale = const Locale('en'),
  BenchmarkReportExporter? exporter,
}) => ProviderScope(
  overrides: [
    performanceBenchmarkRunnerProvider.overrideWithValue(runner),
    if (exporter != null)
      benchmarkReportExporterProvider.overrideWithValue(exporter),
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

final class _FakeBenchmarkReportExporter implements BenchmarkReportExporter {
  _FakeBenchmarkReportExporter({
    required this._onExport,
  });

  final Future<Result<ExportReceipt, ExportFailure>> Function() _onExport;
  int calls = 0;

  @override
  Future<Result<ExportReceipt, ExportFailure>> export({
    required PerformanceBenchmarkReport report,
    required String operationId,
    required DateTime createdAtUtc,
  }) {
    calls += 1;
    return _onExport();
  }
}

ExportReceipt _receipt() => ExportReceipt(
  fileName: 'benchmark-report.json',
  bytesWritten: 256,
);
