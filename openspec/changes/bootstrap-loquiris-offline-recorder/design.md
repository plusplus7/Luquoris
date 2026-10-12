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

The recording control channel uses durable, correlated command receipts rather than treating Android intent enqueueing as command completion. Each Flutter command receives a command ID; Android persists `pending`, then the foreground service persists either a terminal success snapshot or a typed failure (including measured and required storage bytes). Flutter polls that receipt with a bounded per-call and overall deadline. A process restart may therefore report the real terminal outcome instead of degrading authoritative failures into a generic timeout.

An application-process liveness registry distinguishes an actually owned foreground session from stale persisted active state. The first channel read after a cold process start reconciles stale `preparing`, `recording`, paused, or `stopping` state through the persisted state machine into `recoverable`; it never reopens the microphone. The Flutter root eagerly activates the app-scoped recording coordinator, so restoration and native snapshot observation do not depend on visiting a recording screen.

Before native start, Flutter durably creates the meeting in `preparing` with its selected transcription, language, and speaker guidance. If native preflight fails before microphone ownership, Flutter removes that meeting only through a guarded repository operation that proves there are no authoritative audio rows and the lifecycle is still `draft` or `preparing`; cleanup refusal remains visible and disables ordinary start retry until authoritative state is reconciled. An accepted command timeout or other ambiguous native result never triggers cleanup: Flutter reads current native authority, adopts a matching active snapshot when available, and otherwise preserves the meeting while disabling ordinary retry. Once native capture succeeds, the existing app-scoped recording coordinator serializes every authoritative command, restoration, and stream snapshot into Drift lifecycle and duration updates without replacing the coordinator instance. A transient database failure never stops capture, remains visible as a persistence warning, and is retried by later snapshots or restoration rather than being lost when the setup route auto-disposes.

Potentially blocking capture drain and encoder finalization execute on one service-owned serial worker. Stop first durably enters `stopping`, then the worker captures the exact boundary, drains/finalizes audio, persists final progress and the terminal command receipt, and only afterward releases foreground and wake-lock ownership. The control channel remains responsive during this work. Every snapshot ingress in Flutter applies the same session/revision monotonicity rule, so a late command result cannot replace a newer observed snapshot.

Alternative considered: Android `MediaRecorder` plus a second capture path for ASR. This risks microphone contention and prevents a controlled single-source stream, so it is not the target design.

### 3. Canonical audio and recoverable segmentation

The selected canonical encoding is mono 16 kHz AAC-LC at 64 kbit/s, approximately 115.2 MB of audio payload for four hours. Four-hour mono 16 kHz/16-bit PCM would be approximately 460.8 MB, and 32 kbit/s AAC approximately 57.6 MB. Selected-target AudioSpecificConfig, objective round-trip, and human listening evidence support AAC-LC 64 kbit/s as the initial balance of intelligibility, ASR input quality, and space.

Recording startup applies a conservative four-hour preflight: the 115.2 MB AAC payload receives 5% container/journal headroom (120,960,000 bytes) and is added to a 512 MiB safety reserve, requiring 657,830,912 available bytes. Active capture warns below a 30-minute estimate plus 256 MiB (283,555,456 bytes). Below one full logical segment with 5% headroom plus a 1 MiB finalization reserve (3,548,416 bytes), AI work yields and capture is safely finalized at the last committed boundary. Both preflight denial and active exhaustion persist a structured low-storage reason with measured and required bytes. The application never deletes recordings or models automatically to make space.

