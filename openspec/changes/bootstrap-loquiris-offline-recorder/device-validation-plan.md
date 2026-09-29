# Target-Device and Performance Validation Plan

## 1. Purpose and Claim Boundary

The plan determines which independently labeled capabilities may ship:

- **Recorder MVP**: reliable local capture, recovery, session management, export, privacy, and accessibility.
- **Offline Transcription Preview**: a specific model/mode passes accuracy and device-performance gates.
- **Language Identification**: a specific classifier/configuration passes its held-out gate.
- **Speaker Diarization Experimental/Production**: a specific model set remains experimental until its DER and stability gates pass.

Passing one device proves only that exact SKU, firmware, battery condition, configuration, and environment. It does not establish general Redmi, Xiaomi, HyperOS, 4 GB, 6 GB, MediaTek, or “all budget phone” compatibility.

## 2. Device Matrix

### Required release-gate device

- Connected mainland-China Redmi Note 10 Pro, model `M2104K10AC`, device codename `chopin`, observed 6 GB RAM + 128 GB storage class
- Observed platform identifier `mt6893`; formal reports use the device-reported identifier rather than inferring compatibility from a marketed SoC family
- Current intake fingerprint: Android 13/API 33, MIUI 14 `V14.0.8.0.TKPCNXM`, 2023-11-01 security patch, build tag `release-keys`, verified-boot state `green`; bootloader lock state remains to be recorded independently
- Formal configuration: memory extension disabled
- Reality regression: factory-default memory extension and battery policy

At intake, record exact model identifier and codename, SoC/platform, physical RAM, storage, Android release/API, OEM system and MIUI build, security patch, verified-boot/bootloader state, battery health/cycles where available, available storage, and installed test build hash.

### Optional non-gating devices

- Low tier: Redmi 13R 5G 4 GB+128 GB if an actual unit is available; availability is not assumed.
- Higher-performance comparison: an already-owned REDMI Turbo 4, Xiaomi 15, or similar device.

Optional results quantify scaling only and can never replace a failed required-device gate.

## 3. Controlled Environment

- Ambient temperature: 22–26°C, recorded at start and end.
- Required runs: off charger, battery sufficiently charged to finish without entering unintended emergency shutdown.
- Memory extension: disabled for formal gate; enabled/default in a separate regression.
- Background work: unrelated user applications closed for formal performance comparison.
- OEM battery policy: formal controlled setting recorded; separate factory-default regression required.
- Audio playback: fixed room, fixed calibrated speaker, fixed phone position/orientation/distance, fixed playback level, and documented HVAC/fan state.
- Do not use flagship results or direct-digital input as a substitute for the room/microphone gate.

## 4. Test Material

### Quality sets

Maintain held-out, human-verified, legally redistributable or explicitly authorized sets containing at least:

- 30 minutes Chinese across speakers, genders, speeds, and representative accents.
- 30 minutes English across speakers, genders, speeds, and representative accents.
- 30 minutes Chinese-English mixed speech with labeled language spans and preserved named terms.
- Two-, three-, four-, five-, and six-speaker meeting samples.
- Quiet room, normal meeting-table distance, air-conditioner/fan noise, far-field speech, and light overlap variants.

Quality material used for acceptance must not be used to tune model parameters. Store audio/label hashes, provenance, consent/license, recording/playback instructions, and annotation version.

### Stability sets

Use authorized long-form material sufficient for repeated four-hour playback. Include silence, ordinary turns, long turns, language changes, noise intervals, and controlled overlap. The waveform must not contain hidden network-dependent assets or personal meetings without consent.

### Digital/model-isolation set

Run a separate direct/deterministic PCM test through the engine to separate recognition/runtime behavior from microphone, speaker, and room acoustics. Report it alongside, never instead of, acoustic capture.

## 5. Metric Definitions

- **First-text latency**: elapsed monotonic time from qualifying speech availability to first displayed non-empty draft; report p50, p95, and maximum.
- **RTF**: wall processing seconds divided by processed audio seconds; report overall and thermal steady-state windows.
- **Chinese quality**: CER, raw and normalized.
- **English quality**: WER, raw and normalized.
- **Mixed quality**: committed tokenizer and MER/token error rate, raw and normalized.
- **Language identification**: per-class precision/recall/confusion plus principal Chinese/English accuracy; mixed/uncertain reported separately.
- **Diarization**: DER and JER, with scoring collar and overlap policy committed in the evaluation script.
- **Memory**: peak and time-series PSS/RSS for recorder, UI, and inference processes.
- **CPU**: process/thread utilization and selected thread configuration.
- **Thermal**: Android thermal status transitions plus available sensor temperatures; temperature alone is not the cross-device trigger.
- **Energy**: start/end percentage, estimated/observed mAh where available, battery health, charging state, and percentage per hour.
- **UI**: frame timing, severe-jank percentage, and monotonic command-to-visible-feedback latency.
- **Recording integrity**: segment count, missing/corrupt segments, timestamp discontinuities, silence anomalies, manifest/file reconciliation, media-duration error, and maximum crash loss.

Normalization may ignore punctuation, English case, and equivalent number formatting but must not delete lexical errors. Evaluation scripts and normalization rules are versioned with results.

