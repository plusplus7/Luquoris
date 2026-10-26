## Context

The current application preserves authoritative audio independently of optional transcription. Dart coordinates durable post-session jobs and bounded live drafts; Android feeds canonical PCM into `whisper.cpp`. The existing adapter recognizes buffered windows and reconciles hypotheses, but increasing its model size raises the cost of decoding those windows.

The paired test in `docs/evidence/whisper-small-comparison.md` measured base RTF 0.548 and small RTF 1.574 on `M2104K10AC`/`chopin`. It supplies neither an accuracy reference nor verified code-switch coverage. A single batch RTF measurement is not a first-text latency or sustained live-capacity result.

The original bootstrap change remains in progress. Its recorder-first priority, versioned transcripts, explicit current-version selection, offline release permissions, four-hour evidence obligations, and 500 MiB/800 MiB footprint budgets remain applicable.

## Goals / Non-Goals

**Goals:**

- Produce useful provisional Chinese and mixed Chinese/English text during recording entirely on-device.
- Target first visible text p95 ≤2 seconds, finalized utterance delay p95 ≤3 seconds, sustained processing RTF ≤0.7, and non-growing backlog on the evidence device.
- Refine the complete authoritative recording after durable finalization, without losing live evidence or human edits.
- Select model pairs using measured role-specific quality, speed, battery, memory, stability, and license evidence.
- Keep capture, pause, stop, persistence, playback, and recovery reliable when either inference pass fails.

**Non-Goals:**

- Cloud ASR, network audio upload, runtime model downloads, or compatibility with a proprietary recording card.
- Real-time translation, automatic language rewriting, automatic generative correction, or live speaker diarization.
- Guaranteed zero latency, production eligibility on every Android device, or selecting Whisper small as the final production model before evaluation.
- Overwriting the current transcript or resolving arbitrary manual edits across unrelated segmentation automatically.

## Decisions

### 1. Separate streaming and complete-pass engines

Introduce an injectable streaming boundary with session-scoped recognizer state, incremental PCM input, partial/utterance-final events, cancellation, and typed failures. Preserve the existing complete-audio engine role behind its own interface. Native implementations run outside the Flutter isolate and recorder callback.

Confirmed on 2026-10-16 after an incompatible candidate terminated its isolated
probe process: experimental streaming native code runs in a separate,
application-private Android process behind a non-exported bound service. The
existing recorder process remains authoritative. This is a process boundary,
not an Android `isolatedProcess` UID sandbox or a guarantee against device-wide
memory/CPU pressure. Bindings have fresh owner/epoch identity; at most one PCM
request is in flight and only matching remote inference acknowledgement removes
it from pending ownership. Sending IPC, timing out, or unbinding is not release
acknowledgement. Confirmed Binder death degrades the draft and settles that dead
owner's resources; normal closure waits for the remote release acknowledgement.
Late/reordered callbacks cannot revive an owner or publish closed-owner text.
The experimental service/runtime remains disabled from normal app selection
until runtime, model-set and device gates are satisfied.

Evaluate a compact sherpa-onnx Chinese/English streaming Zipformer first, with a streaming Paraformer candidate as an alternative if license and footprint checks permit. These are candidate families, not a locked dependency or an asserted performance result. Record exact artifact revisions and runtime builds before the comparison.

Whisper small is the initial complete-pass comparison baseline. A different compliant offline model can fill that role if small misses quality or footprint gates. Repeatedly decoding larger overlapping Whisper windows remains a fallback experiment, not the planned production streaming design; cloud processing conflicts with the existing offline contract.

### 2. Preserve one authoritative recording path and bounded PCM fan-out

The foreground recorder continues durable canonical audio commits. A bounded, non-blocking consumer receives a copy of canonical mono PCM; backpressure from recognition never reaches microphone reads or durable recording writes.

Live processing owns one session and one live recognizer. Recorder pause/resume and audio-focus interruptions close or reset utterance state with explicit capture-time discontinuities. Timestamp conversion uses media coordinates and recorded gaps, never inference completion time. Explicit run/session/epoch IDs filter late callbacks after stop, cancellation, replacement, or process loss.

If unprocessed unique captured audio exceeds five seconds for three consecutive one-second observations, live inference degrades and releases its resources. Thermal `SEVERE`, unrecoverable memory pressure, engine failure, and unavailable model bundles trigger the same recording-safe path immediately. No catch-up inference can starve recorder controls. The UI preserves the last draft and indicates incomplete live coverage and pending complete-pass work.

### 3. Distinguish provisional text, utterance finalization, and refined output

Use monotonic event sequences and stable utterance IDs within a run. Partial events can replace only the currently provisional hypothesis; an utterance-final event seals its model text. All live text remains read-only during capture. Bookmarks and highlights retain capture-time anchors.

The draft is a separately identified, incomplete-capable transcript version. A complete-pass result is another version, linked to its source recording and processing role. Present an explicit readiness state and version switch; completion alone does not change the current version used by search, playback annotations, text export, or backup.

Human edits belong to their source version. Display a comparison without copying corrections through ambiguous timestamp or token matches. Switching versions never deletes corrections, raw model output, bookmarks, or earlier runs. This is safer than treating an entire completed second pass as replacement text for the current editor.

### 4. Queue refinement only after durable capture finalization

When the meeting selection requests two-pass processing, recording finalization schedules a complete-audio job only after the finalized manifest and ordered audio inventory are durably readable. Both models cannot compete with active capture: refinement is deferred while any recording is active and visibly pauses at safe boundaries if a new recording starts.

Deduplication includes meeting/audio identity, engine/model bundle identity, processing role, parameters, and parameter schema. Recovery never interprets an old draft-engine job as a refinement job. Cancellation/retry preserves completed versions and restarts or resumes only against verified authoritative audio; no draft PCM buffer is required to reconstruct the final output.

