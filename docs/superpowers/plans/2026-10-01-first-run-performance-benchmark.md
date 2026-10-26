# First-run Performance Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the models/performance placeholder with an explicit, microphone-free 45-second benchmark flow that truthfully reports runtime unavailability today and deterministically recommends a conservative mode when a measured runner is injected.

**Architecture:** Add immutable benchmark/report values and a pure versioned recommendation policy below an injected event-stream runner. One auto-disposed Riverpod `Notifier` owns the six presentation states, and a localized adaptive screen renders them without persistence or setting mutation. Production bootstrap installs an explicitly unavailable runner until tasks 10.6 and 11.1/11.2 supply real measurements and inference.

**Tech Stack:** Dart 3.12, Flutter, Riverpod 3.x, sealed value types, the repository's `Result<T, F>` and `ValueObject`, `go_router`, Flutter `gen_l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-first-run-performance-benchmark-design.md`

## Global Constraints

- The only benchmark input is `zh-en-mixed-v1`, SHA-256 `83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7`, 1,440,044 bytes, and exactly 45 seconds.
- No benchmark code may read `AudioCaptureService`, request microphone permission, persist a result, or mutate recording defaults or a performance mode.
- The production runner for task 10.5 must report `benchmark_runtime_not_installed`; no synthetic score or recommendation is allowed.
- Recommendation policy v1 uses balanced RTF ≤ 0.8 and latency ≤ 5 s, power-saving RTF ≤ 1.2 and latency ≤ 12 s, and post-session RTF ≤ 1.0; missing or blocked evidence never passes.
- Recommendation order is balanced, power saving, post-session, then recording only; high quality is never automatically recommended by this short check.
- Every user-visible string must come from English and Chinese ARB files; layout must remain usable at 320 logical pixels and 200% text scaling.
- Add no dependency, database schema, Android permission, model artifact, or recording-path change.
- Before modifying any existing function, class, method, provider, or generated localization class, run upstream `gitnexus_impact` with file/kind disambiguation and report direct callers, affected processes, and risk. Stop and warn before a HIGH or CRITICAL edit.
- Before every commit, run `gitnexus_detect_changes(scope: "all")`; because the shared worktree is already globally CRITICAL, verify the staged file list explicitly and commit only the task's named paths.
- Each task follows red-green-refactor, then runs `dart format`, its targeted tests, and `git diff --check` before the scoped commit.

## Review Focus

- A report for a different asset or policy/schema version must become `benchmark_invalid_output`, never a recommendation; Task 1 pins this.
- Missing metrics, duplicate mode measurements, and numeric passes accompanied by blocking reasons must never pass eligibility; Task 1 pins this.
- Regressing progress, a stream closing without a terminal event, or two terminal events must clear stale success and produce a typed invalid-output state; Task 3 pins this.
- Cancellation racing with a late completion must leave the controller cancelled and disposed navigation must ignore all later events; Task 3 pins this.
- Runtime-unavailable, large-text, compact-width, and assistive-technology users must get a truthful, operable page with no hidden microphone access; Tasks 4 and 5 pin this.

---

## File structure

- `lib/features/models_performance/domain/performance_benchmark.dart` — immutable benchmark definition, measurements, report, recommendation, availability, and failures.
- `lib/features/models_performance/application/benchmark_recommendation_policy.dart` — pure policy-v1 validation and mode selection.
- `lib/features/models_performance/application/performance_benchmark_runner.dart` — runner/event contract plus explicitly unavailable implementation.
- `lib/features/models_performance/application/performance_benchmark_provider.dart` — injectable runner provider.
- `lib/features/models_performance/presentation/models_performance_controller.dart` — six-state screen lifecycle and event validation.
- `lib/features/models_performance/presentation/models_performance_screen.dart` — localized dumb widgets for every state.
- `test/support/fakes/fake_performance_benchmark_runner.dart` — reusable controlled runner for controller, widget, and routing tests.
- Focused tests mirror those responsibilities under `test/features/models_performance/`; existing bootstrap, router, localization, and OpenSpec files change only where named below.

