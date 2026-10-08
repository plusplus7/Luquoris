import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

part 'models_performance_screen_content.dart';

/// Shows the explicit fixed-audio benchmark and its advisory recommendation.
final class ModelsPerformanceScreen extends ConsumerWidget {
  /// Creates the models and performance screen.
  const ModelsPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      modelsPerformanceControllerProvider.select(
        (state) => switch (state) {
          ModelsPerformanceCompleted(
            :final exportReceipt,
            :final exportFailureCode,
          ) =>
            (receipt: exportReceipt, failureCode: exportFailureCode),
          _ => (receipt: null, failureCode: null),
        },
      ),
      (previous, next) {
        final message = switch (next) {
          (:final receipt?, failureCode: _)
              when !identical(previous?.receipt, receipt) =>
            l10n.benchmarkExportSucceeded(receipt.fileName),
          (receipt: _, failureCode: 'export_cancelled')
              when previous?.failureCode != next.failureCode =>
            l10n.benchmarkExportCancelled,
          (receipt: _, :final failureCode?)
              when previous?.failureCode != failureCode =>
            l10n.benchmarkExportFailed,
          _ => null,
        };
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
    );
    final state = ref.watch(modelsPerformanceControllerProvider);
    final controller = ref.read(modelsPerformanceControllerProvider.notifier);
    final spacing = LoquirisSpacing.of(context);
    return Scaffold(
      key: const ValueKey<String>('models-performance'),
      appBar: AppBar(title: Text(l10n.modelsPerformanceTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.all(spacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.benchmarkIntro),
                  SizedBox(height: spacing.section),
                  const _BenchmarkDisclosure(),
                  SizedBox(height: spacing.section),
                  _BenchmarkStateView(
                    state: state,
                    onStart: controller.start,
                    onCancel: () => unawaited(controller.cancel()),
                    onExport: controller.exportReport,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _BenchmarkStateView extends StatelessWidget {
  const _BenchmarkStateView({
    required this.state,
    required this.onStart,
    required this.onCancel,
    required this.onExport,
  });

  final ModelsPerformanceState state;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      ModelsPerformanceUnavailable(:final reasonCode) => _BenchmarkMessage(
        icon: Icons.block_outlined,
        title: l10n.benchmarkUnavailableHeading,
        body: _unavailableText(l10n, reasonCode),
      ),
      ModelsPerformanceReady() => _BenchmarkMessage(
        icon: Icons.speed_outlined,
        title: l10n.benchmarkReadyHeading,
        actionKey: const Key('benchmark-start'),
        actionLabel: l10n.benchmarkStartAction,
        actionIcon: Icons.play_arrow,
        onAction: onStart,
      ),
      ModelsPerformanceRunning(:final progress) => _BenchmarkRunning(
        progress: progress,
        onCancel: onCancel,
      ),
      ModelsPerformanceCompleted(
        :final report,
        :final recommendation,
        :final isExporting,
      ) =>
        _BenchmarkCompleted(
          report: report,
          recommendation: recommendation,
          isExporting: isExporting,
          onRerun: onStart,
          onExport: onExport,
        ),
      ModelsPerformanceFailed(:final failure) => _BenchmarkMessage(
        icon: Icons.error_outline,
        title: l10n.benchmarkFailureHeading,
        body: _failureText(l10n, failure),
        liveLabel: l10n.benchmarkFailedSemantic,
        actionKey: const Key('benchmark-retry'),
        actionLabel: l10n.benchmarkRetryAction,
        actionIcon: Icons.refresh,
        onAction: onStart,
      ),
      ModelsPerformanceCancelled() => _BenchmarkMessage(
        icon: Icons.cancel_outlined,
        title: l10n.benchmarkCancelledHeading,
        body: l10n.benchmarkCancelledBody,
        liveLabel: l10n.benchmarkCancelledHeading,
        actionKey: const Key('benchmark-start'),
        actionLabel: l10n.benchmarkStartAction,
        actionIcon: Icons.play_arrow,
        onAction: onStart,
      ),
    };
  }
}

enum _EvidenceStatus { passed, failed, unmeasured, measured }

int _progressPercent(double progress) => (progress * 100).round();

String _unavailableText(AppLocalizations l10n, String reasonCode) =>
    reasonCode == 'benchmark_runtime_not_installed'
    ? l10n.benchmarkUnavailableRuntimeBody
    : l10n.benchmarkFailureRuntimeUnavailable;

String _failureText(AppLocalizations l10n, BenchmarkFailure failure) =>
    switch (failure) {
      BenchmarkAssetFailure() => l10n.benchmarkFailureInvalidAsset,
      BenchmarkInvalidOutput() => l10n.benchmarkFailureInvalidOutput,
      BenchmarkEngineFailure() => l10n.benchmarkFailureEngine,
      BenchmarkRuntimeFailure(code: 'benchmark_runtime_not_installed') =>
        l10n.benchmarkFailureRuntimeUnavailable,
      BenchmarkRuntimeFailure() => l10n.benchmarkFailureGeneric,
      BenchmarkCancelledFailure() => l10n.benchmarkCancelledBody,
    };

String _recommendationText(
  AppLocalizations l10n,
  BenchmarkRecommendation recommendation,
) => switch (recommendation.reasonCodes.firstOrNull) {
  'benchmark_balanced_eligible' => l10n.benchmarkRecommendationBalanced,
  'benchmark_power_saving_eligible' => l10n.benchmarkRecommendationPowerSaving,
  'benchmark_post_session_eligible' => l10n.benchmarkRecommendationPostSession,
  _ => l10n.benchmarkRecommendationRecordingOnly,
};

String _modeLabel(AppLocalizations l10n, PerformanceMode mode) =>
    switch (mode) {
      PerformanceMode.highQuality => l10n.benchmarkModeHighQuality,
      PerformanceMode.balanced => l10n.benchmarkModeBalanced,
      PerformanceMode.powerSaving => l10n.benchmarkModePowerSaving,
      PerformanceMode.recordingOnly => l10n.benchmarkModeRecordingOnly,
      PerformanceMode.postSession => l10n.benchmarkModePostSession,
    };

_EvidenceStatus _evidenceStatus(
  BenchmarkModeMeasurement measurement,
  BenchmarkRecommendation recommendation,
) {
  if (measurement == recommendation.evidence) return _EvidenceStatus.passed;
  return switch (measurement.status) {
    BenchmarkMeasurementStatus.measured => _EvidenceStatus.measured,
    BenchmarkMeasurementStatus.failed => _EvidenceStatus.failed,
    BenchmarkMeasurementStatus.unmeasured => _EvidenceStatus.unmeasured,
  };
}

String _statusLabel(AppLocalizations l10n, _EvidenceStatus status) =>
    switch (status) {
      _EvidenceStatus.passed => l10n.benchmarkStatusPassed,
      _EvidenceStatus.failed => l10n.benchmarkStatusFailed,
      _EvidenceStatus.unmeasured => l10n.benchmarkStatusUnmeasured,
      _EvidenceStatus.measured => l10n.benchmarkStatusMeasured,
    };

final class _BenchmarkAction extends StatelessWidget {
  const _BenchmarkAction({
    required this.label,
    required this.icon,
    required this.sortOrder,
    required this.onPressed,
    this.outlined = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final double sortOrder;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: ExcludeSemantics(child: Icon(icon)),
              label: Text(label),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: ExcludeSemantics(child: Icon(icon)),
              label: Text(label),
            ),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      sortKey: OrdinalSortKey(sortOrder),
      child: ExcludeSemantics(child: child),
    );
  }
}
