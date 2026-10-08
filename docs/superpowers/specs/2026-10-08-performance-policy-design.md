# Performance Policy and Explicit Degradation Design

**Date:** 2026-10-08

**OpenSpec task:** `bootstrap-loquiris-offline-recorder` 10.7

**Status:** Approved for implementation planning

## Context

Loquiris already defines five `PerformanceMode` values and can derive a
privacy-safe recommendation from a fixed-audio benchmark. It does not yet have
runtime policy objects that explain what each mode permits, a deterministic
decision model for recording-first degradation, or a complete user-visible
description of those protections.

The production inference runtime is intentionally unavailable until the
`whisper.cpp` work in phase 11 passes its evidence gates. Task 10.7 therefore
establishes the contract that a future runtime will consume without pretending
that AI execution is currently installed or selectable.

## Goals

- Define immutable policies for high-quality, balanced, power-saving,
  recording-only, and post-session operation.
- Express quality intent, execution timing, resource intent, supported
  concurrency behavior, and safe fallback paths separately from model or
  platform implementation details.
- Produce deterministic decisions for thermal pressure, backlog, memory
  pressure, low battery, unavailable acceleration, unsupported modes, and
  engine failure.
- Preserve canonical recording under every AI degradation decision.
- Give every automatic degradation stable privacy-safe reason codes and an
  actionable recovery path suitable for localized presentation.
- Explain all five modes and their recording protections on the existing
  Models & Performance screen, including when the inference runtime is absent.
- Leave a narrow contract that phase 11 and phase 12 orchestration can consume
  without changing the meaning of a mode.

## Non-goals

- Installing or invoking a real transcription engine.
- Persisting a selected performance mode in Drift, recording defaults, or a
  meeting record.
- Adding a mode selector that appears to control an unavailable runtime.
- Changing `TranscriptionEngine`, Android channels, native recording, model
  manifests, benchmark thresholds, or benchmark export JSON.
- Implementing live thermal polling, background monitoring, or stateful
  inference orchestration.
- Automatically upgrading a meeting back to a more aggressive mode.
- Defining model-specific thread counts, window sizes, or memory limits before
  target-device evidence exists.

## Chosen approach

Implement a feature-owned, pure-Dart policy catalog and decision engine in the
models/performance domain. Add a read-only mode and degradation overview to the
existing Models & Performance screen. Do not add persistence or runtime wiring.

This is preferred over persisting a setting now because a saved selection
would not yet affect production behavior. It is also preferred over deferring
all policy work to phase 11 because that would entangle mode semantics with one
engine implementation and make recording-first behavior harder to test in
isolation.

## Domain model

### Performance mode policy

`PerformanceModePolicy` is an immutable value describing one existing
`PerformanceMode`. Each policy exposes:

- the mode;
- its allowed execution timing;
- its quality intent;
- its resource intent;
- whether live inference may run;
- whether post-session inference may run;
- whether inference is disabled;
- its ordered safe fallback modes.

The catalog contains exactly one policy for every `PerformanceMode` value. It
rejects duplicates, missing modes, self-fallbacks, fallback cycles, and a
fallback that increases execution aggressiveness.

### Execution timing and AI disposition

Timing and runtime disposition remain separate from the quality mode:

- `liveOrPostSession`: live work is allowed when measured support exists, but
  work may be deferred.
- `postSessionOnly`: inference must not run during capture.
- `disabled`: no inference work is allowed.

A decision reports one of these AI dispositions:

- `running`: live inference may continue under its normal budget;
- `throttled`: live inference may continue with reduced concurrency;
- `paused`: live inference must stop temporarily while recording continues;
- `deferred`: work is queued for post-session processing;
- `disabled`: no AI work is scheduled.

These values describe policy intent, not an engine-specific command.

### Pressure input

`PerformancePolicyInput` contains only value data:

- requested mode;
- current effective mode;
- current processing timing;
- modes supported by verified local manifests and recorded evidence;
- current thermal pressure;
- backlog status;
- memory pressure status;
- low-power status;
- acceleration availability and whether CPU fallback is usable;
- engine availability.

The input carries no exception, device identifier, account information, path,
URI, transcript, audio, or raw platform map.

### Decision output

`PerformancePolicyDecision` contains:

- requested and effective modes;
- effective timing and AI disposition;
- `continueRecording`, which is always true for every valid policy decision;
- whether post-session work remains queued;
- all applicable stable reason codes in deterministic priority order;
- the primary reason code;
- one typed recovery action.

The recovery action is a domain value such as cooling the device, continuing
with post-session processing, retrying the engine later, selecting a supported
mode, or continuing with recording only. Presentation maps it to localized
copy; the domain does not contain display strings.

## Mode semantics

| Mode | Timing | Intent | Safe fallback |
|---|---|---|---|
| High quality | Post-session only | Highest validated accuracy with a larger resource allowance | Balanced, then post-session, then recording-only |
| Balanced | Live or post-session | Default accuracy/resource balance | Power-saving, then post-session, then recording-only |
| Power saving | Live or post-session | Reduced concurrency, smaller model, or conservative budget | Post-session, then recording-only |
| Post-session | Post-session only | Reserve capture-time resources and analyze after recording | Recording-only |
| Recording-only | Disabled | Preserve audio without AI work | None |

Changing quality mode must never advance processing timing. For example,
degrading high-quality to balanced retains post-session timing; it cannot
silently activate live inference.

