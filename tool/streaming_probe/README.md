# Standalone streaming development probe

This tool is **not** linked into the app, a release input, an untrusted model/WAV
importer, or an accuracy/latency qualification harness. It reads an existing local
mono 16-bit 16 kHz WAV through the pinned sherpa-onnx C API. It never opens a
microphone, installs an APK, grants permissions, downloads files, or writes audio.

Both candidate families use 3,200-sample chunks, CPU / one thread / greedy search,
80-dimensional features, and endpoint detection enabled with 2.4 / 1.2 / 20-second
rules. These are explicit development settings, not qualified product defaults.
The model families may implement endpoint detection differently despite identical
requested thresholds. Recognizer and stream creation are separate from feed timing.

Build against the already verified **1.13.8** local development runtime:

```sh
/Users/bytedance/Library/Android/sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android29-clang++ \
  -std=c++17 -O2 -Wall -Wextra -Werror -static-libstdc++ \
  -Ibuild/streaming_spike/runtime/include \
  tool/streaming_probe/streaming_probe.cc \
  -Lbuild/streaming_spike/runtime/jniLibs/arm64-v8a -lsherpa-onnx-c-api \
  -Wl,-rpath-link,build/streaming_spike/runtime/jniLibs/arm64-v8a \
  -o build/streaming_spike/streaming-common-probe
```

CLI: `streaming-common-probe zipformer|paraformer wav encoder decoder tokens
joiner|- [paced]`. Paraformer uses `-` instead of a joiner. The WAV is capped at
20 MiB before decoding and at ten minutes after decoding. Model inputs must be
trusted, preverified local files; upstream native assertions can terminate this
standalone process. This is why the probe does not run in the recorder process.

Default feed is unpaced. `paced` waits until each full chunk is available on a
steady file clock that starts **after model loading**. It neither skips audio nor
pretends the file clock is the first voiced sample. It is not a live capture queue
or a backlog benchmark. A final 4,800-sample silence pad is accounted separately
from unique input audio. Input-finished flush runs before stream/recognizer/wave
destruction. Nonempty partial/final JSONL includes sequence, utterance identity and
the number of real input samples delivered so far (not a word boundary).

Metrics are intentionally narrow:

- `first_nonempty_ms_from_feed_start` is not first-voiced, UI delivery or p95.
- `accept_decode_result_ms` includes accept/decode/result/endpoint/event work and
  tail flush, but not paced sleeping or model loading.
- `processing_to_file_duration_ratio` uses total file duration, including silence;
  it is not a speech-bearing sustained RTF qualification.
- `release_calls_completed` means void C-API destroy calls returned. It does not
  prove RSS recovery, absence of leaks or physical native release under a hang.

## Opt-in device regression

The test only executes a previously pushed executable in the task-specific
`/data/local/tmp/loquiris-streaming-spike-20261015` directory. It assumes the pinned
runtime, both model sets and immutable 45-second fixture already exist there.
The historical `...zipformer-en-20M...` directory name is an alias; actual file
hashes, not that name, identify the bilingual development candidate. Paraformer
uses the eligible `paraformer-published` tree, not the earlier incompatible files.

After separately authorizing device access and pushing the compiled executable:

```sh
LOQUIRIS_STREAMING_PROBE_DEVICE=<authorized-serial> \
ADB=/Users/bytedance/Library/Android/sdk/platform-tools/adb \
python3 -m unittest discover -s tool/streaming_probe -v
```

The suite performs two unpaced model runs and one 45-second paced Zipformer run.
Each subprocess has a 90-second timeout. With no selected device the tests are
explicitly skipped, not evidence of a device pass. The fixture smoke test checks
sample accounting, nonempty partial/final events, endpoint/utterance sequencing,
JSON parsing, release-call completion and no delivery of future file-clock audio.
It has no human reference transcript and makes no accuracy assertion.

Hashes, actual test failures/results and remaining gates are recorded in
[`implementation-status.md`](../../docs/evidence/streaming-two-pass/implementation-status.md).

## Separate debug JNI file-input experiment