### Task 1: Benchmark domain and recommendation policy

**Files:**
- Create: `lib/features/models_performance/domain/performance_benchmark.dart`
- Create: `lib/features/models_performance/application/benchmark_recommendation_policy.dart`
- Create: `test/features/models_performance/benchmark_recommendation_policy_test.dart`

**Interfaces:**
- Consumes: existing `PerformanceMode`, `ValueObject`, `Failure`, and `Result<T, F>`.
- Produces: `firstRunBenchmarkDefinition`, `BenchmarkAvailability`, `BenchmarkModeMeasurement`, `PerformanceBenchmarkReport`, `BenchmarkRecommendation`, `BenchmarkFailure`, and `BenchmarkRecommendationPolicy.recommend(PerformanceBenchmarkReport)`.

- [ ] **Step 1: Write failing fixed-definition and policy tests**

  Add tests named `fixed definition matches bundled manifest`, `threshold equality passes each eligible mode`, `recommendation uses conservative order`, `high quality is never auto selected`, `blocking reason defeats passing numbers`, `missing metric remains ineligible`, `non finite metrics are invalid`, `empty execution identity is invalid`, `duplicate mode measurement is invalid`, and `asset schema and policy mismatch are invalid`.

  Use report fixtures whose only varying fields are measurements. Assert the exact asset ID/hash/bytes/duration, exact threshold equality, and `Err<BenchmarkRecommendation, BenchmarkFailure>` with code `benchmark_invalid_output` for malformed reports.

- [ ] **Step 2: Run the policy test and verify RED**

  Run: `flutter test test/features/models_performance/benchmark_recommendation_policy_test.dart`

  Expected: compilation fails because benchmark domain and policy declarations do not exist.

- [ ] **Step 3: Implement immutable benchmark types**

  In `performance_benchmark.dart`, define:

  ```dart
  const BenchmarkDefinition firstRunBenchmarkDefinition;
  sealed class BenchmarkAvailability extends ValueObject;
  final class BenchmarkAvailable extends BenchmarkAvailability;
  final class BenchmarkUnavailable extends BenchmarkAvailability;
  enum BenchmarkMeasurementStatus { measured, failed, unmeasured }
  final class BenchmarkModeMeasurement extends ValueObject;
  final class PerformanceBenchmarkReport extends ValueObject;
  final class BenchmarkRecommendation extends ValueObject;
  sealed class BenchmarkFailure extends ValueObject implements Failure;
  final class BenchmarkInvalidOutput extends BenchmarkFailure;
  final class BenchmarkRuntimeFailure extends BenchmarkFailure;
  final class BenchmarkAssetFailure extends BenchmarkFailure;
  final class BenchmarkEngineFailure extends BenchmarkFailure;
  final class BenchmarkCancelledFailure extends BenchmarkFailure;
  ```

  `BenchmarkModeMeasurement` has `mode`, `status`, optional non-negative `realTimeFactor`, optional non-negative `firstTextLatency`, and an immutable `blockingReasonCodes`. `PerformanceBenchmarkReport` has schema/policy versions, exact definition, engine/model identity and versions, configuration ID, and immutable measurements. Expand collection elements in `equalityValues`; do not compare list identities.

- [ ] **Step 4: Implement policy v1 as a total function**

  Add:

  ```dart
  final class BenchmarkRecommendationPolicy {
    const BenchmarkRecommendationPolicy();

    Result<BenchmarkRecommendation, BenchmarkFailure> recommend(
      PerformanceBenchmarkReport report,
    );
  }
  ```

  Reject schema/policy versions other than `1`, a definition unequal to `firstRunBenchmarkDefinition`, duplicate mode rows, negative/non-finite values, or an empty engine/model/configuration identity. Select only `measured` rows with every required metric and no blocker, using the global thresholds and order. A valid report with no eligible AI row returns recording only with reason `benchmark_no_ai_mode_eligible` and `shortCheckOnly: true`.

