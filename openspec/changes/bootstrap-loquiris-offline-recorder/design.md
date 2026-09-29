## Context

Loquiris starts as an independent Git repository with OpenSpec initialized but no Flutter application. Fairy is a read-only reference: its strongest reusable patterns are Android foreground recording, segmented durable storage, recovery manifests, WorkManager analysis, release privacy checks, and layered testing. Fairy does not provide the proposed Riverpod, GoRouter, Drift, typed-result, or strict feature-first foundation, and its sleep-domain models and Noctis visual language are out of scope.

The target is an offline Android application that treats captured audio as the primary record and all AI output as optional, reproducible derived data. The first release gate is the connected mainland-China Redmi Note 10 Pro (`M2104K10AC`/`chopin`, 6GB+128GB class); passing that gate proves only that exact hardware, firmware, and environment. Unmeasured transcription and diarization behavior remains experimental.

## Goals / Non-Goals

**Goals:**

- Preserve at least four hours of meeting audio through backgrounding, lock-screen use, pauses, interruptions, low resources, and recoverable process failure.
- Keep capture independent from Flutter UI, database latency, and inference health.
- Support user-selectable near-real-time draft transcription or post-session transcription through replaceable native engine boundaries.
- Represent transcript, language, speaker, processing, model, and revision provenance explicitly in a local Drift database.
- Provide understandable degradation, thermal protection, progress, storage accounting, local search, correction, export, backup, and deletion behavior.
- Build an accessible bilingual Material 3 interface with Loquiris-specific quiet, restrained, professional visual semantics.
- Ship without runtime networking, telemetry, advertising, remote configuration, accounts, or hidden model downloads.
- Produce repeatable accuracy, performance, energy, thermal, recovery, and four-hour evidence before enabling AI by default.

**Non-Goals:**

- Cloud transcription, cloud analysis, synchronization, accounts, remote crash upload, or remote model delivery.
- LLM summarization, translation, semantic/vector search, automatic action items, or invented meeting conclusions.
- Call recording, stealth recording, cross-meeting voice identity, or biometric identity enrollment.
- Real-time speaker diarization, reliable separation of overlapping voices, or guaranteed support for more than six principal speakers.
- A general claim of compatibility with all low-cost Android phones based on one device.
- iOS, desktop, web, sophisticated tablet layouts, or broad external microphone compatibility in the MVP.
- Reusing Fairy sleep concepts, application identity, branding, OpenSpec changes, Git history, or domain code.

## Decisions

### 1. Feature-first Flutter shell with explicit boundaries

The Flutter layer will use feature-first modules with Riverpod view models, one GoRouter configuration, Drift repositories, hand-written sealed `Result<T, F>` failures, and constructor-injected service interfaces. Shared code is limited to true cross-cutting foundations such as design tokens, routing, database infrastructure, and typed errors.

The initial feature areas are sessions, recording, transcript, speakers, export/backup, models/performance, and storage/privacy. Flutter code depends only on interfaces such as `AudioCaptureService`, `TranscriptionEngine`, `SpeakerDiarizationEngine`, `LanguageIdentificationEngine`, `ModelManager`, `ThermalAndPerformanceMonitor`, `SessionRepository`, and `ExportService`.

Alternative considered: reproduce Fairy's global `ChangeNotifier`, manual navigation, and sqflite repository. This is rejected because long-running capture and versioned processing require narrower state ownership, generated query safety, and independently testable failures.

### 2. Native capture is the reliability authority

One Android foreground service owns microphone capture, monotonic timing, audio focus, encoding, segment manifests, notification state, and recovery metadata. A single `AudioRecord` PCM stream fans out to:

1. a highest-priority bounded path that encodes and durably commits the canonical recording; and
2. a lower-priority bounded inference path that may lag, drop draft work, or stop without back-pressuring capture.

Flutter observes snapshots and issues idempotent commands; it is not the recording clock or source of truth. Pause removes time from the media timeline while wall-clock events retain the real pause interval. Notification actions support pause/resume and bookmarking; stop returns to the application for confirmation.

Alternative considered: Android `MediaRecorder` plus a second capture path for ASR. This risks microphone contention and prevents a controlled single-source stream, so it is not the target design.

### 3. Canonical audio and recoverable segmentation

The target canonical encoding is mono 16 kHz AAC-LC at 64 kbit/s, approximately 115.2 MB of audio payload for four hours. Four-hour mono 16 kHz/16-bit PCM would be approximately 460.8 MB, and 32 kbit/s AAC approximately 57.6 MB. AAC 64 kbit/s is selected as the initial balance of intelligibility, ASR input quality, and space.

Short durable commits or journaling cap crash loss at five seconds, while logical segments are approximately five minutes to avoid thousands of user-visible files. The exact recoverable container and muxing method remains subject to a truncation/force-stop spike. Raw committed segments and their manifest are authoritative; a merged M4A and waveform are rebuildable views. A merge failure never hides or invalidates the segments.

