part of 'models_performance_screen.dart';

final class _PerformancePolicyOverview extends StatelessWidget {
  const _PerformancePolicyOverview({required this.recommendedMode});

  final PerformanceMode? recommendedMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final policies = PerformancePolicyCatalog.standard.policies;
    return Column(
      key: const Key('performance-policy-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.performancePolicyHeading,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: spacing.section),
        for (var index = 0; index < policies.length; index++) ...[
          _PerformancePolicyCard(
            policy: policies[index],
            isRecommended: policies[index].mode == recommendedMode,
          ),
          if (index != policies.length - 1) SizedBox(height: spacing.related),
        ],
        SizedBox(height: spacing.section),
        Text(
          l10n.performancePolicyProtectionHeading,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: spacing.related),
        _PerformanceProtection(
          icon: Icons.thermostat_outlined,
          text: l10n.performancePolicyProtectionModerateThermal,
        ),
        SizedBox(height: spacing.related),
        _PerformanceProtection(
          icon: Icons.device_thermostat_outlined,
          text: l10n.performancePolicyProtectionSevereThermal,
        ),
        SizedBox(height: spacing.related),
        _PerformanceProtection(
          icon: Icons.pending_actions_outlined,
          text: l10n.performancePolicyProtectionBacklog,
        ),
        SizedBox(height: spacing.related),
        _PerformanceProtection(
          icon: Icons.mic_none_outlined,
          text: l10n.performancePolicyProtectionRecordingFirst,
        ),
      ],
    );
  }
}

final class _PerformancePolicyCard extends StatelessWidget {
  const _PerformancePolicyCard({
    required this.policy,
    required this.isRecommended,
  });

  final PerformanceModePolicy policy;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final mode = _modeLabel(l10n, policy.mode);
    final timing = _performancePolicyTiming(l10n, policy.timing);
    final description = _performancePolicyDescription(l10n, policy.mode);
    final fallback = _performancePolicyFallback(l10n, policy.mode);
    final semanticParts = <String>[
      mode,
      timing,
      description,
      fallback,
      l10n.performancePolicyLockedBody,
      if (isRecommended) l10n.performancePolicyRecommendedLabel,
    ];
    return Semantics(
      key: Key('performance-policy-${policy.mode.name}'),
      container: true,
      label: semanticParts.join('\n'),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: EdgeInsetsDirectional.all(spacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(mode, style: Theme.of(context).textTheme.titleLarge),
                if (isRecommended) ...[
                  SizedBox(height: spacing.related),
                  _PerformancePolicyDetail(
                    icon: Icons.recommend_outlined,
                    text: l10n.performancePolicyRecommendedLabel,
                  ),
                ],
                SizedBox(height: spacing.related),
                _PerformancePolicyDetail(
                  icon: Icons.schedule_outlined,
                  text: timing,
                ),
                SizedBox(height: spacing.related),
                Text(description),
                SizedBox(height: spacing.related),
                _PerformancePolicyDetail(
                  icon: Icons.alt_route_outlined,
                  text: fallback,
                ),
                SizedBox(height: spacing.related),
                _PerformancePolicyDetail(
                  icon: Icons.lock_outline,
                  text: l10n.performancePolicyLockedBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _PerformancePolicyDetail extends StatelessWidget {
  const _PerformancePolicyDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = LoquirisSpacing.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon)),
        SizedBox(width: spacing.related),
        Expanded(child: Text(text)),
      ],
    );
  }
}

final class _PerformanceProtection extends StatelessWidget {
  const _PerformanceProtection({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = LoquirisSpacing.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon)),
        SizedBox(width: spacing.related),
        Expanded(child: Text(text)),
      ],
    );
  }
}

String _performancePolicyTiming(
  AppLocalizations l10n,
  PerformanceExecutionTiming timing,
) => switch (timing) {
  PerformanceExecutionTiming.liveOrPostSession =>
    l10n.performancePolicyTimingLiveOrPostSession,
  PerformanceExecutionTiming.postSessionOnly =>
    l10n.performancePolicyTimingPostSessionOnly,
  PerformanceExecutionTiming.disabled => l10n.performancePolicyTimingDisabled,
};

String _performancePolicyDescription(
  AppLocalizations l10n,
  PerformanceMode mode,
) => switch (mode) {
  PerformanceMode.highQuality => l10n.performancePolicyHighQualityDescription,
  PerformanceMode.balanced => l10n.performancePolicyBalancedDescription,
  PerformanceMode.powerSaving => l10n.performancePolicyPowerSavingDescription,
  PerformanceMode.postSession => l10n.performancePolicyPostSessionDescription,
  PerformanceMode.recordingOnly =>
    l10n.performancePolicyRecordingOnlyDescription,
};

String _performancePolicyFallback(
  AppLocalizations l10n,
  PerformanceMode mode,
) => switch (mode) {
  PerformanceMode.highQuality => l10n.performancePolicyHighQualityFallback,
  PerformanceMode.balanced => l10n.performancePolicyBalancedFallback,
  PerformanceMode.powerSaving => l10n.performancePolicyPowerSavingFallback,
  PerformanceMode.postSession => l10n.performancePolicyPostSessionFallback,
  PerformanceMode.recordingOnly => l10n.performancePolicyRecordingOnlyFallback,
};
