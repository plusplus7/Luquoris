## Why

Loquiris needs a trustworthy Android foundation for preserving long conversations entirely on-device, with recording reliability taking precedence over experimental AI processing. The project must establish measurable low-cost-device gates before it claims near-real-time transcription or speaker separation.

## What Changes

- Bootstrap an independent Flutter/Android application using feature-first boundaries, Riverpod, GoRouter, Drift, typed results, and testable native service interfaces.
- Add resilient foreground recording with start, pause, resume, confirmed stop, background and lock-screen continuity, short durable commits, logical segmentation, interruption tracking, low-storage protection, and crash recovery.
- Persist meeting sessions, audio segments, processing jobs, timestamped transcript versions, language and speaker labels, bookmarks, revisions, failures, and model provenance locally.
- Add replaceable offline transcription, language-identification, diarization, model-management, thermal/performance, export, and repository interfaces without coupling Flutter UI to a concrete engine.
- Establish `whisper.cpp` multilingual `base q5` as the first license-compliant performance spike; keep near-real-time transcription disabled or experimental until the target-device gates pass.
- Design post-session speaker diarization and correction for up to six principal speakers; real-time diarization is excluded from the MVP.
- Add deterministic local search, bookmarks, manual highlights, transcript correction, local export, backup/restore, storage management, and a seven-day local trash.
- Enforce an offline release posture: no runtime model downloads, no `INTERNET` permission in release, no analytics or remote crash upload, local-only diagnostics, model integrity manifests, and maintained third-party notices.
- Define a single-device release gate on the connected mainland-China Redmi Note 10 Pro (`M2104K10AC`/`chopin`, 6GB+128GB class), with results scoped only to the tested hardware, firmware, and environment.
- Separate the shippable `Recorder MVP` from the gated `Offline Transcription Preview` so AI failure can never invalidate or interrupt the original recording.

## Capabilities

### New Capabilities

- `application-foundation`: Flutter architecture, navigation, state management, typed failures, native boundaries, design system, accessibility, localization, and CI foundations.
- `reliable-recording`: Foreground long-duration audio capture, pause/resume/stop state machine, durable segmentation, interruption handling, storage safeguards, and recovery.
- `meeting-sessions`: Local meeting lifecycle, metadata, playback timeline, bookmarks, revisions, processing states, failures, search, and trash behavior.
- `offline-transcription`: Replaceable on-device draft and post-session transcription, versioning, timestamps, editing protection, progress, and measurable performance gates.
- `language-identification`: User-selected language modes, per-segment local identification, uncertainty handling, and manual correction without translation.
- `speaker-diarization`: Post-session speaker labeling for up to six principal speakers, correction workflows, uncertainty, and experimental-quality gates.
- `model-performance-management`: Bundled model inventory, integrity and license metadata, first-run benchmarking, user-selected operating modes, resource monitoring, and explicit degradation.
- `local-export-backup`: Explicit local audio/text export, deterministic backup/restore, collision handling, and privacy-preserving filenames.
- `storage-privacy`: Private local storage, retention, deletion, cache and log policy, offline release checks, uninstall behavior, and storage accounting.
- `device-validation`: Reproducible accuracy, latency, RTF, memory, CPU, thermal, energy, UI responsiveness, recovery, and four-hour stability evidence.

### Modified Capabilities

None. The project contains no existing capability specifications.

## Impact

- Creates the initial Flutter project, Android application, local database, feature modules, test harnesses, CI workflow, and release checks in the independent Loquiris repository.
- Introduces Android microphone and foreground-service permissions but intentionally excludes network permissions from release artifacts.
- Adds native audio capture/encoding and isolated inference adapters, plus bundled model assets whose combined release package target is at most 500 MiB and installed footprint target is at most 800 MiB.
- Uses Fairy only as a read-only reference for proven recording/recovery and test patterns; no Fairy OpenSpec change, sleep-domain code, branding, package identity, or Git history is linked or modified.
- Requires explicit license and provenance approval before any model is included in a release artifact.
