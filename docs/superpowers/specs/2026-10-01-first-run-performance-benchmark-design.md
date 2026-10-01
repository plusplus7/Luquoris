# First-run performance benchmark and recommendation UI

**Status:** Approved conversational design; awaiting written-spec review

**Date:** 2026-10-01

**OpenSpec task:** `bootstrap-loquiris-offline-recorder` 10.5

## Context

Loquiris already bundles an immutable 45-second Mandarin/English benchmark
asset and exposes a `/settings/models-performance` route, but that route is a
placeholder. The repository has model-integrity and thermal-monitoring seams,
while the real transcription runtime, model, and metric capture arrive in later
tasks 11.1, 11.2, and 10.6. This task must therefore establish the benchmark
flow without inventing device measurements or coupling the UI to an unfinished
engine.

The feature is a short, explicit, on-device check. It offers a recommendation;
it does not prove four-hour stability, activate the microphone, change a
setting, or enable an AI capability.

Here, “first-run” means the check is offered before the user relies on an AI
mode. It does not mean automatic execution or a forced cold-launch onboarding
screen. This task deliberately adds no durable “has run” flag.

## Goals

- Replace the models/performance placeholder with a complete, localized screen.
- Run only after an explicit user action against the fixed bundled benchmark.
- Keep execution behind an injectable boundary so the real engine can be wired
  later without changing presentation or recommendation semantics.
- Represent availability, progress, completion, cancellation, and recoverable
  failure as explicit typed states.
- Recommend the best eligible conservative mode and explain the evidence and
  limitations.
- Make it impossible for this feature flow to call the recording service.
- Remain usable at 320 logical pixels and 200% text scaling.

## Non-goals

- Integrating `whisper.cpp` or importing a production model.
- Implementing CPU, memory, energy, thermal, backlog, or export capture; task
  10.6 owns those implementations.
- Persisting benchmark results, first-run completion, or a selected mode.
- Automatically applying a recommendation or changing recording defaults.
- Claiming long-run stability, release eligibility, or transcription accuracy.
- Implementing runtime behavior for the five performance modes; task 10.7 owns
  those policy objects.

## Selected approach

Use a contract-first feature flow. Domain values, an injected runner, a pure
recommendation policy, one Riverpod controller, and the real screen are built
now. The production composition root installs an explicitly unavailable runner
until later tasks supply a measured implementation. Tests install controlled
runners and exercise the full state machine without presenting their results as
production evidence.

Two alternatives were rejected:

- Deferring the whole screen until the engine exists would reorder the approved
  OpenSpec plan and leave the user contract undefined.
- A synthetic CPU workload would run today but would not measure the intended
  transcription pipeline and could produce a misleading recommendation.

## Architecture

The feature remains under `lib/features/models_performance/` and follows the
existing feature-first layers.

### Domain

The domain layer defines immutable values with value equality:

- `BenchmarkDefinition` identifies the fixed asset by manifest ID, SHA-256,
  byte length, and 45-second media duration.
- `BenchmarkAvailability` is either available or unavailable with a stable
  reason code.
- `BenchmarkModeMeasurement` associates a `PerformanceMode` with measured,
  failed, or unmeasured evidence. It may contain only metrics actually observed
  by the runner; absent required evidence never counts as a pass.
- `PerformanceBenchmarkReport` identifies its schema and recommendation-policy
  versions, fixed asset, engine, model, configuration, mode measurements, and
  privacy-safe blocking reason codes.
- `BenchmarkRecommendation` contains the recommended `PerformanceMode`, the
  evidence used, localized-reason keys, and the short-check limitation flag.
- `BenchmarkFailure` is a sealed typed failure with stable codes for unavailable
  runtime, invalid asset, engine failure, invalid/non-monotonic output, and
  cancellation.

No type stores transcript text, private paths, raw exceptions, or microphone
data.

### Execution boundary

`PerformanceBenchmarkRunner` is an injected interface. It exposes availability
and a single-run event stream containing monotonic progress followed by exactly
one typed completion or failure. Cancelling the stream subscription must stop
or abandon the underlying work and must not emit a late completion to the
disposed controller.

The runner contract requires the supplied `BenchmarkDefinition` to be used and
forbids audio capture. The production implementation for this task is
`UnavailablePerformanceBenchmarkRunner`, with a stable
`benchmark_runtime_not_installed` reason. Later engine and metric tasks replace
that provider override rather than editing the UI.

### Recommendation policy

`BenchmarkRecommendationPolicy` is a total, side-effect-free function over a
completed report. Policy version 1 applies the thresholds already approved in
the OpenSpec evidence plan:

| Mode | Required short-check evidence |
| --- | --- |
| Balanced live | sustained RTF ≤ 0.8 and first-text latency ≤ 5 seconds |
| Power-saving live | sustained RTF ≤ 1.2 and first-text latency ≤ 12 seconds |
| Balanced post-session | RTF ≤ 1.0 |
| Recording only | safe fallback when no measured AI mode is eligible |

An AI mode also fails eligibility when its measurement contains an engine,
memory, thermal, backlog, integrity, or other blocking reason. Missing required
metrics produce `unmeasured`, not a pass. The policy recommends the first
eligible mode in this order: balanced, power saving, post-session, then
recording only. High quality remains visible as a supported concept but is not
automatically recommended by this short check because its RTF allowance and
accuracy trade-off are post-session choices requiring broader evidence.

An unavailable runner produces no recommendation. A completed run with no
eligible AI mode recommends recording only and explains why.

### Presentation controller

`ModelsPerformanceController` is the only mutable state owner. Its immutable
state is exactly one of unavailable, ready, running, completed, failed, or
cancelled. It:

