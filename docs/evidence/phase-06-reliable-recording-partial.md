# Phase 6 Reliable Recording Evidence (Partial)

This document records evidence for completed Phase 6 tasks only. It is not a
claim that foreground capture, interruptions, storage safeguards, recovery, or
the one-hour/four-hour stability gates are complete.

## Task 6.1 — Persisted native recording state machine

Status: verified on 2026-09-30.

Implemented Android-native, persisted recording states for `idle`, `preparing`,
`recording`, `pausedByUser`, `pausedByInterruption`, `stopping`, `finalized`,
`recoverable`, and `failedFinalization`. Start, pause, resume, stop, progress,
finalization, and snapshot operations are serialized and idempotent. A state is
published in memory only after its synchronous durable-store commit succeeds.

On reconstruction, an active snapshot is persisted as `recoverable`; the
microphone is never reopened automatically. Missing state initializes as idle.
Malformed JSON, incompatible schema/state, invalid snapshot invariants, and
unusable revision values fail closed with typed errors while retaining the raw
stored value for diagnosis. Store read/write failures likewise return typed
failures and do not advance authoritative in-memory state.

Revision increments reserve `Long.MAX_VALUE` as invalid persisted input and
refuse commands or active recovery at `Long.MAX_VALUE - 1`. This keeps the
domains of generated, persisted, and reloadable snapshots consistent.

### Verification

- Host/bridge gate: Android debug build, JVM unit tests, Android-test
  compilation, and `lintDebug` passed (`BUILD SUCCESSFUL`, 250 tasks, 2026-09-30).
- Physical-device gate: four tests in
  `SharedPreferencesRecordingStateStoreInstrumentedTest` passed on device model
  `M2104K10AC`, Android 13/API 33 (`BUILD SUCCESSFUL in 23s`). The tests cover
  store reconstruction, active-to-recoverable reconstruction, malformed JSON
  retention, and incompatible schema/state/invariant/revision retention.
- Independent review: no remaining Critical or Important findings after
  revision overflow and recovery-domain fixes.

The device identifier above is the value reported by Android tooling. Per the
device validation specification, this evidence applies only to that exact
device/firmware environment and does not establish compatibility with other
Redmi or Xiaomi models.

## Task 6.2 — Foreground service, wake lock, permissions, and notification

Status: verified on 2026-09-30.

The non-exported Android microphone foreground service now owns the durable
native state-machine instance, promotes itself with an ongoing low-importance
notification, and acquires a non-reference-counted partial wake lock with a
five-hour safety timeout. Destruction and failed ownership paths release the
wake lock. The notification opens Loquiris and intentionally has no destructive
stop action.

The production manifest declares record-audio, foreground-service,
foreground-service-microphone, wake-lock, and notification capabilities without
declaring `INTERNET`. Start preflight returns a typed microphone-permission
failure. On Android 13+, notification denial is an allowed but explicit
`notificationVisibilityReduced` result rather than a false claim of normal
visibility. Runtime permission-request UI remains part of the Flutter/native
adapter work; Task 6.9 retains the denial-path instrumented gate.

Service promotion exceptions are caught inside `onStartCommand`, where Android
can reject promotion asynchronously. That path safely finalizes an unowned
preparing session, removes any partial foreground state, and stops the service.
Ownership is claimed only after promotion and wake-lock acquisition. Once a
session owns the service, repeated same-session requests are idempotent and
conflicting or malformed requests cannot stop or overwrite the owner.

### Verification

- Dart policy test passed 1/1, confirming the production manifest capabilities,
  service declaration, `stopWithTask=false`, microphone service type, and lack
  of an `INTERNET` declaration.
- JVM tests passed for permission policy, reduced notification visibility,
  foreground-state eligibility, idempotent wake-lock acquire/release, retry
  after acquisition failure, promotion exception containment, and ownership.
- Physical-device test passed 1/1 on `M2104K10AC`, Android 13/API 33. It started
  the service from a resumed activity, observed one ongoing notification and a
  persisted `preparing` snapshot, submitted same-session, conflicting-session,
  and invalid-action requests, verified the original session/state/revision and
  notification remained intact, then stopped the service and observed the
  notification disappear.