The standalone executable above remains separate. An additional app experiment
lives exclusively in `android/app/src/debug`: `StreamingNativeKernelProbeService`
runs in `:streaming_native_probe`, adapts canonical PCM through
`StreamingPcmKernel`, and uses a small versioned JNI bridge to the pinned C API.
The default `StreamingInferenceService` remains model-unavailable. No microphone
or user-facing live selection is enabled by this experiment.

`-PloquirisStreamingNativeSpike=true` is an explicit **debug-only** Gradle opt-in.
Normal debug, profile and release builds do not package the experiment's native
libraries. CMake verifies the input header/C-API/ONNX hashes before building.
Android's packaging may strip native ELF metadata; record the actual packaged
library hash separately from the source-runtime hash. This is not permission to
redistribute the candidate or evidence that a model pair is qualified.

The development service accepts only the fixed fixture key `"1".repeat(64)`
(not a production manifest digest). It resolves four fixed names under the
app-private `files/streaming-native-spike-20261016` directory and checks lengths,
canonical paths and pinned SHA-256 values before native allocation. It never
accepts caller-supplied model paths. The framework-provided filesDir parent is
canonicalized first because Android can alias `/data/user/0` to `/data/data`
inside the app process. Fixture-directory/file redirection is still rejected.
These trusted, task-owned fixtures are not a concurrent untrusted import API.

The instrumentation test requires this opt-in build and the already verified
`fixture.wav` plus `encoder.onnx`, `decoder.onnx`, `joiner.onnx`, `tokens.txt`.
The WAV remains the same immutable 45-second smoke input. Creating these private
fixtures or installing APKs requires separate device authorization, a verified
backup, matching signatures, and in-place installation without clearing data.
Nothing in the standalone test command performs these steps.

With an authorized debug/test APK already installed, run only the scoped tests:

```sh
adb -s <authorized-serial> shell am instrument -w \
  -e class com.loquiris.transcription.StreamingRemoteProcessInstrumentedTest,com.loquiris.transcription.StreamingNativeKernelInstrumentedTest \
  com.loquiris.debug.streamingtest/androidx.test.runner.AndroidJUnitRunner
```

The side-by-side test package above requires
`-PloquirisIsolatedStreamingIpcTests=true`. Without the native-spike opt-in, the
real-model test is explicitly skipped. ADB's process exit code alone is not a
test result: inspect the instrumentation `OK`/failure summary. The native test
checks all 225 chunks / 720,000 real samples, nonempty text, endpoint resets,
separate process identity and release acknowledgement. JNI ABI 2 adds an explicit
finish operation that shares the single in-flight slot with PCM. It flushes a
4,800-sample context tail, destroys the finished stream and creates a new stream
on the same recognizer, without advancing canonical media positions. Explicit
finish also creates a fresh stream immediately after a natural endpoint, whose
ordinary Reset retains context. Empty/repeated finish never repeats old text.
The added device cases check an unfinished prefix across a media gap and compare
the endpoint→finish→gap path against an untouched fresh stream. They do not
constitute language accuracy measurements. Close remains cancellation/release
without implicit final text. Recorder pause/focus/stop orchestration and Dart/UI
lifecycle integration are still separate work. No accuracy, latency percentile
or RSS-recovery qualification is asserted.

The file-input suite additionally exercises `StreamingPcmConsumer` over the real
Messenger/JNI path. Its blocking PCM/finish calls belong only on an inference
worker, never a microphone or UI callback. It reconciles matching replies into
owner-scoped capture events, finishes before admitting forward gaps/new capture
epochs, and distinguishes explicit STOP from cancellation. Close is independent
of the worker lock and acknowledges only remote release plus completion of
already-started event/degradation callbacks. Those callbacks may request close,
but must not synchronously wait for their own close acknowledgement. This
primitive is not yet registered with the actual recorder or Dart event channel.

### Authorized microphone smoke (manual coordination required)

`StreamingMicrophoneInstrumentedTest` is a separate native-pipeline smoke, not
part of the file-input command above. It requires both the native-spike build
and the explicit instrumentation argument `authorizedMicrophone=true`, plus an
already granted microphone permission. The test does not grant permission itself.
Run it only after fresh human readiness confirmation and agreed test audio.
It captures roughly 10 seconds, pauses for one second, then captures another
10 seconds through AudioRecord, the existing AAC pipeline and the real remote
JNI consumer. Its short control samples are not a latency percentile.

