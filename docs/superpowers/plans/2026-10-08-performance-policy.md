# Performance Policy and Explicit Degradation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add immutable operating-mode policies, a deterministic recording-first degradation engine, and an honest read-only explanation of those protections on the Models & Performance screen.

**Architecture:** Keep policy semantics in one pure-Dart models/performance domain file. A pure decision engine consumes allowlisted resource-pressure values and returns an immutable effective mode, AI disposition, stable reasons, and recovery action; it never calls a platform, writes persistence, or controls recording. The existing Models & Performance screen renders the catalog and recommendation as read-only information while production inference remains unavailable.

**Tech Stack:** Dart 3, Flutter Material 3, Riverpod presentation state, sealed `Result<T, F>`, Flutter localization ARB/gen-l10n, `flutter_test`, GitNexus, OpenSpec CLI.

**Spec:** `docs/superpowers/specs/2026-10-08-performance-policy-design.md`

## Global Constraints

- Production inference remains unavailable; do not install an engine or make any mode selectable.
- Do not add Drift schema, migration, recording-default, meeting-entity, Android, `TranscriptionEngine`, model-manifest, benchmark-threshold, or benchmark-export changes.
- Every valid decision sets `continueRecording` to `true`; AI pressure never stops canonical capture.
- Automatic mode movement is monotonic toward safer work and never advances processing timing.
- All reasons come from a closed privacy-safe allowlist; never carry exception text, paths, URIs, device/account identifiers, transcript text, audio, or raw platform maps.
- Preserve the shared dirty checkout. Stage only this plan's files or inspected hunks; never stage an entire pre-dirty file blindly.
- Before editing any existing function, class, method, enum, or generated localization class, run upstream GitNexus impact analysis and report direct callers, affected processes, and risk. Stop for user approval before any HIGH or CRITICAL edit that is not already approved for this task.
- Before every commit, run `git diff --cached --check`, inspect the cached name/status and full diff, then run `gitnexus_detect_changes(scope: "staged")`.
- Use `PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin` for Flutter and Dart commands.

## File Structure