### 4. Explicit recording state machine

The native state machine distinguishes idle, preparing, recording, paused-by-user, paused-by-interruption, stopping, finalized, recoverable, and failed-finalization states. Commands are idempotent and persisted transitions include monotonic and wall-clock timing.

Short audio-focus loss may automatically pause and resume. A completed phone call does not silently reopen the microphone: the application requests user confirmation. Swiping away the Flutter task does not stop an active recording. Process or device restart recovers existing material but never automatically activates the microphone.

### 5. Versioned local data model

Drift stores meetings, audio segments, session events, bookmarks, transcript runs, transcript segments, language decisions, speaker clusters, speaker assignments, revisions, processing jobs, model manifests, and export/backup records. Audio bytes remain files in app-private storage rather than database blobs.

Every analysis run records engine version, model hash, parameters, timestamps, progress, and failure. Re-analysis creates a parallel version. Human edits are separate revisions and are never overwritten by a model. Media timestamps exclude pauses; event records also preserve wall-clock time.

### 6. Two transcription modes with independent release gates

Before each meeting the user selects near-real-time draft or post-session analysis; settings remember the last/default selection. A live session may degrade from real-time to post-session but will not attempt to activate real-time processing midway and reconstruct missing context.

The first distributable spike is `whisper.cpp` with multilingual `base q5`. It evaluates post-session accuracy and a sliding-window draft baseline, not a claim of true streaming. `small q5` is a bundled high-quality candidate if it passes license, size, and target-device gates. A sherpa-onnx adapter may be developed behind an experimental flag, but bilingual Zipformer weights cannot ship until their fixed license and provenance are acceptable.

CPU/ARM NEON is the release baseline. Vulkan, NNAPI, and vendor accelerators are optional per-device experiments with lossless CPU fallback. If no compliant model passes, near-real-time remains disabled and only the recorder is released.

### 7. Post-session language and speaker processing

Language mode is Chinese, English, or mixed. Chinese and English act as strong hints but do not delete foreign-language words. Mixed mode stores per-segment language or uncertain status and never translates. Only calibrated confidence becomes a user-facing low-confidence label.

Speaker diarization runs after the meeting and uses an interchangeable offline segmentation, embedding, and clustering engine. The user can select automatic or an expected count of two through six speakers. Stable internal speaker IDs are distinct from editable display labels. Names are never transferred to a new analysis run or another meeting without confirmation. DER must be at most 25% on the defined non-overlap test set before automatic labels are enabled by default; otherwise they remain experimental.

### 8. Performance modes and explicit degradation

Modes are high quality, balanced, power saving, recording only, and post-session analysis. A reproducible 30–60 second bundled audio benchmark recommends a mode without using the microphone or changing settings automatically.

The recorder has resource priority. At Android thermal status `MODERATE`, inference concurrency is reduced; at `SEVERE`, AI pauses while capture continues. Queue backlog, memory pressure, low power, unsupported acceleration, or engine failure similarly degrades AI with an immediate visible explanation. No degradation silently discards canonical audio or stable transcript revisions.

### 9. Offline model distribution and open-source posture

All production models that pass the gates are bundled into each installable artifact; there is no runtime download or removable extension pack. The target release-package size is at most 500 MiB and installed footprint at most 800 MiB. Bundled production models are not individually deletable, but generated caches are.

Every model has an immutable manifest containing source, version, hash, byte length, license snapshot, and expected engine. The application project is non-commercial, but all distributed code and weights must still permit commercial use and redistribution to satisfy the project's fully open-source definition. License-unclear or non-OSI/source-available candidates remain research notes, not release assets.

Release variants include AAB, ABI-specific APKs, and an explicitly larger universal APK. Release manifests must exclude `INTERNET` and `ACCESS_NETWORK_STATE`; build gates scan dependencies and the merged manifest for network, telemetry, advertising, and remote-configuration capabilities.

### 10. Privacy-preserving lifecycle and portability

All data defaults to app-private storage and Android cloud backup is disabled. Explicit export supports M4A, TXT, SRT, and structured JSON, optionally packaged as ZIP. Default filenames contain date/time but not meeting titles or speaker names.

Backups contain meetings, authoritative audio segments, transcripts, revisions, bookmarks, and metadata, but not bundled models, caches, or logs. MVP backups are unencrypted and display a sensitive-data warning. Restore uses hashes to skip identical records and creates a new ID for conflicting content.

Deletion moves a meeting to a seven-day local trash and persists its immediately preceding durable lifecycle so restoration does not turn recoverable or unfinished audio into a falsely finalized meeting. Confirmed permanent deletion first commits a non-restorable `deleting` reservation while retaining every audio path, then removes all authoritative segment files including paths whose rows were soft-deleted, and finally removes database records. A file or final database failure leaves the reservation and metadata available for safe cleanup retry; it never makes a meeting restorable after audio may have been removed. The app never automatically deletes trash or authoritative data for space; it may automatically remove only rebuildable PCM blocks, waveforms, indexes, and failed-job intermediates. Uninstall removes app-private data. Local diagnostic logs roll at seven days or 10 MiB and exclude audio, full transcripts, titles, names, and sensitive paths.