The selected recoverable layout is append-only ADTS plus a checksummed commit journal: commit every 75 AAC frames (4.8 seconds), rotate after 62 commit groups (4,650 frames / 297.6 seconds), and publish the ordered segment manifest by syncing a temporary file, atomically replacing it, then syncing the parent directory. Raw committed segments, journals, codec configuration, and the manifest are authoritative; a continuous M4A and waveform are rebuildable views. Recovery trusts only complete AAC frames authorized by the latest valid journal record and ignores unpublished rotation files. Continuous playback is rebuilt with cumulative-sample timestamps into a temporary M4A, then the completed file is synced, atomically replaced, and followed by a parent-directory sync. A durable building/ready/failed status is bound to a SHA-256 generation of the manifest, journals, committed prefixes, and recovered counters; the resolver accepts only a ready status for the current generation and exact output size. A ready status whose parent-directory sync failed remains quarantined in the current process even if its rename became visible. Startup reconciliation retries a non-live building state after an interrupted rebuild. Critical-low-storage finalization instead persists a failed/deferred status and skips M4A work so the finalization reserve remains available. Recovery save returns a structured playback failure through the Dart boundary rather than falsely reporting the derived artifact as ready. A caller may use the artifact only after that rebuild succeeds; a stale or failed derived artifact is never evidence that audio was committed. A merge failure deletes its temporary output and never hides, rewrites, or invalidates the authoritative segments. Physical power removal, exact-instruction rotation death, and four-hour runs remain release gates rather than assumptions of this selection.

Recovery integrity is evaluated independently from merge success. Segment start samples must equal the preceding journal-authorized end; missing files, a non-empty journal with no valid committed prefix, timeline discontinuity, or discarded post-commit bytes make the session partial. Diagnostics carry stable codes plus an optional manifest sequence only. A present segment that cannot be read because of a transient filesystem `IOException` aborts the whole native inventory with a structured failure; it is never converted into durable corruption evidence. Reconciliation persists current diagnostics in `recovery_findings` within the same Drift transaction as segment and lifecycle changes. The raw-export fallback is a plan, not an external write: it is derived after startup from authoritative `audio_segments`, ordered by manifest sequence, and includes only committed relative paths with their exact journal-authorized byte limits. This allows the user-authorized export flow in Phase 9 to copy no uncommitted or corrupt tail without retaining native absolute paths or duplicating segment authority.

### 4. Explicit recording state machine

The native state machine distinguishes idle, preparing, recording, paused-by-user, paused-by-interruption, stopping, finalized, recoverable, and failed-finalization states. Commands are idempotent and persisted transitions include monotonic and wall-clock timing.

Recovery resolution uses explicit, native-first commands. Saving a recovered meeting never acquires the microphone: native idempotently finalizes a matching recoverable snapshot (or confirms that no matching recorder is active), then Drift changes the meeting from `recoverable` to `finalized`. Explicit continuation runs the normal permission and four-hour storage preflight, verifies the existing authoritative manifest and journal-authorized prefixes, preserves every published segment byte-for-byte, and atomically publishes a new empty continuation segment before capture begins. It continues media duration and byte counters from recovered evidence. A failure at any step leaves the meeting recoverable; neither action silently discards authoritative audio. Repeating either command is safe.

Short audio-focus loss may automatically pause and resume. A completed phone call does not silently reopen the microphone: the application requests user confirmation. Swiping away the Flutter task does not stop an active recording. Process or device restart recovers existing material but never automatically activates the microphone.

Call interruption detection follows a permission-minimizing policy. The recorder does not request `READ_PHONE_STATE` and does not inspect phone numbers, call logs, or subscription data. While capture is active, the foreground service combines audio-focus callbacks, call-like `AudioManager` modes, and `AudioRecordingConfiguration.isClientSilenced` for its own audio session. A transient focus loss can auto-resume only when no call-like or ambiguous microphone interruption was observed. Any interruption observed in a call-like audio mode, and any ambiguous microphone silence whose cause cannot be safely excluded, is upgraded to confirmation-required and cannot reopen the microphone until an explicit user command. This deliberately prefers an extra confirmation over accidentally capturing after a call.

### 5. Versioned local data model

Drift stores meetings, audio segments, session events, bookmarks, transcript runs, transcript segments, language decisions, speaker clusters, speaker assignments, revisions, processing jobs, model manifests, and export/backup records. Each meeting also stores the processing mode and optional expected speaker count selected before capture, while a single local settings row remembers the user's next-recording defaults. Audio bytes remain files in app-private storage rather than database blobs.

