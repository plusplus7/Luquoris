# Offline Whisper Transcription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task in the
> current session. Do not delegate unless the user explicitly requests agents.

**Goal:** Install a real offline `whisper.cpp` transcription runtime, start
durable post-session transcription automatically, and add a recording-safe
near-real-time draft experiment using multilingual `base-q5_1`.

**Architecture:** Android owns a pinned CPU/ARM-NEON `whisper.cpp` runtime,
private model materialization, canonical AAC decoding, and bounded live PCM
inference. Dart owns durable job/run state, idempotent scheduling, result
persistence, version selection, and presentation through existing Riverpod and
repository boundaries. Recording never waits for inference.

**Tech stack:** Dart 3.12, Flutter 3.44, Riverpod 3.x, Drift, Kotlin/JVM 17,
Android API 29+, NDK 28.2, CMake, C++17, JNI, `whisper.cpp` v1.9.4 pinned by
full commit/archive hash, multilingual `ggml-base-q5_1.bin`, Flutter
`MethodChannel`/`EventChannel`, JUnit 4, `flutter_test`.

**Spec:**
`docs/superpowers/specs/2026-10-09-offline-whisper-transcription-design.md`

## Global constraints

- Canonical capture, encoding, journal publication, stop finalization, and
  recovery always outrank inference. No model operation runs on capture,
  encoder, finalization, Android UI, or Flutter UI threads.
- The model source is the reviewed official multilingual
  `ggml-base-q5_1.bin`, approximately 59.7 MB, with exact bytes and SHA-256 in
  its manifest. Model bytes live in Git-ignored `models/local/`; they are never
  committed.
- Vendor a reviewed whisper.cpp v1.9.4 source snapshot by exact upstream commit
  and archive hash. Build only the CPU baseline needed by the application; add
  no FFmpeg, Vulkan, NNAPI, network, telemetry, or remote-download dependency.
- Generated model assets are accepted only after the existing importer verifies
  manifest shape, byte count, SHA-256, artifact path, and license snapshot.
  Runtime verification failure disables AI only.
- Post-session transcription consumes only manifest-ordered,
  journal-authorized AAC prefixes. Missing derived M4A never means audio is
  absent.
- Live inference uses only a bounded copy of PCM. A full queue drops/replaces AI
  work, records backlog/incompleteness, and leaves canonical recording intact.
- Live draft output is never the final transcript. Finalization always schedules
  a complete post-session run.
- Persist only privacy-safe job checkpoints and error codes. Logs/checkpoints
  contain no audio, transcript text, title, name, absolute path, URI, native
  exception text, or stack trace.
- Automatic selection applies only to the first completed transcript for a
  meeting. Explicit re-analysis remains a parallel version requiring user
  selection.
- Near-real-time stays experimental/disabled by default until the physical
  target passes all OpenSpec gates. A short successful device test is not a
  production enablement decision.
- Follow red-green-refactor. Before editing every existing function, class,
  method, provider, Kotlin controller, or C++ entry point, run upstream
  `gitnexus_impact` with file/kind or UID disambiguation and report callers,
  affected processes/modules, and risk. Stop and warn on HIGH or CRITICAL.
- Before each commit, stage only the task's intended files/hunks, run
  `git diff --cached --check`, inspect `git diff --cached --name-status`, and run
  `gitnexus_detect_changes(scope: "staged")`. Never sweep the dirty worktree
  into a task commit.

## Task 1: Pin whisper.cpp and import the base-q5 model

**Files:**

- Create: `third_party/whisper.cpp/` reviewed v1.9.4 source snapshot
- Create: `third_party/whisper.cpp.PROVENANCE.json`
- Create: `models/manifests/whisper-base-q5_1.json`
- Create: `models/licenses/openai-whisper-model-MIT.txt`
- Modify: `models/README.md`
- Modify: `android/app/build.gradle.kts`
- Modify: `.gitignore`
- Modify: `tool/third_party_notices/component_catalog.json`
- Modify: `tool/third_party_notices/approval.json`
- Regenerate: `THIRD_PARTY_NOTICES.md`
- Test: `test/tool/model_import_cli_test.dart`
- Test: `test/tool/model_importer_test.dart`
- Test: `test/policy/release_privacy_policy_test.dart`

- [ ] Run GitNexus impact for the existing Gradle model-asset task/configuration
  symbols and model importer functions that will change; report risk.