- The combined Flutter policy, instrumented, JVM, compile, and lint gate passed
  (`BUILD SUCCESSFUL in 39s`). Independent review reported no remaining
  Critical or Important findings.

## Task 6.3 — Progress snapshots, bookmarks, and notification actions

Status: verified on 2026-09-30.

Recording progress now uses Android elapsed realtime through a monotonic timer.
User-paused wall time is excluded, a regressing clock source cannot reduce the
published media duration, and each progress publication takes the current
authoritative byte-count callback rather than estimating file size in Flutter.
Notification duration and byte counts use stable formatting that supports
recordings longer than four hours.

The foreground notification adds pause and bookmark actions while recording and
resume and bookmark actions while paused. Every action carries both a session
extra and a session/action-derived immutable intent identity, preventing an old
`PendingIntent` from being silently retargeted to another meeting. Selecting the
notification opens the encoded active-session route. No destructive stop action
was added.

Bookmarks are appended independently of transcription as versioned,
length-delimited, CRC-protected frames containing media time and wall-clock
time. Each append syncs the file and its app-private parent directories. On
reopen, an incomplete or invalid tail is truncated before the next append. If a
directory sync fails after the frame reaches disk, retry republishes durability
without duplicating the same unacknowledged frame.

### Verification

- JVM tests passed for pause-aware monotonic duration, non-regression, byte
  snapshots, four-hour-plus formatting, runtime pause/resume/progress behavior,
  bookmark timing and failure handling, frame decoding, torn-tail recovery,
  directory-sync retry deduplication, notification-action identity isolation,
  and active-session route encoding.
- The targeted Android build/JVM/AndroidTest/lint gate passed
  (`BUILD SUCCESSFUL in 27s`, 249 tasks).
- On `M2104K10AC`, Android 13/API 33, the foreground-service test passed 1/1 and
  the app-private bookmark torn-tail recovery test passed 1/1. The foreground
  test sends the notification `PendingIntent` and observes the exact active
  meeting URI delivered through `MainActivity.onNewIntent`. After installing
  the already-built application and test APKs once, the final fresh direct
  instrumentation run of the full class passed both tests together:
  `OK (2 tests)`, 3.717 seconds.
- The original `ActivityScenario` fixture hung because MIUI logged
  `Permission Denied Activity` for an instrumentation-originated launcher
  intent. The corrected fixture brings the target app to the foreground through
  shell UI automation, then invokes the same public service start boundary.
  This removes a device-vendor test-harness restriction without bypassing the
  permission preflight or foreground-service implementation.
- Gradle UTP can still be blocked before test execution by MIUI's USB installer
  with `INSTALL_FAILED_USER_RESTRICTED`. This is an installation-harness
  limitation: the two targeted UTP runs passed, and the full class passed with
  direct instrumentation after one-time APK installation.

Actual encoder byte production and transition from `preparing` to `recording`
belong to Task 6.4. Consequently, physical pause/resume/bookmark action
interaction is retained in Task 6.9; Task 6.3 verifies notification-to-session
routing and durable runtime behavior without claiming microphone capture is
already integrated.

## Task 6.4 — Priority encoding, durable segments, and input health

Status: implementation verified on 2026-09-30; long-duration gates remain in
Tasks 6.10 and 15.

The production capture path now uses one Android `AudioRecord` source configured
for mono 16 kHz PCM16. Fixed 640-byte capture blocks enter a bounded fan-out:
the canonical AAC encoder has the highest-priority worker and any canonical
queue overflow or encoder failure is explicit and sticky, while the independent
bounded inference queue may drop optional draft work without blocking capture.
Pause first changes pipeline state, stops `AudioRecord`, and waits for any
in-flight blocking read to settle before reporting success; resume retains the
PCM sequence.

The canonical encoder uses the platform AAC-LC encoder at 64 kbit/s. It wraps
access units in ADTS, syncs audio before appending and syncing a checksummed
monotonic commit-journal record every 75 AAC frames (4.8 seconds), and rotates
after 62 commit groups (4,650 frames / 297.6 seconds). Codec-specific data and
ordered segment identity are stored in a checksummed manifest. A new segment is
created, synced, and published in the manifest before receiving audio. Manifest
publication writes and syncs a temporary file, atomically replaces the target,
then syncs the containing directory. If the final directory sync is uncertain,
the segment and journal are retained so a possibly visible manifest can never
point at deliberately deleted authoritative audio.