Storage accounting reconciles two authorities without double counting. Android `StorageStatsManager` measures this application's code, private data, cache, and currently available device bytes for the app UID on a background executor. Drift separately sums only journal-authorized committed audio, partitioned into active meetings and trash. The application/models category is Android application bytes plus the non-negative residual private-data total after subtracting cache, active-meeting audio, and trash audio. Model-manifest bytes are explanatory detail already contained within that category, never an additional total. Temporarily inconsistent platform/database observations clamp the residual at zero. The localized screen exposes loading, typed failure, and explicit retry states and explains that bundled all-model assets cannot be removed individually.

Rebuildable-cache cleanup is an explicit user action over exactly four direct children of Android's application cache directory: `pcm`, `waveforms`, `search_indexes`, and `failed_jobs`. Native code does not scan unknown cache siblings, follow symbolic links, or touch application files, recordings, backups, the database, or trash. The versioned storage channel returns only deleted-file and deleted-byte counts, including partial counts on a typed failure; it never returns private paths. Cleanup runs on the storage worker executor, coalesces repeat taps, refreshes accounting after either success or partial failure, and reports localized progress and outcomes.

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

The MVP backup container is a streaming ZIP with `manifest.json` first, followed by canonical `payload/checksums.json` and the allowlisted payload. The manifest independently versions the container and database schema, records application-version provenance and an injected UTC instant, declares `encrypted:false`, and hashes the exact checksum-index bytes. The index sorts safe POSIX archive paths and records the byte length and lowercase SHA-256 of every remaining payload entry. The payload contains a SQLite `VACUUM INTO` snapshot plus native recording manifests, valid journal prefixes, and exact committed segment prefixes. Collection starts from database authority and native manifest validation rather than walking the whole files directory; model binaries, caches, derived playback/waveform/index artifacts, temporary files, and diagnostics therefore cannot enter by accident. Model provenance rows inside the database snapshot remain necessary meeting-analysis metadata, not bundled weights. Building computes hashes before publication, streams to a temporary private file, fsyncs it, and atomically renames only a complete archive; any failure deletes the temporary file.

Restore treats every archive as hostile input before live-data mutation. Native verification requires the exact manifest/checksum entry order, supported format and database schema versions, safe allowlisted paths, exact file sets, byte lengths, hashes, CRC-valid recording manifests, meeting-derived storage keys, and manifest-authorized segment/journal prefixes. It computes a semantic audio fingerprint independent of meeting identity and publishes only a fully verified private staging tree. Dart migrates the staged database copy, cross-checks every database audio row against the verified native recording index, and then fingerprints complete meeting aggregates plus audio. Identical meetings are skipped. A same-ID content conflict receives deterministic UUID-v5 meeting and child identities, rewritten foreign keys and recording paths, and a localized restored-copy title; repeating the same restore remains idempotent even if the active locale or copy title changes. Required model provenance is imported or deterministically remapped by semantic content rather than silently rebound to a conflicting local model.

Database rows and authoritative audio are committed as one recoverable operation. The importer runs in a single Drift transaction and publishes each recording directory atomically before its meeting rows become visible. Published directories retain a restore-operation marker until the database transaction commits; a transaction failure removes only directories carrying that operation's marker. Startup reconciliation deletes marked directories with no matching database audio authority and clears markers for committed meetings, covering process death between filesystem publication and database commit without deleting unrelated recordings. Verified staging and native temporary trees are bounded startup-cleanup targets and are never treated as authoritative meeting data.

Direct SAF exports use one generated operation ID across Dart, the native channel, live progress, cancellation, and the durable `export_records` row. The row records meeting, format, timestamps, pending/completed/failed state, completed bytes, and a stable privacy-safe failure code; it never records a destination URI or the user-edited external display name. A completed direct export therefore has bytes but no app-private relative path, while a future private staging workflow may populate that optional path. Native progress reports destination selection, byte-based writing, and finalization. Cooperative cancellation is checked between bounded writes, closes the destination, and attempts deletion. Provider cleanup refusal is returned and persisted as a distinct code so the UI identifies that an incomplete external file may remain rather than claiming cleanup succeeded.

