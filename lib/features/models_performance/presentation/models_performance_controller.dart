import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_recommendation_policy.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:uuid/uuid.dart';

/// Creates a fresh opaque identity for each benchmark export operation.
final benchmarkExportOperationIdProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

/// Immutable lifecycle state for the first-run performance check.
sealed class ModelsPerformanceState extends ValueObject {
  const ModelsPerformanceState();
}

/// The local benchmark runtime cannot currently execute.
final class ModelsPerformanceUnavailable extends ModelsPerformanceState {
  /// Creates an unavailable state with a privacy-safe [reasonCode].
  const ModelsPerformanceUnavailable(this.reasonCode);

  /// Stable reason mapped to localized presentation copy.
  final String reasonCode;

  @override
  List<Object?> get equalityValues => <Object?>[reasonCode];
}

/// The fixed-audio check is ready for an explicit user start.
final class ModelsPerformanceReady extends ModelsPerformanceState {
  /// Creates the ready state.
  const ModelsPerformanceReady();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// A single fixed-audio benchmark run is active.
final class ModelsPerformanceRunning extends ModelsPerformanceState {
  /// Creates a running state with normalized monotonic [progress].
  const ModelsPerformanceRunning(this.progress);

  /// Completion fraction between zero and one.
  final double progress;

  @override
  List<Object?> get equalityValues => <Object?>[progress];
}

/// A valid report and its advisory recommendation are available.
final class ModelsPerformanceCompleted extends ModelsPerformanceState {
  /// Creates a completed state from the exact measured [report].
  const ModelsPerformanceCompleted({
    required this.report,
    required this.recommendation,
    this.isExporting = false,
    this.exportReceipt,
    this.exportFailureCode,
  });

  /// Exact versioned report emitted by the runner.
  final PerformanceBenchmarkReport report;

  /// Pure recommendation derived from [report].
  final BenchmarkRecommendation recommendation;

  /// Whether the exact completed report is currently being exported.
  final bool isExporting;

  /// Receipt from the latest successful export, when present.
  final ExportReceipt? exportReceipt;

  /// Privacy-safe code from the latest unsuccessful export, when present.
  final String? exportFailureCode;

  /// Returns an export-state update while preserving the measured result.
  ModelsPerformanceCompleted copyWithExport({
    bool? isExporting,
    ExportReceipt? receipt,
    String? failureCode,
    bool clearOutcome = false,
  }) {
    return ModelsPerformanceCompleted(
      report: report,
      recommendation: recommendation,
      isExporting: isExporting ?? this.isExporting,
      exportReceipt: clearOutcome || failureCode != null
          ? null
          : receipt ?? exportReceipt,
      exportFailureCode: clearOutcome || receipt != null
          ? null
          : failureCode ?? exportFailureCode,
    );
  }

  @override
  List<Object?> get equalityValues => <Object?>[
    report,
    recommendation,
    isExporting,
    exportReceipt,
    exportFailureCode,
  ];
}

/// The run stopped with a typed, privacy-safe failure.
final class ModelsPerformanceFailed extends ModelsPerformanceState {
  /// Creates a failed state without raw exception details.
  const ModelsPerformanceFailed(this.failure);

  /// Failure safe to map to localized user-visible copy.
  final BenchmarkFailure failure;