New nested session directories are created one level at a time and each new
directory entry is made durable by syncing its parent before proceeding. File
operation exceptions, including Android directory-sync errors, are converted to
typed manifest failures. The encoder validates the negotiated MIME type, sample
rate, channel count, optional profile/bit-rate fields, and AudioSpecificConfig
before publishing authoritative segment identity.

Input-health snapshots report read calls, PCM bytes, short/zero/error reads,
maximum monotonic read gap, and timestamp regressions. Foreground-service start
now creates this real pipeline in app-private, SHA-256-derived session storage;
the persisted state advances from `preparing` to `recording` only after the
microphone starts. Notification pause/resume controls operate the capture
pipeline before changing the persisted state. Unexpected service destruction
closes native resources and retains the active state and authoritative files
for later recovery rather than claiming successful finalization.

The service supervises asynchronous input and canonical-encoder failure. A
failure durably changes the meeting to `recoverable`, removes the misleading
active notification, releases ownership and the wake lock, and stops the
service. Shutdown reports whether the canonical worker is quiescent; if a
platform encoder call outlives both bounded joins, codec release is deferred
until that worker really exits rather than racing a live writer.

### Verification

- TDD regression tests cover canonical ordering, inference overflow isolation,
  explicit canonical overflow, sticky sink failure, capture health metrics,
  pause/read-settlement and sequence continuity, checksummed manifest parsing,
  atomic publication order, file-operation exception containment,
  uncertain-final-sync file retention, durable nested-directory creation,
  negotiated AAC/ASC validation, recoverable failure supervision,
  uninterruptible-worker shutdown, short-policy rollover/recovery, and the
  production 4.8-second/297.6-second constants.
- The complete Android JVM unit suite passed after the production service
  integration. The complete Flutter suite passed 115 tests, and `flutter
  analyze` reported no issues.
- On `M2104K10AC` (`chopin`), Android 13/API 33, the final direct
  instrumentation run passed the complete `com.loquiris.recording` package:
  `OK (9 tests)`, 7.809 seconds.
  This includes authentic platform AAC, real 16 kHz microphone input, a full
  microphone→priority fan-out→AAC→manifest pipeline across pause/resume, and a
  foreground service that persists `recording`, publishes non-zero bytes, and
  creates private ADTS/manifest files.
- The targeted full pipeline test independently passed `OK (1 test)` in 2.354
  seconds, and the production foreground-service test passed `OK (1 test)` in
  5.36 seconds. No canonical rejection was observed in the pipeline fixture.
- Two independent architecture/reliability reviews were completed. The initial
  review's capture-failure supervision, owned-start rollback, shutdown ordering,
  directory durability, and negotiated-format findings were corrected. The
  final review reported no remaining Critical or Important findings.

This is short functional evidence, not the one-hour or four-hour reliability
gate. Physical power removal, long-run thermal/storage behavior, audio-focus and
call interruptions, low-space finalization, process recreation, and continuous
playback remain unverified in their later OpenSpec tasks.

## Task 6.5 — Audio-focus and call-like interruption policy

Status: implementation verified on 2026-09-30; the physical phone-call stress
gate remains in Task 15.4.

The foreground service now owns Android audio focus for the capture lifetime and
maps transient/permanent focus loss, focus gain, call-like `AudioManager` modes,
and own-session `AudioRecordingConfiguration.isClientSilenced` changes into a
single persisted interruption policy. The app deliberately does not request
`READ_PHONE_STATE` and does not inspect phone numbers, call logs, or subscription
data. This permission-minimizing design treats call-like modes and ambiguous
microphone silence as confirmation-required rather than risking an automatic
microphone reopen.

A short transient focus loss may automatically resume only when the policy owns
the interruption pause and no call-like or ambiguous microphone event occurred.
Permanent focus loss requires explicit focus reacquisition. A completed call or
ambiguous microphone interruption leaves capture paused and removes the one-tap
resume notification action until an explicit confirmation command succeeds.
Stale user-pause commands cannot roll an interruption pause back to an ordinary
user pause.

