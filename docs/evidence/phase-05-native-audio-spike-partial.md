# Phase Evidence: Native Audio Architecture Spike (Partial)

## Status

Phase 5 is incomplete and remains experimental. Task 5.1 is implemented and
host-verified. Host-side planning and recovery harnesses now narrow the task
5.3 candidates. The connected device is now the selected physical Android
target by explicit product decision, but tasks 5.2–5.7 still require authentic
audio, playback, repetition, stall, and stability measurements and are not
claimed or checked off.

## Completed

- Added a debug-only `AudioRecord` spike configured for mono 16 kHz PCM16.
- Added audio-session, routed-input, platform timestamp, byte-count, and
  monotonic elapsed diagnostics in a versioned JSON report.
- Added typed stable failures for permission, unsupported PCM configuration,
  initialization, state, read, and file-write failures.
- Added a frame-aligned capture plan, blocking reads bounded to the requested
  byte count, `flush` plus `fd.sync`, and unconditional stop/release cleanup.
- Added a three-second instrumented harness with microphone permission and
  explicit sample-rate, channel-count, PCM encoding, and file-size assertions.
- Added an instrumented AAC codec-capability probe that discovers AAC encoders,
  verifies declared 16 kHz mono AAC-LC 64 kbit/s support, and performs an actual
  configure/start/stop cycle before writing a private JSON report.
- Added a debug-only AAC encode/decode round-trip harness with a deterministic
  two-second speech-band multi-tone fixture. It records codec identities,
  access-unit and byte counts, elapsed times, decoded sample count, delay-aligned
  correlation, SNR, RMS, and whether the alignment search reached its boundary.
  This is a codec-path smoke metric, not a speech-intelligibility or ASR metric.
- Added exact four-hour storage arithmetic and a provisional AAC commit plan.
  Independent review rejected the initial 78-frame/4.992-second interval as
  having insufficient unmodeled margin, so the synthetic harness now commits
  every 75 frames or 4.8 seconds and accounts for measured commit sync time.
- Added a synthetic ADTS complete-frame-prefix recovery scanner for truncated
  or invalid tails.
- Added a debug-only append/commit store whose commit order is data `fd.sync`,
  fixed-size checksummed journal append, then journal `fd.sync`. Recovery
  intersects the last valid monotonic journal record with the complete ADTS
  frame prefix and a cumulative payload checksum.
- Added an AAC access-unit/ADTS frame codec and authentic-payload recovery
  smoke. It encodes the deterministic fixture with the target's `MediaCodec`,
  commits all but one ADTS frame, recovers only the journal-authorized prefix
  from disk, verifies every recovered payload byte against the encoded prefix,
  rebuilds timestamps, and decodes with a fresh codec instance. The encoder's
  AudioSpecificConfig must parse as AAC-LC, 16 kHz, mono before a target-format
  claim is recorded; the fixed recovery config and both codec identities are
  included in the JSON evidence.
- Added an isolated canonical-worker queue and bounded optional-inference queue.
  Capture publication uses non-blocking offers, frames do not expose mutable
  storage, optional work is dropped on overflow, and canonical queue overflow
  or sink failure is surfaced explicitly rather than silently dropping audio.
- Hardened the codec probe so one broken OEM capability query or codec-release
  failure becomes a stable per-candidate failure instead of suppressing the
  complete report.
- Compared recoverable container candidates in
  [`docs/research/recoverable-aac-storage-candidates.md`](../research/recoverable-aac-storage-candidates.md).
  The ADTS/index plus derived-M4A hybrid is only a provisional hypothesis.
- Kept the spike and microphone permission in the debug source set and debug
  manifest. The release APK does not contain network permissions.

## Host Verification

| Command | Result |
|---|---|
| `./gradlew testDebugUnitTest --tests com.loquiris.spike.PcmCapturePlanTest` | Passed, including unsupported-recorder typed-failure coverage |
| `./gradlew testDebugUnitTest --tests 'com.loquiris.spike.*'` | Passed: PCM plan, storage/commit arithmetic, ADTS prefix recovery, codec failure isolation, immutable fan-out, stalled canonical sink isolation, and explicit overflow/failure tests |
| `./gradlew testDebugUnitTest compileDebugAndroidTestKotlin lintDebug` | Passed on 2026-09-29 after the authentic AAC recovery gate was added; 149 tasks, build successful |
| `./gradlew compileDebugAndroidTestKotlin` | Passed |
| `./gradlew lintDebug` | Passed; no spike warnings or errors |
| `flutter build apk --release` | Passed; 56.5 MB APK |
| `bash tool/check_release_privacy.sh build/app/outputs/flutter-apk/app-release.apk` | Passed; release APK has no network permission |
| Independent native-boundary review | Passed after the unsupported-configuration failure path was added |
| Independent Phase 5 spike re-review | Passed after immutable PCM ownership, isolated canonical worker, explicit overload/failure results, and per-codec exception isolation; no remaining Critical/Important findings |
| `openspec validate bootstrap-loquiris-offline-recorder --type change --strict --json --no-interactive` | Passed; 1 change, 0 issues |

