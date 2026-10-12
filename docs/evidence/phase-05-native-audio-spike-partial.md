# Phase Evidence: Native Audio Architecture Spike

## Status

Phase 5 is complete for its bounded implementation-selection scope. The
selected target has repeated authentic AAC kill/force-stop evidence, a controlled-offset
truncation matrix, directory-synced manifest recovery, final M4A rebuild, and
human playback evidence. Task 5.2 includes objective measurements from one
explicitly authorized real-speech fixture plus a complete listening pass; this
does not claim downstream ASR accuracy. The Phase 5 measured five-second gate
passed with a worst authentic media-plus-sync window of 4.800739 seconds.
Production end-to-end and four-hour release gates remain in phases 7 and 15.

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
- Added a five-case authentic MediaCodec AAC truncation matrix covering one
  byte after the durable prefix, a partial tail frame, an exact tail-frame
  boundary, a one-byte tear of the latest journal record, and a one-byte tear
  of the latest committed frame. Each case records exact pre/post lengths and
  scanner state, reloads synced codec configuration from disk, verifies the
  recovered payload prefix byte-for-byte, and decodes it through a fresh
  decoder. The budget combines media rollback with measured commit sync and
  reserves at least 100 ms for unmodeled delay.
- Added an isolated canonical-worker queue and bounded optional-inference queue.
  Capture publication uses non-blocking offers, frames do not expose mutable
  storage, optional work is dropped on overflow, and canonical queue overflow
  or sink failure is surfaced explicitly rather than silently dropping audio.
  Queue metrics now include a canonical high-water mark.
- Added a 304-second single-session AAC encode and recoverable-container spike.
  It atomically publishes a manifest containing the complete codec-specific
  data file list and ordered segment paths, validates frame/sample journal
  watermarks, ignores an injected unpublished next-segment write, rebuilds and
  fully decodes M4A, and probes four muted Android `MediaPlayer` positions for
  seek completion plus playback-clock advancement across the first commit and
  logical-segment boundaries.
- Replaced the initial batch-encoder baseline with a paced 20 ms producer whose
  canonical consumer is a single continuously configured `MediaCodec` AAC
  encoder. The canonical queue is limited to 25 frames (500 ms), while a
  deliberately undrained two-frame inference queue drops optional work. The
  report records producer deadlines and lateness, publication percentiles,
  canonical backlog, sequence gaps, concurrent codec progress, encoded access
  units, and fresh-decoder sample coverage. Full inference queues no longer
  allocate copies for frames that will be dropped.
- Hardened the codec probe so one broken OEM capability query or codec-release
  failure becomes a stable per-candidate failure instead of suppressing the
  complete report.
- Compared recoverable container candidates in
  [`docs/research/recoverable-aac-storage-candidates.md`](../research/recoverable-aac-storage-candidates.md).
  The ADTS/index plus derived-M4A hybrid is selected for Phase 6 implementation;
  it is not approved for recorder release until the later release gates pass.
- Kept the spike and microphone permission in the debug source set and debug
  manifest. The release APK does not contain network permissions.

## Host Verification

| Command | Result |
|---|---|
| `./gradlew testDebugUnitTest --tests com.loquiris.spike.PcmCapturePlanTest` | Passed, including unsupported-recorder typed-failure coverage |
| `./gradlew testDebugUnitTest --tests 'com.loquiris.spike.*'` | Passed: PCM plan, storage/commit arithmetic, ADTS prefix recovery, codec failure isolation, immutable fan-out, stalled canonical sink isolation, and explicit overflow/failure tests |
| `./gradlew testDebugUnitTest compileDebugAndroidTestKotlin lintDebug` | Passed on 2026-09-29 after the authentic AAC recovery gate was added; 149 tasks, build successful |
| `./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.M4aRebuildSpikeInstrumentedTest testDebugUnitTest compileDebugAndroidTestKotlin lintDebug` | Passed on 2026-09-29; target test 1/1, 249 tasks, build successful in 1m 22s |
| `assembleDebug assembleDebugAndroidTest testDebugUnitTest compileDebugAndroidTestKotlin lintDebug` followed by direct real-speech instrumentation | Passed on 2026-09-30; host build/lint/unit gates passed and selected-target test passed 1/1 in 68.483 s after actual encoder AudioSpecificConfig verification and private-fixture cleanup hardening |
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
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.PcmEncoderFanOutSpikeInstrumentedTest
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.loquiris.spike.M4aRebuildSpikeInstrumentedTest
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