- resolves runner availability on build;
- starts only from ready, completed, failed, or cancelled;
- ignores duplicate start requests while running;
- rejects regressing or out-of-range progress as typed invalid output;
- applies the pure recommendation policy only to a valid completed report;
- cancels its subscription on explicit cancellation or provider disposal;
- clears stale report and recommendation data before a retry; and
- never reads or writes recording defaults, persistence, or capture services.

The provider is auto-disposed with the route. Leaving the page cancels the
current run and discards all transient state.

### Screen

`ModelsPerformanceScreen` replaces the current placeholder at the existing
route. It is a dumb `ConsumerWidget` backed by small const widget classes. The
screen renders:

- **Unavailable:** why the local runtime cannot run the check; no fake start
  action.
- **Ready:** fixed 45-second audio, offline execution, no microphone use, and an
  explicit start action.
- **Running:** accessible progress, disabled repeat start, and cancel.
- **Completed:** recommended mode, pass/fail/unmeasured reasons, available
  metrics, the short-check limitation, and rerun.
- **Failed:** localized privacy-safe failure and retry, with no stale result.
- **Cancelled:** a neutral acknowledgement followed by the normal start action.

The completed state never contains an automatic apply button. Manual mode
selection remains independent and is implemented with the mode policies in
task 10.7.

## Data flow

1. The settings route constructs the screen and auto-disposed controller.
2. The controller asks the injected runner for availability.
3. The user explicitly starts the check.
4. The controller supplies the immutable benchmark definition to the runner.
5. Runner progress events update the live UI; repeat starts remain disabled.
6. A typed report is validated and passed to the pure recommendation policy.
7. The UI displays the recommendation, evidence, and limitations without
   writing settings or storage.
8. Retry starts from a clean transient state; navigation away cancels the run.

No edge in this flow reaches `AudioCaptureService`, recording permissions,
`SessionRepository`, or a database table.

## Error and privacy handling

All expected failures cross the boundary as `Result`/sealed failure values or
typed terminal events. Localized UI strings are selected from stable codes.
Unexpected implementation exceptions are converted at the runner boundary;
their text and stack traces are not retained in UI state.

The feature does not save audio, decoded text, result reports, or device
identifiers. It does not request a permission. The bundled asset is the only
permitted audio input. Task 10.6 may add a separately reviewed, privacy-safe
local export, but this task exposes no export action.

## Accessibility, localization, and adaptive layout

- Every user-visible string is generated from English and Chinese ARB entries.
- Layout uses directional padding and a vertically scrollable content region.
- The main content is width-bounded on wide screens but never assumes a device
  class.
- Progress and terminal results use semantic live regions without announcing
  every minor percentage change.
- Buttons retain descriptive labels and adequate targets; icons are decorative
  unless they add meaning.
- Pass, fail, unmeasured, and recommended states use text and iconography in
  addition to color.
- The screen must render without overflow at 320 logical pixels and 200% text
  scaling in both supported locales.

## Testing

### Pure policy tests

- Every threshold boundary, including equality, selects the expected mode.
- Missing evidence remains unmeasured.
- A blocking reason prevents eligibility even when numeric metrics pass.
- High quality is never automatically selected.
- No eligible AI mode falls back to recording only.

### Controller tests

- Unavailable, ready, running, completed, failed, cancelled, retry, and dispose
  transitions.
- Duplicate starts invoke the runner once.
- Regressing progress and multiple terminal events are rejected.
- Cancellation prevents late events from changing state.
- Retrying clears stale reports and recommendations.

### Widget and integration tests

- All states render in English and Chinese.
- The explicit start, cancel, retry, and rerun actions drive the controller.
- The route renders `ModelsPerformanceScreen` instead of `AppRouteScreen`.
- Narrow-width, 200%-text, and semantics tests cover overflow, live regions,
  labels, and non-color status cues.
- A recorder fake that throws on every member proves the benchmark acceptance
  flow never touches the capture boundary.

The implementation gate is `dart format`, strict `flutter analyze`, targeted
tests, the complete Flutter test suite, `git diff --check`, and strict OpenSpec
validation.

## Anticipated change surface

- New benchmark domain, runner, recommendation policy, controller, and screen
  files under `lib/features/models_performance/`.
- A benchmark runner provider and production unavailable override.
- The existing models/performance route builder.
- English and Chinese ARB entries plus generated localization output.
- Focused domain, controller, widget, routing, localization, and accessibility
  tests.
- OpenSpec task 10.5 is checked only after every gate passes.

No database schema, Android permission, audio-capture implementation, model
artifact, or recording-default type is changed.

## Acceptance criteria

1. Opening models/performance never throws when the engine is absent and
   truthfully explains unavailability.
2. With an available injected runner, only an explicit user action starts one
   run over the fixed 45-second definition.
3. No benchmark path calls microphone or recording services.
4. A valid report yields the deterministic version-1 recommendation and a
   visible explanation without changing settings.
5. Invalid, failed, cancelled, and unmeasured outcomes never become a positive
   recommendation.
6. The page is localized, accessible, adaptive, retryable, and test-covered.
7. The feature makes no long-duration stability or release-readiness claim.

## Follow-on integration

- Task 10.6 supplies measured metrics and privacy-safe local export through the
  report contract.
- Task 10.7 supplies the selectable mode behavior and explicit degradation
  policies.
- Tasks 11.1 and 11.2 install the real transcription engine and bundled model,
  replacing the unavailable runner.
- Tasks 11.5 and 15.x produce target-device and long-duration evidence; the
  short recommendation never substitutes for those gates.