## Physical-Device Procedure

With the selected target connected and authorized:

```sh
cd android
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.AudioRecordSpikeInstrumentedTest
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.AacCodecCapabilityProbeInstrumentedTest
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.AacRoundTripSpikeInstrumentedTest
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.AacAdtsRecoverySpikeInstrumentedTest
adb shell run-as com.loquiris.debug \
  cat files/audio-record-spike-report.json
adb shell run-as com.loquiris.debug \
  cat files/aac-codec-capability-report.json
adb shell run-as com.loquiris.debug \
  cat files/aac-round-trip-report.json
adb shell run-as com.loquiris.debug \
  cat files/aac-adts-recovery-report.json
```

The abrupt-termination tests are intentionally host-orchestrated and skipped
unless their phase argument is present. Keep the target and test APK installed
between preparation and recovery:

```sh
RUN_NONCE=pk-20260929-1115-a
adb shell am instrument -w -r \
  -e loquirisAbruptPhase process-kill-prepare \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AdtsProcessKillPreparationInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
# Expect: INSTRUMENTATION_RESULT: shortMsg=Process crashed.
adb shell am instrument -w -r \
  -e loquirisAbruptPhase process-kill-recover \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AdtsProcessKillRecoveryInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner

RUN_NONCE=fs-20260929-1116-a
adb shell am instrument -w -r \
  -e loquirisAbruptPhase force-stop-prepare \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AdtsForceStopPreparationInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
# From a second host shell, only after the private ready file exists:
adb shell run-as com.loquiris.debug \
  cat files/adts-force-stop/generation-complete
# Verify the first marker line exactly equals the fresh nonce before stopping.
adb shell am force-stop com.loquiris.debug
# Expect the preparation shell to report Process crashed, then run recovery:
adb shell am instrument -w -r \
  -e loquirisAbruptPhase force-stop-recover \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AdtsForceStopRecoveryInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
```

Do not interpret the preparation process crash as a test failure: abrupt
termination is the injected condition. Conversely, do not accept preparation
alone as evidence; the independent recovery phase must pass, match the fresh
nonce and generated watermark, report the expected committed prefix, and
consume the completion marker. A nonce mismatch or missing marker is a failed
run, not a reason to reuse an older fixture.

The report-extraction `run-as` commands are valid only when the debug
application is still installed. The default connected-test lifecycle uninstalls
the test and target
packages after execution, so it preserves the JUnit XML and per-test logcat
under `build/app/outputs/androidTest-results/connected/` but removes the private
PCM and JSON files. A full private report therefore requires a manual debug/test
APK installation and direct instrumentation run, followed by extraction before
uninstall. Do not treat a post-cleanup `unknown package` error as a failed test.

The report may include the routed device's product name, which can be
user-authored for Bluetooth devices; treat it as sensitive test evidence and do
not publish it without review.

## Selected-Target Device Evidence

Earlier on 2026-09-28, no Android device was connected. A later check detected
one Xiaomi `M2104K10AC` (`chopin`) device with Android 13/API 33, MIUI 14 build
`V14.0.8.0.TKPCNXM`, 2023-11-01 security patch, and about 5.36 GiB reported
RAM. A fresh fingerprint reported raw platform `mt6893`, market name Redmi Note
10 Pro, verified-boot state `green`, and about 107 GiB usable `/data`, consistent
with the observed 6GB+128GB class. By explicit product decision on 2026-09-29,
OpenSpec now designates this exact `M2104K10AC`/`chopin` device as the release-
gate target. Results remain scoped to this hardware and firmware.

The first sequential AAC instrumented run did not install or execute. Gradle
reported zero tests and `INSTALL_FAILED_USER_RESTRICTED: Install canceled by
user` while installing the debug APK. No codec or microphone conclusion is
drawn from that attempt.

