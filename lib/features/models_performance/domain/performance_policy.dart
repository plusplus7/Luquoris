import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
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

/// Coarse thermal pressure consumed by the pure policy engine.
enum PerformanceThermalPressure {
  /// No thermal protection is required.
  nominal,

  /// AI concurrency should be reduced.
  moderate,

  /// Live AI should pause while recording continues.
  severe,

  /// The thermal condition could not be classified safely.
  unknown,
}

/// Whether live inference is keeping up with captured audio.
enum PerformanceBacklogPressure {
  /// The measured backlog remains within the validated bound.
  withinLimit,

  /// The measured backlog has remained beyond the validated bound.
  sustainedBeyondLimit,

  /// Backlog health could not be classified safely.
  unknown,
}

/// Coarse memory pressure consumed by the pure policy engine.
enum PerformanceMemoryPressure {
  /// No memory protection is required.
  normal,

  /// AI should pause to preserve recording resources.
  critical,

  /// Memory pressure could not be classified safely.
  unknown,
}

/// Availability of optional acceleration and the validated CPU path.
enum PerformanceAccelerationState {
  /// The selected acceleration path is available.
  available,

  /// Optional acceleration is absent but validated CPU fallback is available.
  unavailableWithCpuFallback,

  /// Neither the selected acceleration nor a same-mode CPU path is available.
  unavailable,
}

/// Availability of the local inference engine.
enum PerformanceEngineState {
  /// The engine is ready to accept local work.
  available,

  /// The engine cannot currently execute work.
  unavailable,
}

/// Effective AI activity chosen without controlling a concrete engine.
enum PerformanceAiDisposition {
  /// Live AI may run with its normal validated budget.
  running,

  /// Live AI may run with a reduced validated budget.
  throttled,

  /// Live AI must pause while capture continues.
  paused,

  /// AI work is retained for post-session processing.
  deferred,

  /// No AI work is scheduled.
  disabled,
}

/// Action presentation can offer for the primary policy reason.
enum PerformanceRecoveryAction {
  /// No recovery action is needed.
  none,

  /// Let the device cool before expecting normal AI work.
  coolDevice,

  /// Preserve the work for post-session processing.
  continuePostSession,

  /// Retry the local engine later without affecting recording.
  retryEngineLater,

  /// Select a locally supported safer mode.
  selectSupportedMode,

  /// Continue with canonical recording and no AI work.
  continueRecordingOnly,
}

/// Closed privacy-safe reasons for automatic policy decisions.
enum PerformanceDegradationReason {
  /// The requested or current mode is not locally supported.
  modeUnsupported('performance_policy_mode_unsupported'),

  /// The local inference engine is unavailable.
  engineUnavailable('performance_policy_engine_unavailable'),

  /// Moderate thermal pressure reduced AI concurrency.
  thermalModerate('performance_policy_thermal_moderate'),

  /// Severe thermal pressure paused live AI.
  thermalSevere('performance_policy_thermal_severe'),

  /// Critical memory pressure paused live AI.
  memoryCritical('performance_policy_memory_critical'),

  /// Sustained backlog deferred live work.
  backlogSustained('performance_policy_backlog_sustained'),

  /// Low-power policy reduced or deferred AI work.
  lowPower('performance_policy_low_power'),

  /// Optional acceleration fell back to a validated CPU path.
  cpuFallback('performance_policy_cpu_fallback'),

  /// No same-mode acceleration or CPU path is available.
  accelerationUnavailable('performance_policy_acceleration_unavailable'),

  /// Resource pressure could not be classified safely.
  pressureUnknown('performance_policy_pressure_unknown'),

  /// No supported AI mode remains available.
  noAiModeEligible('performance_policy_no_ai_mode_eligible');

  const PerformanceDegradationReason(this.code);

  /// Stable code mapped to localized presentation copy.
  final String code;
}