The existing versioned repository may already express these identities. Audit it first; add a forward-only migration only if a required role/link/state cannot be represented safely. Do not infer acceptance of old jobs under a new engine or model hash.

### 5. Verify an atomic multi-file model bundle

Streaming models can require encoder, decoder, joiner, tokenizer, and configuration files. Extend manifests to schema v2 with a sorted inventory of safe relative paths, byte lengths, SHA-256 values, artifact roles, immutable sources, and exact runtime compatibility. Preserve the v1 parser and approved base inputs.

Define the bundle digest as SHA-256 of canonical UTF-8 JSON containing the sorted `{path, role, bytes, sha256}` inventory. Tests fix the canonical encoding, key order, UTF-8 behavior, and complete-file coverage. A live or final run records this digest, selected model role, runtime version, and decoding settings.

Import and publication are atomic for the entire set; verify all files before allocating any recognizer state. A missing or modified tokenizer fails the bundle just like a corrupt encoder. Production packaging uses only explicitly approved role bundles, and debug candidates remain outside ordinary production imports and release artifacts.

### 6. Gate the experience with separate quality and resource evidence

Qualification uses at least 30 held-out, human-verified minutes for each of Chinese, English, and actual within-utterance Chinese/English switching. Include names, domain terms, near/meeting-room distance, quiet/noisy conditions, and interruptions. Consent, audio hashes, annotations, normalization rules, and scoring code are fixed before final evaluation. The old fixture remains a smoke input until its coverage annotation is audited.

Initial proposed quality ceilings for normalized stabilized live output are Chinese CER ≤20%, English WER ≤25%, and mixed MER ≤25%. Refined output must achieve CER ≤15%, WER ≤20%, and MER ≤20%, improve the equally weighted mean of those three error rates by at least 15% relative to the first pass, and regress no individual language metric by more than two percentage points. These are explicit acceptance targets, not measured results. A failed candidate is not promoted by relaxing thresholds after seeing held-out output; revising targets requires a recorded spec decision.

Measure cold and warm sessions separately, with at least 30 eligible utterances per language stratum and at least ten cold starts. First-text time starts at the first voiced captured sample, including queued input and model loading; stable delay starts at the final voiced sample and includes endpointing. Do not dilute scores with synthetic silence, cherry-picked utterances, or empty partial events.

Track effective voiced and total processing RTF over non-overlapping 60-second windows, unique-audio backlog, CPU, continuously sampled PSS/RSS, battery, thermal state, failures, and UI frames. The ≤0.7 gate applies to speech-bearing windows and their run aggregate; backlog p95 must stay ≤2 seconds. Required release evidence includes at least two four-hour live runs plus controlled interruption/recovery tests under the original device/environment obligations. Live battery remains ≤12% per hour, severe-jank frames <1%, and critical recorder feedback ≤500 ms.

RTF goals leave headroom for Android scheduling and recorder work. The complete-pass high-quality gate remains RTF ≤2.0; it is not used to advertise live capability. An approved model's benchmark recommendation never changes the user's meeting settings automatically.

## Risks / Trade-offs

- [Larger model pairs exceed footprint or RAM budgets] → Compare compact streaming candidates first, use one live recognizer, release it before refinement, and measure actual APK/AAB and installed/materialized bytes against existing budgets.
- [Model license differs from runtime license] → Review every weight, tokenizer, and native dependency independently; do not equate an open runtime with redistribution rights for its models.
- [Streaming draft improves speed but loses names or English terms] → Score each language and proper-name subset; keep the candidate experimental when any required stratum fails.
- [Endpoint tuning lowers latency by cutting utterances] → Measure stable latency and lexical error together, retaining pause and code-switch examples in the held-out corpus.
- [Second pass consumes battery or interferes with a new meeting] → Keep refinement outside active capture, observe thermal/battery policy, and resume durably after resources recover.
- [Stale callbacks or new segmentation overwrite user work] → Use run/epoch/utterance identities and separate transcript versions with explicit selection.
- [Existing partial implementation overlaps this change] → Audit the parent change and current uncommitted work first; reuse established recorder/recovery seams and keep evidence/task completion distinct.

## Migration Plan

1. Establish corpus/scoring and pinned candidate license/provenance evidence before a production engine is chosen.
2. Introduce optional streaming and manifest-v2 seams with backward-compatible v1 reading and tests; migrate durable state forward only if the audit establishes a need.
3. Enable a debug-only paired-engine prototype, run direct PCM tests, and then validate actual microphone capture on the target device.
4. Add the version comparison/refinement workflow and failure/recovery tests, preserving existing meeting data and current transcript selections.
5. Promote a specific model pair only after quality, sustained live, footprint, license, and long-run gates pass. Otherwise retain the experiment and the approved recorder/post-session release.

Rollback disables new live selection and leaves recording, old transcripts, and post-session processing available. It does not delete recordings or require a reverse database migration. Changed model sets require a new application build; the runtime never downloads a replacement.

## Open Questions

- Which exact bilingual streaming bundle and complete-pass bundle satisfy all quality, licensing, and footprint gates together? Resolve by the candidate comparison milestone.
- Does the current durable run/job schema express processing role, source-version linkage, and selected bundle digest, or is a forward migration required? Resolve before persistence implementation.
- Does the short benchmark's current language annotation need a corrected annotation version? Audit the source and add genuinely bilingual evaluation material without changing the immutable WAV silently.
- Are proposed quality ceilings realistic for ordinary meeting-room distance on the declared device? Use a separate development corpus for tuning; held-out results remain the release decision input.