- Create `lib/features/models_performance/domain/performance_policy.dart`: policy catalog, pressure values, decisions, failures, and pure degradation engine.
- Create `test/features/models_performance/performance_policy_test.dart`: exhaustive catalog and decision matrix.
- Create `lib/features/models_performance/presentation/performance_policy_overview.dart`: one `part` containing the read-only policy overview and mode cards.
- Modify `lib/features/models_performance/presentation/models_performance_screen.dart`: register the new part and pass an optional recommendation to the overview.
- Modify `lib/features/models_performance/presentation/models_performance_screen_content.dart`: only if a shared private helper is required; do not move unrelated benchmark widgets.
- Modify `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`: English and simplified-Chinese policy, timing, protection, availability, and recommendation copy.
- Regenerate `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, and `lib/l10n/app_localizations_zh.dart` with the repository's configured gen-l10n command.
- Modify `test/features/models_performance/models_performance_screen_test.dart`: policy overview and recommendation behavior.
- Modify `test/accessibility/models_performance_accessibility_test.dart`: semantics, 200% text, and compact layout.
- Modify `test/localization/models_performance_localization_test.dart`: exact bilingual policy vocabulary.
- Modify `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md`: change only 10.7 from unchecked to checked after verification.

## Review Focus

- Simultaneous pressures: the highest-priority condition controls the disposition while every applicable reason remains present; Task 2 adds the exact ordering test.
- Contradictory current/requested mode or timing: return `PerformancePolicyInvalidInput`, never guess; Task 2 adds explicit invalid-input tests.
- High-quality fallback: reducing quality must retain post-session timing and never activate live work; Tasks 1 and 2 both pin this invariant.
- Empty supported-mode set: choose recording-only, continue capture, and expose `performance_policy_no_ai_mode_eligible`; Task 2 covers it.
- Recommendation presentation without runtime: highlight the benchmark recommendation but retain the locked/not-selectable explanation and no apply control; Task 3 covers unavailable and completed states.

---

### Task 1: Immutable Performance Mode Catalog

**Files:**
- Create: `lib/features/models_performance/domain/performance_policy.dart`
- Create: `test/features/models_performance/performance_policy_test.dart`

**Interfaces:**
- Consumes: existing `PerformanceMode` from `processing_entities.dart` and `ValueObject` from `core/domain/value_object.dart`.
- Produces: `PerformanceExecutionTiming`, `PerformanceQualityIntent`, `PerformanceResourceIntent`, `PerformanceModePolicy`, and `PerformancePolicyCatalog.standard` with `policies` and `policyFor(PerformanceMode)`.

- [ ] **Step 1: Run the pre-edit graph check**

Run upstream impact for `PerformanceMode`. Report its direct dependents, affected processes, and risk before adding a consumer. This task creates new symbols and does not edit the enum.

- [ ] **Step 2: Write failing catalog tests**

Add tests named:

- `standard catalog defines exactly one immutable policy per mode`;
- `standard policies expose the approved timing quality resource and fallback matrix`;
- `high quality fallback never advances post session timing`;
- `catalog rejects missing duplicate self cyclic and aggressive fallback definitions`.

Assert this exact matrix:

| Mode | Timing | Quality | Resource | Fallbacks |
|---|---|---|---|---|
| `highQuality` | `postSessionOnly` | `highest` | `expanded` | `balanced`, `postSession`, `recordingOnly` |
| `balanced` | `liveOrPostSession` | `balanced` | `standard` | `powerSaving`, `postSession`, `recordingOnly` |
| `powerSaving` | `liveOrPostSession` | `conservative` | `reduced` | `postSession`, `recordingOnly` |
| `postSession` | `postSessionOnly` | `balanced` | `standard` | `recordingOnly` |
| `recordingOnly` | `disabled` | `none` | `captureOnly` | empty |

Malformed programmer-authored catalogs must throw `ArgumentError`; the standard catalog is deterministic and exposes unmodifiable policy/fallback lists.

- [ ] **Step 3: Run the catalog tests and verify RED**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/features/models_performance/performance_policy_test.dart
```

Expected: FAIL because `performance_policy.dart` and the catalog types do not exist.

- [ ] **Step 4: Implement the immutable catalog**

Create these exact declarations in `performance_policy.dart`:

```dart
enum PerformanceExecutionTiming { liveOrPostSession, postSessionOnly, disabled }
enum PerformanceQualityIntent { highest, balanced, conservative, none }
enum PerformanceResourceIntent { expanded, standard, reduced, captureOnly }

final class PerformanceModePolicy extends ValueObject {
  PerformanceModePolicy({
    required PerformanceMode mode,
    required PerformanceExecutionTiming timing,
    required PerformanceQualityIntent qualityIntent,
    required PerformanceResourceIntent resourceIntent,
    required List<PerformanceMode> safeFallbacks,
  });
}

final class PerformancePolicyCatalog {
  PerformancePolicyCatalog(List<PerformanceModePolicy> policies);
  static final PerformancePolicyCatalog standard;
  List<PerformanceModePolicy> get policies;
  PerformanceModePolicy policyFor(PerformanceMode mode);
}
```

Validate exactly one policy per enum value, no missing values, no self edge, no cycle, and no edge outside the approved safer relation. Copy incoming lists into unmodifiable collections.

- [ ] **Step 5: Format the catalog files**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin dart format lib/features/models_performance/domain/performance_policy.dart test/features/models_performance/performance_policy_test.dart
```

Expected: both files are formatted and the command exits zero.

- [ ] **Step 6: Run the catalog tests GREEN**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/features/models_performance/performance_policy_test.dart
```

Expected: all catalog tests pass.

- [ ] **Step 7: Review scope and commit Task 1**

Stage only the two Task 1 files, run the required cached-diff and GitNexus checks, then commit:

```bash
git commit -m "feat: define performance mode policies"
```

### Task 2: Recording-First Degradation Decision Engine

**Files:**
- Modify: `lib/features/models_performance/domain/performance_policy.dart`
- Modify: `test/features/models_performance/performance_policy_test.dart`