A second sequential attempt on 2026-09-28 reproduced the same failure. Read-only
diagnostics found no effective user restriction, no device/profile owner,
`adb_enabled=1`, `install_non_market_apps=1`, and ADB package verification
disabled. MIUI logs showed its `AdbInstallActivity` opening while
`isKeyguardLocked=true`, followed by `Install canceled by user`. This narrows
the immediate blocker to completing the MIUI on-device installation approval
while the phone is unlocked; it is not a codec-test failure.

On 2026-09-29, the phone was awake and unlocked and both tests ran separately:

| Selected-target command | Result |
|---|---|
| `connectedDebugAndroidTest` for `AacCodecCapabilityProbeInstrumentedTest` | Passed 1/1. At least one encoder declared and successfully configured/started for AAC-LC, 16 kHz, mono, 64 kbit/s. This does not measure encode/decode quality. |
| `connectedDebugAndroidTest` for `AudioRecordSpikeInstrumentedTest` | Passed 1/1 in 3.339 s. Assertions verified PCM16, 16 kHz, mono, exactly 96,000 captured/file bytes for the requested three seconds. |
| One combined invocation selecting both instrumented classes | Passed 2/2 with zero failures, errors, or skips. Persisted XML records 0.121 s for the AAC probe and 3.477 s for capture. |
| Direct instrumentation for `AacRoundTripSpikeInstrumentedTest` | Passed after manual APK installation. The final EOS-corrected report records `c2.android.aac.encoder` and `c2.android.aac.decoder`, 31 access units, 15,872 encoded bytes, 31,744 decoded samples, 330 ms encode, 189 ms decode, 2,048-sample alignment lag, 29,696 aligned samples, 92.8% reference coverage, a 99.2% decoded/input sample ratio, 0.99998097 correlation, 43.61 dB SNR, an unclipped 4,096-sample alignment search, and actual 16 kHz/mono decoder output. |
| Direct instrumentation for `AacAdtsRecoverySpikeInstrumentedTest` | Passed 1/1 in 0.926 s after review-gate hardening. `c2.android.aac.encoder` produced 31 authentic access units; the store committed 30 and retained one uncommitted tail. Recovery read the data and journal files, returned exactly 30 payloads / 15,570 bytes, discarded the 519-byte tail from 16,089 durable bytes, and matched the original committed payload prefix byte-for-byte. A fresh `c2.android.aac.decoder` produced 30,720 samples at 16 kHz mono with 1.0 expected-sample coverage and RMS 5,731.44. Encoder and fixed recovery ASC were both `1408`, parsed as AAC-LC / 16 kHz / mono. This remains a deterministic synthetic-input codec/storage smoke, not real-speech, playback, or abrupt-termination acceptance. |
| Direct instrumentation selecting capability, microphone capture, and AAC round trip together | Passed 3/3 in the latest 5.253 s run after manual APK installation and explicit debug microphone grant. This run verifies the three spike paths coexist on the selected target; it does not establish authorized real-speech quality or long-duration stability. |
| Direct instrumentation for `AdtsDurabilitySpikeInstrumentedTest` | Initial 78-frame run passed 1/1 in 0.112 s, but independent review found its 8 ms raw margin unsafe because the loss calculation omitted commit synchronization and queue/scheduling delay. The corrected 75-frame run passed 1/1 in 0.079 s. Eight synthetic fault cases preserved the expected committed prefix; maximum media loss was 4.8 s, maximum measured commit sync was 3.884 ms, the combined measured risk window was 4.803884 s, and 196.116 ms remained before the five-second limit. The gate reserves at least 100 ms for still-unmodeled delay. This uses fixed-size synthetic ADTS frames and controlled byte truncation, not MediaCodec output or an actual process death. |
| Host-orchestrated `Process.killProcess` preparation and recovery | Preparation wrote 224 synthetic ADTS frames, durably committed frames 1–150, left frames 151–224 uncommitted, then synced a generation-complete marker containing a fresh host nonce and watermarks before terminating its own instrumentation process without closing the store. Android reported `Process crashed`. A wrong-nonce recovery was observed to fail; the matching separate process recovered exactly 150 frames / 19,200 bytes / 153,600 samples, passed 1/1 in 0.055 s, and consumed the marker. The discarded 74-frame tail represents 4.736 s. |
| Host-orchestrated `am force-stop com.loquiris.debug` preparation and recovery | Preparation created the same 150-frame durable prefix and 74-frame tail, synced a nonce-bound generation-complete marker, and retained a strong reference to the open store while waiting. The host verified the marker nonce and issued `am force-stop`; Android reported `Process crashed`. A matching separate recovery process passed 1/1 in 0.078 s with the same 150-frame prefix and 4.736 s modeled loss, then consumed the marker. |
| Abrupt-test ordinary-suite isolation | Selecting all four preparation/recovery classes without the explicit `loquirisAbruptPhase` argument completed `OK (4 tests)` with four assumption skips. The normal connected suite therefore cannot accidentally kill its own runner; host orchestration must opt into each destructive phase. |