### 11. Product surface and accessibility

The initial usable surfaces are session list/search, new recording, active recording and draft, session detail/playback, combined basic text/speaker correction, export, models/performance, and storage/privacy. UI is localized in simplified Chinese and English, follows Material 3 and Loquiris-specific tokens, and uses available width rather than device checks.

Critical controls use text, icon, color, semantic labels, TalkBack announcements, at least 48 dp targets, and accessible confirmations. The active state is always conspicuous; no stealth mode exists. The UI uses a throttled input-activity indicator during capture and builds overview waveforms only after recording.

### 12. Layered verification and release labels

Host CI covers formatting, strict analysis, unit/widget tests, Android JVM tests, builds, model-manifest checks, third-party notices, and offline release scans. Instrumented tests cover foreground service, permissions, process recreation, storage failure, and recovery. Long model and device runs are signed manual release evidence rather than ordinary PR jobs.

`Recorder MVP` and `Offline Transcription Preview` are separate release labels. The recorder label requires all reliability, privacy, export, accessibility, and four-hour gates. Transcription requires the accuracy, RTF, latency, memory, energy, thermal, and UI gates in addition.

## Risks / Trade-offs

- **[Single-device evidence is narrow]** Passing one REDMI SKU does not establish market-wide compatibility. → Bind reports and claims to exact hardware, build, battery health, and environment; accept community matrices only as additional evidence.
- **[Recoverable AAC design is unproven]** Common M4A finalization can lose the active container after abrupt termination. → Spike recoverable commits/container choices before committing the recording backend; test truncation and process death repeatedly.
- **[Shared PCM fan-out can still starve]** Encoding or inference could consume capture buffers under load. → Use bounded queues, dedicated priorities, drop only AI work, and instrument underruns and audio gaps.
- **[Whisper may miss low-end real-time targets]** Sliding-window decoding can duplicate work and heat the device. → Treat it as a measured spike; ship post-session only or recorder-only if gates fail.
- **[Open bilingual streaming weights may lack acceptable provenance]** A compatible runtime license does not license a community model. → Gate every weight separately; do not bundle unclear artifacts.
- **[Bundled models inflate install and update size]** Shipping base, high-quality, and diarization weights may exceed targets or duplicate extracted assets. → Measure AAB/APK and installed footprints early; remove models that do not pass value and size gates rather than introducing hidden downloads.
- **[Diarization quality collapses under overlap and distance]** Clustering cannot reliably unmix simultaneous speakers. → Mark overlap/uncertain regions, provide correction tools, and keep the feature experimental below the DER gate.
- **[OEM background restrictions vary]** MIUI or HyperOS may terminate services despite correct Android APIs. → Gate the selected device on its installed MIUI 14 default and unrestricted battery modes, treat HyperOS behavior as unverified extension risk, provide honest system-specific guidance, and persist recoverable segments continuously.
- **[Unencrypted backup is sensitive]** User-selected destinations can expose meetings. → Require explicit action and warning, use privacy-preserving filenames, and document encryption as a future change rather than implying protection.
- **[No network permission limits repair]** Corrupt bundled models cannot be downloaded again in-app. → Verify hashes, disable only affected AI capabilities, preserve recording, and instruct reinstall from a trusted release.

## Migration Plan

This is a greenfield bootstrap with no production data migration.

1. Create the Flutter/Android shell, offline release gates, typed boundaries, fake engines, and local schema.
2. Implement and verify native capture, segment manifests, recovery, interruption handling, and four-hour recorder evidence before integrating a real AI engine.
3. Add versioned processing jobs, model manifests, benchmark harnesses, and `whisper.cpp base q5` behind a preview gate.
4. Enable transcription only on configurations with recorded passing evidence; retain a fully functional recorder-only mode.
5. Add language and post-session diarization behind independent gates.

Rollback is capability-based: disable or remove the failing AI model/adapter while retaining schema records and canonical audio. A recording format or schema change must be forward-only and include explicit compatibility tests before release.

## Open Questions

- Which recoverable AAC container/commit strategy passes the five-second loss and gap-free playback tests on the target device?
- Do `base q5` and `small q5` meet the agreed Chinese, English, mixed-language, energy, thermal, and RTF gates on the selected firmware?
- Which fully redistributable bilingual streaming model, if any, has sufficient provenance to replace sliding-window draft decoding?
- Can the selected diarization model set remain inside the package/installed-size budgets while meeting DER and six-speaker stability gates?
- What battery-health/cycle record, memory-extension state, and controlled-environment record will complete the first signed evidence for the selected Android 13 / MIUI 14 firmware?