- [ ] Add failing tests requiring the fixed model manifest, exact source URL,
  byte count, SHA-256, engine ID `whisper_cpp`, model format `ggml`, license
  snapshot, transcription capability, and preview-only modes.
- [ ] Download the approved model into
  `models/local/whisper-base-q5_1/ggml-base-q5_1.bin`, calculate its exact byte
  count/SHA-256, and reject the download if they disagree with the reviewed
  upstream object.
- [ ] Import a clean whisper.cpp v1.9.4 source snapshot, record tag, full commit,
  archive SHA-256, upstream URL, license, and included directories; exclude
  examples and optional FFmpeg/GPU integrations from the build.
- [ ] Wire a Gradle pre-build verification/copy task that consumes only
  `build/generated/model_assets/`; fail with a stable build error when local
  inputs were not imported. Keep release assets uncompressed where native
  loading requires random access.
- [ ] Run `dart run tool/import_models.dart`, focused importer tests, notice
  generation/check, privacy policy tests, and a debug native configuration
  build.
- [ ] Run staged GitNexus change detection and commit only Task 1 as
  `build: pin offline whisper runtime and model`.

## Task 2: Build the native whisper runtime and post-session decoder

**Files:**

- Create: `android/app/src/main/cpp/CMakeLists.txt`
- Create: `android/app/src/main/cpp/loquiris_whisper_jni.cpp`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/WhisperNativeBindings.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/WhisperModelStore.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/AuthoritativeAudioResolver.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/AndroidAacPcmDecoder.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/WhisperPostSessionEngine.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/TranscriptionNativeModels.kt`
- Create tests under: `android/app/src/test/kotlin/com/loquiris/transcription/`
- Create instrumentation tests under:
  `android/app/src/androidTest/kotlin/com/loquiris/transcription/`
- Modify: `android/app/build.gradle.kts`

- [ ] Run impact analysis for `RecordingSegmentInventoryReader`,
  `RecordingAdtsJournal`, and any existing storage resolver reused by the new
  authoritative audio resolver; report risk before edits.
- [ ] Write failing JVM tests for safe meeting-relative resolution, ordered
  manifest segments, journal byte limits, gaps/partial input, cancellation,
  timestamp monotonicity, and stable failure mapping.
- [ ] Write a failing instrumentation smoke test that loads the verified model,
  transcribes the fixed authorized WAV fixture, returns at least one monotonic
  segment, and releases every native handle.
- [ ] Configure CMake/C++17 with release optimization for debug and release
  Android variants, CPU backend only, ARM NEON for `arm64-v8a`, hidden symbols,
  and one JNI shared library.
- [ ] Implement a minimal JNI surface: create/free context, transcribe bounded
  PCM, cancel by run handle, enumerate normalized segment timestamps/text, and
  report engine version. Catch all native exceptions before JNI return.
- [ ] Implement atomic asset materialization and SHA-256 re-verification in
  private model storage; never load an unverified file.
- [ ] Resolve journal-authorized AAC inputs by meeting identity, decode with
  Android `MediaCodec` to mono 16 kHz PCM in bounded windows, and preserve
  pause-free cumulative media time.
- [ ] Run Kotlin JVM tests, the native build, and the model-load/transcription
  instrumentation smoke test on the connected Redmi.
- [ ] Run staged change detection and commit Task 2 as
  `feat: add native whisper post-session runtime`.

## Task 3: Add the versioned Flutter/native transcription channel

**Files:**

- Create: `android/app/src/main/kotlin/com/loquiris/transcription/TranscriptionChannelContract.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/TranscriptionChannelController.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/TranscriptionRunRegistry.kt`
- Create: `android/app/src/test/kotlin/com/loquiris/transcription/TranscriptionChannelContractTest.kt`
- Create: `android/app/src/test/kotlin/com/loquiris/transcription/TranscriptionChannelControllerTest.kt`
- Create: `lib/native/method_channel_transcription_engine.dart`
- Create: `test/native/method_channel_transcription_engine_test.dart`
- Modify: `lib/services/service_contracts.dart`
- Modify: `test/support/fakes/fake_services.dart`
- Modify: `android/app/src/main/kotlin/com/loquiris/MainActivity.kt`

- [ ] Run upstream impact for `TranscriptionRequest`, `TranscriptionEngine`,
  `FakeTranscriptionEngine`, and `MainActivity.configureFlutterEngine`; stop on
  HIGH/CRITICAL.
- [ ] Add failing Dart contract tests for model/language/parameter fields,
  progress events, stable chunks, cancellation, malformed payloads, wrong run
  IDs, timeout/missing-plugin errors, and exception-text exclusion.
- [ ] Add failing Kotlin tests proving strict version/type validation, one
  background inference executor, UI-executor replies, one terminal result,
  progress ordering, cancellation idempotency, and controller close cleanup.
- [ ] Define channel `com.loquiris/transcription_v1` plus a separate event stream.
  Requests carry only schema version, run ID, meeting ID, validated relative
  segment references, model ID, language hint, and canonical parameter version.
- [ ] Implement `MethodChannelTranscriptionEngine` so `eventsFor(runId)` filters
  a broadcast event stream and `transcribe` returns typed failures without
  leaking platform strings.
- [ ] Register the controller in `MainActivity` with its own executor and shut it
  down deterministically.
- [ ] Run focused Dart/Kotlin tests and one channel round-trip instrumented test.
- [ ] Run staged change detection and commit Task 3 as
  `feat: expose offline transcription engine channel`.

## Task 4: Implement durable transcription jobs and run persistence

**Files:**

- Modify: `lib/services/analysis_repository_contracts.dart`
- Modify: `lib/services/service_providers.dart`
- Modify: `lib/data/repositories/drift_analysis_repositories.dart`
- Modify: `lib/features/models_performance/domain/processing_entities.dart`
- Modify: `lib/features/transcript/domain/transcript_entities.dart`
- Modify: `test/data/drift_analysis_repositories_test.dart`
- Modify: `test/support/fakes/fake_services.dart`
- Modify: `test/services/service_contracts_test.dart`

- [ ] Run upstream impact for `TranscriptRepository`,
  `DriftTranscriptRepository`, `ProcessingJob`, `TranscriptRun`, and affected
  provider symbols; report the blast radius.
- [ ] Add failing repository tests for idempotent enqueue by deterministic job
  key, queued-to-running progress, orphaned-running recovery, privacy-safe
  checkpoints, atomic completion with stable segments, terminal failure, retry,
  cancellation, and first-version-only current selection.
- [ ] Add a narrow `TranscriptionJobRepository` contract. Do not expose raw Drift
  rows or database handles to presentation code.
- [ ] Implement Drift transactions over existing tables without a schema change.
  Enforce owner/model/run foreign keys and reject regressing progress,
  incompatible provenance, duplicate visible segments, and illegal transitions.
- [ ] Keep completed `TranscriptRepository.saveVersion` compatibility while
  adding the atomic job/run writer needed by the coordinator.
- [ ] Run focused repository/domain tests, migration/schema tests, analyzer, and
  code generation only if table declarations actually change.
- [ ] Run staged change detection and commit Task 4 as
  `feat: persist resumable transcription jobs`.

## Task 5: Automatically orchestrate post-session transcription

**Files:**

- Create: `lib/features/transcript/application/transcription_coordinator.dart`
- Create: `lib/features/transcript/application/transcription_parameters.dart`
- Create: `lib/features/transcript/application/transcription_ids.dart`
- Create: `lib/features/models_performance/application/asset_bundle_model_artifact_source.dart`
- Create: `test/features/transcript/transcription_coordinator_test.dart`
- Create: `test/features/models_performance/application/asset_bundle_model_artifact_source_test.dart`
- Modify: `lib/bootstrap/bootstrap.dart`
- Modify: `lib/app.dart`
- Modify: `lib/features/recording/presentation/recording_controller.dart`
- Modify: `test/bootstrap/bootstrap_test.dart`
- Modify: `test/features/recording/presentation/recording_controller_test.dart`

- [ ] Run impact for `bootstrap`, `LoquirisApp.build`,
  `RecordingController._synchronizeSnapshot`, and every provider installed by
  the coordinator; report risk before edits.
- [ ] Write failing coordinator tests proving exactly-once scheduling on the
  first matching `finalized` transition, no scheduling for recording-only mode,
  complete post-session fallback for near-real-time mode, no duplicate launch
  from repeated snapshots, model-verification failure isolation, progress
  persistence, result persistence, first-version selection, retry, and startup
  recovery.
- [ ] Install typed model manifest loading, `RuntimeModelManager`, the production
  transcription engine adapter, and `TranscriptionJobRepository` in bootstrap.
- [ ] Implement deterministic UUID-v5 job/run/segment identities from meeting,
  model hash, engine version, parameter version, and media boundaries.
- [ ] Implement an app-scoped `TranscriptionCoordinator` watched eagerly by
  `LoquirisApp`, parallel to the existing recording coordinator. Serialize
  per-meeting mutations while allowing only one native base-model inference at
  a time.
- [ ] On startup, reconcile queued/running/paused jobs before accepting new
  launches. Treat a lost native run as resumable, never succeeded.
- [ ] Map engine output to completed `TranscriptRun` and `TranscriptSegment`
  values, preserve raw/display text separately, and select only the first
  meeting transcript automatically.
- [ ] Run coordinator, bootstrap, recording-controller, and repository tests.
- [ ] Run staged change detection and commit Task 5 as
  `feat: start transcription after recording finalization`.

## Task 6: Show durable processing and transcript results

**Files:**

- Modify: `lib/features/sessions/presentation/session_detail_controller.dart`
- Modify: `lib/features/sessions/presentation/session_detail_screen.dart`
- Modify: `lib/features/transcript/presentation/transcript_editor_controller.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Modify: `test/features/sessions/session_detail_screen_test.dart`
- Modify: `test/features/transcript/transcript_editor_screen_test.dart`
- Modify: `test/localization/phase_08_localization_test.dart`
- Modify: `test/accessibility/session_tools_accessibility_test.dart`

