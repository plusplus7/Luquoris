## 1. Governance and Baseline

- [x] 1.1 Record the read-only Fairy reuse map and prohibited sleep-domain/branding/Git-history boundaries in project documentation
- [x] 1.2 Adopt Apache-2.0 for Loquiris code and add contribution, security, privacy, and model-acceptance policies
- [x] 1.3 Create the initial `THIRD_PARTY_NOTICES` generation and review workflow with no production model entries assumed
- [x] 1.4 Pin Flutter, Dart, Android Gradle Plugin, Kotlin, JDK, NDK, and build-tool versions and document a clean bootstrap
- [x] 1.5 Define phase evidence templates covering completed work, commands/results, unverified assumptions, risks, and next recommendation

## 2. Flutter and Android Foundation

- [x] 2.1 Generate the Flutter project in the existing repository without nesting another Loquiris directory
- [x] 2.2 Set production package/application identities and configure Android API 29 minimum with current target/compile SDK
- [x] 2.3 Add feature-first directories, Riverpod, GoRouter, Drift, localization, and strict lint configuration
- [x] 2.4 Implement the hand-written sealed typed-result and structured failure foundation with unit tests
- [x] 2.5 Define injectable service interfaces and fake implementations for capture, transcription, language, speakers, models, performance, sessions, and export
- [x] 2.6 Add the bootstrap sequence, top-level error containment, local-only log sink, and test overrides
- [x] 2.7 Add release manifest and dependency checks that reject networking, telemetry, advertising, and remote configuration
- [x] 2.8 Run format, analysis, unit smoke tests, debug build, and release privacy checks; publish phase evidence

## 3. Design System and Navigation Shell

- [x] 3.1 Create Loquiris color, typography, spacing, shape, motion, and semantic-status tokens independent of Noctis assets
- [x] 3.2 Build light/dark Material 3 themes, adaptive page scaffolds, and shared accessible controls
- [x] 3.3 Add simplified Chinese and English ARB resources with system default and in-app override
- [x] 3.4 Configure routes for sessions, new recording, active recording/draft, detail/editor, export, models/performance, and storage/privacy
- [x] 3.5 Build empty/loading/error/recovery states and a navigation shell using fake repositories
- [x] 3.6 Add token, theme, localization, large-text, TalkBack semantics, and core navigation widget tests
- [x] 3.7 Capture initial phone-portrait goldens and overflow regressions for landscape and constrained widths; publish phase evidence

## 4. Domain Model and Drift Persistence

- [x] 4.1 Define immutable meeting (including pre-trash lifecycle restoration and durable permanent-deletion reservation), validated app-relative path, audio segment, session event, bookmark, processing job, fully provenance-bearing transcript/diarization runs, transcript segments, speaker clusters and interval assignments, language decisions, typed revisions, complete model manifests, and export entities; nullable corrections must be explicitly clearable
- [x] 4.2 Define matching Drift tables for every versioned entity and assignment, including pre-trash lifecycle restoration and durable permanent-deletion reservation, plus indexes, checked invariants, explicit foreign-key actions, cross-table transaction boundaries, connection PRAGMAs, and the initial schema version
- [x] 4.3 Implement `SessionRepository` queries and streams for lifecycle, library, search, trash, storage accounting, and recovery reconciliation
- [x] 4.4 Implement transcript/model/revision repositories with parallel analysis versions and non-destructive human corrections
- [x] 4.5 Add database migration harnesses, fixture builders, transaction-failure tests, and forward-only migration documentation
- [x] 4.6 Verify pause-aware media time and wall-clock event mappings with deterministic clock tests
- [x] 4.7 Run repository/unit tests and publish phase evidence before native capture integration

## 5. Native Audio Architecture Spike

- [x] 5.1 Build an Android `AudioRecord` spike for mono 16 kHz PCM with device-route and audio-session diagnostics
- [ ] 5.2 Measure and document AAC-LC 64 kbit/s encoder availability and quality on the selected target device
- [ ] 5.3 Compare recoverable AAC storage candidates for short durable commits, logical five-minute segments, gap-free playback, and final M4A muxing
- [ ] 5.4 Force-stop, kill, and truncate the spike at controlled offsets and measure the maximum recoverable loss
- [ ] 5.5 Measure PCM-to-encoder and bounded fan-out behavior under artificial inference stalls and prove the recorder path does not back-pressure
- [ ] 5.6 Select or reject the canonical container/commit design using recorded evidence and update design/specs if the AAC target changes
- [ ] 5.7 Publish spike code, tests, storage calculations, device/firmware details, failures, and recommendation; do not proceed if the five-second loss gate is unmet

## 6. Reliable Foreground Recording