The test creates a unique app-private `streaming-mic-<UUID>` directory and keeps
that new recording/report. It never invokes the old destructive test reset or
deletes existing recordings. Initialization failure retains independent cleanup
responsibility until the pipeline adopts the source/encoder; every cleanup is
attempted independently, preserving the original failure. Finish waits are
harness-bounded, but a timeout is never resource-release acknowledgement.
The report contains counts and explicit assertion/cleanup status, not raw text.
Its canonical-completeness assertion covers accepted/processed frame counts and
a readable manifest, not an independently decoded sample-by-sample AAC audit.
This test alone does not verify Dart/UI delivery, code-switch accuracy, long-run
resource limits or production eligibility.

The new Dart `streaming_v1` adapter and mirrored Kotlin contract remain
unregistered foundations. Their unit-tested lifecycle preserves real native
release ownership, cancellation fences, and early final/gap delivery. The
first-listener buffer is bounded to 64 text/gap events; overflow requests
degradation and closure, never a fabricated release ACK. They do not yet turn
the microphone smoke above into a Dart/UI integration test.

### Debug Dart file-channel smoke

Later debug-only registration is provided by `StreamingDebugBridge` behind
DEBUG plus `loquirisStreamingNativeSpike=true`. The physical-device case is
`integration_test/streaming_channel_round_trip_test.dart`, driven by
`test_driver/streaming_channel_driver.dart`. It requests only
`debug-native-file-probe` and canonical inventory digest
`18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b`.
No arbitrary paths, PCM, microphone access or model selection cross this seam.
It validates real Dart/native finals and a canonical pause gap using two reused
four-second prefixes, then actual release acknowledgement. Normal recorder and
microphone-to-Dart orchestration are not yet registered by this file factory.

For a device with valuable existing debug data, back up first, verify the
installed signing certificate, then use an in-place non-incremental ADB install.
Do not allow a failed install to trigger an uninstall/data-clear fallback.
Connect the Flutter driver to the already-running app using `--use-existing-app`
and `--keep-app-running`; keep VM service URLs private and remove only forwards
created for this test. The rebuilt release has a different hash from the older
baseline; consult the implementation evidence rather than claiming byte equality.

### Prepared Dart microphone-channel case (not automatic)

`integration_test/streaming_microphone_channel_test.dart` is skipped unless built
with `--dart-define=LOQUIRIS_AUTHORIZED_STREAMING_MIC=true`. Its debug route is
`debug-native-microphone-probe`, using the same canonical inventory digest above.
It also requires the native-spike DEBUG build and an already granted microphone
permission, rechecked before touching AudioRecord. No probe code grants it.
Launching this opted-in entry with permission granted starts a new microphone
probe: do so only after fresh human playback readiness, never as file regression.

The plain owner uses interruptible windows; its runner captures 10 seconds,
pauses one second and captures another ten. STOP drains/finalizes; cancellation
wakes the schedule and releases without adding a final. STOP→cancel upgrades
propagate through Dart/controller/owner while the original ACK is still pending.
New app-private `streaming-dart-mic-<UUID>` AAC/report directories are retained,
without clearing old data. Unknown native allocations during failed construction
retain ownership rather than falsely ACK release. The cross-language assertions
require nonempty finals in both capture epochs and a PAUSE boundary; zero-length
gaps are valid because paused wall time is not captured media.

The authorized short Dart microphone case passed on 2026-10-16; see the
implementation evidence for the retained recording/report and exact scope.
It is not normal recorder/UI integration, language-accuracy qualification,
latency-percentile measurement, or independently decoded AAC integrity evidence.

### Prepared normal-recorder channel case (fresh readiness required)

`integration_test/streaming_recorder_channel_test.dart` is skipped unless built
with `--dart-define=LOQUIRIS_AUTHORIZED_STREAMING_RECORDER=true`. The debug-only
`debug-native-recorder-probe` route requires the pinned inventory and existing
microphone permission. It attaches to `RecordingForegroundService`'s exact
canonical fan-out through `LivePcmInferenceRegistry`, never a second source.
The shared Whisper arbiter remains reserved until actual remote release ACK.