- [ ] **Step 5: Run policy tests and verify GREEN**

  Run: `dart format lib/features/models_performance/domain/performance_benchmark.dart lib/features/models_performance/application/benchmark_recommendation_policy.dart test/features/models_performance/benchmark_recommendation_policy_test.dart && flutter test test/features/models_performance/benchmark_recommendation_policy_test.dart`

  Expected: all policy tests pass.

- [ ] **Step 6: Review scope and commit Task 1**

  Run `gitnexus_detect_changes(scope: "all")`, stage only the three Task 1 files, run `git diff --cached --check`, inspect `git diff --cached --name-status`, then commit:

  ```bash
  git commit -m "feat: define benchmark recommendation policy"
  ```

### Task 2: Injectable runner and truthful production bootstrap

**Files:**
- Create: `lib/features/models_performance/application/performance_benchmark_runner.dart`
- Create: `lib/features/models_performance/application/performance_benchmark_provider.dart`
- Create: `test/support/fakes/fake_performance_benchmark_runner.dart`
- Create: `test/features/models_performance/performance_benchmark_runner_test.dart`
- Modify: `lib/bootstrap/bootstrap.dart:94-258`
- Modify: `test/bootstrap/bootstrap_test.dart:1-67`

**Interfaces:**
- Consumes: Task 1 domain types and `firstRunBenchmarkDefinition`.
- Produces: `PerformanceBenchmarkRunner.availability`, `PerformanceBenchmarkRunner.run(BenchmarkDefinition)`, sealed `PerformanceBenchmarkEvent` variants, `UnavailablePerformanceBenchmarkRunner`, `performanceBenchmarkRunnerProvider`, and a reusable fake.

- [ ] **Step 1: Run pre-edit impact analysis for existing bootstrap symbols**

  Run upstream impact for `bootstrap` in `lib/bootstrap/bootstrap.dart` and `main` in `test/bootstrap/bootstrap_test.dart`, including tests. Report direct callers, affected processes, modules, and risk before editing; stop for user direction if either report is HIGH or CRITICAL.

- [ ] **Step 2: Write failing runner and bootstrap tests**

  Assert `UnavailablePerformanceBenchmarkRunner.availability` is `BenchmarkUnavailable('benchmark_runtime_not_installed')`, and its defensive `run(firstRunBenchmarkDefinition)` emits exactly one typed runtime failure with the same code. Extend `production bootstrap installs local session persistence` to require `ref.read(performanceBenchmarkRunnerProvider) is UnavailablePerformanceBenchmarkRunner`.

- [ ] **Step 3: Run targeted tests and verify RED**

  Run: `flutter test test/features/models_performance/performance_benchmark_runner_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: compilation fails on missing runner/provider types.

- [ ] **Step 4: Implement runner contract and fake**

  Define:

  ```dart
  abstract interface class PerformanceBenchmarkRunner {
    BenchmarkAvailability get availability;
    Stream<PerformanceBenchmarkEvent> run(BenchmarkDefinition definition);
  }

  sealed class PerformanceBenchmarkEvent;
  final class BenchmarkProgressed extends PerformanceBenchmarkEvent;
  final class BenchmarkSucceeded extends PerformanceBenchmarkEvent;
  final class BenchmarkRunFailed extends PerformanceBenchmarkEvent;
  ```

  `BenchmarkProgressed.progress` is a normalized double. `BenchmarkSucceeded` carries one report. `BenchmarkRunFailed` carries one typed failure. Add `UnavailablePerformanceBenchmarkRunner` and a provider whose unoverridden body throws `UnimplementedError`, matching existing composition-root enforcement.

  The fake exposes configurable availability and stream factory, records every supplied definition, and never imports capture services.

- [ ] **Step 5: Install the unavailable runner in production bootstrap**

  Import the feature provider/runner into `bootstrap.dart` and add exactly one override returning `const UnavailablePerformanceBenchmarkRunner()`. Do not install model, metrics, or transcription providers in this task.

- [ ] **Step 6: Run targeted tests and verify GREEN**

  Run: `dart format lib/features/models_performance/application/performance_benchmark_runner.dart lib/features/models_performance/application/performance_benchmark_provider.dart test/support/fakes/fake_performance_benchmark_runner.dart lib/bootstrap/bootstrap.dart test/features/models_performance/performance_benchmark_runner_test.dart test/bootstrap/bootstrap_test.dart && flutter test test/features/models_performance/performance_benchmark_runner_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: runner and bootstrap tests pass.