- [ ] 6.1 Implement the persisted native recording state machine and idempotent start, pause, resume, stop, and snapshot commands
- [ ] 6.2 Implement the foreground service, wake lock lifecycle, microphone permission handling, and visible recording notification
- [ ] 6.3 Implement monotonic duration, file-size snapshots, bookmark action, pause/resume notification action, and return-to-active-session behavior
- [ ] 6.4 Implement priority audio encoding, durable segment manifests, atomic metadata writes, logical segment rollover, and input-health metrics
- [ ] 6.5 Implement audio-focus and call interruption events with transient auto-resume and post-call user confirmation rules
- [ ] 6.6 Implement start-time four-hour storage preflight, active low-space thresholds, safe finalization, and structured failures
- [ ] 6.7 Implement Flutter `AudioCaptureService` channel adapter, fake adapter, view model, and lifecycle-independent active-state restoration
- [ ] 6.8 Add Android JVM tests for state transitions, manifests, thresholds, clocks, encoding queues, and interruption policy
- [ ] 6.9 Add instrumented tests for permission denial, screen lock/background, task dismissal, notification actions, and service process recreation
- [ ] 6.10 Run a preliminary one-hour physical-device recorder test and publish phase evidence before recovery and four-hour gates

## 7. Recovery, Finalization, and Playback

- [ ] 7.1 Implement startup reconciliation across Drift records, authoritative manifests, segment files, and incomplete derived files
- [ ] 7.2 Implement recoverable-session UI that never reopens the microphone automatically and supports save or explicit continuation
- [ ] 7.3 Implement rebuildable continuous playback and final M4A muxing without treating merged output as authoritative
- [ ] 7.4 Implement gap/corruption detection, partial-session status, structured recovery diagnostics, and raw-segment export fallback
- [ ] 7.5 Add force-stop, native crash simulation, Flutter process recreation, device restart, truncation, and failed-merge instrumented tests
- [ ] 7.6 Verify committed segments remain usable and simulated crash loss never exceeds five seconds; publish phase evidence

## 8. Session Library and Manual Meeting Tools

- [ ] 8.1 Implement session list, localized default title, rename, state badges, duration/size, local title/transcript search, and trash navigation
- [ ] 8.2 Implement new-recording mode/language/speaker-count controls with remembered defaults and immediate post-preflight start
- [ ] 8.3 Implement active recording UI with accessible recording status, timer, size, input activity, pause/resume, confirmed stop, and bookmark/highlight controls
- [ ] 8.4 Implement session detail with segment-backed playback, event timeline, bookmark navigation, processing state, and failure explanation
- [ ] 8.5 Implement combined basic transcript/language/speaker editor with revision history and no active-draft editing
- [ ] 8.6 Implement seven-day trash, explicit permanent deletion, restore, and external-copy disclaimer
- [ ] 8.7 Add view-model, widget, accessibility, localization, search, edit-conflict, and golden tests; publish phase evidence

## 9. Export, Backup, Restore, and Storage

- [ ] 9.1 Implement local M4A/segment, TXT, SRT, JSON, and ZIP export with privacy-preserving default names
- [ ] 9.2 Implement progress, cancellation, structured errors, and cleanup for long export operations
- [ ] 9.3 Define and implement the checksummed local backup format excluding models, caches, and logs
- [ ] 9.4 Implement restore validation, identical-content skip, conflicting-ID duplication, and restored-copy labeling
- [ ] 9.5 Implement storage accounting by application/models, meetings, cache, trash, and free space
- [ ] 9.6 Implement safe cleanup limited to rebuildable PCM, waveform, index, and failed-job temporary data
- [ ] 9.7 Add export round-trip, backup/restore collision, low-space, deletion, and sensitive-filename tests
- [ ] 9.8 Verify Android backup is disabled and uninstall behavior is accurately documented; publish phase evidence

## 10. Model Supply Chain and Benchmark Harness

- [ ] 10.1 Define the model manifest schema for source, version, SHA-256, bytes, runtime compatibility, license snapshot, and enabled modes
- [ ] 10.2 Implement build-time model import/verification tooling without committing large model weights to Git
- [ ] 10.3 Implement runtime model integrity checks that disable dependent AI only and never block recording
- [ ] 10.4 Add fixed redistributable Chinese/English/mixed benchmark audio and record its provenance, consent, license, and hashes
- [x] 10.5 Implement the 30–60 second first-run benchmark and recommendation UI without microphone activation or automatic setting changes
- [x] 10.6 Implement CPU/memory/RTF/latency/thermal/energy/backlog metric capture and privacy-safe local result export
- [x] 10.7 Add high-quality, balanced, power-saving, recording-only, and post-session policy objects with explicit user-visible degradation
- [ ] 10.8 Measure APK/AAB and installed footprints; fail production selection above 500 MiB release or 800 MiB installed targets
- [ ] 10.9 Generate and review third-party notices from lock files, native dependencies, and model manifests; publish phase evidence

## 11. Whisper Transcription Spike

- [ ] 11.1 Integrate `whisper.cpp` behind `TranscriptionEngine` in an isolated native execution boundary using CPU/ARM NEON as baseline
- [ ] 11.2 Import and verify multilingual `base q5` through the approved build-time model workflow
- [ ] 11.3 Implement post-session decoding, timestamp normalization, progress, cancellation, resumable job state, and structured failures
- [ ] 11.4 Implement a bounded sliding-window draft experiment with stable/unstable hypotheses and backlog reporting
- [ ] 11.5 Benchmark Chinese CER, English WER, mixed MER, first-text latency, RTF, peak PSS, energy, thermals, and UI responsiveness on the target device
- [ ] 11.6 Evaluate `small q5` as an included high-quality model against accuracy gain, RTF ≤2.0, memory stability, license, and size budgets
- [ ] 11.7 Decide production, preview, or rejected status for each mode/model strictly from recorded gates and update manifests/notices
- [ ] 11.8 Publish raw benchmark configuration, normalized scoring scripts, results, limitations, and phase recommendation