The case first refuses any active/recoverable recording, starts one unique new
recording through the normal Dart recording-control service, observes streaming
for ten seconds, pauses one second, resumes ten seconds, and stops the recorder
before waiting for streaming release. Teardown also stops only that matching
new recording **before** any potentially blocked inference ACK; every independent
cleanup is attempted. New original audio remains in the normal recording store.
No recording is cleared, replaced or deleted. Do not launch the opted-in entry
until fresh human playback readiness; it is not a non-microphone regression.

This authorized short case passed on 2026-10-17; consult the implementation
evidence for its retained normal recording and release ACK. Future runs still
require fresh human readiness. It checks the service/channel integration,
not the visible recorder widgets, lexical accuracy, p95, interruption hardware,
AAC decode coverage or long-run/release qualification. The production selector
still does not expose this candidate. See the latest implementation evidence
for build/install status and backups; do not use uninstall/reset fallbacks.

### Prepared visible recorder UI case (not executed)

`integration_test/streaming_recorder_ui_test.dart` is independently skipped unless
built with `--dart-define=LOQUIRIS_AUTHORIZED_STREAMING_RECORDER_UI=true`.
It uses the existing foreground recorder, the explicit debug recorder probe,
and a route-independent `StreamingLiveTranscriptAdapter` to drive the actual
recording screen. The normal selector remains disabled; no model is chosen
implicitly. The test itself never grants microphone permission.

After refusing active/recoverable capture, the case starts one unique new
recording, renders read-only live text, taps the actual pause/resume/confirmed
STOP controls, and checks a visible nonempty PAUSE final plus a later STOP final.
The pause lasts at least one second; final delivery has a bounded wait rather
than a one-second latency assertion. Normal STOP is distinct from cancel, and
the live controller retains its lifetime across immediate navigation until
the final events and actual native release settle. Teardown first stops only
this matching new recording, then independently unmounts and releases inference.
New original recording files are retained. No old data is reset or removed.

This is deliberately a UI/channel smoke: a temporary in-memory session repository
and no-op refinement finalization handler isolate it from existing app database
contents and background jobs. The detail-route key proves navigation, not loaded
details or durable transcript persistence. It does not prove numeric backlog,
lexical accuracy, latency percentiles, hardware interruptions, AAC decode
coverage, long-run stability or production eligibility.

The opted-in debug APK has been compiled and separately signed with the prior
debug certificate, but **not installed or launched**. Use only the verified signed
candidate recorded in the implementation evidence; the default Flutter debug
signature differs. Before any install or launch, obtain fresh human playback
readiness, recheck target identity/certificate and idle recording state, preserve
existing data, and use the non-destructive in-place install/driver procedure above.
Neither the earlier passed microphone run nor this prepared build starts another
recording automatically.

The first authorized visible-UI run on 2026-10-17 **failed** while waiting for a
nonempty PAUSE endpoint. It did not reach resume or normal-STOP UI assertions.
Independent teardown finalized the new recording and acknowledged inference
release; microphone permission/app-ops were restored afterward. The new audio is
retained. Do not treat the prepared build or earlier service-only pass as a UI
pass, and do not automatically repeat microphone capture. See implementation
evidence for exact scope; distinguishing empty recognition from dropped delivery
requires further offline investigation and privacy-safe boundary observations.

The subsequent fixed-file real-panel diagnostic now passes with two nonempty
finals observed at native wire, projection and view. Its initial timeout was a
test-only `expect()`/`pump()` guard conflict before native open; callback
assertions now use `expectSync()`. Do not infer that this explains the earlier
microphone failure. Content-free delivery counters are available for the next
authorized recorder UI attempt; they retain no text, owner IDs or paths.
The updated recorder UI package is built/signed only, not installed or launched.
Fresh human readiness is still required for another microphone attempt. Exact
package identities, private evidence and scope are in the implementation status.