/// Immutable value-only inputs to one degradation decision.
@immutable
final class PerformancePolicyInput extends ValueObject {
  /// Creates one complete pressure observation for the current meeting.
  PerformancePolicyInput({
    required this.requestedMode,
    required this.currentMode,
    required this.currentTiming,
    required Set<PerformanceMode> supportedModes,
    required this.thermalPressure,
    required this.backlogPressure,
    required this.memoryPressure,
    required this.isLowPower,
    required this.accelerationState,
    required this.engineState,
  }) : supportedModes = Set<PerformanceMode>.unmodifiable(supportedModes);

  /// User-requested starting mode.
  final PerformanceMode requestedMode;

  /// Current effective mode, which must not be more aggressive than requested.
  final PerformanceMode currentMode;

  /// Current capture-relative processing timing.
  final PerformanceExecutionTiming currentTiming;

  /// Modes backed by verified local evidence and model availability.
  final Set<PerformanceMode> supportedModes;

  /// Current coarse thermal pressure.
  final PerformanceThermalPressure thermalPressure;

  /// Current sustained-backlog classification.
  final PerformanceBacklogPressure backlogPressure;

  /// Current coarse memory pressure.
  final PerformanceMemoryPressure memoryPressure;

  /// Whether local low-power policy is active.
  final bool isLowPower;

  /// Current optional-acceleration and CPU-fallback availability.
  final PerformanceAccelerationState accelerationState;

  /// Current local-engine availability.
  final PerformanceEngineState engineState;

  @override
  List<Object?> get equalityValues => <Object?>[
    requestedMode,
    currentMode,
    currentTiming,
    for (final mode in PerformanceMode.values) supportedModes.contains(mode),
    thermalPressure,
    backlogPressure,
    memoryPressure,
    isLowPower,
    accelerationState,
    engineState,
  ];
}

/// Immutable recording-first result of one policy evaluation.
@immutable
final class PerformancePolicyDecision extends ValueObject {
  /// Creates a complete, privacy-safe policy result.
  PerformancePolicyDecision({
    required this.requestedMode,
    required this.effectiveMode,
    required this.effectiveTiming,
    required this.aiDisposition,
    required this.continueRecording,
    required this.postSessionQueued,
    required List<PerformanceDegradationReason> reasons,
    required this.primaryReason,
    required this.recoveryAction,
  }) : reasons = List<PerformanceDegradationReason>.unmodifiable(reasons);

  /// Original user-requested mode.
  final PerformanceMode requestedMode;

  /// Mode selected after monotonic safety degradation.
  final PerformanceMode effectiveMode;

  /// Capture-relative timing that must not advance the prior timing.
  final PerformanceExecutionTiming effectiveTiming;

  /// Engine-agnostic AI activity allowed by the decision.
  final PerformanceAiDisposition aiDisposition;

  /// Whether canonical capture must continue.
  final bool continueRecording;

  /// Whether unfinished AI work remains available after capture.
  final bool postSessionQueued;

  /// All applicable reasons in deterministic priority order.
  final List<PerformanceDegradationReason> reasons;

  /// Highest-priority reason controlling recovery presentation.
  final PerformanceDegradationReason? primaryReason;

  /// User-actionable recovery for [primaryReason].
  final PerformanceRecoveryAction recoveryAction;

  @override
  List<Object?> get equalityValues => <Object?>[
    requestedMode,
    effectiveMode,
    effectiveTiming,
    aiDisposition,
    continueRecording,
    postSessionQueued,
    reasons.length,
    ...reasons,
    primaryReason,
    recoveryAction,
  ];
}

/// Recoverable failure produced by invalid policy input.
@immutable
sealed class PerformancePolicyFailure extends ValueObject implements Failure {
  const PerformancePolicyFailure(this.code);

  @override
  final String code;

  @override
  List<Object?> get equalityValues => <Object?>[code];
}