Interruption events use versioned, length-delimited, CRC-protected journal
frames in app-private storage, with torn-tail recovery and synchronous append.
Their media timestamp comes from the exact capture pause boundary while wall
time remains independent. Event append is intentionally decoupled from active
state progress persistence: if the microphone has already stopped and a later
progress write fails, the session becomes `recoverable`, the microphone remains
closed, and the interruption marker is still written best-effort before service
cleanup.

### Verification

- TDD tests cover transient auto-resume, call and microphone confirmation,
  permanent-focus reacquisition, platform callback mapping, stale notification
  commands, journal CRC/torn-tail behavior, exact pause boundaries, and both
  user/interruption pause progress-write failures. The failure-injection test
  proves a call marker remains journaled at the exact 1,000 ms media boundary
  after the session becomes recoverable.
- The complete Android JVM suite plus debug, AndroidTest, and release APK builds
  passed together (`BUILD SUCCESSFUL`, 362 tasks). Flutter analysis reported no
  issues and the complete Flutter suite passed 115 tests.
- The release privacy gate passed both the structured dependency/manifest check
  and APK inspection: the release APK contains no network permissions and the
  production manifest does not add `READ_PHONE_STATE`.
- Fresh debug and test APKs were installed on the connected `M2104K10AC`
  (`chopin`), Android 13/API 33. The complete recording instrumentation package
  passed `OK (9 tests)` in 7.876 seconds, including real microphone capture,
  pause/resume, canonical AAC/manifest output, and foreground-service startup.
- Three independent review rounds corrected permanent-focus reacquisition,
  exact capture-boundary timing, unsafe pause rollback, and journal persistence
  during progress-write failure. The final review reported no remaining
  Critical or Important findings.

This evidence verifies the implementation and short device regression surface.
It does not claim that a real incoming/outgoing phone call has been exercised;
that end-to-end interruption flow remains part of the four-hour physical-device
stress gate in Task 15.4.

## Task 6.6 — Storage preflight and active low-space protection

Status: implementation verified on 2026-09-30; controlled physical storage
exhaustion remains in Tasks 6.9 and 15.4.

The selected 64 kbit/s AAC mode estimates 115,200,000 bytes of four-hour audio
payload. Startup adds 5% container/journal headroom (120,960,000 bytes total)
and a 512 MiB safety reserve, so capture requires at least 657,830,912 available
bytes. Both the caller-facing start path and the authoritative foreground
service recheck this threshold before capture state or the microphone pipeline
is created, closing the caller/service time-of-check gap.

During capture, the service warns below the estimated space for 30 more minutes
plus 256 MiB (283,555,456 bytes). Below one complete 297.6-second logical
segment with 5% headroom plus a 1 MiB finalization reserve (3,548,416 bytes), it
stops inference work, pauses at the exact capture boundary, commits progress,
finishes the encoder, and releases foreground ownership only after successful
finalization. If any required durability step fails, the session remains
recoverable rather than being presented as finalized. A pipeline failure that
coincides with critical free space first persists the low-storage cause before
generic recovery cleanup.

Preflight denial and active exhaustion use a versioned, length-delimited,
CRC-protected structured failure frame containing the measured and required
bytes. The frame is written through a synced temporary file, atomic replacement,
and parent-directory sync. The policy never deletes recordings, transcripts,
models, or other user data automatically.

### Verification

- TDD policy tests cover exact estimate arithmetic, threshold boundaries,
  unavailable storage readings, warning and critical actions, and both healthy
  and already-failed pipeline decisions.
- Atomic failure-journal tests cover decoding, file and directory durability,
  temporary-file cleanup, and rejection of malformed replacement data.
- The complete Android JVM suite plus debug, AndroidTest, and release builds
  passed together (`BUILD SUCCESSFUL`, 362 tasks). Flutter analysis reported no
  issues and the complete Flutter suite passed 115 tests.
- The release privacy gate passed dependency/manifest inspection and confirmed
  that the release APK declares no network permission.
- Fresh APKs on `M2104K10AC` (`chopin`), Android 13/API33, passed the foreground
  service instrumentation class: `OK (3 tests)` in 5.456 seconds. This includes
  structured preflight rejection without microphone startup alongside normal
  service capture and progress publication.
- Architecture/reliability re-review verified the authoritative second
  preflight and the low-storage cause ordering. It reported no remaining
  Critical or Important findings.

