# Benchmark Metrics and Local Export Design

**Date:** 2026-10-02
**OpenSpec task:** 10.6
**Status:** Approved for implementation planning

## Purpose

Implement a small, truthful measurement layer for the fixed first-run benchmark. The layer captures real Android process/resource observations before and after one benchmark run, combines them with inference-owned timing measurements, and lets the user export a privacy-safe JSON report to an explicitly selected local destination.

The real inference engine is not available until later OpenSpec work. Production therefore continues to report the benchmark runtime as unavailable. This task builds and tests the measurement and export path without fabricating production results.

## Goals

- Capture process CPU time, process PSS memory, thermal state, and optional device energy before and after one benchmark run.
- Retain runner-provided real-time factor, first-text latency, and maximum backlog for each measured mode.
- Produce versioned immutable metrics with explicit unavailable reason codes.
- Export one deterministic, privacy-safe JSON document through Android's user-selected Storage Access Framework destination.
- Keep benchmark failure, metric failure, recording, and canonical audio independent.
- Make the result directly usable by the future real benchmark runner without changing presentation logic.

## Non-goals

- Continuous background monitoring or a general performance daemon.
- Periodic sampling, charts, history, database persistence, or a metrics dashboard.
- Peak-memory claims based on high-frequency sampling.
- Application-exclusive energy attribution.
- Synthetic production measurements or a fake production recommendation.
- Implementing the inference engine, model integration, policy modes, or thermal degradation behavior owned by later tasks.

## Existing boundaries

The codebase already has:

- `ThermalAndPerformanceMonitor`, `DevicePerformanceSnapshot`, and a Riverpod provider, but no production Android implementation;
- `PerformanceBenchmarkReport` and mode measurements containing RTF and first-text latency;
- an unavailable production benchmark runner and deterministic fake runners for tests;
- an Android SAF export channel that can write small UTF-8 documents after explicit user confirmation.

The implementation extends these seams instead of introducing a parallel monitoring framework.

## Architecture

### Android snapshot reader

Add a versioned `com.loquiris/performance_metrics_v1` MethodChannel with one operation: `readSnapshot`.

The Android reader returns only:

- monotonic observation time in milliseconds;
- cumulative process CPU time in milliseconds from `Process.getElapsedCpuTime()`;
- current process PSS in bytes from `Debug.MemoryInfo.getTotalPss()`;
- the current Android thermal status mapped to the existing coarse `ThermalState` contract;
- optional remaining device energy in nanowatt-hours from `BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER`;
- whether the device is charging.

The read runs on a background executor. The channel reply returns on the Android UI thread. The channel never returns device identifiers, filesystem paths, exception text, or arbitrary platform maps.

PSS is a point-in-time sample. The resulting metric is named `maxSampledPssBytes`, meaning the greater of the start and end readings, not a claimed runtime peak.

### Dart snapshot contract

Extend `DevicePerformanceSnapshot` with validated immutable fields:

- `observedAtMonotonic`;
- `processCpuTime`;
- `processPssBytes`;
- `thermalState`;
- optional `remainingDeviceEnergyNanowattHours`;
- `isCharging`.

`ThermalAndPerformanceMonitor` is simplified to a single `current()` read. Continuous snapshot streaming is outside this task and will not be implemented speculatively. The production `MethodChannelThermalAndPerformanceMonitor` strictly validates the version, types, ranges, and optional fields and maps timeouts, missing plugins, platform failures, and malformed responses to stable `PerformanceUnavailable` codes.

### Before/after collector

`MetricsCapturingPerformanceBenchmarkRunner` decorates any available `PerformanceBenchmarkRunner`:

1. read a start snapshot;
2. invoke the delegate runner with the unchanged fixed benchmark definition;
3. forward progress and terminal failure events unchanged;
4. on successful completion, read an end snapshot;
5. attach collected resource metrics to a copied benchmark report;
6. never turn a successful benchmark into a failed benchmark solely because optional metrics were unavailable.

The decorator is not installed around the unavailable production runner. The future real runner will be wrapped at bootstrap when it is introduced.

The collector derives:

- elapsed wall time from monotonic timestamps;
- process CPU time delta;
- `maxSampledPssBytes` from the two samples;
- the more severe of the two thermal states;
- optional device energy used as `startRemaining - endRemaining`.

Energy is emitted only when both counters exist, both samples are discharging, time moves forward, and the remaining-energy counter does not increase. Otherwise the value is absent and a stable reason code explains why. The field is explicitly named `deviceEnergyUsedNanowattHours`; it is a device-level estimate, not Loquiris-exclusive consumption.