/// Current mode and timing contradict the approved monotonic policy graph.
final class PerformancePolicyInvalidInput extends PerformancePolicyFailure {
  /// Creates the stable invalid-input failure.
  const PerformancePolicyInvalidInput()
    : super('performance_policy_invalid_input');
}

/// Pure deterministic recording-first policy evaluator.
final class PerformanceDegradationPolicy {
  /// Creates an evaluator over the approved catalog or an injected test catalog.
  PerformanceDegradationPolicy({PerformancePolicyCatalog? catalog})
    : _catalog = catalog ?? PerformancePolicyCatalog.standard;

  final PerformancePolicyCatalog _catalog;

  /// Chooses the safest effective policy without controlling side effects.
  Result<PerformancePolicyDecision, PerformancePolicyFailure> decide(
    PerformancePolicyInput input,
  ) {
    if (!_validCurrentState(input)) {
      return const Err<PerformancePolicyDecision, PerformancePolicyFailure>(
        PerformancePolicyInvalidInput(),
      );
    }

    if (input.requestedMode == PerformanceMode.recordingOnly &&
        input.currentMode == PerformanceMode.recordingOnly) {
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decision(
          input: input,
          mode: PerformanceMode.recordingOnly,
          timing: PerformanceExecutionTiming.disabled,
          disposition: PerformanceAiDisposition.disabled,
          queued: false,
          reasons: const [],
          recovery: PerformanceRecoveryAction.none,
        ),
      );
    }

    final reasons = _reasons(input);
    var mode = input.currentMode;
    if (!input.supportedModes.contains(mode)) {
      mode = _firstSupportedFallback(mode, input.supportedModes);
    }
    if (!_hasSupportedAi(input.supportedModes) &&
        !reasons.contains(PerformanceDegradationReason.noAiModeEligible)) {
      reasons.add(PerformanceDegradationReason.noAiModeEligible);
    }
    _sortReasons(reasons);