This evidence does not claim that the phone was deliberately filled during an
active recording. Destructive real-space exhaustion, notification visibility,
and the resulting audio playback/recovery check remain explicit physical-device
gates in Tasks 6.9 and 15.4.

## Task 6.7 — Flutter control boundary and lifecycle-independent restoration

Status: implementation verified on 2026-09-30; destructive process-recreation
and long-running UI/service interaction remain in Tasks 6.9 and 15.4.

The app root now eagerly owns a non-auto-disposed Riverpod recording
coordinator, so native restoration and snapshot observation start without
opening a recording screen. Restoration subscribes before its initial read,
buffers concurrent snapshots, and applies one session/revision monotonicity
rule to restoration, stream updates, and command outcomes. A late command
result therefore cannot replace a newer native revision.

The versioned Dart/Kotlin control channel returns correlated command IDs.
Android synchronously persists pending receipts with command, session,
creation metadata, and a process-incarnation ID, then the foreground service persists either the terminal
snapshot or a typed failure. Authoritative storage rejection retains measured
and required bytes. Flutter polls only that receipt, with both a remaining
overall deadline and a timeout around each platform call. Stale pending work
without live process ownership is reconciled to an interrupted terminal
failure when a later process observes that the originating process no longer
exists.

Cold-process snapshot reads distinguish the application-process liveness of a
real service owner from stale persisted active state. Without a live owner,
the persisted state machine atomically converts active state to `recoverable`;
it never reopens the microphone. Manual stop and critical-storage finalization
first persist `stopping`, then pause, drain, finish, sync progress, and publish
the terminal state on one service-owned worker. Foreground and wake-lock
ownership are retained until completion, and `onDestroy` does not concurrently
close the same pipeline while finalization is in flight.

### Verification

- Flutter analysis reported no issues and the complete Flutter suite passed
  129 tests. Targeted tests cover root-level eager restoration, restoration
  subscription races, command failure retention, late-revision rejection,
  receipt decoding, structured storage failures, and command timeout behavior.
- The complete recording Android JVM package passed after the worker,
  liveness, receipt, and state-machine changes. Targeted tests prove stale
  active-to-recoverable conversion, live-owner preservation, exact stop
  progress ordering, and that finalization submission does not block its caller.
- Debug AndroidTest APK construction passed. On the connected `M2104K10AC`
  (`chopin`), Android 13/API33, the Flutter integration test passed 1/1 and
  restored a real Kotlin-persisted snapshot through the production MethodChannel.
  MIUI again returned `DELETE_FAILED_INTERNAL_ERROR` only for the test harness's
  post-success uninstall; the test itself passed.
- A fresh 56.7 MB release APK built successfully. The release privacy gate
  passed dependency/manifest inspection and confirmed no network permissions.
- OpenSpec strict validation and `git diff --check` passed. GitNexus change
  detection rates the cumulative uncommitted Phase 5/6 worktree CRITICAL (85
  changed indexed symbols and 29 affected flows), so this evidence does not
  reduce the need for later physical interruption, recovery, and long-run gates.

This verification does not claim a process kill during an in-flight command,
four-hour stability, notification-action interaction, task dismissal, screen
lock continuity, or real low-space exhaustion. Those remain explicit Tasks 6.9,
6.10, 14.6, and 15.4 rather than assumptions of this adapter milestone.

## Task 6.8 — Android JVM reliability matrix

Status: verified on 2026-09-30.

The host-side recording suite now contains 22 focused test classes. It covers
persisted and idempotent state transitions, stale-active recovery, monotonic
media clocks and exact capture boundaries, segment/checksum/atomic-manifest
durability, negotiated AAC format validation, canonical-versus-inference queue
priority, capture failure supervision, storage thresholds and structured
failure journals, foreground ownership and wake-lock rules, command contracts,
serialized finalization, bookmarks, audio-focus/call-like policy, interruption
journals, and conservative platform-signal mapping.

The complete `com.loquiris.recording` JVM package passed after the final 6.7
service-lifecycle fixes. Tests remain deterministic and use injected clocks,
stores, sinks, sources, encoders, and synchronization gates; no microphone,
network, wall-clock delay, or OEM behavior is treated as a JVM-test result.
Android platform and lifecycle claims remain in the instrumented and physical
device tasks.

## Task 6.9 — Physical Android lifecycle and notification instrumentation