- [ ] Run impact for both controllers/screens and generated localization entry
  points before edits; report risk.
- [ ] Add failing widget tests for queued/running percentage, completed transcript
  preview, typed failure with retry, retry coalescing, navigation from finalized
  recording while work continues, and preserved playback controls.
- [ ] Add localized Chinese/English labels for preparing model, decoding,
  transcribing, delayed, incomplete, retry, cancellation, and stable failure
  categories. Never display raw codes as primary copy.
- [ ] Refresh detail when job/run state changes without polling the native
  engine from the screen. Keep transcript editing locked until a stable run is
  completed.
- [ ] Run widget, localization, accessibility, golden/overflow, and navigation
  tests.
- [ ] Run staged change detection and commit Task 6 as
  `feat: present offline transcription progress and results`.

## Task 7: Add the recording-safe live PCM draft runtime

**Files:**

- Modify: `android/app/src/main/kotlin/com/loquiris/recording/PriorityPcmFanOut.kt`
- Modify: `android/app/src/main/kotlin/com/loquiris/recording/RecordingCapturePipeline.kt`
- Modify: `android/app/src/main/kotlin/com/loquiris/recording/RecordingForegroundService.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/LivePcmInferenceRegistry.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/WhisperDraftEngine.kt`
- Create: `android/app/src/main/kotlin/com/loquiris/transcription/DraftHypothesisReconciler.kt`
- Modify/create tests under:
  `android/app/src/test/kotlin/com/loquiris/recording/` and
  `android/app/src/test/kotlin/com/loquiris/transcription/`
