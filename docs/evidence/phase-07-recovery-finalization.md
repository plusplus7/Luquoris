# Phase Evidence: Recovery, Finalization, and Playback

## Scope

- OpenSpec change: `bootstrap-loquiris-offline-recorder`
- Task IDs: 7.1–7.6, with this report closing 7.5 and 7.6
- Commit/build identifier: working tree based on `7088398`; no release commit was created
- Date and operator: 2026-10-01, Codex with user-assisted device unlock only
- Device: Redmi Note 10 Pro, `M2104K10AC`/`chopin`, observed 6 GB + 128 GB class, Android 13/API 33

## Completed

- Added opt-in, nonce-bound two-phase instrumentation for a real device restart. Preparation records authentic microphone audio, pauses at a stable commit boundary, fsyncs a marker containing the manifest SHA-256 and every journal-authorized prefix length and SHA-256, and waits for a host reboot. Recovery compares the same manifest and ordered committed prefixes byte-for-byte before reconciling the stale active snapshot to `recoverable`; it also requires no live microphone owner or notification and a non-empty raw-segment fallback plan.
- Added an authentic `MediaCodec` AAC failed-merge test. An injected muxer failure removes the temporary M4A, leaves the manifest, journals, and data files byte-identical, exposes the complete committed timeline through startup recovery/raw fallback, and permits a subsequent clean rebuild.
- Retained and freshly exercised the authentic controlled-truncation matrix for a one-byte tail, mid-frame tail, frame-boundary tail, latest-journal-record truncation, and latest-committed-frame truncation.
- Re-ran cold service-process recreation with microphone permission revoked during recovery. The new process advances the persisted active snapshot to `recoverable`, does not reopen capture, leaves no foreground notification, and rejects a fresh start with `recording_permission_denied`.
- Existing nonce-bound authentic `Process.killProcess` and host `am force-stop` tests remain the native-crash and force-stop coverage. Their recorded Phase 5 evidence recovered and decoded the exact committed AAC prefix with 1.6 seconds of source-to-commit loss.
- Hardened both destructive host runners against residue from an interrupted earlier run. A host `force-stop` clears only stale process/notification state, not application data; every preparation then creates and every recovery verifies a fresh nonce.

## Five-second loss and usability result

The fresh truncation report used `c2.android.aac.encoder`, AAC-LC mono 16 kHz at 64 kbit/s, and 75 frames per durable commit. All five corruption positions recovered the exact authorized prefix, reloaded codec configuration from disk, decoded with full expected-sample coverage (`1.0`), and kept sample counts consistent with recovered frames.

- Maximum simulated crash loss: **4,800,000 µs (4.8 s)**
- Maximum observed commit sync: **2,458 µs**
- Measured risk window: **4,802,458 µs**
- Remaining margin below the five-second requirement: **197,542 µs**
- Required unmeasured scheduling margin: **100,000 µs**, satisfied

This passes the OpenSpec simulated-crash gate on the selected device. It does not turn physical power removal, arbitrary flash-controller loss, or other OEM/firmware combinations into verified claims.

## Verification

| Command or procedure | Environment | Result | Evidence path |
|---|---|---|---|
| `tool/run_recording_device_restart_test.sh`, followed after credential unlock by the emitted nonce-bound recovery command | Selected Redmi, debug + AndroidTest APKs | Device rebooted; same durable fixture recovered; exact manifest hash and all ordered committed prefix records matched; recovery passed `OK (1 test)` | `RecordingDeviceRestartPreparationInstrumentedTest`, `RecordingDeviceRestartRecoveryInstrumentedTest`, `RecordingDeviceRestartFixture` |
| Direct `AuthenticAacTruncationMatrixInstrumentedTest` | Selected Redmi | Passed `OK (1 test)` in 5.752 s; all five scenarios exact-prefix/decode checks passed; max loss 4.8 s | Device-private `files/authentic-aac-truncation-matrix-report.json` (ephemeral); metrics reproduced above |
| Direct `RecordingFailedMergeRecoveryInstrumentedTest` | Selected Redmi | Passed `OK (1 test)` in 0.908 s; authoritative files stayed byte-identical and clean retry succeeded | `RecordingFailedMergeRecoveryInstrumentedTest.kt` |
| `tool/run_recording_service_recreation_test.sh` | Selected Redmi | Preparation produced the required `Process crashed`; microphone-revoked cold recovery passed `OK (1 test)` in 0.13 s | Host command output; runner and two phase-gated instrumented tests |
| Existing authentic native process-kill and force-stop procedures | Same selected device class, Phase 5 | Both independent recovery phases decoded full committed prefixes; each measured 1.6 s source-to-commit loss | `docs/evidence/phase-05-native-audio-spike-partial.md` |
| `flutter analyze` | macOS host, pinned Flutter SDK | No issues | Command output |
| `PATH=<flutter>/bin:$PATH flutter test` | macOS host, pinned Flutter SDK | All 150 tests passed | Command output |
| `./gradlew :app:testDebugUnitTest :app:compileDebugAndroidTestKotlin` | macOS host, JDK 17 | `BUILD SUCCESSFUL` | Gradle output |
| `bash -n` on recording host runners | macOS host | Passed | Command output |
| `openspec validate bootstrap-loquiris-offline-recorder --strict` | macOS host | Change is valid | Command output |
| `git diff --check` | macOS host | Passed | Command output |

The first recovery invocation immediately after the user unlocked credential storage reported `Process crashed`; clearing logcat and immediately repeating the identical recovery command against the same nonce and untouched fixture passed. No assertion failure or authoritative-data mismatch appeared. This is retained as a MIUI post-unlock test-runner timing risk rather than omitted from the evidence.

Independent focused review found no Critical or Important issue in the final foreground-start and host-cleanup changes. Starting `MainActivity` occurs before recording and marker creation, and the preparation still kills the process that owns the real Activity/service. Host `force-stop` does not clear application data; fresh-nonce checks prevent stale fixtures from passing.

## Unverified assumptions

- Physical power removal at an arbitrary flash-write instant remains untested.
- The Phase 15 four-hour production-recorder run remains untested; the earlier one-hour run is preliminary and not release-eligible.
- Results are scoped to the selected `M2104K10AC`/`chopin` firmware and do not establish behavior on other OEMs or filesystems.
- The observed 197.542 ms loss-window headroom is adequate for this measured device/run but remains narrow enough to preserve as a release risk.
- Flutter engine death independent of the Android service process is covered by channel/unit and cold-process behavior, not a separate OEM-level Flutter-engine-only crash injector.

## Risks

- The recoverable AAC design risk is reduced for controlled truncation, process death, force-stop, device reboot, and failed derived merge on the selected device.
- Physical power-loss durability and four-hour stability remain release gates.
- MIUI may transiently fail to start instrumentation immediately after credential unlock; the recovery data remained intact and the identical retry passed.
- GitNexus rates the cumulative dirty Phase 5–7 worktree `CRITICAL` because it spans 41 tracked files and 36 execution flows. Task-specific tests and reviews passed, but this broad scope should be split or reviewed carefully before any commit/PR.

## Recommendation

Proceed to Phase 8 session-library and manual meeting tools. Keep physical power-loss and the full four-hour matrix open for Phase 15, and do not present this Phase 7 result as cross-device or release-complete evidence.