Status: verified on 2026-09-30 on the selected target device; long-duration
stability remains in Tasks 6.10 and 15.

The Android instrumentation surface now covers microphone-permission denial,
background and screen-off continuity, recent-task dismissal, real notification
pause/bookmark/resume actions, and cold application/service-process recovery.
The permission test injects a denied platform context and proves that the
public start boundary returns `recording_permission_denied` without dispatching
the foreground service.

The lifecycle tests use production `AudioRecord`, AAC, manifests, persisted
snapshots, notification `PendingIntent`s, and `stopWithTask=false` behavior.
They take their byte baseline only after HOME/backgrounding or after Android
reports the recent task removed. The screen-off case waits for
`PowerManager.isInteractive == false` before taking a second baseline. Each
case then requires canonical bytes to grow while the foreground notification
remains present.

The notification test sends the actual system pause action, waits for
`pausedByUser`, and proves both canonical bytes and media time remain unchanged
through a 2.2-second stability window. It sends the bookmark action and decodes
the durable CRC-protected event from private storage, then sends Resume and
requires state plus canonical byte growth. The action list is exactly Pause and
Bookmark while recording and contains no destructive Stop action.

Process recreation uses two opt-in instrumented phases plus the checked-in
`tool/run_recording_service_recreation_test.sh` host runner. Preparation starts
real capture, waits for durable bytes, publishes a fresh nonce-bound marker,
and deliberately kills the process that owns the foreground service. The host
requires Android's `Process crashed` result, verifies the private marker,
revokes `RECORD_AUDIO`, and launches recovery in a new process with the same
nonce. Recovery requires the microphone permission to be denied, converts the
persisted active snapshot to `recoverable`, verifies the revision advanced and
bytes did not regress, observes no live owner or notification, and proves a new
service start is rejected for permission rather than reopening capture. The
runner restores the test permission on exit. Without explicit phase arguments,
both destructive tests are assumption-skipped so an ordinary suite cannot kill
itself.

Test cleanup now requests graceful stop when the current process owns capture
and waits for a terminal snapshot, released process ownership, and notification
removal before deleting state or files. Stale active snapshots are reconciled
before cleanup. This prevents the service's asynchronous finalization worker
from recreating state after the next test has begun.

### Verification

- TDD recorded the expected AndroidTest compile failure while the shared test
  harness and process-recreation fixture were absent; adding only those test
  utilities made `:app:compileDebugAndroidTestKotlin` pass.
- On the connected `M2104K10AC` (`chopin`), Android 13/API33, the initial
  permission, background/screen-off, task-dismissal, and notification matrix
  passed 4/4 through Gradle UTP. After review hardening, permission denial,
  post-removal byte growth, and pause stability/bookmark/resume passed together
  `OK (3 tests)` in 11.343 seconds. The screen-off/background case independently
  passed `OK (1 test)` in 3.8 seconds.
- The checked-in host runner passed end to end: preparation produced the
  required `shortMsg=Process crashed`, then microphone-revoked cold recovery
  passed `OK (1 test)` in 0.09 seconds. A separate ordinary invocation without
  phase arguments completed `OK (2 tests)` with both tests assumption-skipped.
- Fresh host regression evidence includes `flutter analyze` with no issues,
  all 129 Flutter tests passing, the complete `com.loquiris.recording` Android
  JVM package passing, AndroidTest compilation, script syntax validation, and
  `git diff --check`.
- Independent review found five Important test-trust issues and no Critical
  issues. The pause-stability assertion, post-dismiss baseline, asynchronous
  cleanup barrier, microphone-revoked recovery, and repeatable host runner were
  added in response. Final re-review reported no remaining Critical or
  Important issues.

Turning the screen off on a password-protected phone necessarily activates the
system keyguard. ADB can wake the display but cannot bypass the user's password;
manual unlock after this test is a device-security requirement, not a Loquiris
failure. These short instrumented runs do not replace the one-hour or four-hour
physical stability gates.

## Task 6.10 — Preliminary one-hour physical-device recording

Status: preliminary exploratory evidence passed on 2026-09-30. This run closes
the Phase 6 one-hour gate but is explicitly ineligible for the Phase 15 release
matrix because ambient room temperature was not measured and the phone remained
USB-powered.