- [ ] **Step 7: Review scope and commit Task 2**

  Run `gitnexus_detect_changes(scope: "all")`, stage only Task 2 paths, check the staged diff and names, then commit:

  ```bash
  git commit -m "feat: add injectable performance benchmark runner"
  ```

### Task 3: Controller state machine and cancellation safety

**Files:**
- Create: `lib/features/models_performance/presentation/models_performance_controller.dart`
- Create: `test/features/models_performance/models_performance_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 policy/report values and Task 2 runner provider/events.
- Produces: six sealed `ModelsPerformanceState` variants, `ModelsPerformanceController.start()`, `ModelsPerformanceController.cancel()`, and `modelsPerformanceControllerProvider`.

- [ ] **Step 1: Write failing controller transition tests**

  Cover: unavailable build; ready build; one start supplies exactly `firstRunBenchmarkDefinition`; duplicate start is ignored; monotonic progress updates running state; valid completion produces the policy recommendation; runner failure clears stale output; retry after failure/completion starts cleanly; explicit cancel calls stream cancellation and yields cancelled; a late event after cancel/dispose is ignored; regressing/out-of-range progress fails with `benchmark_invalid_output`; close-without-terminal fails; and a second terminal event replaces any stale success with invalid output.

- [ ] **Step 2: Run controller tests and verify RED**

  Run: `flutter test test/features/models_performance/models_performance_controller_test.dart`

  Expected: compilation fails because controller and states do not exist.

- [ ] **Step 3: Implement the six immutable states**

  Define `ModelsPerformanceUnavailable`, `ModelsPerformanceReady`, `ModelsPerformanceRunning`, `ModelsPerformanceCompleted`, `ModelsPerformanceFailed`, and `ModelsPerformanceCancelled` as immutable structural values. Completed carries the exact report and recommendation; failed carries only a typed `BenchmarkFailure`; running carries normalized progress.

- [ ] **Step 4: Implement the auto-disposed Notifier**

  Add:

  ```dart
  final class ModelsPerformanceController
      extends Notifier<ModelsPerformanceState> {
    @override
    ModelsPerformanceState build();
    void start();
    Future<void> cancel();
  }

  final NotifierProvider<ModelsPerformanceController, ModelsPerformanceState>
      modelsPerformanceControllerProvider;
  ```

  Use one `StreamSubscription`, a monotonically increasing run generation, a terminal-seen flag, and last progress. Register explicit subscription cancellation with `ref.onDispose`. Convert unexpected runner errors to `BenchmarkRuntimeFailure('benchmark_runner_exception')`; never retain exception text.

- [ ] **Step 5: Run controller tests and verify GREEN**

  Run: `dart format lib/features/models_performance/presentation/models_performance_controller.dart test/features/models_performance/models_performance_controller_test.dart && flutter test test/features/models_performance/models_performance_controller_test.dart`

  Expected: all state, race, malformed-stream, and retry tests pass.

- [ ] **Step 6: Review scope and commit Task 3**

  Run `gitnexus_detect_changes(scope: "all")`, stage only the controller and its test, check the staged diff and names, then commit:

  ```bash
  git commit -m "feat: orchestrate performance benchmark state"
  ```

### Task 4: Localized adaptive recommendation screen

**Files:**
- Create: `lib/features/models_performance/presentation/models_performance_screen.dart`
- Create: `test/features/models_performance/models_performance_screen_test.dart`
- Create: `test/accessibility/models_performance_accessibility_test.dart`
- Create: `test/localization/models_performance_localization_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`

**Interfaces:**
- Consumes: Task 3 controller provider and states.
- Produces: `ModelsPerformanceScreen` with key `models-performance`, localized labels/reasons for all six states, and no business logic in widgets.

- [ ] **Step 1: Run pre-edit impact analysis for localization symbols**

  Run upstream impact for `AppLocalizations`, `AppLocalizationsEn`, and `AppLocalizationsZh` in their generated files, plus `main` in any existing localization test file that will be modified. Report blast radius and stop before generation if HIGH or CRITICAL.

- [ ] **Step 2: Write failing screen, localization, and accessibility tests**

  Add widget cases for unavailable, ready, running, completed, failed, cancelled, start, duplicate-start disabling, cancel, retry, and rerun. Override `audioCaptureServiceProvider` with a provider factory that throws if read; prove ready-to-completed flow succeeds anyway. Assert completed UI shows recommendation plus the short-check warning and has no apply/settings mutation action.

  Add English/Chinese localization assertions, a 320×640 viewport at 200% text scaling with no exception and a scrollable body, semantic live regions for progress and terminal results, explicit button labels, and text/icon status cues rather than color-only output.

- [ ] **Step 3: Run screen tests and verify RED**

  Run: `flutter test test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart`

  Expected: compilation fails because the screen and localization getters do not exist.

- [ ] **Step 4: Add exact English and Chinese localization keys**

  Add ARB entries for: intro, fixed-audio/privacy disclosure, unavailable heading/body, ready heading, start, running heading/progress, cancel, cancelled heading/body, recommendation heading, short-check limitation, rerun, generic failure/retry, passed/failed/unmeasured statuses, five mode names, RTF and latency metric labels, and stable explanations for balanced, power saving, post-session, recording-only fallback, invalid asset/output, engine failure, and runtime unavailable.

  Use ICU numeric placeholders for progress percentage and formatted metric values; do not concatenate localized sentences in Dart.

- [ ] **Step 5: Regenerate localization output**

  Run: `flutter gen-l10n`

  Expected: the three generated localization files expose every new getter with matching English and Chinese implementations.

- [ ] **Step 6: Implement dumb adaptive widgets for all states**

  Build `ModelsPerformanceScreen` as a `ConsumerWidget` with `Scaffold`, `SafeArea`, directional padding, `SingleChildScrollView`, and a centered width constraint. Extract const widget classes for disclosure, progress, recommendation, status row, unavailable, failure, and actions; keep recommendation/failure mapping in top-level pure presentation functions, not `build()`.

  Use stable keys `benchmark-start`, `benchmark-progress`, `benchmark-cancel`, `benchmark-retry`, and `benchmark-rerun`. Use semantic live regions without announcing each small percentage update. Do not render a microphone icon or an apply button.

- [ ] **Step 7: Run UI tests and verify GREEN**

  Run: `dart format lib/features/models_performance/presentation/models_performance_screen.dart test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart && flutter test test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart`

  Expected: all six states, actions, locales, compact layout, semantics, and capture-isolation tests pass.

- [ ] **Step 8: Review scope and commit Task 4**

  Run `gitnexus_detect_changes(scope: "all")`, stage only Task 4 paths, verify generated output contains no unrelated churn, check the staged diff and names, then commit:

  ```bash
  git commit -m "feat: add performance recommendation screen"
  ```

### Task 5: Route integration and end-to-end acceptance

**Files:**
- Modify: `lib/routing/app_router.dart:4-10,68-75`
- Modify: `test/routing/app_router_test.dart:1-53`
- Modify: `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md:99`

**Interfaces:**
- Consumes: `ModelsPerformanceScreen`, `performanceBenchmarkRunnerProvider`, and the existing `AppRoutes.modelsPerformance` route.
- Produces: a reconstructable models/performance URL that renders the real unavailable screen in production and preserves every existing route.

- [ ] **Step 1: Run pre-edit impact analysis for route and test symbols**

  Run upstream impact for `appRouterProvider` in `lib/routing/app_router.dart` and `main` in `test/routing/app_router_test.dart`, including tests. Report direct callers, affected flows/modules, and risk; stop before editing on HIGH or CRITICAL.

- [ ] **Step 2: Write failing route acceptance assertions**

  Override `performanceBenchmarkRunnerProvider` with `const UnavailablePerformanceBenchmarkRunner()` in the route harness. Strengthen the existing reconstructable-surface test so `/settings/models-performance` finds the screen key and the localized runtime-unavailable explanation, not merely the old placeholder title.

- [ ] **Step 3: Run routing test and verify RED**

  Run: `flutter test test/routing/app_router_test.dart`

  Expected: the unavailable explanation is absent because the route still builds `AppRouteScreen`.

- [ ] **Step 4: Replace only the placeholder route builder**

  Import `models_performance_screen.dart` and change the models/performance builder to `const ModelsPerformanceScreen()`. Keep the route path, settings shell branch, `AppDestination`, not-found screen, and all other builders unchanged.

- [ ] **Step 5: Run feature and routing regression tests**

  Run: `dart format lib/routing/app_router.dart test/routing/app_router_test.dart && flutter test test/features/models_performance test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart test/routing/app_router_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: all targeted tests pass.