**Interfaces:**
- Consumes: `PerformancePolicyCatalog.standard` and its exact mode/timing/fallback matrix from Task 1.
- Produces: pressure enums, `PerformancePolicyInput`, `PerformancePolicyDecision`, `PerformancePolicyFailure`, `PerformancePolicyInvalidInput`, `PerformanceDegradationReason`, `PerformanceRecoveryAction`, and `PerformanceDegradationPolicy.decide(PerformancePolicyInput)` returning `Result<PerformancePolicyDecision, PerformancePolicyFailure>`.

- [ ] **Step 1: Run pre-edit impact analysis**

Run upstream impact for `PerformanceModePolicy` and `PerformancePolicyCatalog`. Report the blast radius before extending the new domain file.

- [ ] **Step 2: Write the failing decision matrix**

Add tests named:

- `recording only disables AI and always continues recording`;
- `unsupported mode selects its first supported safe fallback`;
- `empty support falls back to recording only with no eligible reason`;
- `moderate thermal pressure throttles live work without changing mode`;
- `severe thermal and critical memory pause AI and queue post session work`;
- `sustained backlog makes post session fallback terminal for the meeting`;
- `low power chooses supported power saving then post session`;
- `acceleration loss retains mode with CPU fallback and otherwise degrades`;
- `engine failure preserves capture and returns an actionable retry decision`;
- `simultaneous pressures use fixed priority and retain all reasons`;
- `high quality degradation retains post session timing`;
- `unknown pressure defers conservatively then uses recording only`;
- `contradictory current mode or timing returns invalid input`;
- `automatic decisions never upgrade the current mode`;
- `every valid input in the cross product continues recording`;
- `reason codes are closed stable and privacy safe`.

The simultaneous-pressure test must assert engine/unsupported first, severe thermal or critical memory second, sustained backlog third, low power or moderate thermal fourth, and acceleration last. Reason ordering follows that priority even when the input set is constructed in another order.

- [ ] **Step 3: Run decision tests and verify RED**

Run the Task 1 test file. Expected: FAIL because the decision declarations and `decide` method do not exist.

- [ ] **Step 4: Add exact pressure and decision declarations**

Add:

```dart
enum PerformanceThermalPressure { nominal, moderate, severe, unknown }
enum PerformanceBacklogPressure { withinLimit, sustainedBeyondLimit, unknown }
enum PerformanceMemoryPressure { normal, critical, unknown }
enum PerformanceAccelerationState { available, unavailableWithCpuFallback, unavailable }
enum PerformanceEngineState { available, unavailable }
enum PerformanceAiDisposition { running, throttled, paused, deferred, disabled }
enum PerformanceRecoveryAction { none, coolDevice, continuePostSession, retryEngineLater, selectSupportedMode, continueRecordingOnly }

final class PerformancePolicyInput extends ValueObject {
  PerformancePolicyInput({
    required PerformanceMode requestedMode,
    required PerformanceMode currentMode,
    required PerformanceExecutionTiming currentTiming,
    required Set<PerformanceMode> supportedModes,
    required PerformanceThermalPressure thermalPressure,
    required PerformanceBacklogPressure backlogPressure,
    required PerformanceMemoryPressure memoryPressure,
    required bool isLowPower,
    required PerformanceAccelerationState accelerationState,
    required PerformanceEngineState engineState,
  });
}

final class PerformancePolicyDecision extends ValueObject {
  PerformancePolicyDecision({
    required PerformanceMode requestedMode,
    required PerformanceMode effectiveMode,
    required PerformanceExecutionTiming effectiveTiming,
    required PerformanceAiDisposition aiDisposition,
    required bool continueRecording,
    required bool postSessionQueued,
    required List<PerformanceDegradationReason> reasons,
    required PerformanceDegradationReason? primaryReason,
    required PerformanceRecoveryAction recoveryAction,
  });
}

sealed class PerformancePolicyFailure extends ValueObject implements Failure {
  const PerformancePolicyFailure(String code);
}

final class PerformancePolicyInvalidInput extends PerformancePolicyFailure {
  const PerformancePolicyInvalidInput()
    : super('performance_policy_invalid_input');
}

final class PerformanceDegradationPolicy {
  PerformanceDegradationPolicy({PerformancePolicyCatalog? catalog});
  Result<PerformancePolicyDecision, PerformancePolicyFailure> decide(
    PerformancePolicyInput input,
  );
}
```