- Modify: `lib/services/service_contracts.dart`
- Modify: `lib/native/method_channel_transcription_engine.dart`
- Modify: `test/native/method_channel_transcription_engine_test.dart`

- [ ] Run impact for `PriorityPcmFanOut.publish`,
  `RecordingCapturePipeline.captureLoop`, service start/stop paths, and the
  transcription interface. Warn before any HIGH/CRITICAL edit.
- [ ] Add failing stress tests proving a stalled or failed inference consumer
  cannot delay/reject canonical work; queue overflow increments AI-drop/backlog
  state only; stop drains canonical work without waiting for whisper.
- [ ] Add failing reconciler tests for rolling-window overlap, monotonic
  timestamps, unstable replacement, stable horizon promotion, duplicate-token
  removal, and incomplete gaps.
- [ ] Extend the lower-priority fan-out with a replaceable inference consumer
  that runs on its own worker. Preserve all existing canonical queue behavior
  and metrics.
- [ ] Implement one bounded live inference context with fixed window/stride and
  one decode in flight. New windows may replace obsolete queued windows.
- [ ] Extend `TranscriptionEngine` with idempotent `startDraft`/`stopDraft`
  operations and stream draft/backlog/degradation events through the existing
  versioned event channel.
- [ ] Stop/release live inference on meeting stop, service recovery, severe
  thermal state, model failure, or channel owner loss without touching capture.
- [ ] Run all recording JVM tests plus live transcription tests and a short
  device stress test with artificial whisper stalls.
- [ ] Run staged change detection and commit Task 7 as
  `feat: add bounded live whisper drafts`.

## Task 8: Present live drafts and explicit fallback

**Files:**