    if (input.engineState == PerformanceEngineState.unavailable) {
      final queued = _hasSupportedPostSession(input.supportedModes, _catalog);
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decision(
          input: input,
          mode: PerformanceMode.recordingOnly,
          timing: PerformanceExecutionTiming.disabled,
          disposition: PerformanceAiDisposition.disabled,
          queued: queued,
          reasons: reasons,
          recovery: queued
              ? PerformanceRecoveryAction.retryEngineLater
              : PerformanceRecoveryAction.continueRecordingOnly,
        ),
      );
    }

    if (input.thermalPressure == PerformanceThermalPressure.severe ||
        input.memoryPressure == PerformanceMemoryPressure.critical) {
      if (mode == PerformanceMode.recordingOnly) {
        return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
          _decisionForMode(
            catalog: _catalog,
            input: input,
            mode: mode,
            reasons: reasons,
            forcedDisposition: PerformanceAiDisposition.disabled,
            queued: false,
            recovery: PerformanceRecoveryAction.continueRecordingOnly,
          ),
        );
      }
      final timing = _constrainTiming(
        input.currentTiming,
        _catalog.policyFor(mode).timing,
      );
      final isLive = timing == PerformanceExecutionTiming.liveOrPostSession;
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decision(
          input: input,
          mode: mode,
          timing: timing,
          disposition: isLive
              ? PerformanceAiDisposition.paused
              : PerformanceAiDisposition.deferred,
          queued: _hasSupportedPostSession(input.supportedModes, _catalog),
          reasons: reasons,
          recovery: input.thermalPressure == PerformanceThermalPressure.severe
              ? PerformanceRecoveryAction.coolDevice
              : PerformanceRecoveryAction.continuePostSession,
        ),
      );
    }

    if (_hasUnknownPressure(input)) {
      final deferred = _supportedReachableMode(
        mode,
        input.supportedModes,
        PerformanceMode.postSession,
      );
      final nextMode = deferred ?? PerformanceMode.recordingOnly;
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decisionForMode(
          catalog: _catalog,
          input: input,
          mode: nextMode,
          reasons: reasons,
          forcedDisposition: nextMode == PerformanceMode.recordingOnly
              ? PerformanceAiDisposition.disabled
              : PerformanceAiDisposition.deferred,
          queued: nextMode != PerformanceMode.recordingOnly,
          recovery: nextMode == PerformanceMode.recordingOnly
              ? PerformanceRecoveryAction.continueRecordingOnly
              : PerformanceRecoveryAction.continuePostSession,
        ),
      );
    }

    if (input.backlogPressure ==
        PerformanceBacklogPressure.sustainedBeyondLimit) {
      final nextMode = _supportedReachableMode(
        mode,
        input.supportedModes,
        PerformanceMode.postSession,
      );
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decisionForMode(
          catalog: _catalog,
          input: input,
          mode: nextMode ?? PerformanceMode.recordingOnly,
          reasons: reasons,
          forcedDisposition: nextMode == null
              ? PerformanceAiDisposition.disabled
              : PerformanceAiDisposition.deferred,
          queued: nextMode != null,
          recovery: nextMode == null
              ? PerformanceRecoveryAction.continueRecordingOnly
              : PerformanceRecoveryAction.continuePostSession,
        ),
      );
    }

    if (input.accelerationState == PerformanceAccelerationState.unavailable) {
      mode = _firstSupportedFallback(mode, input.supportedModes);
    }

    if (input.isLowPower) {
      final powerSaving = _supportedReachableMode(
        mode,
        input.supportedModes,
        PerformanceMode.powerSaving,
      );
      final postSession = _supportedReachableMode(
        mode,
        input.supportedModes,
        PerformanceMode.postSession,
      );
      mode = powerSaving ?? postSession ?? PerformanceMode.recordingOnly;
      final timing = _constrainTiming(
        input.currentTiming,
        _catalog.policyFor(mode).timing,
      );
      final disposition = switch (timing) {
        PerformanceExecutionTiming.liveOrPostSession =>
          PerformanceAiDisposition.throttled,
        PerformanceExecutionTiming.postSessionOnly =>
          PerformanceAiDisposition.deferred,
        PerformanceExecutionTiming.disabled =>
          PerformanceAiDisposition.disabled,
      };
      return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
        _decision(
          input: input,
          mode: mode,
          timing: timing,
          disposition: disposition,
          queued: timing == PerformanceExecutionTiming.postSessionOnly,
          reasons: reasons,
          recovery: timing == PerformanceExecutionTiming.disabled
              ? PerformanceRecoveryAction.continueRecordingOnly
              : PerformanceRecoveryAction.continuePostSession,
        ),
      );
    }

    final timing = _constrainTiming(
      input.currentTiming,
      _catalog.policyFor(mode).timing,
    );
    final disposition = switch (timing) {
      PerformanceExecutionTiming.liveOrPostSession
          when input.thermalPressure == PerformanceThermalPressure.moderate =>
        PerformanceAiDisposition.throttled,
      PerformanceExecutionTiming.liveOrPostSession =>
        PerformanceAiDisposition.running,
      PerformanceExecutionTiming.postSessionOnly =>
        PerformanceAiDisposition.deferred,
      PerformanceExecutionTiming.disabled => PerformanceAiDisposition.disabled,
    };
    return Ok<PerformancePolicyDecision, PerformancePolicyFailure>(
      _decision(
        input: input,
        mode: mode,
        timing: timing,
        disposition: disposition,
        queued: timing == PerformanceExecutionTiming.postSessionOnly,
        reasons: reasons,
        recovery: _recoveryFor(reasons),
      ),
    );
  }

  bool _validCurrentState(PerformancePolicyInput input) {
    if (!_isReachable(input.requestedMode, input.currentMode)) return false;
    final currentRank = _timingRank(input.currentTiming);
    final requestedTiming = _catalog.policyFor(input.requestedMode).timing;
    final currentModeTiming = _catalog.policyFor(input.currentMode).timing;
    return currentRank >= _timingRank(requestedTiming) &&
        currentRank >= _timingRank(currentModeTiming);
  }

  bool _isReachable(PerformanceMode start, PerformanceMode target) {
    if (start == target) return true;
    final visited = <PerformanceMode>{};
    bool visit(PerformanceMode mode) {
      if (!visited.add(mode)) return false;
      for (final fallback in _catalog.policyFor(mode).safeFallbacks) {
        if (fallback == target || visit(fallback)) return true;
      }
      return false;
    }

    return visit(start);
  }

  PerformanceMode _firstSupportedFallback(
    PerformanceMode mode,
    Set<PerformanceMode> supported,
  ) {
    for (final fallback in _catalog.policyFor(mode).safeFallbacks) {
      if (supported.contains(fallback)) return fallback;
    }
    return PerformanceMode.recordingOnly;
  }

  PerformanceMode? _supportedReachableMode(
    PerformanceMode current,
    Set<PerformanceMode> supported,
    PerformanceMode candidate,
  ) => supported.contains(candidate) && _isReachable(current, candidate)
      ? candidate
      : null;
}