Make `PerformanceDegradationReason` an enhanced enum with these exact codes:

- `performance_policy_mode_unsupported`;
- `performance_policy_engine_unavailable`;
- `performance_policy_thermal_moderate`;
- `performance_policy_thermal_severe`;
- `performance_policy_memory_critical`;
- `performance_policy_backlog_sustained`;
- `performance_policy_low_power`;
- `performance_policy_cpu_fallback`;
- `performance_policy_acceleration_unavailable`;
- `performance_policy_pressure_unknown`;
- `performance_policy_no_ai_mode_eligible`.

Pin these representative outputs in addition to the cross-product invariant:

| Input from a valid balanced live state | Effective result |
|---|---|
| No pressure | balanced, live-or-post-session, running, no reason, no queued work |
| Moderate thermal | balanced, live-or-post-session, throttled, cool-device action |
| Severe thermal | balanced, live-or-post-session, paused, post-session queued, cool-device action |
| Critical memory | balanced, live-or-post-session, paused, post-session queued, continue-post-session action |
| Sustained backlog | post-session, post-session-only, deferred, post-session queued |
| Low power with power-saving supported | power-saving, live-or-post-session, throttled |
| Low power without power-saving | post-session, post-session-only, deferred |
| Acceleration loss with CPU fallback | balanced and running, plus CPU-fallback reason |
| Engine unavailable | recording-only and disabled, with retry-later action and post-session queued only when a retry-capable post-session mode is supported |
| Unknown pressure | post-session and deferred, or recording-only when post-session is unsupported |

- [ ] **Step 5: Implement the minimal deterministic policy**

Validate that the current mode equals the request or is reachable through the request's safe fallback graph, and that current timing is no more aggressive than the current policy. Return `PerformancePolicyInvalidInput` for contradictions.

For valid input, retain all applicable reasons, sort them by the approved priority, choose only supported safe fallbacks, preserve post-session timing, and set `continueRecording: true`. `recordingOnly` is always a safe terminal capability even when the supplied supported-mode set is empty. Do not add state, timers, platform reads, thresholds, or persistence.

- [ ] **Step 6: Format the policy files**

Run Dart format on the two Task 2 files. Expected: both files are formatted
and the command exits zero.

- [ ] **Step 7: Run focused tests GREEN**

Run the policy test file. Expected: all catalog and decision tests pass.

- [ ] **Step 8: Review scope and commit Task 2**

Stage only the two Task 2 files, run the required cached-diff and GitNexus checks, then commit:

```bash
git commit -m "feat: add recording-first degradation policy"
```

### Task 3: Read-Only Policy Overview and Localized Protection Copy

**Files:**
- Create: `lib/features/models_performance/presentation/performance_policy_overview.dart`
- Modify: `lib/features/models_performance/presentation/models_performance_screen.dart`
- Modify only if needed: `lib/features/models_performance/presentation/models_performance_screen_content.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Modify: `test/features/models_performance/models_performance_screen_test.dart`
- Modify: `test/accessibility/models_performance_accessibility_test.dart`
- Modify: `test/localization/models_performance_localization_test.dart`

**Interfaces:**
- Consumes: `PerformancePolicyCatalog.standard`, existing benchmark state, and optional `BenchmarkRecommendation.mode`.
- Produces: private `_PerformancePolicyOverview({required PerformanceMode? recommendedMode})` in a `part of 'models_performance_screen.dart'` file; it is informational only and exposes no selection callback.

- [ ] **Step 1: Run pre-edit impact analysis and stop on unapproved risk**

Run upstream impact for `ModelsPerformanceScreen`, `PerformanceMode`, and `AppLocalizations`. Report direct dependents, affected processes, and risk. Because generated localization is widely consumed, stop and request approval if this analysis is HIGH or CRITICAL and the risk was not explicitly approved for task 10.7.

- [ ] **Step 2: Write failing presentation tests**

In `models_performance_screen_test.dart`, add:

- `unavailable runtime still explains all five locked policies`;
- `completed benchmark highlights recommendation without applying or selecting it`;
- `policy overview explains thermal backlog and recording first recovery`.

Assert keys `performance-policy-overview` and `performance-policy-<mode.name>` for all five modes. In the unavailable state, assert the not-selectable runtime explanation and no radio, choice chip, apply button, or selection callback. In the completed state, assert Balanced has localized recommended semantics while the same locked explanation remains.

In `models_performance_accessibility_test.dart`, add:

- `policy cards expose mode timing availability and fallback semantics`;
- `policy overview survives compact width and 200 percent text`.

In `models_performance_localization_test.dart`, add `performance policy vocabulary exists in both locales`; assert exact English and Chinese headings, locked text, timing vocabulary, recommended label, and the four protection explanations.

- [ ] **Step 3: Run presentation tests and verify RED**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart
```

