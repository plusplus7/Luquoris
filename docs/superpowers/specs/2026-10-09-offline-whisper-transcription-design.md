# Offline Whisper Transcription Design

**Date:** 2026-10-09

**Status:** Approved direction

**OpenSpec change:** `bootstrap-loquiris-offline-recorder`

**Selected approach:** Native `whisper.cpp` through an isolated Android/JNI boundary

## Problem

Loquiris currently persists a user's selected transcription mode but has no
production `TranscriptionEngine`, no bundled speech model, and no durable
orchestrator that starts transcription. Consequently, a near-real-time meeting
shows no draft text and a post-session meeting does not begin analysis after
recording finalization.

The implementation must provide real offline transcription while preserving the
project's primary invariant: canonical recording must never wait for, or be
invalidated by, AI processing.

## Product outcome

After this work:

- a post-session meeting automatically starts local transcription after durable
  recording finalization;
- the resulting timestamped transcript is stored as a provenance-bearing
  version and is visible in meeting detail;
- interrupted post-session jobs resume safely after process restart;
- near-real-time mode can display bounded sliding-window draft hypotheses;
- live inference can degrade to post-session processing without stopping or
  corrupting recording; and
- all advertised transcription remains usable with Android network permissions
  absent.

Near-real-time remains an experimental capability until the selected Redmi Note
10 Pro passes the OpenSpec latency, RTF, memory, energy, thermal, UI, and
four-hour stability gates. Implementing the path does not itself authorize a
production-quality claim.

## Chosen architecture

### Native inference boundary

Pin a reviewed `whisper.cpp` revision in the repository and build its required
C/C++ sources with the Android NDK and CMake. The release baseline uses CPU and
ARM NEON only. Vulkan, NNAPI, and vendor accelerators are outside this change.

An Android transcription component owns:

- model extraction and native loading;
- AAC-to-16 kHz mono PCM decoding;
- `whisper.cpp` context lifetime;
- inference worker threads;
- cancellation flags;
- timestamp normalization; and
- privacy-safe progress and terminal failure reporting.

Flutter communicates through a versioned transcription channel adapter that
implements the existing `TranscriptionEngine` contract. Native work runs on a
dedicated serial inference executor and never on the Android UI thread, Flutter
isolate, recording control executor, or encoder/finalization worker.

The channel accepts meeting identity plus validated app-relative audio
references. Android resolves all references beneath the application's private
recording root and rejects traversal or mismatched meeting ownership. Absolute
private paths never cross into presentation code.

### Recording isolation

Post-session inference reads only journal-authorized canonical audio. It does
not rewrite the source manifests, journals, or AAC segments. It may reuse a
generation-valid continuous M4A when available, but the absence of a derived
M4A must not be interpreted as absence of audio.

Near-real-time inference attaches to the existing lower-priority branch of
`PriorityPcmFanOut`. The encoder branch remains highest priority. The inference
branch has a fixed capacity and must accept, drop, or replace work without ever
blocking the capture loop. Dropped live work marks the draft delayed or
incomplete and schedules complete post-session processing.

No `whisper.cpp` call occurs on the capture or encoding thread.

## Model supply chain

Use the official multilingual `ggml-base-q5_1.bin` artifact fixed to an exact
source revision, byte length, and SHA-256. The model is approximately 59.7 MB.
The user's approved local workflow is:

1. download the exact artifact into the Git-ignored
   `models/local/<model-id>/` directory;
2. commit a typed manifest containing source, version, expected engine, byte
   length, SHA-256, license snapshot, and enabled experimental modes;
3. run the existing `tool/import_models.dart` verification pipeline;
4. package only the generated, verified model asset tree; and
5. atomically materialize the asset into app-private model storage on first use
   and verify it again before native loading.

The model file itself is never committed to Git. `whisper.cpp` source and the
model weights receive separate license/provenance entries and third-party
notice review. A missing or invalid model disables transcription only; recording
remains available.

The release footprint and installed footprint gates must be rerun after the
model and native libraries are packaged.

## Durable orchestration

Add an application-scoped `TranscriptionCoordinator` and a narrow durable job
repository over the existing `processing_jobs`, `transcript_runs`, and
`transcript_segments` tables.

For a post-session meeting, the coordinator performs these transitions:

1. observe the authoritative recording transition to `finalized`;
2. verify that the meeting selected a transcription-enabled mode;
3. idempotently create a queued processing job and queued transcript run with
   engine/model provenance;
4. mark both running before invoking the engine;
5. persist normalized progress without storing transcript text in checkpoints;
6. atomically save the completed run and stable segments;
7. select the result automatically only when the meeting does not already have
   a current transcript version; and
8. mark the job succeeded, or store a stable failure code and expose retry.

The idempotency key is derived from meeting identity, requested mode, engine
version, model ID, model hash, and inference-parameter version. Duplicate
finalized snapshots therefore cannot launch duplicate runs.

At bootstrap, the coordinator scans queued, running, and resumably paused
transcription jobs. A process death converts an orphaned running job back to a
resumable state. The checkpoint identifies only the last durably completed
media boundary and parameter version; it contains no transcript text. Work may
repeat after the checkpoint, but committed segment identity and database
transactions prevent duplicate visible output.

