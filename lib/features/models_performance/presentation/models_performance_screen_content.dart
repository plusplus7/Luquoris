part of 'models_performance_screen.dart';

final class _BenchmarkDisclosure extends StatelessWidget {
  const _BenchmarkDisclosure();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.section),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.privacy_tip_outlined),
            ),
            SizedBox(width: spacing.related),
            Expanded(child: Text(l10n.benchmarkFixedAudioDisclosure)),
          ],
        ),
      ),
    );
  }
}

final class _BenchmarkMessage extends StatelessWidget {
  const _BenchmarkMessage({
    required this.icon,
    required this.title,
    this.body,
    this.liveLabel,
    this.actionKey,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? liveLabel;
  final Key? actionKey;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final spacing = LoquirisSpacing.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (liveLabel case final label?)
              Semantics(
                container: true,
                liveRegion: true,
                label: label,
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              )
            else
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: spacing.related),
            ExcludeSemantics(child: Icon(icon, size: 32)),
            if (body case final message?) ...[
              SizedBox(height: spacing.related),
              Text(message),
            ],
            if (onAction case final action?) ...[
              SizedBox(height: spacing.section),
              _BenchmarkAction(
                key: actionKey,
                label: actionLabel!,
                icon: actionIcon!,
                sortOrder: 10,
                onPressed: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _BenchmarkRunning extends StatelessWidget {
  const _BenchmarkRunning({required this.progress, required this.onCancel});

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final progressLabel = l10n.benchmarkProgressPercent(
      _progressPercent(progress),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: l10n.benchmarkRunningHeading,
          child: ExcludeSemantics(
            child: Text(
              l10n.benchmarkRunningHeading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        SizedBox(height: spacing.related),
        Semantics(
          container: true,
          label: progressLabel,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  key: const Key('benchmark-progress'),
                  value: progress,
                ),
                SizedBox(height: spacing.related),
                Text(progressLabel),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.section),
        _BenchmarkAction(
          key: const Key('benchmark-cancel'),
          label: l10n.benchmarkCancelAction,
          icon: Icons.close,
          sortOrder: 10,
          outlined: true,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

final class _BenchmarkCompleted extends StatelessWidget {
  const _BenchmarkCompleted({
    required this.report,
    required this.recommendation,
    required this.onRerun,
  });

  final PerformanceBenchmarkReport report;
  final BenchmarkRecommendation recommendation;
  final VoidCallback onRerun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: l10n.benchmarkCompletedSemantic,
          child: ExcludeSemantics(
            child: Text(
              l10n.benchmarkRecommendationHeading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        SizedBox(height: spacing.related),
        Text(
          _modeLabel(l10n, recommendation.mode),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: spacing.related),
        Text(_recommendationText(l10n, recommendation)),
        SizedBox(height: spacing.related),
        Text(l10n.benchmarkShortCheckLimitation),
        SizedBox(height: spacing.section),
        Text(
          l10n.benchmarkEvidenceHeading,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: spacing.related),
        for (final measurement in report.measurements) ...[
          _BenchmarkStatusRow(
            measurement: measurement,
            status: _evidenceStatus(measurement, recommendation),
          ),
          SizedBox(height: spacing.related),
        ],
        _BenchmarkAction(
          key: const Key('benchmark-rerun'),
          label: l10n.benchmarkRerunAction,
          icon: Icons.refresh,
          sortOrder: 20,
          outlined: true,
          onPressed: onRerun,
        ),
      ],
    );
  }
}

final class _BenchmarkStatusRow extends StatelessWidget {
  const _BenchmarkStatusRow({required this.measurement, required this.status});

  final BenchmarkModeMeasurement measurement;
  final _EvidenceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final mode = _modeLabel(l10n, measurement.mode);
    final statusLabel = _statusLabel(l10n, status);
    final icon = switch (status) {
      _EvidenceStatus.passed => Icons.check_circle_outline,
      _EvidenceStatus.failed => Icons.error_outline,
      _EvidenceStatus.unmeasured => Icons.help_outline,
      _EvidenceStatus.measured => Icons.analytics_outlined,
    };
    return Semantics(
      container: true,
      label: l10n.benchmarkModeStatusSemantic(mode, statusLabel),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: EdgeInsetsDirectional.all(spacing.related),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                SizedBox(width: spacing.related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode),
                      Text(statusLabel),
                      if (measurement.realTimeFactor case final value?)
                        Text(l10n.benchmarkRtfMetric(value)),
                      if (measurement.firstTextLatency case final latency?)
                        Text(
                          l10n.benchmarkLatencyMetric(
                            latency.inMilliseconds,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