List<PerformanceDegradationReason> _reasons(PerformancePolicyInput input) {
  final reasons = <PerformanceDegradationReason>[];
  if (!input.supportedModes.contains(input.currentMode)) {
    reasons.add(PerformanceDegradationReason.modeUnsupported);
  }
  if (input.engineState == PerformanceEngineState.unavailable) {
    reasons.add(PerformanceDegradationReason.engineUnavailable);
  }
  if (input.thermalPressure == PerformanceThermalPressure.severe) {
    reasons.add(PerformanceDegradationReason.thermalSevere);
  }
  if (input.memoryPressure == PerformanceMemoryPressure.critical) {
    reasons.add(PerformanceDegradationReason.memoryCritical);
  }
  if (input.backlogPressure ==
      PerformanceBacklogPressure.sustainedBeyondLimit) {
    reasons.add(PerformanceDegradationReason.backlogSustained);
  }
  if (input.isLowPower) {
    reasons.add(PerformanceDegradationReason.lowPower);
  }
  if (input.thermalPressure == PerformanceThermalPressure.moderate) {
    reasons.add(PerformanceDegradationReason.thermalModerate);
  }
  switch (input.accelerationState) {
    case PerformanceAccelerationState.available:
      break;
    case PerformanceAccelerationState.unavailableWithCpuFallback:
      reasons.add(PerformanceDegradationReason.cpuFallback);
    case PerformanceAccelerationState.unavailable:
      reasons.add(PerformanceDegradationReason.accelerationUnavailable);
  }
  if (_hasUnknownPressure(input)) {
    reasons.add(PerformanceDegradationReason.pressureUnknown);
  }
  _sortReasons(reasons);
  return reasons;
}

bool _hasUnknownPressure(PerformancePolicyInput input) =>
    input.thermalPressure == PerformanceThermalPressure.unknown ||
    input.backlogPressure == PerformanceBacklogPressure.unknown ||
    input.memoryPressure == PerformanceMemoryPressure.unknown;

bool _hasSupportedAi(Set<PerformanceMode> supported) => supported.any(
  (mode) => mode != PerformanceMode.recordingOnly,
);

bool _hasSupportedPostSession(
  Set<PerformanceMode> supported,
  PerformancePolicyCatalog catalog,
) => supported.any(
  (mode) =>
      mode != PerformanceMode.recordingOnly &&
      catalog.policyFor(mode).timing != PerformanceExecutionTiming.disabled,
);

void _sortReasons(List<PerformanceDegradationReason> reasons) {
  reasons.sort(
    (left, right) => _reasonRank(left).compareTo(_reasonRank(right)),
  );
}