RUN_NONCE=auth-fs-20260929-a
adb shell am instrument -w -r \
  -e loquirisAbruptPhase authentic-force-stop-prepare \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AuthenticAacForceStopPreparationInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
# From a second shell, verify the first marker line equals RUN_NONCE:
adb shell run-as com.loquiris.debug \
  cat files/authentic-aac-force-stop/generation-complete
adb shell am force-stop com.loquiris.debug
adb shell am instrument -w -r \
  -e loquirisAbruptPhase authentic-force-stop-recover \
  -e loquirisRunNonce "$RUN_NONCE" \
  -e class com.loquiris.spike.AuthenticAacForceStopRecoveryInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
adb shell run-as com.loquiris.debug \
  cat files/authentic-aac-force-stop/recovery-report.json
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
| Host-orchestrated authentic AAC `Process.killProcess` preparation and recovery | Passed after review-gate hardening. Preparation encoded 256,000 deterministic source samples (16 s) through `c2.android.aac.encoder`, verified 1.0 source-sample coverage, generated 250 variable-length authentic AAC access units, committed 225 frames / 230,400 samples / 116,775 bytes, persisted source and codec watermarks, then terminated without closing the store; Android reported `Process crashed`. The nonce-matched independent recovery process passed 1/1 in 0.772 s, recovered from data/journal/marker only, calculated 1.6 s source-to-committed loss, and decoded 230,400 samples with 1.0 coverage and RMS 6,264.49 through `c2.android.aac.decoder`. ASC was `1408`. This is one self-process-kill run with synthetic PCM input, not real microphone speech, repeated-offset, or playback acceptance. |
| Host-orchestrated `am force-stop com.loquiris.debug` preparation and recovery | Preparation created the same 150-frame durable prefix and 74-frame tail, synced a nonce-bound generation-complete marker, and retained a strong reference to the open store while waiting. The host verified the marker nonce and issued `am force-stop`; Android reported `Process crashed`. A matching separate recovery process passed 1/1 in 0.078 s with the same 150-frame prefix and 4.736 s modeled loss, then consumed the marker. |
| Host-orchestrated authentic AAC `am force-stop com.loquiris.debug` preparation and recovery | Passed 1/1 in the independent recovery phase. The host verified fresh nonce `auth-fs-20260929-a` plus 256,000 source samples, 250 generated frames, 225 committed frames, 129,750 prepared bytes, encoder identity, and ASC before issuing `am force-stop`; the waiting preparation instrumentation then reported `Process crashed`. Recovery used the isolated authentic-force-stop directory and recovered 225 frames / 230,400 samples / 116,775 committed bytes, calculated 1.6 s source-to-committed loss, and decoded 230,400 samples with 1.0 coverage and RMS 6,264.49 in 0.831 s. This is one force-stop run with deterministic PCM input, not repeated-offset, microphone-speech, or playback acceptance. |
| Authentic AAC controlled-truncation matrix | Passed 1/1 in 2.255 s after TDD and review hardening. Five authentic variable-length AAC cases recovered the expected 150-frame / 153,600-sample / 77,850-byte prefix with byte-identical payloads and 1.0 decode coverage. Exact scanner results were: committed-prefix+1 byte = 150 complete frames / 1 trailing byte; mid-frame = 187 / 259; frame boundary = 187 / 0; latest journal tear = 225 complete frames with journal 168→167 bytes; latest committed-frame tear = 224 complete frames / 518 trailing bytes with data 116,775→116,774 bytes. Worst media rollback was 4.8 s, maximum measured authentic commit sync was 739 us, measured risk was 4.800739 s, and 199.261 ms remained before five seconds while the gate requires at least 100 ms. Every scenario reloaded synced ASC `1408` from disk before decoding. |
| Repeated authentic AAC `Process.killProcess` matrix | Three fresh nonce-bound prepare/recover cycles passed 3/3. Every preparation ended with Android `Process crashed`; every independent recovery returned 225/250 frames, 230,400/256,000 samples, 116,775 committed bytes, 1.6 s source-to-commit loss, 1.0 decode coverage, and RMS 6,264.49. |
| Repeated authentic AAC `am force-stop` matrix | Three fresh nonce-bound cycles passed 3/3. The host waited for and verified each durable marker before force-stop; each preparation then reported `Process crashed`, and every independent recovery produced the same 225-frame prefix, 1.6 s loss, 1.0 decode coverage, and RMS 6,264.49. |
| Stalled-inference concurrent encoder/fan-out gate (task 5.5) | Passed repeated selected-target runs after a failing 5 ms max-publication experiment exposed scheduler/allocation outliers. The final design paced 800 × 20 ms PCM frames over 16 seconds into a 25-frame canonical queue whose worker continuously fed one `c2.android.aac.encoder`; the two-frame inference queue was never drained. Every passing run accepted/processed 800/800 canonical frames with zero rejection, zero sequence gaps, zero missed producer deadlines, byte-identical PCM, 250 access units / 128,000 bytes, and 1.0 encoded plus decoded sample coverage while inference accepted 2 and explicitly dropped 798. Early passing runs recorded exact 16.000 s production, canonical high-water 2–3/25, producer max lateness 1.544–2.676 ms, publication p95 0.561–0.694 ms and max 10.813–13.928 ms, and codec lifetimes 15.961–16.006 s. Review then required distinct MediaCodec drain states and exact queue high-water synchronization. After both blocker fixes, a fresh run passed with 16.001 s production, exact high-water 2/25, 2.057 ms max lateness, 0.435/0.719/14.339 ms publication p50/p95/max, and 15.970 s codec lifetime. Gates are p95 <5 ms, max <15 ms (75% of one frame period), max producer lateness <5 ms, and no 20 ms deadline miss. This proves artificial inference stalls do not back-pressure the synthetic paced PCM-to-encoder path on this target; it is not AudioRecord or long-duration evidence. |
| Deterministic two-segment recovery and M4A rebuild (task 5.3 evidence) | Passed on the selected target. One continuous `MediaCodec` session encoded 4,864,000 deterministic PCM samples / 304.000 s into 4,750 authentic AAC AU (fresh directory-sync run: 36.092 s), then wrote authoritative ADTS/journal segments containing 4,650 and 100 frames. The first has 62 × 75-frame commits; the second has a 75-frame commit plus a final 25-frame commit. Manifest publication syncs the temporary file, atomically replaces the manifest, then opens and `fsync`s the parent directory; the selected-target report records all three expected directory syncs. Recovery validates committed-sample watermarks of 4,761,600 and 102,400, ignores an injected uncommitted next-segment file before manifest publication, and reproduces the encoded payload timeline byte-for-byte before remux. The derived M4A is 2,454,905 bytes. `MediaExtractor` returned 4,750/4,750 payloads byte-for-byte; every AU PTS matched the exact cumulative-sample value from 0 through 303.936 s with a 64 ms maximum delta, extractor duration was 304.000 s, and fresh-decoder coverage was 1.0. Muted Android `MediaPlayer` reported 304.000 s and advanced its playback clock after seeking to 0, 4.8, 297.6, and 302 s. The user separately played the complete retained boundary M4A and reported complete playback with no audible anomaly. `afinfo` independently reported 4,750 packets at 64 kbit/s, 303.868 s estimated playable duration, and one global 2,112-frame priming region; the 132 ms container trim estimate did not produce a reported audible gap. This does not simulate physical power removal or process death at the exact rotation instruction, which remain broader stability/fault-injection limits rather than unrecorded claims. |
| Authorized real-speech AAC quality (task 5.2) | Passed the objective selected-target gate on 2026-09-30 using one explicitly authorized local 302.741 s, 48 kHz stereo AAC source. The harness decoded and downmixed it to 16 kHz mono, encoded 4,730 access units at a requested 64 kbit/s through `c2.android.aac.encoder` in 39.144 s, parsed actual encoder AudioSpecificConfig `1408` as AOT 2 / 16 kHz / mono, decoded them through `c2.android.aac.decoder` in 8.698 s, and rebuilt a 2,444,646-byte M4A. Delay-aligned comparison found a 2,048-sample lag, 99.9507% reference coverage, 0.999930 decoded/reference sample ratio, 0.999023 correlation, and 26.864 dB SNR without clipping the alignment search. The hardened test passed 1/1 in 68.483 s. The user then listened to the exported generic-name copy and reported no incomplete playback, discontinuity, repetition, click, or obvious distortion. Later runs require a separate publish argument and rollback a failed pending insert. The source fixture is staged only in app-private cache, deleted after the run, and absent from both the regenerated androidTest APK and production APK. No source filename, speech content, transcript, or speaker identity is recorded in project evidence. This is one codec round-trip fixture, not an ASR result or population-level claim. |
| Abrupt-test ordinary-suite isolation | Selecting the four synthetic preparation/recovery classes without the explicit `loquirisAbruptPhase` argument completed `OK (4 tests)` with four assumption skips. The two authentic AAC process-kill classes completed `OK (2 tests)` in 0.032 s and the two authentic AAC force-stop classes completed `OK (2 tests)` in 0.039 s, all with assumption skips. The normal connected suite therefore cannot accidentally kill its own runner; host orchestration must opt into each destructive phase. |

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
unmodeled headroom. Together with the later manifest-directory sync, rebuild,
platform playback probes, and complete human playback evidence, this supports
task 5.3; it is one component of the Phase 5 five-second gate rather than a
claim about later production end-to-end release tests.
Self-process kill and host `am force-stop` preserve the synthetic
committed prefix on the selected target. Authentic `MediaCodec` payloads have
passed normal-process recovery, five controlled truncation offsets, three
self-process-kill cycles, and three host force-stop cycles. A continuous
producer with real AudioRecord input and physical power removal remain untested.
Recovered playback and file/manifest/parent-directory sync ordering have passed.
The synthetic paced producer and encoder/queue backlog gate passed under an
artificial inference stall.