## Degradation rules

The decision engine is pure and evaluates simultaneous pressures in this fixed
order:

1. engine failure or an unsupported mode;
2. severe thermal pressure or critical memory pressure;
3. sustained backlog beyond the supported bound;
4. low-power policy or moderate thermal pressure;
5. unavailable acceleration.

All applicable reasons are retained, while the highest-priority reason selects
the recovery action and final disposition.

### Engine failure and unsupported modes

An unavailable engine disables live AI and preserves recording. If later
post-session retry is meaningful, the decision queues that work and explains
the retry path; otherwise it falls back to recording-only. An unsupported
requested mode selects the first supported safe fallback. If none exists,
recording-only is used.

### Thermal and memory pressure

Moderate thermal pressure reduces AI concurrency without changing the visible
quality mode. Severe thermal pressure or critical memory pressure pauses live
AI immediately, continues recording, and retains post-session work. A mode
that was already post-session does not start any capture-time work.

### Backlog

Sustained backlog beyond the mode's supported bound defers live inference to
post-session processing. It never drops canonical audio and never attempts to
re-enter live mode automatically during that meeting.

### Low power

Low-power policy first selects a supported power-saving budget. When no safe
live power-saving configuration exists, work is deferred to post-session. The
decision remains advisory to the future orchestrator and cannot stop capture.

### Acceleration

Optional acceleration failure uses CPU fallback when that fallback has passed
the required mode gates. Acceleration unavailability by itself does not imply
recording-only. When the current mode cannot run safely on CPU, the policy uses
the first supported safe fallback.

### Monotonic safety

Within one meeting, an automatic decision may retain or reduce the current
resource/quality position but may not upgrade it. Temporary throttling may be
lifted by a future orchestrator after pressure clears, but a switch from live
to post-session is terminal for that meeting unless the user starts a new run.

## Stable reasons and privacy

Reason codes use a closed allowlist owned by the policy feature. The initial
set covers unsupported mode, engine unavailable, thermal moderation, severe
thermal pressure, memory pressure, backlog, low power, acceleration fallback,
and no eligible AI mode. Codes are deterministic identifiers, not arbitrary
platform text.

Unknown or contradictory input returns a typed invalid-policy result rather
than guessing. An unknown pressure that still permits a valid conservative
decision defers to post-session; if that is unsupported, it selects
recording-only. No raw error or private value is included in equality,
diagnostics, or UI text.

## User experience

The Models & Performance screen always includes a read-only operating-modes
section beneath the benchmark content. It lists all five modes, their timing,
their recording-first behavior, and their normal fallback. The section:

- highlights the recommended mode after a valid benchmark;
- labels unsupported or unavailable modes honestly;
- states that modes cannot be selected until a compatible local runtime and
  model have passed their gates;
- explains moderate thermal throttling, severe thermal pause, backlog deferral,
  and recording-only fallback;
- never claims that a mode is currently active.

The content uses headings, text, icons, and semantic labels rather than color
alone. Every mode and degradation explanation remains readable with large text,
TalkBack, narrow widths, landscape constraints, and both supported locales.

Phase 12 can later render a live degradation banner by mapping
`PerformancePolicyDecision.primaryReasonCode` and its recovery action through
the same localized vocabulary. Task 10.7 does not add an unused live banner.

## Files and boundaries

Expected implementation scope:

- add a feature-owned performance policy domain file;
- add exhaustive pure-domain tests;
- extend the existing Models & Performance screen and its part file;
- add English and simplified-Chinese ARB entries and regenerate localization;
- extend widget, accessibility, localization, and constrained-layout tests;
- mark only OpenSpec task 10.7 complete after repository-wide verification.

The implementation must not edit Drift schema files, native Android sources,
recording defaults, meeting entities, the `TranscriptionEngine` interface,
model manifest semantics, or the unavailable production benchmark runner.
Existing uncommitted work in those areas remains outside this task.

## Verification strategy

Implementation follows test-driven development.

Domain tests cover:

- one complete, immutable policy per enum value;
- catalog validation and deterministic ordering;
- the exact timing and fallback semantics of all five modes;
- unsupported modes and empty support sets;
- every individual pressure;
- simultaneous pressure priority and retention of all reasons;
- CPU fallback behavior;
- post-session timing preservation;
- monotonic degradation and rejection of automatic upgrades;
- `continueRecording == true` for every valid decision;
- stable reason-code allowlisting and privacy-safe values.

Presentation tests cover:

- all five mode explanations in ready, unavailable, and completed benchmark
  states;
- recommendation highlighting without automatic selection;
- explicit unavailable-runtime copy;
- degradation behavior and recovery explanations;
- English and simplified-Chinese strings;
- TalkBack semantics, large text, and constrained-width overflow.

Final verification includes focused tests, formatting, strict analysis, the
complete Flutter suite, strict OpenSpec validation, staged-diff inspection, and
GitNexus change detection before each commit.

## Delivery sequence

1. Add failing policy catalog and decision tests.
2. Implement the pure domain model and decision engine.
3. Add failing mode-overview, localization, accessibility, and layout tests.
4. Implement the read-only Models & Performance presentation.
5. Run repository-wide verification and mark only task 10.7 complete.

This sequence creates no runtime or persistence compatibility promise beyond
the approved policy contract.
