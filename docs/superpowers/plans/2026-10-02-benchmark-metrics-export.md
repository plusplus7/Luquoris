# Benchmark Metrics and Local Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture truthful before/after Android resource observations around a real benchmark runner, retain runner-owned inference measurements, and let the user explicitly export one deterministic privacy-safe JSON report without affecting recording or fabricating production results.

**Architecture:** Extend the existing performance contracts with one current-snapshot read, then decorate an available benchmark runner with a pure two-snapshot collector; the unavailable production runner remains undecorated until the real inference runtime arrives. A pure encoder validates schema-v2 reports and a feature-owned exporter delegates one small JSON document to the existing Android Storage Access Framework gateway. The completed benchmark screen adds one coalesced secondary export action and localized outcome feedback, with no background monitoring, persistence, or dashboard.

**Tech Stack:** Dart 3.12, Flutter, Riverpod 3.x, sealed value types, the repository's `Result<T, F>` and `ValueObject`, Flutter `MethodChannel`, Android API 29+ Kotlin/JVM 17, Android `Process`/`Debug.MemoryInfo`/`PowerManager`/`BatteryManager`, existing SAF export gateway, `jsonEncode`, Flutter `gen_l10n`, `flutter_test`, JUnit 4.

**Spec:** `docs/superpowers/specs/2026-10-02-benchmark-metrics-export-design.md`

## Global Constraints

- Capture exactly two resource snapshots per successful decorated run: one before delegation and one after the delegate emits success; do not add streaming, periodic sampling, a daemon, charts, history, or database persistence.
- Android observations are monotonic time in milliseconds, cumulative process CPU milliseconds, current process PSS bytes, coarse thermal state, optional remaining device energy in nanowatt-hours, and charging state; they contain no identifier, path, URI, arbitrary platform map, exception text, audio, or transcript.
- Name memory output `maxSampledPssBytes`; it is the greater of two point-in-time PSS samples and must never be described as runtime peak memory.
- Name energy output `deviceEnergyUsedNanowattHours`; it is an optional device-level remaining-energy delta, never application-exclusive attribution.
- Emit energy only when both counters exist, neither snapshot is charging, monotonic time advances, and the counter does not increase; otherwise keep energy null and emit a stable reason code.
- Reject negative values, non-finite doubles, reversed time, decreasing CPU, overflow beyond signed 64-bit integer range, malformed platform types, and unsupported report versions; do not clamp or invent values.
- RTF, first-text latency, and maximum backlog remain runner-owned. Missing values stay null, and `maximumBacklog` is a non-negative signed-64-bit integer when present.
- Report schema `1` remains valid without the resource shape; schema `2` requires a `BenchmarkResourceMetrics` value that either contains all four core metrics or contains none plus a stable unavailability reason. Policy version remains `1`.
- A snapshot or energy failure must never replace delegate progress, failure, or a successful report. Recording, canonical audio, and transcript state must remain untouched.
- Production continues to install `UnavailablePerformanceBenchmarkRunner`; do not decorate it or fabricate a report before the real runtime work in 11.1.
- Export only `benchmark-report.json` as UTF-8 `application/json`, with no audio, no segment fallback, stable native session ID `benchmark`, a fresh operation UUID, and default UTC filename `Loquiris-benchmark-YYYYMMDD-HHmmss.json`.
- The JSON allowlist contains only version, fixed benchmark metadata, execution identifiers, mode/status/RTF/latency/backlog/blocker data, and resource metrics/reason codes. It never contains user content, names, device/account/network identifiers, paths/URIs, exceptions, stack traces, or raw platform maps.
- Export encoding must finish and validate before the system destination picker opens. Equal reports produce byte-identical JSON with fixed object-key order, mode-index order, and sorted reason-code arrays.
- The explicit completed-state export action is at least 48 logical pixels, localized in English and Chinese, hidden in every non-completed state, and never mutates the report or recommendation.
- Add no dependency, Android permission, database table, recording-path change, or telemetry/network behavior.
- Before modifying every existing function, class, method, provider, generated localization class, or Kotlin controller, run upstream `gitnexus_impact` with file/kind disambiguation and report direct callers, affected processes, and risk. Stop and warn before any HIGH or CRITICAL edit.
- Before every commit, run `gitnexus_detect_changes(scope: "staged")`, inspect `git diff --cached --name-status`, and verify affected flows match the task. The shared worktree is already dirty: stage only task 10.6 hunks and new files, never an entire pre-dirty file without inspecting its staged patch.
- Each implementation task follows red-green-refactor, then runs `dart format`, its focused tests, `git diff --check`, and staged-scope detection before its scoped commit.

## Review Focus