When a user explicitly requests re-analysis, the new result remains a parallel
version and never silently becomes current.

## Post-session decoding

The native decoder inventories authoritative segments in manifest order and
limits each file to its journal-authorized byte prefix. AAC access units are
decoded to mono 16 kHz PCM and delivered to whisper in bounded windows.

Each result segment includes:

- a deterministic segment ID within the run;
- pause-free media start and end timestamps;
- raw model text;
- deterministically trimmed display text;
- stable status; and
- no automatic translation or simplified/traditional Chinese conversion.

Progress is based on decoded media time divided by authoritative meeting media
duration. Cancellation is cooperative between decode/inference windows. Source
audio remains unchanged on cancellation or failure.

## Near-real-time draft

The live experiment uses a bounded rolling PCM window with a fixed stride. Only
one live decode may run at a time for a meeting. Newer windows may replace
queued obsolete windows, but they may not block recording.

Overlapping hypotheses are reconciled as follows:

- text near the newest window boundary remains unstable and may be replaced;
- a hypothesis becomes stable only after it is outside the replacement horizon
  and its media timestamps are monotonic;
- duplicate overlap is removed deterministically using timestamp and token
  agreement; and
- final stop always schedules a full post-session pass rather than treating
  live draft text as the authoritative final transcript.

Draft events include current backlog. If backlog, memory pressure, low-power
policy, severe thermal state, or engine failure exceeds the supported policy,
the coordinator visibly marks live output delayed/incomplete and falls back to
post-session work. It never attempts to reconstruct silently missed live
context while capture is active.

## UI behavior

The active recording screen observes draft state owned by the application-level
coordinator. It renders stable and unstable text distinctly and shows backlog
or degradation state. Draft text remains read-only; bookmarks and highlights
remain available regardless of inference health.

The meeting detail screen observes durable processing jobs and transcript
versions. It shows queued/running progress, a retryable structured failure, or
the selected completed transcript. Finishing recording navigates to detail as
already designed; automatic post-session processing continues there.

All new user-facing strings are localized in simplified Chinese and English,
and progress/failure changes are exposed through non-color semantics suitable
for TalkBack.

## Failure handling

Stable failure categories cover at least:

- model asset missing, corrupt, or incompatible;
- native runtime unavailable or initialization failed;
- recording inventory invalid or partial;
- audio decode failed;
- inference cancelled;
- inference out of memory;
- inference execution failed;
- result timestamp/order invalid;
- progress/result channel interrupted; and
- database persistence failed.

Native exceptions, absolute paths, audio content, transcript content, meeting
titles, and speaker names are excluded from diagnostic codes and logs.

Partial recordings may be transcribed only over verified usable committed
prefixes and must retain a visible partial-input warning. A database write
failure never deletes native output or source audio; retry either resumes from
the durable checkpoint or safely recomputes derived output.

## Verification strategy

Implementation follows test-driven increments:

1. model manifest/import/build-asset tests;
2. CMake/JNI smoke and native model-load failure tests;
3. AAC decode and timestamp normalization tests with fixed local fixtures;
4. Dart method-channel contract and event parsing tests;
5. durable job state-machine, idempotency, resume, retry, and version-selection
   repository tests;
6. coordinator tests proving finalized post-session meetings automatically
   enqueue once and recording-only meetings do not;
7. live bounded-queue tests proving inference stalls cannot back-pressure the
   encoder;
8. widget/localization/accessibility tests for draft, progress, fallback, and
   failure states;
9. Android device tests using short authorized Chinese, English, and mixed
   samples; and
10. target-device benchmarks and long-run evidence required by OpenSpec before
    enabling near-real-time by default.

Every modified function, class, or method receives GitNexus upstream impact
analysis before editing. High or critical results pause implementation for an
explicit warning. GitNexus change detection is run before any commit.

## Implementation boundaries

This design covers OpenSpec tasks 11.1 through 11.4 and the production workflow
needed for automatic post-session execution and live draft presentation. It
does not claim completion of accuracy benchmarks, `small q5` evaluation,
speaker diarization, or final release enablement. Those remain separately gated
by tasks 11.5–11.8, 12.4–12.8, 13, and 15.

## Rejected alternatives

### Dart FFI owns whisper directly

This reduces channel code but makes native context lifetime, cancellation,
process recovery, private-file resolution, and capture-resource isolation part
of Flutter execution. It increases the chance that inference affects UI or
recording responsiveness and is rejected for the recorder-first product.

### Third-party Android wrapper

An opaque wrapper could shorten initial integration but weakens control over
the exact `whisper.cpp` revision, compiler flags, native threading, model
loading, dependency inventory, and failure mapping. It is rejected unless a
future wrapper independently passes the same provenance and behavior gates.

### Post-session-only implementation

This would solve automatic final transcription faster but leaves the selected
near-real-time mode nonfunctional. It is rejected as the endpoint, although
post-session is deliberately implemented and verified before enabling the live
experiment.