- [ ] **Step 6: Run full verification**

  Run:

  ```bash
  flutter gen-l10n
  dart format --output=none --set-exit-if-changed \
    lib/bootstrap/bootstrap.dart \
    lib/features/models_performance/application/benchmark_recommendation_policy.dart \
    lib/features/models_performance/application/performance_benchmark_provider.dart \
    lib/features/models_performance/application/performance_benchmark_runner.dart \
    lib/features/models_performance/domain/performance_benchmark.dart \
    lib/features/models_performance/presentation/models_performance_controller.dart \
    lib/features/models_performance/presentation/models_performance_screen.dart \
    lib/routing/app_router.dart \
    test/accessibility/models_performance_accessibility_test.dart \
    test/bootstrap/bootstrap_test.dart \
    test/features/models_performance \
    test/localization/models_performance_localization_test.dart \
    test/routing/app_router_test.dart \
    test/support/fakes/fake_performance_benchmark_runner.dart
  flutter analyze --fatal-infos --fatal-warnings
  flutter test
  git diff --check
  npx openspec validate bootstrap-loquiris-offline-recorder --strict
  ```

  Expected: no generated drift, no formatting change, analyzer clean, complete suite green, diff clean, and strict OpenSpec validation passes.

- [ ] **Step 7: Mark OpenSpec task 10.5 complete**

  Change only task 10.5 from `[ ]` to `[x]`. Do not mark 10.6, 10.7, 11.1, or 11.2.

- [ ] **Step 8: Run final change detection and commit Task 5**

  Run `gitnexus_detect_changes(scope: "all")`; confirm newly affected symbols and flows are limited to the benchmark feature, bootstrap composition, localization, and models/performance route while separately acknowledging the pre-existing global dirty-tree risk. Stage only Task 5 paths, inspect `git diff --cached --name-status`, then commit:

  ```bash
  git commit -m "feat: route first-run performance benchmark"
  ```

- [ ] **Step 9: Record completion evidence**

  Report targeted/full test counts, analyzer/OpenSpec results, GitNexus blast radius, the five scoped commits, and the explicit limitation that production remains unavailable until the real engine/model/metrics tasks are complete.