The prepared diagnostic package was subsequently installed and run once after
fresh readiness on 2026-10-17. It displayed five nonempty finals and reached
normal STOP/navigation, but the case **failed** its no-degradation assertion:
two wire gaps mapped to incomplete-coverage discontinuity events. Their precise
reasons/intervals are not retained by the current trace, so they must not simply
be ignored to obtain a pass. Independent teardown released resources and
microphone permission/app-ops were restored; the new audio is retained. No
automatic retry is authorized. See implementation evidence for exact scope.

The next offline revision adds bounded gap reason/epoch/media-interval evidence
and replaces the one-PAUSE smoke's blanket no-degradation assertion with strict
coverage validation. Only an optional initial attachment gap and the requested
pause boundary can qualify; unexpected/duplicate/missing boundaries, native
failures, truncated evidence or missing UI incomplete/cause messages still fail.
The endpoint wait permits an initial coverage notice while awaiting a final,
but remains bounded and immediately rejects actual failure reasons. A successful
smoke with missing live media is labelled `passed_incomplete_coverage`; this is
not coverage-ratio, latency or production acceptance. Old count-only failures
are not reclassified. The revised signed package is prepared only; obtain fresh
readiness before installing or starting it. Exact identities and 877-test host
verification are recorded in implementation status.

The revised package was run once after fresh readiness at 2026-10-17 14:58 and
**failed before PAUSE was acknowledged**: the test logged a missed pause-control
hit test, and native receipts contain start/teardown-stop but no pause. Its new
gap evidence also reports a non-prefix 0.32–4.02-second live discontinuity, which
the strict oracle would not accept as an initial attachment gap. Neither issue
is hidden by the new policy. Independent teardown released resources and
microphone permission/app-ops were restored; new and old recordings are retained.
Do not retry capture automatically. Reproduce hit-testing and investigate the
PCM discontinuity offline before preparing another authorized attempt.

Offline follow-up reproduced and corrected caption-growth control movement:
controls now precede live text, with original-coordinate pause-tap regression
tests for compact, landscape and enlarged text. Native fanout tests also
reproduced the 0.32–4.02-second startup gap with the legacy 16-frame queue.
Only explicitly opted-in debug streaming capture now retains up to 256 derived
frames (5.12 seconds at full reads); default/release remain 16 and canonical
recording is unchanged. This is bounded startup retention, not a qualified
latency/backlog/memory result or proof that the actual device gap is fixed.
No gap checks were relaxed. Host verification: 880 Flutter tests, 541 native
tests, no Dart analysis issues, Android lint successful with warnings. The new
signed package is prepared only, not installed/launched; exact hashes and scope
are in implementation status. No device or microphone operation occurred during
this offline follow-up. Fresh readiness is required for another actual attempt.

After fresh readiness, the controls/startup package was run once at 2026-10-17
15:36 and the actual recorder UI smoke passed: pause/resume/normal STOP,
read-only finals, finish/release/disposal and no-late-event checks succeeded.
Seven nonempty finals reached the stopped view; the only gap marker was a
zero-length pause boundary, with no positive live-coverage gap or failure cause.
Native command receipts confirm start/pause/resume/stop. The prior gap did not
recur in this attempt, not a guarantee for all startup/overload conditions.
No controlled latency, bilingual accuracy, long-run or durable transcript claim
is made. Microphone permission/app-ops are off again; all 33 protected prior
files match and the new recording is retained. The package is now installed;
do not launch another capture without fresh readiness. Exact evidence and
limitations are recorded in implementation status.

Offline task-4.3 follow-up moved the debug backlog watchdog before the remote
Ready wait, so model loading no longer exempts retained PCM from the existing
five-second/three-observation rule. New real-fanout/RemoteSession tests verify
degradation while Ready is pending, canonical progress, and no release before
remote ACK; a real-lease late-Ready cancellation regression prevents reattachment.
Prebinding arbiter waiting and numeric backlog UI are still outside this slice.
544 native and 880 Flutter tests pass; Android lint succeeds with warnings and
Dart analysis finds no issues. The newly signed loading-backlog package is
prepared only, not installed/launched. This offline work did not touch the
device or microphone; it neither changes previous device evidence nor qualifies
latency, resources or production availability. See implementation status for
exact artifact hashes, review scope and the cumulative worktree's HIGH-risk
GitNexus warning.