  @override
  List<Object?> get equalityValues => <Object?>[failure];
}

/// The user deliberately stopped the active check.
final class ModelsPerformanceCancelled extends ModelsPerformanceState {
  /// Creates the cancelled acknowledgement state.
  const ModelsPerformanceCancelled();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// Owns one route-scoped, fixed-audio benchmark lifecycle.
final class ModelsPerformanceController
    extends Notifier<ModelsPerformanceState> {
  static const _policy = BenchmarkRecommendationPolicy();
  static const _runnerException = BenchmarkRuntimeFailure(
    'benchmark_runner_exception',
  );

  StreamSubscription<PerformanceBenchmarkEvent>? _subscription;
  int _runGeneration = 0;
  bool _terminalSeen = false;
  double _lastProgress = 0;

  @override
  ModelsPerformanceState build() {
    ref.onDispose(() {
      _runGeneration += 1;
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
    return switch (ref.watch(performanceBenchmarkRunnerProvider).availability) {
      BenchmarkAvailable() => const ModelsPerformanceReady(),
      BenchmarkUnavailable(:final reasonCode) => ModelsPerformanceUnavailable(
        reasonCode,
      ),
    };
  }

  /// Starts a clean run from any non-running, available result state.
  void start() {
    if (state
        case ModelsPerformanceUnavailable() || ModelsPerformanceRunning()) {
      return;
    }

    final generation = ++_runGeneration;
    final previous = _subscription;
    _subscription = null;
    if (previous != null) unawaited(previous.cancel());
    _terminalSeen = false;
    _lastProgress = 0;
    state = const ModelsPerformanceRunning(0);

    Stream<PerformanceBenchmarkEvent> events;
    try {
      events = ref
          .read(performanceBenchmarkRunnerProvider)
          .run(firstRunBenchmarkDefinition);
    } on Object {
      _finishMalformed(generation, _runnerException);
      return;
    }
    if (!ref.mounted || generation != _runGeneration) return;
    _subscription = events.listen(
      (event) => _onEvent(generation, event),
      onError: (Object error, StackTrace stackTrace) {
        _finishMalformed(generation, _runnerException);
      },
      onDone: () => _onDone(generation),
    );
  }

  /// Cancels only an active run and ignores all events racing behind it.
  Future<void> cancel() async {
    if (state is! ModelsPerformanceRunning) return;
    _runGeneration += 1;
    final subscription = _subscription;
    _subscription = null;
    _terminalSeen = false;
    _lastProgress = 0;
    state = const ModelsPerformanceCancelled();
    try {
      await subscription?.cancel();
    } on Object {
      // Cancellation is best-effort; the generation guard still rejects events.
    }
  }

  /// Exports the current completed report, coalescing concurrent requests.
  Future<void> exportReport() async {
    final completed = state;
    if (completed is! ModelsPerformanceCompleted || completed.isExporting) {
      return;
    }

    state = completed.copyWithExport(
      isExporting: true,
      clearOutcome: true,
    );
    late final Result<ExportReceipt, ExportFailure> outcome;
    try {
      outcome = await ref
          .read(benchmarkReportExporterProvider)
          .export(
            report: completed.report,
            operationId: ref.read(benchmarkExportOperationIdProvider)(),
            createdAtUtc: ref.read(clockProvider).now().toUtc(),
          );
    } on Object {
      outcome = const Err(
        ExportUnavailable('benchmark_export_exception'),
      );
    }

    if (!ref.mounted) return;
    final latest = state;
    if (latest is! ModelsPerformanceCompleted ||
        !identical(latest.report, completed.report)) {
      return;
    }
    state = switch (outcome) {
      Ok(:final value) => latest.copyWithExport(
        isExporting: false,
        receipt: value,
      ),
      Err(:final failure) => latest.copyWithExport(
        isExporting: false,
        failureCode: failure.code,
      ),
    };
  }

  void _onEvent(int generation, PerformanceBenchmarkEvent event) {
    if (!ref.mounted || generation != _runGeneration) return;
    if (_terminalSeen) {
      _finishMalformed(generation, const BenchmarkInvalidOutput());
      return;
    }
    switch (event) {
      case BenchmarkProgressed(:final progress):
        if (!progress.isFinite ||
            progress < 0 ||
            progress > 1 ||
            progress < _lastProgress) {
          _finishMalformed(generation, const BenchmarkInvalidOutput());
          return;
        }
        _lastProgress = progress;
        state = ModelsPerformanceRunning(progress);
      case BenchmarkSucceeded(:final report):
        _terminalSeen = true;
        state = switch (_policy.recommend(report)) {
          Ok(:final value) => ModelsPerformanceCompleted(
            report: report,
            recommendation: value,
          ),
          Err(:final failure) => ModelsPerformanceFailed(failure),
        };
      case BenchmarkRunFailed(:final failure):
        _terminalSeen = true;
        state = ModelsPerformanceFailed(failure);
    }
  }

  void _onDone(int generation) {
    if (!ref.mounted || generation != _runGeneration) return;
    _subscription = null;
    if (!_terminalSeen) {
      _finishMalformed(generation, const BenchmarkInvalidOutput());
    }
  }

  void _finishMalformed(int generation, BenchmarkFailure failure) {
    if (!ref.mounted || generation != _runGeneration) return;
    _runGeneration += 1;
    final subscription = _subscription;
    _subscription = null;
    _terminalSeen = false;
    _lastProgress = 0;
    state = ModelsPerformanceFailed(failure);
    if (subscription != null) unawaited(subscription.cancel());
  }
}

/// Auto-disposed state owner for the models and performance route.
final NotifierProvider<ModelsPerformanceController, ModelsPerformanceState>
modelsPerformanceControllerProvider =
    NotifierProvider.autoDispose<
      ModelsPerformanceController,
      ModelsPerformanceState
    >(ModelsPerformanceController.new);