int _reasonRank(PerformanceDegradationReason reason) => switch (reason) {
  PerformanceDegradationReason.modeUnsupported => 0,
  PerformanceDegradationReason.engineUnavailable => 1,
  PerformanceDegradationReason.thermalSevere => 2,
  PerformanceDegradationReason.memoryCritical => 3,
  PerformanceDegradationReason.pressureUnknown => 4,
  PerformanceDegradationReason.backlogSustained => 5,
  PerformanceDegradationReason.lowPower => 6,
  PerformanceDegradationReason.thermalModerate => 7,
  PerformanceDegradationReason.cpuFallback => 8,
  PerformanceDegradationReason.accelerationUnavailable => 9,
  PerformanceDegradationReason.noAiModeEligible => 10,
};

PerformanceRecoveryAction _recoveryFor(
  List<PerformanceDegradationReason> reasons,
) => switch (reasons.firstOrNull) {
  PerformanceDegradationReason.modeUnsupported =>
    PerformanceRecoveryAction.selectSupportedMode,
  PerformanceDegradationReason.engineUnavailable =>
    PerformanceRecoveryAction.retryEngineLater,
  PerformanceDegradationReason.thermalModerate ||
  PerformanceDegradationReason.thermalSevere =>
    PerformanceRecoveryAction.coolDevice,
  PerformanceDegradationReason.memoryCritical ||
  PerformanceDegradationReason.backlogSustained ||
  PerformanceDegradationReason.lowPower ||
  PerformanceDegradationReason.pressureUnknown =>
    PerformanceRecoveryAction.continuePostSession,
  PerformanceDegradationReason.cpuFallback => PerformanceRecoveryAction.none,
  PerformanceDegradationReason.accelerationUnavailable =>
    PerformanceRecoveryAction.selectSupportedMode,
  PerformanceDegradationReason.noAiModeEligible =>
    PerformanceRecoveryAction.continueRecordingOnly,
  null => PerformanceRecoveryAction.none,
};

PerformancePolicyDecision _decisionForMode({
  required PerformancePolicyCatalog catalog,
  required PerformancePolicyInput input,
  required PerformanceMode mode,
  required List<PerformanceDegradationReason> reasons,
  required PerformanceAiDisposition forcedDisposition,
  required bool queued,
  required PerformanceRecoveryAction recovery,
}) => _decision(
  input: input,
  mode: mode,
  timing: _constrainTiming(
    input.currentTiming,
    catalog.policyFor(mode).timing,
  ),
  disposition: forcedDisposition,
  queued: queued,
  reasons: reasons,
  recovery: recovery,
);

PerformancePolicyDecision _decision({
  required PerformancePolicyInput input,
  required PerformanceMode mode,
  required PerformanceExecutionTiming timing,
  required PerformanceAiDisposition disposition,
  required bool queued,
  required List<PerformanceDegradationReason> reasons,
  required PerformanceRecoveryAction recovery,
}) {
  final disabled = timing == PerformanceExecutionTiming.disabled;
  return PerformancePolicyDecision(
    requestedMode: input.requestedMode,
    effectiveMode: mode,
    effectiveTiming: timing,
    aiDisposition: disabled ? PerformanceAiDisposition.disabled : disposition,
    continueRecording: true,
    postSessionQueued:
        queued &&
        (!disabled || input.engineState == PerformanceEngineState.unavailable),
    reasons: reasons,
    primaryReason: reasons.firstOrNull,
    recoveryAction: recovery,
  );
}

PerformanceExecutionTiming _constrainTiming(
  PerformanceExecutionTiming current,
  PerformanceExecutionTiming target,
) => _timingRank(current) >= _timingRank(target) ? current : target;

int _timingRank(PerformanceExecutionTiming timing) => switch (timing) {
  PerformanceExecutionTiming.liveOrPostSession => 0,
  PerformanceExecutionTiming.postSessionOnly => 1,
  PerformanceExecutionTiming.disabled => 2,
};

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
      policies[mode]!.safeFallbacks.forEach(visit);
      visiting.remove(mode);
    }

    visit(start);
  }
}