- A start/end snapshot with reversed time or decreased CPU must yield schema-v2 unavailable metrics, while negative/overflow snapshot values and partial report cores must be rejected at their boundaries rather than clamped or allowed to lose benchmark success; Task 1 pins this in `benchmark_metrics_collector_test.dart` and `service_contracts_test.dart`.
- Unknown thermal input and missing, charging, or increasing energy counters must preserve valid CPU/PSS/wall metrics while reporting truthful thermal/energy availability; Task 1 pins this in `benchmark_metrics_collector_test.dart`.
- A malformed, slow, missing-plugin, or failing Android response must close with stable codes and deliver its reply on the UI executor without blocking the channel thread; Task 2 pins this across the Dart adapter and Kotlin controller tests.
- A report containing path-like execution identities, non-finite values, unsupported versions, reordered modes, or absent optional values must either fail before the picker or encode deterministic allowlisted JSON with explicit nulls; Task 3 pins this in encoder/exporter tests.
- Duplicate export taps, picker cancellation, widget disposal during export, and export failure after completion must produce at most one native write and must retain the exact completed report/recommendation; Task 4 pins this in controller, widget, localization, and accessibility tests.

---

## File structure

- `lib/services/service_contracts.dart` — current-only performance snapshot contract with validated monotonic, CPU, PSS, thermal, optional energy, and charging fields.
- `lib/features/models_performance/domain/benchmark_resource_metrics.dart` — schema-v2 resource value and stable reason-code constants.
- `lib/features/models_performance/domain/performance_benchmark.dart` — backlog, resource shape, report copy/equality, and schema-v1/v2 data.
- `lib/features/models_performance/application/benchmark_metrics_collector.dart` — pure two-snapshot derivation and invalid/unavailable handling.
- `lib/features/models_performance/application/metrics_capturing_performance_benchmark_runner.dart` — event-preserving decorator that attaches schema-v2 metrics only to delegate success.
- `android/app/src/main/kotlin/com/loquiris/performance/` — versioned snapshot channel contract, Android API reader, and background/UI executor controller.
- `lib/native/method_channel_thermal_and_performance_monitor.dart` — strict Dart decoder and stable platform failure mapping.
- `lib/features/models_performance/application/benchmark_report_json_encoder.dart` — pure schema validation and deterministic JSON allowlist.
- `lib/features/models_performance/application/benchmark_report_exporter.dart` — feature-owned export boundary and Riverpod provider.
- `lib/features/export_backup/application/local_benchmark_report_exporter.dart` — SAF payload adapter with no database/history dependency.
- `lib/features/models_performance/presentation/` — completed-state export orchestration, action, and localized result feedback.
- Tests mirror each responsibility under `test/features/models_performance/`, `test/native/`, `test/accessibility/`, and `android/app/src/test/kotlin/com/loquiris/performance/`.

### Task 1: Resource domain, validation, collector, and runner decorator

**Files:**
- Create: `lib/features/models_performance/domain/benchmark_resource_metrics.dart`
- Create: `lib/features/models_performance/application/benchmark_metrics_collector.dart`
- Create: `lib/features/models_performance/application/metrics_capturing_performance_benchmark_runner.dart`
- Create: `test/features/models_performance/benchmark_metrics_collector_test.dart`
- Create: `test/features/models_performance/metrics_capturing_performance_benchmark_runner_test.dart`
- Modify: `lib/services/service_contracts.dart:659-713`
- Modify: `lib/features/models_performance/domain/performance_benchmark.dart:54-142`
- Modify: `lib/features/models_performance/application/benchmark_recommendation_policy.dart:44-105`
- Modify: `test/support/fakes/fake_services.dart:303-327`
- Modify: `test/services/service_contracts_test.dart`
- Modify: `test/features/models_performance/benchmark_recommendation_policy_test.dart`

**Interfaces:**
- Consumes: `ThermalState`, `Result<T, F>`, `PerformanceFailure`, `PerformanceBenchmarkRunner`, and its existing event stream.
- Produces: `DevicePerformanceSnapshot({required Duration observedAtMonotonic, required Duration processCpuTime, required int processPssBytes, required ThermalState thermalState, required bool isCharging, int? remainingDeviceEnergyNanowattHours})`; current-only `ThermalAndPerformanceMonitor.current()`; optional `BenchmarkModeMeasurement.maximumBacklog`; schema-v2 `BenchmarkResourceMetrics`; `PerformanceBenchmarkReport.copyWith(...)`; `BenchmarkMetricsCollector.collect(start, end)`; and `MetricsCapturingPerformanceBenchmarkRunner({required delegate, required monitor, collector})`.

- [ ] **Step 1: Run pre-edit impact analysis and report the blast radius**

  Run upstream impact, including tests, for `DevicePerformanceSnapshot`, `ThermalAndPerformanceMonitor`, `BenchmarkModeMeasurement`, `PerformanceBenchmarkReport`, and `BenchmarkRecommendationPolicy.recommend`, using their file paths and kinds to disambiguate. For each result, report direct callers, affected execution flows/modules, and risk; stop for user direction on HIGH or CRITICAL.