Expected: FAIL because the overview, keys, and localization getters do not exist.

- [ ] **Step 4: Add bilingual ARB copy**

Add these consistently prefixed `performancePolicy...` messages; ARB
descriptions must say where each string appears and must not introduce new
placeholders:

| Suffix | English | Simplified Chinese |
|---|---|---|
| `Heading` | Operating modes and recording protection | 运行模式与录音保护 |
| `LockedBody` | Modes remain informational until a compatible local inference runtime and model pass validation. This screen never changes settings automatically. | 在兼容的本地推理运行时和模型通过验证前，这些模式仅供说明。本页面绝不会自动更改设置。 |
| `RecommendedLabel` | Recommended by this check | 本次检查推荐 |
| `TimingLiveOrPostSession` | During recording or after recording | 录音期间或录音结束后 |
| `TimingPostSessionOnly` | After recording only | 仅在录音结束后 |
| `TimingDisabled` | AI processing off | AI 处理已关闭 |
| `HighQualityDescription` | Uses a validated higher-quality model after recording. | 录音结束后使用通过验证的更高质量模型。 |
| `HighQualityFallback` | Falls back to balanced post-session processing, then recording only. | 可降为均衡的会后处理，最后仅保留录音。 |
| `BalancedDescription` | Balances transcript quality with device resources. | 在转写质量与设备资源之间取得平衡。 |
| `BalancedFallback` | Reduces resource use, defers work, or keeps recording only. | 可降低资源使用、延后处理，或仅保留录音。 |
| `PowerSavingDescription` | Uses a smaller model or reduced concurrency when validated. | 通过验证后，使用更小的模型或更低的并发。 |
| `PowerSavingFallback` | Defers work until after recording, then keeps recording only if needed. | 可将处理延后到录音结束后，必要时仅保留录音。 |
| `PostSessionDescription` | Reserves capture-time resources and analyzes locally after recording. | 录音时保留资源，结束后再在本机分析。 |
| `PostSessionFallback` | Recording remains available if analysis cannot run. | 即使无法分析，录音仍然可用。 |
| `RecordingOnlyDescription` | Saves canonical audio without running AI. | 保存权威音频，不运行 AI。 |
| `RecordingOnlyFallback` | Recording continues without an AI fallback. | 录音继续，不再执行 AI 降级。 |
| `ProtectionHeading` | How Loquiris protects recording | Loquiris 如何保护录音 |
| `ProtectionModerateThermal` | Moderate heat reduces AI concurrency. | 中度发热时会降低 AI 并发。 |
| `ProtectionSevereThermal` | Severe heat pauses AI while recording continues. | 严重发热时会暂停 AI，但录音继续。 |
| `ProtectionBacklog` | Sustained backlog moves unfinished work to after recording. | 持续积压会把未完成的工作移到录音结束后。 |
| `ProtectionRecordingFirst` | Engine or resource failure never discards canonical recording audio. | 引擎或资源故障绝不会丢弃权威录音音频。 |

Reuse the existing `benchmarkMode...` messages for the five mode labels.