The following remain unverified:

- resampling behavior on alternate input routes of the selected target;
- retained full private route and timestamp reports across repeated runs;
- downstream ASR-quality measurements remain a transcription-engine concern;
  task 5.2 codec metrics and human listening have passed on the selected target;
- physical power removal and process death at the exact manifest-rotation
  instruction; file/manifest fsync ordering, unpublished-segment rejection,
  full decode/player probes, and complete human playback have passed;
- production end-to-end maximum recoverable loss and the later release gate;
  the Phase 5 measured gate passed, while exact-rotation death and phases 7/15
  long-run evidence remain open;
- real `AudioRecord`-to-encoder backlog behavior over long duration; task 5.5
  covers a deterministic paced PCM producer and artificial inference stall.

## Recommendation

- Complete the remaining intake record for this selected target, including
  battery health/cycles where available, formal off-charger configuration,
  memory-extension state, ambient temperature, and installed build hash.
- Use the task 5.2 AAC fixture as an input to downstream ASR-quality measurements
  when an engine spike exists; do not reinterpret codec quality as ASR accuracy.
- Use the persisted JUnit/logcat artifacts for connected-test evidence; use the
  manual instrumentation workflow only when the full private JSON is required.
- Implement Phase 6 with the selected ADTS/journal/directory-synced-manifest
  layout and preserve every measured ordering/recovery invariant; do not treat
  selection as a substitute for the required four-hour release evidence.