- [ ] **Step 2: Write failing snapshot/domain/collector tests**

  Add tests named:

  - `snapshot stores monotonic cpu pss thermal energy and charging values`;
  - `schema two report equality includes backlog resources and reasons`;
  - `collector derives wall cpu maximum sampled pss and worst known thermal`;
  - `collector emits device energy only for a falling discharging counter`;
  - `missing charging and increasing energy keep core metrics with stable reasons`;
  - `unknown thermal never hides a known state and two unknown samples stay unknown`;
  - `reversed time and decreased cpu become unavailable without clamping`;
  - `snapshot constructor rejects negative and int64 overflow values`;
  - `schema one stays valid and schema two rejects partial core metrics negative backlog and non finite rtf`.

  Use start `(1000 ms wall, 400 ms CPU, 10,000 PSS bytes, warm, 9,000 nWh, discharging)` and end `(2500, 850, 12,000, hot, 8,400, discharging)`. Assert `wallDuration == 1500 ms`, `processCpuTime == 450 ms`, `maxSampledPssBytes == 12000`, worst thermal `hot`, and energy `600`. Assert reversed time and decreased CPU return a resource value with null core fields and `performance_metrics_invalid_delta`; assert negative/overflow snapshot construction and partial report resources are rejected, never clamped.

- [ ] **Step 3: Run domain/collector tests and verify RED**

  Run: `flutter test test/services/service_contracts_test.dart test/features/models_performance/benchmark_metrics_collector_test.dart test/features/models_performance/benchmark_recommendation_policy_test.dart`

  Expected: compilation fails because the expanded snapshot, backlog/resource report shape, and collector do not exist.

- [ ] **Step 4: Implement the current-only snapshot and schema-v2 values**

  Remove `ThermalAndPerformanceMonitor.snapshots`; keep only:

  ```dart
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>> current();
  ```

  Replace `processMemoryBytes` with `processPssBytes` and add the exact fields in the Interfaces block. Constructors assert non-negative signed-64-bit integer values (`<= 9223372036854775807`) and non-negative durations; runtime validation must still fail closed because asserts are not a release boundary. Simplify `FakeThermalAndPerformanceMonitor` to a configurable current result and `currentCalls` counter; remove its stream controller and dispose API.

  Define:

  ```dart
  final class BenchmarkResourceMetrics extends ValueObject {
    final Duration? wallDuration;
    final Duration? processCpuTime;
    final int? maxSampledPssBytes;
    final ThermalState? worstThermalState;
    final int? deviceEnergyUsedNanowattHours;
    final List<String> unavailableReasonCodes;
  }
  ```

  Core fields are all present or all null. Add exact constants `performance_metrics_start_unavailable`, `performance_metrics_end_unavailable`, `performance_metrics_invalid_delta`, `device_energy_counter_unavailable`, `device_energy_measurement_charging`, and `device_energy_counter_increased`. Add nullable non-negative signed-64-bit `maximumBacklog` to `BenchmarkModeMeasurement`. Add nullable `resourceMetrics` to the report, include all new values in structural equality, and add `copyWith({int? schemaVersion, BenchmarkResourceMetrics? resourceMetrics})` that preserves every runner-owned field.

- [ ] **Step 5: Implement validation and pure two-snapshot aggregation**

  Update recommendation validation to accept only schema `1` or `2`; schema 1 requires null resources, while schema 2 requires a resource object satisfying the all-or-none core invariant. Validate durations, integers, `maximumBacklog`, finite/non-negative RTF, and non-empty stable reason codes. Preserve policy-v1 thresholds and recommendation order unchanged.

  Add:

  ```dart
  final class BenchmarkMetricsCollector {
    const BenchmarkMetricsCollector();

    BenchmarkResourceMetrics collect(
      DevicePerformanceSnapshot start,
      DevicePerformanceSnapshot end,
    );

    BenchmarkResourceMetrics unavailable(String reasonCode);
  }
  ```

  Rank known thermal states `nominal < warm < hot < critical`; ignore `unknown` when the other sample is known, and return `unknown` only when both are unknown. Use checked subtraction and signed-64-bit bounds. Energy unavailability adds one sorted reason without discarding core metrics.

- [ ] **Step 6: Write failing event-preservation decorator tests**

  Add tests named `decorator reads exactly before and after and attaches schema two metrics`, `progress and delegate failure pass through unchanged`, `start failure preserves success and skips the unusable end read`, `end failure preserves success with an unavailable reason`, `delegate stream error is not converted by metric capture`, and `unavailable production runner is never decorated or monitored`.

  Assert the successful report retains the identical definition, identities, measurements, RTF, latency, and backlog; only `schemaVersion: 2` and `resourceMetrics` differ. A start or end metric failure must still emit `BenchmarkSucceeded`, with null core metrics and the exact start/end reason.

- [ ] **Step 7: Run decorator tests and verify RED**

  Run: `flutter test test/features/models_performance/metrics_capturing_performance_benchmark_runner_test.dart`

  Expected: compilation fails because the decorator is absent.

- [ ] **Step 8: Implement the event-preserving runner decorator**

  Define:

  ```dart
  final class MetricsCapturingPerformanceBenchmarkRunner
      implements PerformanceBenchmarkRunner {
    const MetricsCapturingPerformanceBenchmarkRunner({
      required PerformanceBenchmarkRunner delegate,
      required ThermalAndPerformanceMonitor monitor,
      BenchmarkMetricsCollector collector = const BenchmarkMetricsCollector(),
    });
  }
  ```

  Proxy `availability`. On `run`, await one start read, subscribe to the delegate once, forward progress/failure/error/done semantics, and only after `BenchmarkSucceeded` read the end snapshot and emit a copied schema-v2 report. If the start read fails, do not issue a meaningless end read. Catch only monitor exceptions and convert them to the matching stable metric-unavailable reason; do not catch or reinterpret delegate failures/errors.