The checked-in `tool/run_one_hour_recording_test.sh` runner hard-binds the run to
`M2104K10AC`/`chopin`, grants only the already-declared microphone and
notification permissions, opts into the otherwise skipped hour-long test, and
always prints the private JSON report. A failed or interrupted host run retains
the last atomically published report and force-stops the target package if
needed to release the microphone while leaving committed audio recoverable.

The instrumented test requires the secure keyguard to be unlocked, launches the
real app into the foreground, starts production `AudioRecord`/AAC capture, then
returns HOME and switches the display off. It records one sample per minute and
requires the recording state, canonical bytes, media time, revision, foreground
notification, and live service ownership to remain valid and monotonic. It
allows at most one explicitly recorded interactive sample out of 61 and
immediately switches the display off again if one occurs. Finalization must
remove the notification and live owner before the test validates every manifest
entry, journal-authorized ADTS prefix, segment offset, unexpected/orphan file,
and the audio-duration-to-monotonic-time delta.

### Measured result

- Device: Redmi `M2104K10AC` (`chopin`), MediaTek MT6891/`mt6893`, Android
  13/API33, MIUI build `V14.0.8.0.TKPCNXM`, 2023-11-01 security patch,
  5,753,860,096 reported RAM bytes.
- Instrumentation result: `OK (1 test)` after 3,605.016 seconds; 61/61 scheduled
  samples were captured and all 61 reported `screenInteractive=false`.
- Final snapshot: `finalized`, 3,601,378 ms media time, 29,246,959 total
  authoritative-directory bytes, revision 3,463, no remaining foreground
  service, live owner, or active recording notification.
- Durable audio: 13 logical segments, 56,270 committed AAC frames,
  57,620,480 committed samples, 29,204,131 committed audio bytes, and
  3,601,280 ms committed duration. The committed-audio/final-timeline delta was
  98 ms, below the one-second gate. No orphan, missing, corrupt, uncommitted, or
  invalid suffix was accepted.
- Process PSS ranged from 303,814 to 330,906 KiB and ended at 328,513 KiB.
  This is a sampled range, not proof of the unsampled instantaneous peak.
- Battery temperature ranged from 28.0°C to 29.7°C and Android thermal status
  remained 0 at every sample. Battery stayed at 100% because USB power was
  connected, so this run provides no valid battery-drain-per-hour result.
- Private available storage decreased by 30,420,992 bytes. The final directory
  total exceeds committed ADTS bytes because it also includes commit journals
  and the manifest.
- The acoustic input was uncontrolled room ambience. This run validates capture
  continuity and structural integrity, not intelligibility, meeting-room
  distance, speech quality, ASR accuracy, or human playback.

The atomically persisted machine-readable summary is mirrored in
`docs/evidence/task-6-10-one-hour-summary.json`; the complete 61-sample report
remains in the debug app's private `files/device-validation` directory on the
tested phone.

### Failure evidence and hardening

The first opt-in attempt stopped before the hour because the secure keyguard was
already active. Android logs showed `RECORD_AUDIO` in foreground-only mode,
`Service.startForeground() not allowed due to bg restriction`, and the audio
policy silencing the record stream. The test now fails fast on a locked device,
launches the real app foreground before capture, and only backgrounds/locks
after canonical bytes exist.

A second attempt safely stopped at minute one because the display became
interactive. Power logs proved the requested sleep completed and a later
`android.policy:FINGERPRINT` event woke the device. The test now records such
wakes, immediately restores screen-off state, and requires at least 60 of 61
screen-off samples. The passing run observed zero interactive samples.

TDD first produced the expected AndroidTest compilation failure for the absent
one-hour observer. The implementation then passed AndroidTest compilation and
APK assembly. Independent review initially found five Important trust issues:
device binding/evidence fields, incomplete manifest coverage, unenforced
screen-off state, non-atomic report publication, and unsafe host failure
handling. All were corrected. Follow-up review of the fingerprint-wake
tolerance reported no remaining Critical or Important issue.

## Remaining long-duration work

Phase 6 is complete. This preliminary run is not a four-hour claim and does not
replace Task 15's three four-hour recorder runs, interruption stress flow,
off-charger energy measurement, measured ambient conditions, real meeting
audio, recovery gates, or end-to-end playback/export inspection.