The captured per-test logcat independently records `AudioRecord` and
`AudioFlinger` opening at 16 kHz, PCM16, one channel, audio session 241, starting
successfully, and stopping cleanly. These results establish selected-target
spike compatibility only. The Gradle lifecycle removed the private reports
before host extraction; no unrecorded codec identity or route-product value is
inferred. The later direct round-trip workflow intentionally kept both packages
installed until `aac-round-trip-report.json` was extracted. The first direct
run exposed an OEM behavior where decoder output omitted the optional
`KEY_PCM_ENCODING`; treating the absent key as Android's PCM16 default while
still rejecting an explicitly different encoding made the same test pass.
Independent review then identified possible false passes from short decoded
prefixes, missing codec-config-buffer fallback and timestamp/format checks, and
cleanup failures that could be swallowed or overwrite the primary failure. The
harness now gates reference coverage and decoded/input sample ratio, reports a
truncated alignment search, accepts CSD from either output format or codec-config
buffers, requires strictly increasing encoder/decoder timestamps, verifies the
actual decoder sample rate/channel count, and preserves primary plus suppressed
stop/release failures while always attempting release.
The final review also found that the decoder EOS initially reused the final
access-unit PTS. The harness now derives EOS from total input samples and sample
rate, proves it follows the last access unit, and covers that contract with a
unit test before queueing the empty EOS buffer.

The corrected synthetic durability run exercised tails of 8, 75, 78, and 80
frames, three byte-level truncations inside a 75-frame uncommitted tail, and a
one-byte truncation of the latest journal record. In every case recovery kept
the expected preceding commit. The worst case deliberately discarded one
75-frame commit after its journal record was torn, corresponding to 4.8 seconds
at 16 kHz with 1,024 samples per AAC frame. Its risk calculation adds the
largest measured two-sync commit duration and requires 100 ms of additional
unmodeled headroom. This is positive evidence for the proposed interval and
journal format, but not acceptance evidence for task 5.3 or the five-second
release gate. Self-process kill and host `am force-stop` now preserve the
synthetic committed prefix on the selected target. Authentic `MediaCodec`
payloads have separately passed one normal-process ADTS commit/recovery/decode
cycle, but the combination of authentic payloads with abrupt termination, a
continuous producer with encoder/queue backlog, recovered playback,
directory-entry durability, and repeated controlled offsets remain untested.

The following remain unverified:

- resampling behavior on alternate input routes of the selected target;
- retained full private route and timestamp reports across repeated runs;
- authorized real-speech AAC-LC 64 kbit/s listening, intelligibility, and ASR
  quality on the selected target; codec availability and synthetic round trip
  have passed;
- authorized real-speech listening, intelligibility, and downstream ASR-quality
  measurements on the selected target; the synthetic round trip proves only
  that this target's codec path is functional;
- recoverable AAC/container behavior using authentic MediaCodec AAC payloads
  under repeated force-stop, process-kill, and controlled-truncation offsets;
  a normal-process authentic-payload commit/recovery/decode cycle and synthetic
  fixed-frame abrupt/truncation mechanisms have each passed once, separately,
  on the selected target;
- maximum recoverable loss, gap-free playback, and five-second loss gate;
- encoder and bounded inference fan-out behavior under artificial stalls.

## Recommendation

- Complete the remaining intake record for this selected target, including
  battery health/cycles where available, formal off-charger configuration,
  memory-extension state, ambient temperature, and installed build hash.
- Continue task 5.2 with authorized real-speech AAC listening/intelligibility
  and downstream ASR-quality measurements on this exact device and firmware.
- Use the persisted JUnit/logcat artifacts for connected-test evidence; use the
  manual instrumentation workflow only when the full private JSON is required.
- Do not select a canonical AAC container or begin phase 6 until tasks 5.2–5.6
  have real device evidence and the five-second loss gate passes.