- [ ] **Step 9: Run focused tests and verify GREEN**

  Run: `dart format lib/services/service_contracts.dart lib/features/models_performance/domain/benchmark_resource_metrics.dart lib/features/models_performance/domain/performance_benchmark.dart lib/features/models_performance/application/benchmark_recommendation_policy.dart lib/features/models_performance/application/benchmark_metrics_collector.dart lib/features/models_performance/application/metrics_capturing_performance_benchmark_runner.dart test/support/fakes/fake_services.dart test/services/service_contracts_test.dart test/features/models_performance/benchmark_metrics_collector_test.dart test/features/models_performance/benchmark_recommendation_policy_test.dart test/features/models_performance/metrics_capturing_performance_benchmark_runner_test.dart && flutter test test/services/service_contracts_test.dart test/features/models_performance/benchmark_metrics_collector_test.dart test/features/models_performance/benchmark_recommendation_policy_test.dart test/features/models_performance/metrics_capturing_performance_benchmark_runner_test.dart`

  Expected: snapshot, schema-v1/v2, aggregation, partial energy, invalid-delta, and event-preservation tests pass.

- [ ] **Step 10: Review scope and commit Task 1**

  Stage only Task 1 files/hunks. Run `git diff --cached --check`, `git diff --cached --name-status`, and `gitnexus_detect_changes(scope: "staged")`; inspect every changed symbol/process, then commit:

  ```bash
  git commit -m "feat: capture benchmark resource metrics"
  ```

### Task 2: Android snapshot channel and strict Dart adapter

**Files:**
- Create: `android/app/src/main/kotlin/com/loquiris/performance/PerformanceMetricsChannelContract.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/performance/PerformanceMetricsReader.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/performance/PerformanceMetricsChannelController.kt`
- Create: `android/app/src/test/kotlin/com/loquiris/performance/PerformanceMetricsChannelContractTest.kt`
- Create: `android/app/src/test/kotlin/com/loquiris/performance/PerformanceMetricsReaderTest.kt`
- Create: `android/app/src/test/kotlin/com/loquiris/performance/PerformanceMetricsChannelControllerTest.kt`
- Create: `lib/native/method_channel_thermal_and_performance_monitor.dart`
- Create: `test/native/method_channel_thermal_and_performance_monitor_test.dart`
- Modify: `android/app/src/main/kotlin/com/loquiris/MainActivity.kt:1-129`
- Modify: `lib/bootstrap/bootstrap.dart:1-228`
- Modify: `test/bootstrap/bootstrap_test.dart:1-73`

**Interfaces:**
- Consumes: Task 1 `ThermalAndPerformanceMonitor`, `DevicePerformanceSnapshot`, `ThermalState`, existing `thermalAndPerformanceMonitorProvider`, Flutter binary messenger, and Android API 29+.
- Produces: channel `com.loquiris/performance_metrics_v1`, method `readSnapshot`, request/response version `1`, `PerformanceMetricsReader.readSnapshot()`, `PerformanceMetricsChannelController.handle(...)`, and `MethodChannelThermalAndPerformanceMonitor.current()` with a two-second timeout.

- [ ] **Step 1: Run pre-edit impact analysis and report the blast radius**

  Run upstream impact, including tests, for `MainActivity.configureFlutterEngine`, `MainActivity.onDestroy`, `bootstrap`, `thermalAndPerformanceMonitorProvider`, and the bootstrap installation test. Report direct callers, processes/modules, and risk; stop on HIGH or CRITICAL before editing.

- [ ] **Step 2: Write failing Kotlin contract and reader tests**

  Add JUnit cases named `read snapshot accepts only version one`, `unsupported method and malformed request return stable failures`, `thermal statuses map to coarse states`, `pss kilobytes convert to bytes with overflow rejection`, and `unsupported or negative energy becomes null`.

  Pin thermal mapping: `NONE` and `LIGHT -> nominal`, `MODERATE -> warm`, `SEVERE -> hot`, `CRITICAL`, `EMERGENCY`, and `SHUTDOWN -> critical`, every other value -> `unknown`. Pin success shape:

  ```text
  {v:1, ok:true, snapshot:{observedAtMonotonicMs, processCpuTimeMs,
  processPssBytes, thermalState, remainingDeviceEnergyNanowattHours,
  isCharging}}
  ```

  Failure responses contain only `{v:1, ok:false, failure:{code}}`.

- [ ] **Step 3: Run Kotlin tests and verify RED**

  Run: `./android/gradlew -p android testDebugUnitTest --tests 'com.loquiris.performance.*'`

  Expected: Kotlin compilation fails because the performance channel package does not exist.