## 6. Acceptance Thresholds

### Recorder MVP

- Three independent four-hour recording-only runs pass.
- One four-hour stress flow passes.
- Previously committed audio loss: zero.
- Maximum loss after simulated abrupt failure: five seconds.
- Final media-duration error: at most one second after accounting for intentional pauses.
- Unexplained corrupt segment or audio gap: zero.
- Recording-only battery target: at most 5% per hour under the controlled configuration.
- Pause/stop command feedback: within 500 ms.
- Severe-jank frame ratio on the critical recording UI: below 1%.

### Offline Transcription Preview

- Balanced live: first text p95 at most 5 seconds and sustained RTF at most 0.8.
- Power-saving live: first text at most 12 seconds and sustained RTF at most 1.2.
- Balanced post-session: RTF at most 1.0.
- High-quality post-session: RTF at most 2.0.
- Live balanced battery target: at most 12% per hour.
- No recording integrity regression, recorder process starvation, unrecoverable engine crash, or four-hour thermal failure.
- Initial quality targets: normalized Chinese CER at most 18%, English WER at most 20%, and mixed MER/token error rate at most 25% on the defined sets.

If any required live threshold fails, near-real-time is withheld or explicitly experimental; it is not replaced with an unsuitable model solely to preserve a feature checkbox.

### Language identification

- Principal Chinese/English accuracy at least 90% on the held-out labeled segments.
- Low-confidence samples may be uncertain instead of forced.
- Mixed spans must retain original text and be reported separately.

### Speaker diarization

- DER at most 25% on the defined two-to-six-speaker non-overlap acceptance set.
- Noise, far-field, and overlap results reported independently.
- Four-hour post-session job completes without memory kill, unrecoverable failure, or unsafe thermal behavior.
- Identity drift and transcript-alignment errors included in qualitative review.

## 7. Required Runs

### Recorder-only repeatability

Run three four-hour meetings. Across the set, include screen lock, background operation, recent-task dismissal, bookmarks, several user pauses, and normal stop/finalization. At least one run starts under factory-default OEM policy.

### Four-hour stress flow

Script and timestamp:

1. Start after permission and storage preflight.
2. Lock screen and keep recording.
3. Background/dismiss the Flutter task.
4. Pause and resume multiple times.
5. Add bookmarks from application and notification.
6. Trigger transient audio-focus loss.
7. Trigger a call or equivalent validated call-interruption procedure; confirm post-call resume.
8. Exercise low-battery policy without allowing device shutdown.
9. Exercise a controlled low-storage threshold and validate warning/safe handling.
10. Force-kill the relevant non-recorder and recorder processes at planned points in separate subruns; validate recovery and maximum loss.
11. Complete or recover the meeting, play it end-to-end or run integrity scanning, and export it.

### Near-real-time repeatability

If proposed for release, run two four-hour live-transcription meetings with the selected production model/mode. Capture cold-start and thermal steady-state metrics, backlog, draft gaps, engine fallback, frame timing, and recording integrity.

### Post-session matrix

Run each proposed production model with pinned threads/parameters on Chinese, English, mixed, noise, distance, and long-form material. Run the diarization model on two-to-six-speaker sets with automatic and guided speaker counts.

## 8. Failure Injection

- Revoke/deny microphone and notification permissions at relevant lifecycle points.
- Force-stop Flutter UI while preserving the service, and kill the native recorder during an active durable unit.
- Truncate/corrupt the active unit while preserving older committed units.
- Fail database writes, manifest rename/fsync, M4A muxing, export destination writes, and backup restore mid-transaction.
- Stall and crash the inference process; fill its queue and exhaust its configured memory budget.
- Trigger Android thermal MODERATE and SEVERE policies through controlled test hooks before relying on naturally occurring heat.
- Cross low-space warning and stop thresholds without deleting user data.
- Reboot after committed segments exist, if the chosen Android test setup permits repeatable automation.

Production code must not depend on test hooks being present in release builds.

## 9. Evidence Package

Each run produces:

- Build commit/hash, signed artifact hash, model hashes, configuration, and feature flags.
- Device fingerprint and controlled-environment record.
- Script/checklist with monotonic event timestamps.
- Privacy-safe machine metrics and state transitions.
- Segment/manifest integrity report and audio-duration/gap results.
- Accuracy scorer inputs by hash, scorer version, raw and normalized outputs.
- Known deviations, failures, manual observations, and rerun rationale.
- Independent pass/fail for Recorder MVP, Transcription Preview, language identification, and diarization.

The final report must state unverified assumptions and must not convert an absent result into a pass.

## 10. Stop and Downgrade Rules

- Stop AI evaluation immediately if it threatens authoritative recording; investigate under a recorder-safe harness.
- If the native storage spike cannot meet five-second crash loss, do not begin production recorder implementation with that design.
- If no compliant model meets live gates, ship post-session or recorder-only behavior.
- If a model lacks acceptable fixed redistribution terms, remove it from release consideration regardless of accuracy.
- If the complete production model set exceeds size budgets, remove the lowest-value model; do not introduce hidden downloads.
- If diarization misses DER/stability gates, retain manual speaker correction and label automatic analysis experimental.
