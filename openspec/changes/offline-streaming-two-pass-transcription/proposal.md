## Why

Loquiris needs useful text while a meeting is still being recorded, without uploading audio or sacrificing the original recording. The 2026-10-14 target-device comparison found that Whisper base produces poor Chinese text and Whisper small takes 70.824 seconds for 45 seconds of audio, so increasing the current model size alone does not meet that goal.

## What Changes

- Introduce a replaceable, genuinely streaming on-device recognition engine for Chinese, English, and Chinese/English code-switching; evaluate sherpa-onnx streaming Zipformer and streaming Paraformer candidates rather than committing to a model before measurement.
- Display timestamped provisional text during capture with bounded latency and backlog, explicit utterance finalization, visible degradation, and independent recorder controls.
- After recording is durably finalized, run a separately selected higher-quality offline model over the complete authoritative audio. Retain the live draft, the refined output, and human edits as distinguishable versions; require explicit selection before refined output becomes current.
- Support bundled multi-file streaming model sets with atomic integrity checks, immutable provenance, license review, and backward-compatible base-model manifests.
- Establish separate live and final accuracy gates, actual bilingual evaluation, repeated latency measurements, four-hour resource/stability evidence, and release gating on the exact `M2104K10AC`/`chopin` configuration.
- Preserve the offline release posture, existing package/installed-size budgets, and recording-first degradation. There is no cloud transcription, runtime weight download, translation, or dependency on a recording-card vendor.

## Capabilities

### New Capabilities

- `streaming-draft-transcription`: Local incremental recognition, language preservation, bounded live latency/backlog, capture-time alignment, and recording-safe fallback.
- `two-pass-transcription`: Complete offline refinement after capture, independent engine/model roles, durable jobs, version selection, and protection of user corrections.
- `streaming-transcription-qualification`: Multi-file model integrity, reproducible role-specific accuracy/performance evidence, and evidence-gated production availability.

### Modified Capabilities

None in the canonical `openspec/specs/` tree, which currently contains no published capabilities. These new capabilities supplement the pending `bootstrap-loquiris-offline-recorder` requirements; they do not archive, rewrite, or mark that change's unfinished tasks complete. In overlapping behavior, the stricter live gate in this change applies to the new streaming capability.

## Impact

- Changes transcription service/native boundaries, live draft coordination, timestamp reconciliation, post-session scheduling, transcript version presentation, and model/runtime management; recording storage remains authoritative.
- May add sherpa-onnx/ONNX Runtime and candidate weights after pinned provenance and individual runtime/weight license checks. The selected implementation must fit the existing 500 MiB release and 800 MiB installed budgets.
- Requires versioned bundle manifests and, only if necessary, forward-only persistence changes for engine roles, run provenance, and refined-run selection.
- Adds local scoring tools and physical-device evidence. The existing 45-second fixture is a smoke/performance input, not proof of code-switch accuracy or production quality.