- [ ] **Step 4: Implement the Android value reader and channel contract**

  `PerformanceMetricsReader` reads `SystemClock.elapsedRealtime()`, `Process.getElapsedCpuTime()`, `Debug.getMemoryInfo(...).totalPss * 1024L` with checked multiplication, `PowerManager.currentThermalStatus`, `BatteryManager.getLongProperty(BATTERY_PROPERTY_ENERGY_COUNTER)`, and `BatteryManager.isCharging`. Treat a negative/unsupported energy counter as null. Keep Android calls behind injectable zero-argument readers so local JVM tests exercise mapping without invoking stubbed framework methods.

  `PerformanceMetricsChannelContract` accepts only method `readSnapshot` and arguments map `{'v': 1}`. It emits only the fixed primitive shape above and stable codes `performance_metrics_method_unsupported`, `performance_metrics_request_invalid`, `performance_metrics_read_failed`, or `performance_metrics_channel_invalid`; never include exception strings.

- [ ] **Step 5: Write failing controller concurrency tests**

  Add cases named `reader runs on worker and reply runs on reply executor`, `reader failure returns structured privacy safe error`, and `one request produces exactly one reply`. Use queued fake executors to prove `handle` returns before reading, the worker does not call the reply callback directly, and duplicate completion is impossible.

- [ ] **Step 6: Implement the background controller and register it in MainActivity**

  Define `PerformanceMetricsChannelController(reader, metricsExecutor, replyExecutor).handle(method, arguments, reply)`. Decode synchronously, run only the Android read on `metricsExecutor`, and marshal exactly one response through `replyExecutor`.

  Add a dedicated single-thread `performanceMetricsExecutor` in `MainActivity`, register the versioned channel during `configureFlutterEngine`, and shut the executor down in `onDestroy`. Do not reuse recording, export, playback, or storage executors.

- [ ] **Step 7: Write failing Dart adapter tests**

  Add tests named `decodes exact versioned snapshot`, `rejects wrong version missing keys wrong types negative overflow and unknown thermal names`, `maps timeout missing plugin and platform failure to channel unavailable`, and `never exposes platform exception text`. Assert milliseconds convert to `Duration`, absent energy remains null, and malformed success returns `PerformanceUnavailable('performance_metrics_channel_invalid')`.

- [ ] **Step 8: Run Dart adapter tests and verify RED**

  Run: `flutter test test/native/method_channel_thermal_and_performance_monitor_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: compilation fails because the adapter is missing and bootstrap does not install the monitor.

- [ ] **Step 9: Implement strict decoding and install only the monitor**

  Add:

  ```dart
  final class MethodChannelThermalAndPerformanceMonitor
      implements ThermalAndPerformanceMonitor {
    const MethodChannelThermalAndPerformanceMonitor({
      MethodChannel? channel,
      Duration timeout = const Duration(seconds: 2),
    });
  }
  ```

  Invoke `readSnapshot` with `{'v': 1}`. Validate the exact response version, booleans, strings, signed-64-bit integers, non-negative fields, nullable energy, and the five thermal enum names. Map timeout, `MissingPluginException`, and `PlatformException` to `performance_metrics_channel_unavailable`; map malformed values to `performance_metrics_channel_invalid` without logging raw exception content.

  Override `thermalAndPerformanceMonitorProvider` in `bootstrap` with this adapter. Keep `performanceBenchmarkRunnerProvider` bound directly to `UnavailablePerformanceBenchmarkRunner`; extend the bootstrap test to assert both installations and prove reading the runner does not invoke the monitor.

- [ ] **Step 10: Run focused tests and verify GREEN**

  Run: `dart format lib/native/method_channel_thermal_and_performance_monitor.dart lib/bootstrap/bootstrap.dart test/native/method_channel_thermal_and_performance_monitor_test.dart test/bootstrap/bootstrap_test.dart && flutter test test/native/method_channel_thermal_and_performance_monitor_test.dart test/bootstrap/bootstrap_test.dart && ./android/gradlew -p android testDebugUnitTest --tests 'com.loquiris.performance.*'`

  Expected: strict adapter, Kotlin mapping, background/reply executor, and production bootstrap tests pass.

- [ ] **Step 11: Review scope and commit Task 2**

  Stage only Task 2 files/hunks. Run staged diff checks and `gitnexus_detect_changes(scope: "staged")`, verify only the performance channel/bootstrap flows are affected, then commit:

  ```bash
  git commit -m "feat: read Android benchmark metrics"
  ```

### Task 3: Deterministic JSON and local SAF exporter

**Files:**
- Create: `lib/features/models_performance/application/benchmark_report_json_encoder.dart`
- Create: `lib/features/models_performance/application/benchmark_report_exporter.dart`
- Create: `lib/features/export_backup/application/local_benchmark_report_exporter.dart`
- Create: `test/features/models_performance/benchmark_report_json_encoder_test.dart`
- Create: `test/features/export_backup/local_benchmark_report_exporter_test.dart`
- Modify: `lib/bootstrap/bootstrap.dart:103-228`
- Modify: `test/bootstrap/bootstrap_test.dart:1-73`

**Interfaces:**
- Consumes: schema-v1/v2 report values, `ExportDestinationGateway.save(ExportDestinationPayload)`, `ExportReceipt`, `ExportFailure`, and the existing JSON `ExportFormat`.
- Produces: `BenchmarkReportJsonEncoder.encode(PerformanceBenchmarkReport) -> Result<String, ExportFailure>`; `BenchmarkReportExporter.export({required report, required operationId, required createdAtUtc})`; `benchmarkReportExporterProvider`; and `LocalBenchmarkReportExporter({required destinationGateway, encoder})`.

- [ ] **Step 1: Run pre-edit impact analysis and report the blast radius**

  Run upstream impact, including tests, for `ExportDestinationPayload`, `ExportDestinationGateway.save`, `bootstrap`, and the production bootstrap test. New encoder/exporter symbols should report no callers before creation. Report risk and stop on HIGH or CRITICAL.

- [ ] **Step 2: Write failing deterministic encoder tests**

  Add cases named `encodes schema two in fixed allowlisted order`, `sorts measurements by performance mode and reason codes lexically`, `uses explicit nulls for missing runner and energy metrics`, `equal reports produce identical utf8 bytes`, `rejects unsupported partial negative non finite and path like identity values`, and `output contains no user device path uri exception audio or transcript keys`.

  Pin this fixed top-level/key order:

  1. `schemaVersion`, `policyVersion`;
  2. `benchmark` with `id`, `sha256`, `bytes`, `mediaDurationMilliseconds`;
  3. `execution` with `engineId`, `engineVersion`, `modelId`, `modelVersion`, `configurationId`;
  4. `measurements`, each with `mode`, `status`, `realTimeFactor`, `firstTextLatencyMilliseconds`, `maximumBacklog`, `blockingReasonCodes`;
  5. `resources` with `wallDurationMilliseconds`, `processCpuTimeMilliseconds`, `maxSampledPssBytes`, `worstThermalState`, `deviceEnergyUsedNanowattHours`, `unavailableReasonCodes`.

  Encode nullable values as JSON `null`, not zero or empty synthetic measurements. Sort measurement copies by `PerformanceMode.index` and reason-code copies lexically without mutating the report. Accept stable execution IDs matching `[A-Za-z0-9._-]{1,128}``; reject slash, backslash, colon, control characters, and whitespace-only values with `benchmark_report_invalid`.

