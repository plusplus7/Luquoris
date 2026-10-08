import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/performance_policy.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';

void main() {
  test('standard catalog defines exactly one immutable policy per mode', () {
    final catalog = PerformancePolicyCatalog.standard;

    expect(
      catalog.policies.map((policy) => policy.mode),
      orderedEquals(PerformanceMode.values),
    );
    expect(
      () => catalog.policies.add(_recordingOnlyPolicy()),
      throwsUnsupportedError,
    );
    expect(
      () => catalog
          .policyFor(PerformanceMode.highQuality)
          .safeFallbacks
          .add(PerformanceMode.highQuality),
      throwsUnsupportedError,
    );
  });

  test(
    'standard policies expose the approved timing quality resource and fallback matrix',
    () {
      final expected =
          <
            PerformanceMode,
            (
              PerformanceExecutionTiming,
              PerformanceQualityIntent,
              PerformanceResourceIntent,
              List<PerformanceMode>,
            )
          >{
            PerformanceMode.highQuality: (
              PerformanceExecutionTiming.postSessionOnly,
              PerformanceQualityIntent.highest,
              PerformanceResourceIntent.expanded,
              const [
                PerformanceMode.balanced,
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.balanced: (
              PerformanceExecutionTiming.liveOrPostSession,
              PerformanceQualityIntent.balanced,
              PerformanceResourceIntent.standard,
              const [
                PerformanceMode.powerSaving,
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.powerSaving: (
              PerformanceExecutionTiming.liveOrPostSession,
              PerformanceQualityIntent.conservative,
              PerformanceResourceIntent.reduced,
              const [
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.postSession: (
              PerformanceExecutionTiming.postSessionOnly,
              PerformanceQualityIntent.balanced,
              PerformanceResourceIntent.standard,
              const [PerformanceMode.recordingOnly],
            ),
            PerformanceMode.recordingOnly: (
              PerformanceExecutionTiming.disabled,
              PerformanceQualityIntent.none,
              PerformanceResourceIntent.captureOnly,
              const [],
            ),
          };

      for (final entry in expected.entries) {
        final policy = PerformancePolicyCatalog.standard.policyFor(entry.key);
        final (timing, quality, resource, fallbacks) = entry.value;

        expect(policy.timing, timing, reason: entry.key.name);
        expect(policy.qualityIntent, quality, reason: entry.key.name);
        expect(policy.resourceIntent, resource, reason: entry.key.name);
        expect(
          policy.safeFallbacks,
          orderedEquals(fallbacks),
          reason: entry.key.name,
        );
      }
    },
  );

  test('high quality fallback never advances post session timing', () {
    final policy = PerformancePolicyCatalog.standard.policyFor(
      PerformanceMode.highQuality,
    );

    expect(policy.timing, PerformanceExecutionTiming.postSessionOnly);
    expect(
      policy.safeFallbacks,
      orderedEquals(const [
        PerformanceMode.balanced,
        PerformanceMode.postSession,
        PerformanceMode.recordingOnly,
      ]),
    );
  });

  test(
    'catalog rejects missing duplicate self cyclic and aggressive fallback definitions',
    () {
      final valid = _standardPolicies();

      expect(
        () => PerformancePolicyCatalog(valid.sublist(0, valid.length - 1)),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([...valid, valid.first]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          _policy(
            PerformanceMode.highQuality,
            timing: PerformanceExecutionTiming.postSessionOnly,
            quality: PerformanceQualityIntent.highest,
            resource: PerformanceResourceIntent.expanded,
            fallbacks: const [PerformanceMode.highQuality],
          ),
          ...valid.skip(1),
        ]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          valid.first,
          _policy(
            PerformanceMode.balanced,
            fallbacks: const [PerformanceMode.powerSaving],
          ),
          _policy(
            PerformanceMode.powerSaving,
            quality: PerformanceQualityIntent.conservative,
            resource: PerformanceResourceIntent.reduced,
            fallbacks: const [PerformanceMode.balanced],
          ),
          ...valid.skip(3),
        ]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          ...valid.take(3),
          _policy(
            PerformanceMode.postSession,
            timing: PerformanceExecutionTiming.postSessionOnly,
            fallbacks: const [PerformanceMode.highQuality],
          ),
          valid.last,
        ]),
        throwsArgumentError,
      );
    },
  );

  test('recording only disables AI and always continues recording', () {
    final decision = _ok(
      _decide(
        _input(
          requestedMode: PerformanceMode.recordingOnly,
          currentMode: PerformanceMode.recordingOnly,
          currentTiming: PerformanceExecutionTiming.disabled,
          supportedModes: const {},
        ),
      ),
    );

    expect(decision.effectiveMode, PerformanceMode.recordingOnly);
    expect(decision.effectiveTiming, PerformanceExecutionTiming.disabled);
    expect(decision.aiDisposition, PerformanceAiDisposition.disabled);
    expect(decision.continueRecording, isTrue);
    expect(decision.postSessionQueued, isFalse);
    expect(decision.reasons, isEmpty);
    expect(decision.primaryReason, isNull);
    expect(decision.recoveryAction, PerformanceRecoveryAction.none);
  });

  test('unsupported mode selects its first supported safe fallback', () {
    final decision = _ok(
      _decide(
        _input(
          supportedModes: const {
            PerformanceMode.powerSaving,
            PerformanceMode.postSession,
          },
        ),
      ),
    );

    expect(decision.effectiveMode, PerformanceMode.powerSaving);
    expect(
      decision.effectiveTiming,
      PerformanceExecutionTiming.liveOrPostSession,
    );
    expect(decision.aiDisposition, PerformanceAiDisposition.running);
    expect(
      decision.reasons,
      orderedEquals(const [PerformanceDegradationReason.modeUnsupported]),
    );
    expect(
      decision.recoveryAction,
      PerformanceRecoveryAction.selectSupportedMode,
    );
  });

  test(
    'empty support falls back to recording only with no eligible reason',
    () {
      final decision = _ok(
        _decide(_input(supportedModes: const {})),
      );

      expect(decision.effectiveMode, PerformanceMode.recordingOnly);
      expect(decision.aiDisposition, PerformanceAiDisposition.disabled);
      expect(
        decision.reasons,
        orderedEquals(const [
          PerformanceDegradationReason.modeUnsupported,
          PerformanceDegradationReason.noAiModeEligible,
        ]),
      );
      expect(decision.continueRecording, isTrue);
    },
  );

  test(
    'moderate thermal pressure throttles live work without changing mode',
    () {
      final decision = _ok(
        _decide(
          _input(thermalPressure: PerformanceThermalPressure.moderate),
        ),
      );

      expect(decision.effectiveMode, PerformanceMode.balanced);
      expect(decision.aiDisposition, PerformanceAiDisposition.throttled);
      expect(decision.postSessionQueued, isFalse);
      expect(
        decision.primaryReason,
        PerformanceDegradationReason.thermalModerate,
      );
      expect(decision.recoveryAction, PerformanceRecoveryAction.coolDevice);
    },
  );

  test(
    'severe thermal and critical memory pause AI and queue post session work',
    () {
      final severe = _ok(
        _decide(_input(thermalPressure: PerformanceThermalPressure.severe)),
      );
      final memory = _ok(
        _decide(_input(memoryPressure: PerformanceMemoryPressure.critical)),
      );

      expect(severe.effectiveMode, PerformanceMode.balanced);
      expect(severe.aiDisposition, PerformanceAiDisposition.paused);
      expect(severe.postSessionQueued, isTrue);
      expect(
        severe.primaryReason,
        PerformanceDegradationReason.thermalSevere,
      );
      expect(severe.recoveryAction, PerformanceRecoveryAction.coolDevice);
      expect(memory.aiDisposition, PerformanceAiDisposition.paused);
      expect(memory.postSessionQueued, isTrue);
      expect(
        memory.primaryReason,
        PerformanceDegradationReason.memoryCritical,
      );
      expect(
        memory.recoveryAction,
        PerformanceRecoveryAction.continuePostSession,
      );
    },
  );

  test(
    'sustained backlog makes post session fallback terminal for the meeting',
    () {
      final decision = _ok(
        _decide(
          _input(
            backlogPressure: PerformanceBacklogPressure.sustainedBeyondLimit,
          ),
        ),
      );

      expect(decision.effectiveMode, PerformanceMode.postSession);
      expect(
        decision.effectiveTiming,
        PerformanceExecutionTiming.postSessionOnly,
      );
      expect(decision.aiDisposition, PerformanceAiDisposition.deferred);
      expect(decision.postSessionQueued, isTrue);
      expect(
        decision.primaryReason,
        PerformanceDegradationReason.backlogSustained,
      );
    },
  );

  test('low power chooses supported power saving then post session', () {
    final powerSaving = _ok(
      _decide(
        _input(
          supportedModes: const {
            PerformanceMode.balanced,
            PerformanceMode.powerSaving,
            PerformanceMode.postSession,
          },
          isLowPower: true,
        ),
      ),
    );
    final postSession = _ok(
      _decide(
        _input(
          supportedModes: const {
            PerformanceMode.balanced,
            PerformanceMode.postSession,
          },
          isLowPower: true,
        ),
      ),
    );

    expect(powerSaving.effectiveMode, PerformanceMode.powerSaving);
    expect(powerSaving.aiDisposition, PerformanceAiDisposition.throttled);
    expect(postSession.effectiveMode, PerformanceMode.postSession);
    expect(postSession.aiDisposition, PerformanceAiDisposition.deferred);
    expect(postSession.postSessionQueued, isTrue);
  });

  test(
    'acceleration loss retains mode with CPU fallback and otherwise degrades',
    () {
      final cpu = _ok(
        _decide(
          _input(
            accelerationState:
                PerformanceAccelerationState.unavailableWithCpuFallback,
          ),
        ),
      );
      final unavailable = _ok(
        _decide(
          _input(
            supportedModes: const {
              PerformanceMode.balanced,
              PerformanceMode.powerSaving,
              PerformanceMode.postSession,
            },
            accelerationState: PerformanceAccelerationState.unavailable,
          ),
        ),
      );

      expect(cpu.effectiveMode, PerformanceMode.balanced);
      expect(cpu.aiDisposition, PerformanceAiDisposition.running);
      expect(
        cpu.primaryReason,
        PerformanceDegradationReason.cpuFallback,
      );
      expect(unavailable.effectiveMode, PerformanceMode.powerSaving);
      expect(
        unavailable.primaryReason,
        PerformanceDegradationReason.accelerationUnavailable,
      );
    },
  );

  test(
    'engine failure preserves capture and returns an actionable retry decision',
    () {
      final decision = _ok(
        _decide(
          _input(engineState: PerformanceEngineState.unavailable),
        ),
      );

      expect(decision.effectiveMode, PerformanceMode.recordingOnly);
      expect(decision.aiDisposition, PerformanceAiDisposition.disabled);
      expect(decision.continueRecording, isTrue);
      expect(decision.postSessionQueued, isTrue);
      expect(
        decision.primaryReason,
        PerformanceDegradationReason.engineUnavailable,
      );
      expect(
        decision.recoveryAction,
        PerformanceRecoveryAction.retryEngineLater,
      );
    },
  );

  test('simultaneous pressures use fixed priority and retain all reasons', () {
    final decision = _ok(
      _decide(
        _input(
          engineState: PerformanceEngineState.unavailable,
          thermalPressure: PerformanceThermalPressure.severe,
          backlogPressure: PerformanceBacklogPressure.sustainedBeyondLimit,
          memoryPressure: PerformanceMemoryPressure.critical,
          isLowPower: true,
          accelerationState: PerformanceAccelerationState.unavailable,
        ),
      ),
    );

    expect(
      decision.reasons,
      orderedEquals(const [
        PerformanceDegradationReason.engineUnavailable,
        PerformanceDegradationReason.thermalSevere,
        PerformanceDegradationReason.memoryCritical,
        PerformanceDegradationReason.backlogSustained,
        PerformanceDegradationReason.lowPower,
        PerformanceDegradationReason.accelerationUnavailable,
      ]),
    );
    expect(
      decision.primaryReason,
      PerformanceDegradationReason.engineUnavailable,
    );
    expect(decision.effectiveMode, PerformanceMode.recordingOnly);
  });

  test('high quality degradation retains post session timing', () {
    final decision = _ok(
      _decide(
        _input(
          requestedMode: PerformanceMode.highQuality,
          currentMode: PerformanceMode.highQuality,
          currentTiming: PerformanceExecutionTiming.postSessionOnly,
          supportedModes: const {PerformanceMode.balanced},
        ),
      ),
    );

    expect(decision.effectiveMode, PerformanceMode.balanced);
    expect(
      decision.effectiveTiming,
      PerformanceExecutionTiming.postSessionOnly,
    );
    expect(decision.aiDisposition, PerformanceAiDisposition.deferred);
  });

  test('unknown pressure defers conservatively then uses recording only', () {
    final deferred = _ok(
      _decide(
        _input(thermalPressure: PerformanceThermalPressure.unknown),
      ),
    );
    final disabled = _ok(
      _decide(
        _input(
          supportedModes: const {},
          backlogPressure: PerformanceBacklogPressure.unknown,
        ),
      ),
    );

    expect(deferred.effectiveMode, PerformanceMode.postSession);
    expect(deferred.aiDisposition, PerformanceAiDisposition.deferred);
    expect(
      deferred.primaryReason,
      PerformanceDegradationReason.pressureUnknown,
    );
    expect(disabled.effectiveMode, PerformanceMode.recordingOnly);
    expect(disabled.aiDisposition, PerformanceAiDisposition.disabled);
  });

  test('contradictory current mode or timing returns invalid input', () {
    final upgradedCurrent = _decide(
      _input(
        currentMode: PerformanceMode.highQuality,
        currentTiming: PerformanceExecutionTiming.postSessionOnly,
      ),
    );
    final liveHighQuality = _decide(
      _input(
        requestedMode: PerformanceMode.highQuality,
        currentMode: PerformanceMode.highQuality,
      ),
    );

    expect(_failure(upgradedCurrent), const PerformancePolicyInvalidInput());
    expect(_failure(liveHighQuality), const PerformancePolicyInvalidInput());
  });

  test('automatic decisions never upgrade the current mode', () {
    final decision = _ok(
      _decide(
        _input(
          currentMode: PerformanceMode.powerSaving,
          supportedModes: PerformanceMode.values.toSet(),
        ),
      ),
    );

    expect(decision.effectiveMode, PerformanceMode.powerSaving);
    expect(decision.aiDisposition, PerformanceAiDisposition.running);
  });

  test('every valid input in the cross product continues recording', () {
    for (final mode in PerformanceMode.values) {
      final timing = PerformancePolicyCatalog.standard.policyFor(mode).timing;
      for (final thermal in PerformanceThermalPressure.values) {
        for (final backlog in PerformanceBacklogPressure.values) {
          for (final memory in PerformanceMemoryPressure.values) {
            for (final lowPower in [false, true]) {
              for (final acceleration in PerformanceAccelerationState.values) {
                for (final engine in PerformanceEngineState.values) {
                  final result = _decide(
                    _input(
                      requestedMode: mode,
                      currentMode: mode,
                      currentTiming: timing,
                      thermalPressure: thermal,
                      backlogPressure: backlog,
                      memoryPressure: memory,
                      isLowPower: lowPower,
                      accelerationState: acceleration,
                      engineState: engine,
                    ),
                  );

                  expect(
                    result,
                    isA<
                      Ok<PerformancePolicyDecision, PerformancePolicyFailure>
                    >(),
                  );
                  expect(_ok(result).continueRecording, isTrue);
                }
              }
            }
          }
        }
      }
    }
  });

  test('reason codes are closed stable and privacy safe', () {
    final codes = PerformanceDegradationReason.values
        .map((reason) => reason.code)
        .toList();

    expect(codes, const [
      'performance_policy_mode_unsupported',
      'performance_policy_engine_unavailable',
      'performance_policy_thermal_moderate',
      'performance_policy_thermal_severe',
      'performance_policy_memory_critical',
      'performance_policy_backlog_sustained',
      'performance_policy_low_power',
      'performance_policy_cpu_fallback',
      'performance_policy_acceleration_unavailable',
      'performance_policy_pressure_unknown',
      'performance_policy_no_ai_mode_eligible',
    ]);
    for (final code in codes) {
      expect(code, isNot(contains('/')));
      expect(code, isNot(contains('://')));
      expect(code, isNot(contains('exception')));
      expect(code, isNot(contains('device')));
      expect(code, isNot(contains('transcript')));
    }
  });
}

final _degradationPolicy = PerformanceDegradationPolicy();

Result<PerformancePolicyDecision, PerformancePolicyFailure> _decide(
  PerformancePolicyInput input,
) => _degradationPolicy.decide(input);

PerformancePolicyInput _input({
  PerformanceMode requestedMode = PerformanceMode.balanced,
  PerformanceMode currentMode = PerformanceMode.balanced,
  PerformanceExecutionTiming currentTiming =
      PerformanceExecutionTiming.liveOrPostSession,
  Set<PerformanceMode>? supportedModes,
  PerformanceThermalPressure thermalPressure =
      PerformanceThermalPressure.nominal,
  PerformanceBacklogPressure backlogPressure =
      PerformanceBacklogPressure.withinLimit,
  PerformanceMemoryPressure memoryPressure = PerformanceMemoryPressure.normal,
  bool isLowPower = false,
  PerformanceAccelerationState accelerationState =
      PerformanceAccelerationState.available,
  PerformanceEngineState engineState = PerformanceEngineState.available,
}) => PerformancePolicyInput(
  requestedMode: requestedMode,
  currentMode: currentMode,
  currentTiming: currentTiming,
  supportedModes: supportedModes ?? PerformanceMode.values.toSet(),
  thermalPressure: thermalPressure,
  backlogPressure: backlogPressure,
  memoryPressure: memoryPressure,
  isLowPower: isLowPower,
  accelerationState: accelerationState,
  engineState: engineState,
);

PerformancePolicyDecision _ok(
  Result<PerformancePolicyDecision, PerformancePolicyFailure> result,
) => (result as Ok<PerformancePolicyDecision, PerformancePolicyFailure>).value;

PerformancePolicyFailure _failure(
  Result<PerformancePolicyDecision, PerformancePolicyFailure> result,
) => (result as Err<PerformancePolicyDecision, PerformancePolicyFailure>)
    .failure;

List<PerformanceModePolicy> _standardPolicies() => [
  _policy(
    PerformanceMode.highQuality,
    timing: PerformanceExecutionTiming.postSessionOnly,
    quality: PerformanceQualityIntent.highest,
    resource: PerformanceResourceIntent.expanded,
    fallbacks: const [
      PerformanceMode.balanced,
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.balanced,
    fallbacks: const [
      PerformanceMode.powerSaving,
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.powerSaving,
    quality: PerformanceQualityIntent.conservative,
    resource: PerformanceResourceIntent.reduced,
    fallbacks: const [
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.postSession,
    timing: PerformanceExecutionTiming.postSessionOnly,
    fallbacks: const [PerformanceMode.recordingOnly],
  ),
  _recordingOnlyPolicy(),
];

PerformanceModePolicy _recordingOnlyPolicy() => _policy(
  PerformanceMode.recordingOnly,
  timing: PerformanceExecutionTiming.disabled,
  quality: PerformanceQualityIntent.none,
  resource: PerformanceResourceIntent.captureOnly,
);

PerformanceModePolicy _policy(
  PerformanceMode mode, {
  PerformanceExecutionTiming timing =
      PerformanceExecutionTiming.liveOrPostSession,
  PerformanceQualityIntent quality = PerformanceQualityIntent.balanced,
  PerformanceResourceIntent resource = PerformanceResourceIntent.standard,
  List<PerformanceMode> fallbacks = const [],
}) => PerformanceModePolicy(
  mode: mode,
  timing: timing,
  qualityIntent: quality,
  resourceIntent: resource,
  safeFallbacks: fallbacks,
);