- Create: `lib/features/transcript/presentation/live_transcript_controller.dart`
- Create: `lib/features/transcript/presentation/live_transcript_panel.dart`
- Create: `test/features/transcript/live_transcript_controller_test.dart`
- Create: `test/features/transcript/live_transcript_panel_test.dart`
- Modify: `lib/features/recording/presentation/active_recording_screen.dart`
- Modify: `lib/features/transcript/application/transcription_coordinator.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Modify: `test/features/recording/presentation/active_recording_screen_test.dart`
- Modify: `test/accessibility/session_tools_accessibility_test.dart`

- [ ] Run impact for `ActiveRecordingScreen.build`, coordinator live methods,
  and localization symbols; report risk.
- [ ] Add failing controller tests for stable/unstable replacement, run identity
  filtering, monotonic media order, backlog, incomplete state, thermal/model
  fallback, stop cleanup, and ignored late events.
- [ ] Add failing widget tests for read-only draft text, visual/semantic stable
  distinction, backlog/degradation explanation, 320 px width, 200% text, and
  unaffected pause/stop/bookmark controls.
- [ ] Start draft only for `nearRealTime`; post-session selection never opens a
  live engine. Any dropped/backlogged/failing draft keeps post-session fallback
  armed.
- [ ] Render draft below recording health without shifting critical controls out
  of reach. Announce meaningful state changes through localized live regions,
  not every partial token.
- [ ] Run controller/widget/localization/accessibility/golden tests and the
  existing finalized-navigation regression.
- [ ] Run staged change detection and commit Task 8 as
  `feat: show experimental live transcription drafts`.

## Task 9: Integrated verification, evidence, and OpenSpec state

**Files:**

- Create: `docs/evidence/phase-11-whisper-transcription-spike.md`
- Create: `docs/evidence/phase-11-whisper-transcription-device.json`
- Create/update: focused device runner scripts under `tool/`
- Modify: `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md`
- Modify: `docs/evidence/phase-10-release-footprint.json`
- Regenerate: `THIRD_PARTY_NOTICES.md`

- [ ] Run `dart format --output=none --set-exit-if-changed lib test tool`,
  `flutter analyze --fatal-infos --fatal-warnings`, full `flutter test`, Android
  JVM tests, and targeted Android instrumented tests.
- [ ] Build debug and release artifacts, run merged-manifest/dependency privacy
  scans, verify no network permission, and rerun model/license/notice checks.
- [ ] Measure APK/AAB and clean installed footprints with the bundled model and
  native ABIs; fail above OpenSpec limits.
- [ ] Install the exact debug artifact on the connected Redmi. Record short
  Chinese, English, and mixed meetings in both modes. Verify live draft events,
  automatic final processing, durable transcript rows, restart recovery,
  retry, playback responsiveness, and no new recording gaps.
- [ ] Record first-text latency, post-session RTF, CPU/PSS, thermal, energy,
  backlog, Flutter frame timing, native failures, and exact device/build/model
  provenance. Do not invent CER/WER/MER from the short smoke set.
- [ ] Mark OpenSpec tasks 11.1–11.4 complete only when their implementation and
  evidence pass. Leave 11.5–11.8 and 12.8 incomplete until the full evaluation
  and long-run gates are actually satisfied.
- [ ] Run strict OpenSpec validation and final
  `gitnexus_detect_changes(scope: "staged")`; inspect every affected process.
- [ ] Commit Task 9 as `docs: publish offline whisper spike evidence`.

## Final acceptance

- Post-session meetings enqueue exactly one durable run after authoritative
  finalization and eventually show a timestamped offline transcript.
- A process restart resumes or safely recomputes unfinished work without
  duplicating the visible version.
- Near-real-time meetings show real draft events on the target device or a
  truthful delayed/incomplete fallback; they always receive a full final pass.
- Inference stalls, crashes, cancellation, model corruption, and thermal
  degradation never stop, corrupt, or back-pressure canonical recording.
- Release artifacts remain offline and within size budgets, and every native
  library/model entry has fixed provenance and reviewed license text.
- The app does not claim production near-real-time quality before the remaining
  device gates pass.

## Primary upstream references

- Official whisper.cpp Android example:
  `https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.android`
- Official whisper.cpp v1.9.4 release:
  `https://github.com/ggml-org/whisper.cpp/releases/tag/v1.9.4`
- Reviewed model object:
  `https://huggingface.co/ggerganov/whisper.cpp/blob/f281eb45af861ab5e5297d23694b7d46e090c02c/ggml-base-q5_1.bin`