- [ ] **Step 3: Run encoder tests and verify RED**

  Run: `flutter test test/features/models_performance/benchmark_report_json_encoder_test.dart`

  Expected: compilation fails because the encoder does not exist.

- [ ] **Step 4: Implement pure validation and deterministic encoding**

  Add:

  ```dart
  final class BenchmarkReportJsonEncoder {
    const BenchmarkReportJsonEncoder();

    Result<String, ExportFailure> encode(PerformanceBenchmarkReport report);
  }
  ```

  Validate before constructing output, including the schema-v1/v2 invariants from Task 1, finite numbers, signed-64-bit bounds, fixed benchmark definition, policy version `1`, unique modes, stable identity syntax, and reason-code syntax `[a-z0-9_]{1,128}`. Use insertion-ordered Dart maps and `jsonEncode`; do not serialize object `toString()` output or any unlisted field.

- [ ] **Step 5: Write failing exporter tests**

  Add cases named `valid report opens one privacy safe json destination`, `invalid report never opens destination`, `picker cancellation and destination failure pass through unchanged`, and `export does not read or write meeting export history`.

  With UTC `2026-10-02T10:30:00Z` and operation `benchmark-op-1`, assert the exact payload: operation ID `benchmark-op-1`, session ID `benchmark`, `ExportFormat.json`, filename `Loquiris-benchmark-20261002-103000.json`, MIME `application/json`, one document key `benchmark-report.json`, `includeAudio: false`, `allowSegmentFallback: false`, empty segment/diagnostic lists, and no repository dependency.

- [ ] **Step 6: Run exporter tests and verify RED**

  Run: `flutter test test/features/export_backup/local_benchmark_report_exporter_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: compilation fails because the feature boundary/provider and local implementation do not exist.

- [ ] **Step 7: Implement the feature boundary and SAF adapter**

  Define:

  ```dart
  abstract interface class BenchmarkReportExporter {
    Future<Result<ExportReceipt, ExportFailure>> export({
      required PerformanceBenchmarkReport report,
      required String operationId,
      required DateTime createdAtUtc,
    });
  }
  ```

  Add a provider that throws until bootstrap overrides it. `LocalBenchmarkReportExporter` calls the encoder first, returns encoding failure without calling the gateway, formats the exact UTC filename, and sends the exact payload from Step 5. It does not depend on `SessionRepository`, `ExportRecordRepository`, `LocalExportService`, or a database.

- [ ] **Step 8: Share one gateway in bootstrap without changing the unavailable runner**

  Construct one `MethodChannelExportDestinationGateway` before the override list and pass that same instance to both `LocalExportService` and `LocalBenchmarkReportExporter`. Add the benchmark exporter provider override and extend the bootstrap test to assert `LocalBenchmarkReportExporter` is installed. Do not export during bootstrap and do not alter the existing meeting export/history behavior.

- [ ] **Step 9: Run focused tests and verify GREEN**

  Run: `dart format lib/features/models_performance/application/benchmark_report_json_encoder.dart lib/features/models_performance/application/benchmark_report_exporter.dart lib/features/export_backup/application/local_benchmark_report_exporter.dart lib/bootstrap/bootstrap.dart test/features/models_performance/benchmark_report_json_encoder_test.dart test/features/export_backup/local_benchmark_report_exporter_test.dart test/bootstrap/bootstrap_test.dart && flutter test test/features/models_performance/benchmark_report_json_encoder_test.dart test/features/export_backup/local_benchmark_report_exporter_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: deterministic JSON, fail-before-picker, exact SAF payload, cancellation/failure pass-through, and bootstrap installation tests pass.