Deletion moves a meeting to a seven-day local trash and persists its immediately preceding durable lifecycle so restoration does not turn recoverable or unfinished audio into a falsely finalized meeting. Confirmed permanent deletion first commits a non-restorable `deleting` reservation while retaining every audio path, then removes all authoritative segment files including paths whose rows were soft-deleted, and finally removes database records. A file or final database failure leaves the reservation and metadata available for safe cleanup retry; it never makes a meeting restorable after audio may have been removed. The app never automatically deletes trash or authoritative data for space; it may automatically remove only rebuildable PCM blocks, waveforms, indexes, and failed-job intermediates. Uninstall removes app-private data. Local diagnostic logs roll at seven days or 10 MiB and exclude audio, full transcripts, titles, names, and sensitive paths.

### 11. Product surface and accessibility

The initial usable surfaces are session list/search, new recording, active recording and draft, session detail/playback, combined basic text/speaker correction, export, models/performance, and storage/privacy. UI is localized in simplified Chinese and English, follows Material 3 and Loquiris-specific tokens, and uses available width rather than device checks.

Session detail reads one transactionally consistent local projection containing the meeting, authoritative segment metadata, wall-clock events, bookmarks/highlights, current processing jobs, and recovery findings. Playback is isolated behind an injectable `SessionPlaybackService`; Dart supplies only the meeting identity, a screen-scoped ownership token, and media-time commands. The Android implementation resolves the current generation-validated derived M4A inside app-private storage on a serial background Looper, prepares media asynchronously, and exposes typed unavailable/failure states without returning a private absolute path to Dart. It never treats a stale, building, failed, or quarantined artifact as playable. A seek command completes only after the native player confirms its position. Replacement loads transfer ownership atomically, and a stale screen release or observation cannot close or update the replacement session. Search and bookmark navigation seek on the pause-free media timeline; event presentation retains wall-clock ordering.

Critical controls use text, icon, color, semantic labels, TalkBack announcements, at least 48 dp targets, and accessible confirmations. The active state is always conspicuous; no stealth mode exists. The UI uses a throttled input-activity indicator during capture and builds overview waveforms only after recording.

### 12. Layered verification and release labels

Host CI covers formatting, strict analysis, unit/widget tests, Android JVM tests, builds, model-manifest checks, third-party notices, and offline release scans. Instrumented tests cover foreground service, permissions, process recreation, storage failure, and recovery. Long model and device runs are signed manual release evidence rather than ordinary PR jobs.

`Recorder MVP` and `Offline Transcription Preview` are separate release labels. The recorder label requires all reliability, privacy, export, accessibility, and four-hour gates. Transcription requires the accuracy, RTF, latency, memory, energy, thermal, and UI gates in addition.

## Risks / Trade-offs

- **[Single-device evidence is narrow]** Passing one REDMI SKU does not establish market-wide compatibility. → Bind reports and claims to exact hardware, build, battery health, and environment; accept community matrices only as additional evidence.
- **[Recoverable AAC evidence remains device- and fault-scope-bound]** The selected ADTS/journal/manifest design passed truncation, repeated process kill/force-stop, directory-sync, rebuild, decode, player, and human-listening gates on the selected device, but not physical power removal or a four-hour production implementation. → Preserve the measured ordering and recovery invariants in Phase 6, then run the required long recorder/release matrix without treating the spike as broad OEM proof.
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

- Do `base q5` and `small q5` meet the agreed Chinese, English, mixed-language, energy, thermal, and RTF gates on the selected firmware?
- Which fully redistributable bilingual streaming model, if any, has sufficient provenance to replace sliding-window draft decoding?
- Can the selected diarization model set remain inside the package/installed-size budgets while meeting DER and six-speaker stability gates?
- What battery-health/cycle record, memory-extension state, and controlled-environment record will complete the first signed evidence for the selected Android 13 / MIUI 14 firmware?
