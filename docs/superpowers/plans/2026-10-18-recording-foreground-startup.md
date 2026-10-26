# Recording Foreground Startup Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove disk-backed state preparation from the period before recording-service foreground promotion, without losing recordings or replacing the installed app under a different signing key.

**Architecture:** Promote an unowned valid start with a non-persisted `preparing` notification before initializing/transitioning the recording state. Keep existing recording ownership, capture, state failures and cleanup semantics; reuse a small ordering helper in `RecordingForegroundPromotion` so blocking storage can be regression-tested without a microphone.

**Tech Stack:** Kotlin/JUnit, Android foreground service, existing Flutter application, read-only Android API-34 emulator with host audio disabled.

**Spec:** User-reported `ForegroundServiceDidNotStartInTimeException` for `com.loquiris` on 2026-10-18; recorder-first requirements in `openspec/changes/offline-streaming-two-pass-transcription/design.md` sections 2 and 6. Official Android guidance: https://developer.android.com/develop/background-work/services/fgs/troubleshooting

## Global Constraints

- Preserve the dirty worktree and all existing device data; no clear-data, uninstall, signature bypass or diagnostic-app reinstallation on the physical device.
- Installed package is `com.loquiris`, last updated 2026-10-12, SHA-256 `db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
- Installed signing certificate is `86025ec572ad5073b2481883cafd7e7cd3c0222bd3e5321666a79167960e6bd6`; measurement tooling deletes its ephemeral private key. Never attempt replacement with a different certificate.
- Private data is not readable through `run-as` for this release build. No claim of a complete production-data backup until an actual checked export exists.
- Do not start physical microphone capture during this repair without fresh readiness. Emulator audio input/output are disabled.
- Installed APK clean-state start succeeds on the isolated API-34 emulator; this is a startup-order hardening regression against the confirmed timeout class, not proof of the physical device's precise blocking call.
- No commit or unrelated OpenSpec task completion is part of this request.

## Review Focus

- Slow state load/save: foreground promotion must already have succeeded before preparation enters.
- Promotion rejection: no state preparation, audio allocation or recording mutation may occur.
- Invalid/recoverable/storage-denied start: remove only the temporary unowned foreground notification and preserve recovery evidence.
- Duplicate/conflicting request during active capture: preserve the existing owner's notification and recorder.
- Preparation exception: do not misclassify it as successful preparation or a promotion failure; retain existing typed state initialization failures.

### Task 1: Foreground-before-preparation order

**Files:** Modify `android/app/src/main/kotlin/com/loquiris/recording/RecordingServiceLifecycle.kt`; test `android/app/src/test/kotlin/com/loquiris/recording/RecordingForegroundPromotionTest.kt`.

**Interfaces:** Produces `RecordingForegroundPromotion.beforePreparation(promoter: ForegroundPromoter, prepare: () -> Unit): Boolean`; `false` means promotion failed and `prepare` did not run. Preparation exceptions are not caught as promotion failures.

- [x] Add literal-order, blocking-preparation, rejected-promotion and preparation-exception tests. A realistic mutation running `prepare` first must fail the first two tests.
- [x] Observe expected RED against legacy preparation-first ordering, then implement promotion-first ordering and verify GREEN.

### Task 2: Wire actual service and preserve failure ownership

**Files:** Modify `android/app/src/main/kotlin/com/loquiris/recording/RecordingForegroundService.kt`; extend an existing service-start ownership test only if a new pure policy is needed.

**Interfaces:** Consumes Task 1 helper. `handleStart` keeps its existing signature. `onCreate` no longer loads/recovers persisted recording state before promotion. Only a valid, unowned, permission-allowed start creates a transient preparing notification; state initialization follows successful promotion.

- [x] Run GitNexus upstream impact before every changed service/helper symbol and report HIGH/CRITICAL if encountered.
- [x] Move state initialization out of `onCreate`, call Task 1 helper before storage/state work, remove the old late promotion block, and retain the final notification refresh after capture begins.
- [x] Ensure failed unowned starts remove their transient notification without stopping or demoting an existing owner. Preserve all actual recording and recovery files.
- [x] Run full native unit/lint, Flutter tests and analysis. Review the narrow slice independently; record any limitation rather than claiming all cumulative changes are safe.

Final review extension: rejected-command receipt I/O also needs worker dispatch because stopping an older start can leave a newer unseen request pending. Added `RecordingRejectedCommandDispatcher.kt` and its unit tests; synchronous-writer RED followed by full-suite GREEN. Graceful close drains accepted receipts. Minor fixed-ID instrumentation synchronization weakness is deferred and recorded in evidence.

### Task 3: Emulator verification and safe deployment decision

**Files:** Evidence under `build/recording-start-crash-fix-1X8ZkU/`; scoped human-readable evidence in `docs/evidence/`.

- [x] Verify ordinary start/pause/stop and a rejected start on the isolated read-only emulator; no destructive instrumented harness runs on the physical device.
- [x] Build the normal app entry with experimental streaming disabled, not an integration-test entry; verify package identity, manifest/privacy and signing certificate.
- [x] If the original signing key is unavailable, stop before physical installation. Present the checked repair and the data-export/signature blocker; a data-destructive replacement requires a separate user decision.
- [x] Stop only the emulator started for this task, preserve logs/artifacts, and hand off exact verified results without claiming a physical-device fix before it is tested.

Completion boundary: normal-main DEBUG verification artifact only, not a release build or production privacy qualification. Physical update is deliberately not performed. See `docs/evidence/2026-10-18-recording-foreground-startup.md` for exact results, identity, rulings and deferred minor.