- [ ] **Step 10: Review scope and commit Task 3**

  Stage only Task 3 files/hunks. Run staged diff checks and `gitnexus_detect_changes(scope: "staged")`, verify no meeting persistence or recording flow is unexpectedly affected, then commit:

  ```bash
  git commit -m "feat: export benchmark metrics locally"
  ```

### Task 4: Coalesced completed-state export action and localization

**Files:**
- Modify: `lib/features/models_performance/presentation/models_performance_controller.dart:48-210`
- Modify: `lib/features/models_performance/presentation/models_performance_screen.dart:1-137`
- Modify: `lib/features/models_performance/presentation/models_performance_screen_content.dart:111-194`
- Modify: `lib/l10n/app_en.arb:614-678`
- Modify: `lib/l10n/app_zh.arb:231-270`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Modify: `test/features/models_performance/models_performance_controller_test.dart`
- Modify: `test/features/models_performance/models_performance_screen_test.dart`
- Modify: `test/accessibility/models_performance_accessibility_test.dart`
- Modify: `test/localization/models_performance_localization_test.dart`

**Interfaces:**
- Consumes: Task 3 `benchmarkReportExporterProvider`, existing `clockProvider`, `Uuid.v4()`, completed report/recommendation, and `_BenchmarkAction`.
- Produces: completed state fields `isExporting`, `exportReceipt`, and `exportFailureCode`; `ModelsPerformanceController.exportReport()`; completed-only key `benchmark-export`; localized idle/busy/success/cancel/failure strings; and transient snackbar feedback.

- [ ] **Step 1: Run pre-edit impact analysis and warn before risky symbols**

  Run upstream impact, including tests, for `ModelsPerformanceCompleted`, `ModelsPerformanceController`, `ModelsPerformanceController.build`, `ModelsPerformanceScreen.build`, `_BenchmarkCompleted.build`, `_BenchmarkAction`, `AppLocalizations`, `AppLocalizationsEn`, and `AppLocalizationsZh`. Report direct callers, affected processes/modules, and risk. If any result is HIGH or CRITICAL, warn and wait before editing as required by repository policy.

- [ ] **Step 2: Write failing controller export tests**

  Add cases named `completed report exports with fresh uuid and fixed utc clock`, `duplicate export requests coalesce to one call`, `export outside completed state is ignored`, `success cancellation and failure retain exact report and recommendation`, `rerun clears prior export outcome`, and `disposed controller ignores late export completion`.

  Override the exporter, UUID factory, and `clockProvider`. Assert `createdAtUtc` is UTC, a second call while in flight is ignored, and the completed state's original `report`/`recommendation` remain equal and identical where applicable.

- [ ] **Step 3: Run controller tests and verify RED**

  Run: `flutter test test/features/models_performance/models_performance_controller_test.dart`

  Expected: compilation fails because completed export state and `exportReport()` do not exist.

- [ ] **Step 4: Implement coalesced export orchestration**

  Add an injectable provider:

  ```dart
  final benchmarkExportOperationIdProvider = Provider<String Function()>(
    (ref) => const Uuid().v4,
  );
  ```

  Extend `ModelsPerformanceCompleted` with immutable export outcome fields and `copyWithExport({bool? isExporting, ExportReceipt? receipt, String? failureCode, bool clearOutcome = false})`; the method always preserves the existing report and recommendation. `exportReport()` returns immediately unless state is completed and not exporting, marks only the export flag, calls the Task 3 boundary with the current report/UUID/UTC clock, checks `ref.mounted` and that the same report is still current, then records either receipt or stable failure code. Starting/rerunning a benchmark replaces the entire completed state and therefore clears export outcome.

- [ ] **Step 5: Write failing widget, accessibility, and localization tests**

  Add cases named `export action appears only for completed report`, `export action disables while in flight and duplicate taps write once`, `success cancellation and failure show localized feedback without changing recommendation`, `export action is a labeled 48 dp secondary control at 200 percent text`, and `benchmark export copy exists in English and Chinese`.

  Verify no export action in unavailable/ready/running/failed/cancelled states. Verify success mentions only the returned display filename, cancellation has its own neutral message, generic failure exposes no code/URI/exception, and the recommendation/evidence remain visible after every outcome.

- [ ] **Step 6: Run UI tests and verify RED**

  Run: `flutter test test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart`

  Expected: tests fail because the action and localization getters do not exist.