Negative deltas, decreasing process CPU time, invalid durations, and values outside the integer contract are rejected rather than clamped or guessed.

### Report model

Add optional immutable `BenchmarkResourceMetrics` to `PerformanceBenchmarkReport`:

- wall duration;
- process CPU time;
- maximum sampled PSS;
- worst observed thermal state;
- optional device energy used;
- stable unavailable reason codes.

Add optional `maximumBacklog` to `BenchmarkModeMeasurement`. RTF, first-text latency, and backlog remain owned by the inference runner because platform resource APIs cannot derive them. Missing runner metrics remain absent; no default numeric values are inserted.

Schema version 2 identifies reports containing the new resource-metric shape. The parser/validator accepts only supported versions and exact finite, non-negative values.

## Local JSON export

Add a `BenchmarkReportExporter` interface owned by the models/performance feature. Its production implementation lives beside the existing local export infrastructure and reuses `ExportDestinationGateway` for the actual SAF write.

The export is one small UTF-8 document named `benchmark-report.json` inside the existing generic document payload. It uses:

- MIME type `application/json`;
- a privacy-preserving default filename such as `Loquiris-benchmark-20261002-103000.json`;
- no audio or segment fallback;
- a generated operation identifier;
- a stable non-user identifier for the generic document request.

The benchmark export is not stored in the meeting export table because it has no meeting owner and does not need history. The screen shows one explicit export action only when a valid completed report exists. Success, picker cancellation, malformed report, and destination failure map to localized messages. The existing recording and benchmark result are never mutated.

### JSON allowlist

`BenchmarkReportJsonEncoder` is a pure Dart deterministic encoder. It writes only:

- report and policy schema versions;
- fixed benchmark ID, SHA-256, byte length, and media duration;
- engine, model, and configuration identifiers and versions;
- mode, measurement status, RTF, first-text latency, maximum backlog, and stable blocking reason codes;
- wall duration, process CPU time, sampled PSS, coarse thermal state, optional device energy used, and stable unavailable reason codes.

It never writes:

- audio or transcript content;
- meeting titles, speaker labels, or human names;
- private or external paths and URIs;
- Android ID, serial number, account information, or network information;
- exception messages or stack traces;
- raw platform maps.

Object keys and mode measurements use deterministic ordering so equal reports produce equal JSON bytes.

## Error behavior

- A start or end snapshot failure is represented by a stable metrics-unavailable reason and does not block benchmark completion.
- A benchmark runtime or engine failure is still the benchmark's terminal failure and is not hidden by metric collection.
- Unsupported energy measurement does not make CPU, memory, or thermal measurements unavailable.
- Malformed Android channel values fail closed with `performance_metrics_channel_invalid`.
- Export encoding rejects invalid report values before opening the system destination picker.
- Export cancellation and destination errors use stable existing export failure semantics and never expose destination URIs.
- No metrics failure can affect microphone capture, canonical recording, or stable transcript revisions.

## User interface

The completed benchmark state keeps its existing recommendation and evidence. It adds one secondary 48 dp action labelled through localization: export benchmark result.

The screen does not add charts, live gauges, monitoring controls, history, or a separate metrics page. Export status is limited to concise localized success or failure feedback, and the result remains advisory.

## Testing

### Dart tests

- strict valid and invalid MethodChannel response decoding;
- timeout, missing plugin, and platform failure mapping;
- before/after CPU, wall-time, PSS, thermal, and energy aggregation;
- charging, unsupported, increasing, and missing energy counters;
- partial snapshot failure without losing a successful benchmark report;
- invalid negative, reversed-time, NaN, and infinite values;
- backlog validation and report equality;
- deterministic JSON and the privacy allowlist;
- export success, picker cancellation, malformed report, and destination failure;
- production unavailable runner never reads the monitor or creates a report;
- widget action visibility, semantics, and localized feedback.

### Android JVM tests

- channel request/version validation;
- thermal-status mapping;
- PSS kilobyte-to-byte conversion;
- optional energy and charging-state encoding;
- background execution and structured failure responses.

### Repository verification

- focused Flutter and Android JVM tests;
- formatting and strict Flutter analysis;
- complete Flutter test suite;
- `git diff --check`;
- strict OpenSpec validation;
- GitNexus staged-scope detection before each commit.

## Implementation boundaries

Implementation should be split into reviewable commits:

1. domain report and collector semantics;
2. Android snapshot reader and Dart MethodChannel adapter;
3. deterministic JSON exporter and SAF integration;
4. completed-screen export action and localization;
5. full verification and OpenSpec task completion.

Each shared symbol receives GitNexus impact analysis before editing. The existing dirty working tree is preserved, and each commit stages only task 10.6 changes.
