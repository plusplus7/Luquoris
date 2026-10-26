## 1. Baseline and acceptance inputs

- [x] 1.1 Audit the parent bootstrap change, current uncommitted implementation, recorder PCM fan-out, live lifecycle, durable jobs, and transcript selection; record reuse points and run GitNexus impact analysis before any symbol edit.
- [ ] 1.2 Record exact target-device hardware/firmware and establish controlled/default-state test configurations without altering the existing recorder evidence.
- [ ] 1.3 Audit the 45-second fixture's actual language coverage and version its coverage annotation if necessary; retain its immutable audio and keep it separate from accuracy acceptance.
- [ ] 1.4 Assemble and rights-check at least 30 held-out human-verified minutes of Chinese with names, terminology, and the declared acoustic conditions.
- [ ] 1.5 Assemble and rights-check at least 30 held-out human-verified minutes of English with the same evaluation discipline.
- [ ] 1.6 Assemble and rights-check at least 30 held-out human-verified minutes of genuine within-utterance Chinese/English switching, with explicit language/token annotations.
- [ ] 1.7 Implement and test deterministic raw/normalized CER, WER, and mixed MER scoring, error breakdowns, equal-stratum aggregate improvement, and per-language regression checks; freeze corpus hashes and scoring rules before final model evaluation.

## 2. Candidate provenance and selection spike

- [ ] 2.1 Pin compact bilingual streaming Zipformer and an eligible streaming Paraformer alternative; record all runtime, weight, tokenizer, and configuration sources and separate redistribution/license decisions.
- [ ] 2.2 Compare eligible candidates using identical local PCM, documented endpoint/chunk settings, model loading, first-text latency, stable latency, effective RTF, backlog, memory, and language-stratified accuracy.
- [ ] 2.3 Evaluate Whisper small as the initial refinement baseline and compare another compliant complete-pass model if required by quality/footprint results.
- [ ] 2.4 Select a development pair and document eliminated candidates, measured trade-offs, exact runtime/model identities, and remaining release gates; do not represent spike selection as production approval.

## 3. Model bundles and runtime boundaries

- [x] 3.1 Add backward-compatible manifest-v2 multi-artifact inventories, canonical bundle-digest vectors, and compatibility checks while preserving v1 parsing and existing durable identities.
- [x] 3.2 Extend build-time import and native materialization to verify/publish all bundle files atomically; test absent/corrupt tokenizer, encoder, configuration, duplicate/path-traversal entries, and failed publication rollback.
- [x] 3.3 Add injectable session-scoped streaming engine contracts and fakes with partial/final utterance events, run/epoch/sequence identity, typed failures, cancellation, and native resource ownership.
- [ ] 3.4 Integrate the selected streaming runtime in Android worker execution, with one recognizer, bounded canonical PCM fan-out, and no work on microphone callbacks or the Flutter isolate.
- [ ] 3.5 Add debug-only candidate gates and production model-set verification; verify offline inference with networking disabled and absence of network/runtime-download dependencies in release inputs.

## 4. Live draft lifecycle and UI

- [x] 4.1 Reconcile provisional/final utterances with capture-time mapping and stale-event rejection; test duplicate, reordered, late, and replaced-owner callbacks.
- [ ] 4.2 Handle recording pause/resume, audio-focus interruption, discontinuities, stop, and cancellation with correct utterance reset/finalization and media-time gaps.
- [ ] 4.3 Implement unique-audio backlog accounting and the five-second/three-observation degradation rule; test memory, thermal, engine, and model failures without capture backpressure.
- [ ] 4.4 Display read-only live text, provisional/final status, backlog, incomplete coverage, and actionable fallback states with localization, accessibility, and recorder-control feedback checks.
- [ ] 4.5 Verify real Dart-to-Android streaming on authorized microphone input, including Chinese speech and within-utterance English terms, and assert all native resources are released after closure.

## 5. Durable two-pass processing

- [x] 5.1 Audit whether existing persistence represents processing role, source/run linkage, bundle provenance, completeness, and explicit current-version selection; implement and test a forward-only migration only for demonstrated gaps.
- [ ] 5.2 Persist two-pass meeting selection and idempotently queue refinement after finalized authoritative audio inventory becomes durably readable.
- [ ] 5.3 Run refinement over all original ordered segments, including degraded live intervals; test missing/corrupt audio, repeated finalization notifications, stable job identity, and failure reporting.
- [ ] 5.4 Defer refinement during active recording and safely yield to a newly started meeting; test thermal/battery/memory pause states, cancellation, process death, resume, and retry.
- [ ] 5.5 Retain live and refined transcript versions with independent raw output/provenance; add readiness notification and explicit current-version selection without automatic overwrite.
- [ ] 5.6 Preserve human corrections and recording-anchored bookmarks across segmentation changes; test version switching, search, playback text, local export, and backup/restore consumers against the selected version.

## 6. Quality and short-run qualification

- [ ] 6.1 Evaluate stabilized live and refined output on every frozen language stratum; publish raw/normalized scores, proper-name/code-switch errors, aggregate relative improvement, and per-language regressions against the spec ceilings.
- [ ] 6.2 Measure at least 30 utterances per stratum and ten cold starts; report cold/warm first-text p95, endpoint-to-final p95, model loading, queuing, and display delivery against the 2-second/3-second targets.
- [ ] 6.3 Verify speech-bearing sustained RTF ≤0.7, unique-audio backlog p95 ≤2 seconds, non-growing backlog, recorder-control feedback ≤500 ms, and complete-pass RTF ≤2.0.
- [ ] 6.4 Repeat evaluation with direct digital input and controlled room playback/noise conditions, preserving separate acoustic/model results and exact recording positions.
- [ ] 6.5 Update the fixed first-run benchmark to recommend only qualified model roles/modes without changing user defaults automatically or claiming accuracy/long-run acceptance from a short run.

## 7. Long-run and release evidence

- [ ] 7.1 Complete the first four-hour target-device live run with continuous CPU/PSS/RSS, battery, thermal, backlog, audio integrity, and Flutter-frame sampling.
- [ ] 7.2 Complete an independent second four-hour live run and required controlled/default-configuration regression; publish all failures and verify ≤12% battery/hour and <1% severe-jank frames.
- [ ] 7.3 Run interruption, lock/background, new-recording-during-refinement, process-recovery, and resource-pressure regressions while preserving the parent recorder-first acceptance gates.
- [ ] 7.4 Measure release APK/AAB and installed/materialized footprint for the selected pair against 500 MiB/800 MiB limits; update third-party notices and obtain independent runtime/weight redistribution review before production bundling.
- [ ] 7.5 Run relevant Dart/native/widget/integration/migration tests, formatting/static analysis, offline/privacy gates, and GitNexus change-scope review; record exact build/model/corpus hashes with evidence.
- [ ] 7.6 Publish the model-pair decision and scoped release status; promote live capability only when every gate passes, otherwise retain experimental/live-disabled availability and the independently qualified recorder/post-session path.

## 8. Handoff and compatibility

- [ ] 8.1 Document how to select live two-pass, post-session-only, and recording-only modes; explain draft/refined version selection, resource fallback, and retry without promising zero latency.
- [ ] 8.2 Validate feature-disable rollback on meetings containing legacy runs and new paired runs, preserving original audio, human corrections, explicit current selections, and readable v1/v2 provenance.
- [x] 8.3 Link the new evidence to the parent bootstrap tasks where appropriate without marking unrelated or unfulfilled acceptance work complete; validate both OpenSpec changes before archival decisions.