- [ ] **Step 7: Add localization keys and regenerate output**

  Add English and Chinese values for `benchmarkExportAction`, `benchmarkExportingAction`, `benchmarkExportSucceeded(fileName)`, `benchmarkExportCancelled`, and `benchmarkExportFailed`. Use one ICU string placeholder only for the privacy-safe returned filename. Run `flutter gen-l10n` and inspect the three generated files for only the intended getters.

- [ ] **Step 8: Implement the completed-only secondary action and feedback**

  Pass `controller.exportReport` only into `_BenchmarkCompleted`. Render `_BenchmarkAction(key: Key('benchmark-export'), outlined: true, sortOrder: 30)` after rerun, with its minimum interactive dimension raised from the existing 44 to 48 logical pixels for all benchmark actions. Disable it and show busy copy while exporting.

  In `ModelsPerformanceScreen.build`, listen only for changes to completed export receipt/failure and show one localized `SnackBar`; suppress repeated feedback on unrelated rebuilds. Map `export_cancelled` separately, use generic localized failure for every other code, and never interpolate a failure code or raw platform value.

- [ ] **Step 9: Run focused tests and verify GREEN**

  Run: `dart format lib/features/models_performance/presentation/models_performance_controller.dart lib/features/models_performance/presentation/models_performance_screen.dart lib/features/models_performance/presentation/models_performance_screen_content.dart test/features/models_performance/models_performance_controller_test.dart test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart && flutter test test/features/models_performance/models_performance_controller_test.dart test/features/models_performance/models_performance_screen_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart`

  Expected: coalescing, lifecycle races, visibility, feedback, 48 dp semantics, compact/large-text layout, and both locales pass.

- [ ] **Step 10: Review scope and commit Task 4**

  Stage only Task 4 hunks and generated localization changes. Run staged diff checks and `gitnexus_detect_changes(scope: "staged")`, verify no recording/settings flow is affected, then commit:

  ```bash
  git commit -m "feat: add benchmark report export action"
  ```

### Task 5: Full verification and OpenSpec completion

**Files:**
- Modify: `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md:100`

**Interfaces:**
- Consumes: the four independently committed deliverables above and the approved task 10.6 design.
- Produces: repository-wide verification evidence and the single OpenSpec checkbox change `- [ ] 10.6` to `- [x] 10.6`.

- [ ] **Step 1: Re-read the approved design and audit scope**

  Check every Goals, Non-goals, Error behavior, JSON allowlist, UI, Testing, and Implementation boundaries item against Tasks 1-4. Confirm production still reports runtime unavailable, the monitor is current-only, no database/history/schema/permission/dependency was added, and recording/audio/transcript code has no task 10.6 edit.

- [ ] **Step 2: Run all focused metric/export tests together**

  Run: `flutter test test/services/service_contracts_test.dart test/features/models_performance test/features/export_backup/local_benchmark_report_exporter_test.dart test/native/method_channel_thermal_and_performance_monitor_test.dart test/accessibility/models_performance_accessibility_test.dart test/localization/models_performance_localization_test.dart test/bootstrap/bootstrap_test.dart`

  Expected: all focused Dart/Flutter tests pass.

- [ ] **Step 3: Run Android JVM verification**

  Run: `./android/gradlew -p android testDebugUnitTest`

  Expected: all Android local unit tests pass, including the performance channel suite.

- [ ] **Step 4: Run formatting and static analysis**

  Run: `dart format --output=none --set-exit-if-changed lib test && flutter analyze --fatal-infos --fatal-warnings`

  Expected: formatter exits zero and analysis reports no issues.

- [ ] **Step 5: Run the complete Flutter suite**

  Run: `flutter test`

  Expected: the entire Flutter test suite passes with no skipped task 10.6 acceptance test.

- [ ] **Step 6: Validate repository/OpenSpec hygiene**

  Run: `git diff --check && openspec validate bootstrap-loquiris-offline-recorder --strict`

  Expected: no whitespace errors and strict OpenSpec validation succeeds.

- [ ] **Step 7: Run pre-edit impact for the task checklist, then mark only 10.6 complete**

  Run upstream impact for the tasks document/path; expect no code symbol and zero affected execution flows. Change exactly line 10.6 from unchecked to checked. Do not alter 10.7 or later tasks.

- [ ] **Step 8: Stage the checklist plus any narrowly required verification fix and detect changes**

  Stage only the 10.6 checklist hunk and any explicitly reviewed task 10.6 verification fix. Run `git diff --cached --check`, inspect `git diff --cached --name-status` and the full cached diff, then run `gitnexus_detect_changes(scope: "staged")` and verify affected symbols/processes are expected.

- [ ] **Step 9: Commit task completion**

  ```bash
  git commit -m "feat: complete benchmark metrics capture"
  ```

- [ ] **Step 10: Report final evidence**

  Report the five commit hashes, focused/Android/full-suite/analyzer/OpenSpec results, GitNexus affected flows and risk, and any device-only validation still deferred to task 11.5. Explicitly state that production benchmark execution remains unavailable until the real inference runtime is installed.
