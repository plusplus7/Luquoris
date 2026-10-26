> Updated 2026-10-22: **42/44** tasks now verified after [native target GPU acceptance](remote-server-transcription-target.md). The report below records the earlier verification checkpoint.

# Remote transcription verification — 2026-10-21

Change: `remote-server-transcription`. Implementation is present. Container
build/control-plane/TLS verification was continued on 2026-10-22; GPU, accuracy
and physical-phone acceptance remain unverified. No commit or release was
created. Existing offline work was preserved against the implementation baseline.

## Verified boundaries

- API: authenticated ownership, token rejection, bounded bodies, durable resumable
  chunks, idempotent submission, concurrent sealing, length/digest/decode checks.
- Ledger: exclusive GPU claim, generation/lease recovery, bounded retries,
  cancellation races, atomic result publication and crash-orphan/retention cleanup.
- CPU pipeline: bounded overlapping windows, conservative RMS silence heuristic,
  real media offsets, boundary reconciliation, alignment omissions/timestamp
  rejection, punctuation restoration, immutable artifact-set/digest binding.
- Processes: real child cancellation, timeout, inherited lock on parent death,
  stable error codes, decoder watchdog over blocking stdout reads and reaping.
- Flutter: remote mode does not need phone weights; durable new-run intents,
  consent/configuration, progress/expiry, source versions, corrections/export.
- Drift v7: additive remote tables, all existing migration shape paths, retained
  v6 rows, exact closed-file recovery after a forced mid-v7 failure, old restore
  identities, invalid/cross-meeting restore rejection, restored-copy provenance
  and repeat-restore idempotence. Restores clear credentials and disable uploads.
- Android API 34 arm64 emulator: shared fixtures including unknown versions and
  fields, Android Keystore destination binding, actual bundled SQLite STRICT
  commit/rollback, repository import on a real exported Drift v7 database,
  duplicate completion preserving human edits, wrong-run rejection, cancellation
  during result response, persisted expiry and restart/backoff preserving job ID.
  HTTP is an injected boundary in repository tests; TLS transport is not exercised
  against a deployed server by these tests.
- App launches into the meeting library on the emulator without model assets.
  APK inspection found no model_assets/ggml/safetensors entries.

## Commands and evidence

Use the repository-pinned Flutter SDK and put its `bin` on PATH. Database schema
export/steps, build_runner and test schema generation ran before analyze:

```sh
dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/
dart run drift_dev schema steps drift_schemas/ lib/data/database/schema_versions.dart
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/drift/generated/
flutter analyze
flutter test --reporter expanded
cd server
uv run --frozen pytest -q
uv run --frozen ruff check .
uv run --frozen ruff format --check .
```

Native reproduction (from repository root):

```sh
dart run tool/export_remote_test_database.dart
JAVA_HOME=<Android-Studio-JDK> android/gradlew -p android \
  :app:testDebugUnitTest :app:assembleDebug :app:assembleDebugAndroidTest
adb -s <emulator> install -r build/app/outputs/apk/debug/app-debug.apk
adb -s <emulator> install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s <emulator> shell am instrument -w -e package com.loquiris.remote \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
```

Fresh results are captured in adjacent small evidence files. Full local logs are
`/tmp/loquiris-server-final-tests.log`, `/tmp/loquiris-remote-flutter-final.log`,
`/tmp/loquiris-remote-analyze-final.log`, `/tmp/loquiris-remote-android-final.log`
and `/tmp/loquiris-remote-emulator-tests.log`.

`processReleaseMainManifest` and `writeReleaseDependencyInventory` succeeded.
The release dependency/privacy configuration was checked; an unreviewed notice
candidate was generated under `build/third_party_notices/remote-candidate.json`.
It does not approve redistribution or constitute a signed release build.
Compose configuration validates with the nonsecret example configuration.
Evaluation CLI ran against a synthetic protocol fixture to check report writing;
that smoke test is not a model-accuracy result. Unmeasured timing/memory fields
remain null; worker metrics document cold-job and allocator measurement scope.

Independent read-only code review found no remaining Important issues after the
cancellation, restore, retention, artifact binding, overlap, decoder timeout,
profile readiness and Android SQLite fixes. Later strict parser checks were
verified by failing-then-passing Dart and Android tests.

## Remaining acceptance blockers

- **4.3, 4.4, 4.6, 8.4:** no connection to the Windows/WSL2 RTX 3080 Ti machine.
  Model execution, Qwen recognition followed by the aligner, alternative Whisper,
  real CUDA behavior, long-audio throughput and peak device resources are untested.
- **8.1 is now verified complete:** both Linux/amd64 image builds and three
  container tests passed on 2026-10-22. See [container evidence](remote-server-transcription-containers.md).
  GPU-image dependency import could not finish due to local disk exhaustion;
  it is not included in the verified scope and remains target-dependent.
- **8.5:** no authorized representative recordings with human references and
  comparable local-baseline outputs were supplied. No accuracy improvement or
  production default selection is claimed.
- **8.6:** physical phone debug install was rejected with
  `INSTALL_FAILED_USER_RESTRICTED`; an existing test-package signature also
  conflicted. No app was uninstalled, data cleared, security policy bypassed or
  device setting changed. Emulator checks do not replace real phone background,
  network outage, trusted TLS, server restart, cancellation/expiry and full
  recording-to-result/edit/export acceptance.

The target-host run must record actual model revisions, CUDA/driver/runtime,
model load and separate recognition/alignment stages, >30-second boundary cases,
long and silent/noisy/mixed-language recordings, VRAM/RSS, reference-based CER/WER
and manual proper-noun/omission/duplicate review. Keep tasks unchecked until this
is observed. The primary Qwen profile is a development candidate, not a measured
accuracy/capacity recommendation.

## Scope and risk

GitNexus upstream impact was run before existing symbol edits. AppDatabase was
CRITICAL and that migration/startup/restore blast radius was reported before
editing. Most narrower integrations were LOW. New remote modules are absent
from the index (UNKNOWN), so tests and independent review cover those boundaries.
The final `detect_changes(all)` includes extensive pre-existing uncommitted
recording/refinement changes; its aggregate CRITICAL rating cannot be attributed
solely to this change. See the adjacent impact and baseline-relative file reports.
Other active OpenSpec changes were not marked complete or archived.
