import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

/// Capture-relative timing allowed by one performance policy.
enum PerformanceExecutionTiming {
  /// Inference may run during capture or after capture completes.
  liveOrPostSession,

  /// Inference may run only after capture completes.
  postSessionOnly,

  /// Inference is disabled.
  disabled,
}

/// Accuracy intent independent from a concrete model implementation.
enum PerformanceQualityIntent {
  /// Prefer the highest validated local quality.
  highest,

  /// Balance accuracy against local resource use.
  balanced,

  /// Prefer conservative resource use.
  conservative,

  /// No inference quality target applies.
  none,
}

/// Relative resource allowance independent from engine-specific thread counts.
enum PerformanceResourceIntent {
  /// Allow the largest validated inference budget.
  expanded,

  /// Use the default validated inference budget.
  standard,

  /// Reduce the validated inference budget.
  reduced,

  /// Reserve resources for canonical audio capture.
  captureOnly,
}

/// Immutable semantics for one user-facing [PerformanceMode].
@immutable
final class PerformanceModePolicy extends ValueObject {
  /// Creates a mode policy with an ordered safe fallback path.
  PerformanceModePolicy({
    required this.mode,
    required this.timing,
    required this.qualityIntent,
    required this.resourceIntent,
    required List<PerformanceMode> safeFallbacks,
  }) : safeFallbacks = List<PerformanceMode>.unmodifiable(safeFallbacks);

  /// Mode described by this policy.
  final PerformanceMode mode;

  /// Capture-relative timing this mode permits.
  final PerformanceExecutionTiming timing;

  /// Quality goal without choosing a concrete model.
  final PerformanceQualityIntent qualityIntent;

  /// Relative resource goal without choosing engine parameters.
  final PerformanceResourceIntent resourceIntent;

  /// Ordered modes that are no more aggressive than this mode.
  final List<PerformanceMode> safeFallbacks;

  @override
  List<Object?> get equalityValues => <Object?>[
    mode,
    timing,
    qualityIntent,
    resourceIntent,
    safeFallbacks.length,
    ...safeFallbacks,
  ];
}

/// Validated, complete catalog of performance-mode semantics.
final class PerformancePolicyCatalog {
  /// Validates and owns exactly one immutable policy for every mode.
  PerformancePolicyCatalog(List<PerformanceModePolicy> policies) {
    final byMode = <PerformanceMode, PerformanceModePolicy>{};
    for (final policy in policies) {
      if (byMode.containsKey(policy.mode)) {
        throw ArgumentError.value(
          policy.mode,
          'policies',
          'contains a duplicate mode',
        );
      }
      byMode[policy.mode] = policy;
    }
    if (byMode.length != PerformanceMode.values.length ||
        !PerformanceMode.values.every(byMode.containsKey)) {
      throw ArgumentError.value(
        policies,
        'policies',
        'must contain every performance mode exactly once',
      );
    }
    _validateFallbacks(byMode);
    _policies = List<PerformanceModePolicy>.unmodifiable(
      PerformanceMode.values.map((mode) => byMode[mode]!),
    );
    _byMode = Map<PerformanceMode, PerformanceModePolicy>.unmodifiable(byMode);
  }

  /// Approved policy catalog used by recommendation and runtime consumers.
  static final PerformancePolicyCatalog standard = PerformancePolicyCatalog([
    PerformanceModePolicy(
      mode: PerformanceMode.highQuality,
      timing: PerformanceExecutionTiming.postSessionOnly,
      qualityIntent: PerformanceQualityIntent.highest,
      resourceIntent: PerformanceResourceIntent.expanded,
      safeFallbacks: const [
        PerformanceMode.balanced,
        PerformanceMode.postSession,
        PerformanceMode.recordingOnly,
      ],
    ),
    PerformanceModePolicy(
      mode: PerformanceMode.balanced,
      timing: PerformanceExecutionTiming.liveOrPostSession,
      qualityIntent: PerformanceQualityIntent.balanced,
      resourceIntent: PerformanceResourceIntent.standard,
      safeFallbacks: const [
        PerformanceMode.powerSaving,
        PerformanceMode.postSession,
        PerformanceMode.recordingOnly,
      ],
    ),
    PerformanceModePolicy(
      mode: PerformanceMode.powerSaving,
      timing: PerformanceExecutionTiming.liveOrPostSession,
      qualityIntent: PerformanceQualityIntent.conservative,
      resourceIntent: PerformanceResourceIntent.reduced,
      safeFallbacks: const [
        PerformanceMode.postSession,
        PerformanceMode.recordingOnly,
      ],
    ),
    PerformanceModePolicy(
      mode: PerformanceMode.postSession,
      timing: PerformanceExecutionTiming.postSessionOnly,
      qualityIntent: PerformanceQualityIntent.balanced,
      resourceIntent: PerformanceResourceIntent.standard,
      safeFallbacks: const [PerformanceMode.recordingOnly],
    ),
    PerformanceModePolicy(
      mode: PerformanceMode.recordingOnly,
      timing: PerformanceExecutionTiming.disabled,
      qualityIntent: PerformanceQualityIntent.none,
      resourceIntent: PerformanceResourceIntent.captureOnly,
      safeFallbacks: const [],
    ),
  ]);

  late final List<PerformanceModePolicy> _policies;
  late final Map<PerformanceMode, PerformanceModePolicy> _byMode;

  /// Policies in stable [PerformanceMode] declaration order.
  List<PerformanceModePolicy> get policies => _policies;

  /// Returns the complete policy for [mode].
  PerformanceModePolicy policyFor(PerformanceMode mode) => _byMode[mode]!;
}

const _approvedFallbacks = <PerformanceMode, Set<PerformanceMode>>{
  PerformanceMode.highQuality: {
    PerformanceMode.balanced,
    PerformanceMode.postSession,
    PerformanceMode.recordingOnly,
  },
  PerformanceMode.balanced: {
    PerformanceMode.powerSaving,
    PerformanceMode.postSession,
    PerformanceMode.recordingOnly,
  },
  PerformanceMode.powerSaving: {
    PerformanceMode.postSession,
    PerformanceMode.recordingOnly,
  },
  PerformanceMode.postSession: {PerformanceMode.recordingOnly},
  PerformanceMode.recordingOnly: {},
};

void _validateFallbacks(
  Map<PerformanceMode, PerformanceModePolicy> policies,
) {
  for (final policy in policies.values) {
    final seen = <PerformanceMode>{};
    for (final fallback in policy.safeFallbacks) {
      if (fallback == policy.mode ||
          !seen.add(fallback) ||
          !_approvedFallbacks[policy.mode]!.contains(fallback)) {
        throw ArgumentError.value(
          policy.safeFallbacks,
          'safeFallbacks',
          'must contain distinct approved safer modes',
        );
      }
    }
  }

  for (final start in PerformanceMode.values) {
    final visiting = <PerformanceMode>{};
    void visit(PerformanceMode mode) {
      if (!visiting.add(mode)) {
        throw ArgumentError.value(
          policies,
          'policies',
          'fallback graph contains a cycle',
        );
      }
      for (final fallback in policies[mode]!.safeFallbacks) {
        visit(fallback);
      }
      visiting.remove(mode);
    }

    visit(start);
  }
}