## 12. Production Transcription and Language Workflow

- [ ] 12.1 Implement durable transcription jobs, engine/model provenance, parallel result versions, current-version selection, and retry/resume
- [ ] 12.2 Implement live incremental draft UI, delayed/incomplete state, post-session fallback, and thermal/resource degradation notifications
- [ ] 12.3 Implement stable timestamped transcript segments, raw/display text separation, deterministic formatting, and correction revisions
- [ ] 12.4 Implement Chinese, English, mixed, and uncertain language labels through `LanguageIdentificationEngine`
- [ ] 12.5 Implement manual segment-language correction and ensure re-analysis never overwrites it
- [ ] 12.6 Implement transcript search-to-playback, SRT/JSON output, progress/remaining-time estimates, and failure recovery
- [ ] 12.7 Add engine-contract, versioning, backlog, editing, language, export, thermal-degradation, and process-recreation tests
- [ ] 12.8 Enable near-real-time only if all required target-device gates pass; otherwise ship post-session or recorder-only status and publish evidence

## 13. Post-Session Speaker Diarization

- [ ] 13.1 Complete fixed license/provenance review for the proposed segmentation, embedding, and clustering weights before integration
- [ ] 13.2 Implement `SpeakerDiarizationEngine` and resumable post-session job orchestration without capture-time resource competition
- [ ] 13.3 Implement automatic or user-guided two-to-six-speaker clustering and timestamp alignment to transcript segments
- [ ] 13.4 Implement stable meeting-local speaker IDs, rename, merge, split/reassign, uncertainty, and revision preservation
- [ ] 13.5 Add overlap, far-field, fan-noise, unknown-count, expected-count, language-bias, and six-speaker evaluation cases
- [ ] 13.6 Measure DER/JER, four-hour memory/time/thermal stability, label drift, and installed-size impact on the target device
- [ ] 13.7 Enable automatic labels by default only if DER ≤25% and all stability gates pass; otherwise retain manual/experimental behavior
- [ ] 13.8 Publish phase evidence, failure cases, and user-visible limitations without claiming real-time diarization

## 14. CI, Privacy, and Release Hardening

- [ ] 14.1 Add GitHub Actions for formatting, strict analysis, Flutter tests, Android JVM tests, build smoke tests, and artifact retention
- [ ] 14.2 Add CI checks for forbidden permissions/dependencies, cloud endpoints, telemetry, model hash drift, license drift, and notice drift
- [ ] 14.3 Add release configurations for AAB, ABI-specific signed APKs, and a clearly identified universal APK
- [ ] 14.4 Add local-only rolling diagnostics capped at seven days or 10 MiB and verify prohibited content never appears
- [ ] 14.5 Complete bilingual privacy, consent, recording visibility, deletion, backup sensitivity, uninstall, model, and compatibility documentation
- [ ] 14.6 Run Flutter integration and Android instrumented suites for recording, process death, permissions, low storage, thermal degradation, export, and recovery
- [ ] 14.7 Run dependency/license audit and manually approve every shipped model and native library in `THIRD_PARTY_NOTICES`
- [ ] 14.8 Publish release-candidate automated evidence and unresolved-risk assessment

## 15. Physical-Device Release Gates

- [ ] 15.1 Fingerprint the connected mainland-China Redmi Note 10 Pro (`M2104K10AC`/`chopin`, 6GB+128GB class), firmware, security patch, battery health, and factory settings
- [ ] 15.2 Prepare the fixed room layout, calibrated playback, authorized 30-minute Chinese/English/mixed quality sets, long stability audio, and two-to-six-speaker samples
- [ ] 15.3 Run three four-hour recording-only tests off charger at 22–26°C with memory extension disabled
- [ ] 15.4 Run the four-hour interruption stress flow covering pause/resume, lock/background, task dismissal, focus/call interruption, low battery, low storage, and abnormal process recovery
- [ ] 15.5 If proposed, run two four-hour near-real-time tests and record latency, RTF, CPU/PSS, thermal, energy, backlog, gaps, failures, and UI frames
- [ ] 15.6 Run post-session balanced/high-quality transcription, language, and diarization matrices including noise, distance, overlap, and six speakers
- [ ] 15.7 Repeat critical flows with factory-default memory extension and OEM battery policy and document differences from the controlled baseline
- [ ] 15.8 Produce a signed validation report that grants or withholds Recorder MVP, Offline Transcription Preview, language, and diarization labels independently
- [ ] 15.9 Complete privacy, permission, license, package-size, installed-size, reproducible-build, backup/restore, and release-notes review
- [ ] 15.10 Present the measured release recommendation and all remaining experimental assumptions before enabling or advertising any AI capability