- [ ] **Step 5: Regenerate localization**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter gen-l10n
```

- [ ] **Step 6: Implement the informational overview**

Register `part 'performance_policy_overview.dart';` in the screen library. Append `_PerformancePolicyOverview` below `_BenchmarkStateView` with section spacing. Derive `recommendedMode` only from `ModelsPerformanceCompleted`; every other state passes null.

Render policies in `PerformancePolicyCatalog.standard.policies` order. Each card contains the existing localized mode label, localized timing, description, fallback, locked availability, and a text/icon recommendation marker when applicable. Follow existing spacing/theme tokens, use no color-only status, provide a semantic container label, and add no controls.

- [ ] **Step 7: Format the presentation files**

Format the touched Dart files. Expected: formatting completes without an
error and changes only the intended Task 3 Dart files.

- [ ] **Step 8: Run presentation tests GREEN**

Run the three presentation/localization test files. Expected: all pass without overflow or semantic exceptions.

- [ ] **Step 9: Run policy plus presentation regression tests**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/features/models_performance/performance_policy_test.dart test/features/models_performance/models_performance_controller_test.dart test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart
```

Expected: all policy, controller, UI, accessibility, and localization tests pass.

- [ ] **Step 10: Review scope and commit Task 3**

Stage only the Task 3 files and inspected localization hunks. Run the required cached-diff and GitNexus checks, then commit:

```bash
git commit -m "feat: explain performance mode protections"
```

### Task 4: Repository Verification and OpenSpec Completion

**Files:**
- Modify: `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md`

**Interfaces:**
- Consumes: the independently committed catalog, decision engine, and informational presentation from Tasks 1-3.
- Produces: repository-wide verification evidence and the single checklist change `- [ ] 10.7` to `- [x] 10.7`.

- [ ] **Step 1: Audit the implementation against the approved spec**

Confirm each goal, non-goal, mode semantic, pressure priority, privacy rule, UI statement, and test class in `docs/superpowers/specs/2026-10-08-performance-policy-design.md`. Confirm there is no database, Android, recording-default, meeting-entity, `TranscriptionEngine`, model-manifest, runtime-runner, or benchmark-export change.

- [ ] **Step 2: Run focused verification**

Run the combined Task 3 regression command. Expected: all focused tests pass.

- [ ] **Step 3: Run the formatter gate**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin dart format --output=none --set-exit-if-changed lib test
```

Expected: formatter exits zero without changes.

- [ ] **Step 4: Run strict analysis**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter analyze --fatal-infos --fatal-warnings
```

Expected: analyzer reports no issues.

- [ ] **Step 5: Run the complete Flutter suite**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test
```

Expected: the entire suite passes with no skipped task 10.7 acceptance test.

- [ ] **Step 6: Validate OpenSpec strictly**

Run:

```bash
openspec validate bootstrap-loquiris-offline-recorder --strict
```

Expected: the active change is valid.

- [ ] **Step 7: Mark only task 10.7 complete**

Inspect the tasks-file diff, change exactly `- [ ] 10.7` to `- [x] 10.7`, and leave 10.8 and every later task unchanged.

- [ ] **Step 8: Stage, detect changes, and commit completion**

Stage only the 10.7 checklist hunk and any narrowly required verification fix. Run the required cached-diff and GitNexus checks, then commit:

```bash
git commit -m "feat: complete performance policy task"
```

- [ ] **Step 9: Request one final code review and apply at most one fix pass**

Ask a fresh reviewer to inspect the implementation range from the plan's starting commit through Task 4 against the design, OpenSpec 10.7, dirty-worktree isolation, privacy, accessibility, and verification evidence. Reproduce every actionable finding before editing; apply one reviewed fix pass, rerun affected tests plus the full suite, run staged GitNexus detection, and commit fixes separately. Record declined findings as explicit rulings rather than silently ignoring them.

- [ ] **Step 10: Report final evidence**

Report the design and implementation commit hashes, focused/full-suite/analyzer/OpenSpec results, GitNexus risks and affected flows, final-review rulings, and the explicit fact that policies remain informational until a validated inference runtime consumes them.
