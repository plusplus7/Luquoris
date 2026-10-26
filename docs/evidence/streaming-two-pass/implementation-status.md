# Streaming two-pass implementation evidence

## Baseline audit — task 1.1

Observed on 2026-10-14 against HEAD
`6b528f7128983a3ce440dc5006eaba6802b033ad`, including the pre-existing
uncommitted recording-inventory fix and the earlier experimental Whisper-small
changes. This document records evidence/status, not a separate implementation plan.

- The recorder's `PcmInferenceConsumer` fan-out and
  `LivePcmInferenceRegistry` already isolate native draft ownership and thermal
  degradation. Reuse these seams; microphone callbacks must remain independent.
- `WhisperDraftEngine` currently re-decodes rolling buffered windows, rather
  than maintaining a genuinely streaming recognizer. It is a legacy fallback,
  not qualification evidence for the new live engine.
- `TranscriptionCoordinator.startLiveDraft` and `scheduleFinalized` select the
  same manifest and derive the same run identity for the same meeting. New
  engine roles and parameters must distinguish live and complete-pass runs.
- `LiveTranscriptController` retains draft text only in screen/application
  memory. A durable separately selectable draft version is not implemented.
- The coordinator already waits for durable meeting finalization and inventories
  committed original audio; reuse its idempotent job and authoritative-audio path.
- `DriftTranscriptRepository.saveVersion` preserves parallel versions;
  `selectCurrent` provides explicit selection and corrections belong to stable
  segment/run IDs. `DriftTranscriptionJobRepository.complete` automatically
  selects the first completed run when no selection exists; new refinement must
  not inherit that behavior accidentally.
- Existing model manifests and runtime verification describe one file. New
  bundles must verify every artifact, not only an encoder or archive checksum.
- Preserve all pre-existing changes, existing recording evidence, and the parent
  bootstrap task status. Do not infer production readiness from this audit.

Fresh baseline verification: `flutter test --no-pub --reporter compact`
completed with **541 passed**, zero failures. GitNexus context resolved the
coordinator and impact analysis was performed before manifest edits: the
`BundledModelManifest` public surface has 19 direct dependents, one indexed
affected process, and HIGH risk. Its parser has one direct caller and LOW risk.

## External acceptance inputs — 2026-10-14 baseline

At that baseline, `adb devices` listed no connected device. Therefore no new target-device
hardware snapshot, microphone test, battery/thermal test, controlled/default-state
run, or four-hour acceptance result has been recorded in this session.

The repository contains one 45-second smoke/performance WAV, no human reference
transcript for that excerpt, and no 30-minute-per-stratum held-out corpus. Two
previous machine outputs contain Chinese text but do not prove human-verified
language coverage. Published language labels alone are not acceptance evidence.

Public dataset and candidate-model provenance are being investigated before
claiming any corpus, license, model-selection, or production gate complete.

## Manifest inventory — task 3.1

V2 parsing preserves per-file source/license metadata and exact runtime version,
rejects unknown fields, duplicate roles/paths, unsafe namespaces, noninteger
schema revisions, mutable sources, incorrect aggregate lengths/digests, and
portable integer overflow. Commit-addressed source formats are documented in
`tool/model_manifest/README.md`; the v1 schema is unchanged and a separate v2
shape schema is provided. V1 remains a singleton inventory whose durable digest
is the original weight SHA-256, not a new inventory hash.

ASCII and independently calculated UTF-8 vectors fix JSON key order, compact
encoding, lexical path ordering and tokenizer coverage. Parsed inventories are
immutable and independent of input mutation. The 28 parser/legacy tests passed.
Review findings on source pinning, integer dispatch, overflow, and additional
vectors were addressed. Review initially misread the existing NUL escape and
proposed a URL normalization bypass; both were withdrawn after tests established
the existing rejection. Explicit defensive checks and regressions remain.

Fresh verification after the current bundle/import slice: **574 Flutter tests
passed**, `flutter analyze --no-pub` reported **no issues**, **312 native JVM
tests passed** (77 suites, zero failures/errors), and `git diff --check` passed.
These do not qualify a streaming engine, model pair, device run, or release.
No v2 bundle is included in production model inputs.

## Smoke fixture annotation — task 1.3 partial

Annotation v2 removes unsupported verified-language labels and records the
original declared labels separately. Coverage remains human-review-required;
no reference transcript exists. Machine outputs are not a human coverage audit.
The WAV/source/license hashes, consent attestation, fixture ID and 45-second
duration are unchanged. The three asset/provenance tests passed, including exact
immutable audio and license digests. Task 1.3 stays unchecked pending actual
human coverage verification; it is not accuracy-acceptance material.

## Atomic verification/publication — task 3.2

Build import verifies and stages every artifact and all license snapshots.
Global destination reservation rejects model/model and model/license collisions;
the reserved `index` ID cannot overwrite the catalog. The completed staging tree
is reverified against all inventory files and original typed manifests before
publication. Injected replacement failure restores prior output; a cleanup
failure after commit preserves the backup without falsely claiming rollback.

Runtime verification checks encoder, tokenizer, and configuration independently.
The new native bundle store validates the same canonical digest before opening
assets, copies and verifies the whole set in a private staging directory, syncs
files and directory entries, atomically renames the content-addressed directory,
and syncs its parent before returning ready. The Android path uses `Os.fsync`;
JVM tests explicitly inject sync behavior. Missing/corrupt files, duplicate and
traversing paths, failed publication, post-rename sync failure, and the fixed
UTF-8 vector are covered. Existing unrelated published model sets are retained.

Final reviewed slice: **575 Flutter tests passed**, **312 native tests passed**,
analyzer **no issues**, diff whitespace check clean, and OpenSpec validation
passed. Review found no remaining Important blockers after the regression fixes.
This is a bundle infrastructure completion, not recognizer integration or
approval to ship candidate weights. Production remains on the existing v1 set.

## Session-scoped streaming seam — task 3.3

The separate injectable boundary pins meeting/run/owner epoch and bundle/parameter
identity. Partial and final utterances carry monotonic sequence, stable utterance
IDs, original text, and captured-media intervals. The session owns a native PCM
subscription/worker/recognizer as one resource lifetime; cancellation/replacement
is idempotent and its acknowledgement cannot depend on a paused UI consumer.
Typed terminal failures release ownership while preserving their cause; explicit
cancellation drops buffered callbacks. No platform handles or PCM decoding cross
this Dart interface. The provider throws until explicitly wired.

Nine contract-fake tests cover partial/final delivery, duplicate ownership,
replacement, preparation failure, listener-triggered cancellation, paused
consumers, terminal failure, and release exactly once. Lifecycle review findings
were reproduced by failing tests before fixes. Fresh full verification:
**584 Flutter tests passed**, analyzer **no issues**, diff check clean, and review
found no remaining Important blockers. The seam is not yet wired to a selected
native runtime; tasks 3.4/4.5 and all device acceptance gates remain open.

## Immutable draft reconciliation — task 4.1

The pure reducer accepts only its exact meeting/run/owner epoch and newer valid
sequences. Provisional text revises only the current utterance with its original
capture origin; endpoint-final text cannot be rewritten. New utterances cannot
overlap prior finalized capture intervals. No processing-clock timestamp or
human revision enters this state. Explicit closure and matching terminal failure
retain the last snapshot and reject all later callbacks.

Six reducer tests cover revisions/finals, duplicate/reordered events, foreign
meeting/run/epoch callbacks, closed-owner late events, failures, immutable lists,
and capture positions. Fresh full suite: **590 Flutter tests passed**; analyzer
**no issues**; diff check clean. Review found no Important reducer blockers.
The reviewer's separate test attempt hit a generated native-assets manifest
startup error while tests were run concurrently; the subsequent isolated full
suite passed. UI consumption and pause/discontinuity ownership transitions remain
tasks 4.4 and 4.2, respectively, not claimed by this reducer evidence.

## Additive paired-run persistence — task 5.1

Audit found existing exact engine/runtime/model/parameter columns and explicit
meeting transcript selections, but no processing role, source-run link,
coverage completeness, full bundle inventory, or authoritative-audio inventory
identity. Schema v5 adds an optional `transcript_processing_metadata` sidecar.
No legacy run is relabeled and no existing table or shipped migration changes.
The new table is STRICT, one-to-one with a run, checks role/completeness/JSON
revision/audio hashes, and uses composite foreign keys for same-meeting links.
Refinement requires a finalized audio inventory hash; source-less refinement
remains representable when live processing never produced a draft.

The append-only v4→v5 step creates only that table and its unique run index.
Versioned snapshots and era-correct test classes were generated with Drift;
build_runner ran before analysis. All upgrade pairs through v5 pass shape
validation. A hostile v4 fixture retains all meeting/model/run/selection/text/
bookmark fields exactly. A real failure after table creation, during index
publication, restores the closed v4 file byte-for-byte through the existing
snapshot opener. Existing WAL-sidecar restoration remains tested. The full
multi-file v2 fixture round-trips without losing per-file source/license fields.

Fresh verification: **600 Flutter tests passed**, analyzer **no issues**,
format check unchanged, diff whitespace clean. Read-only review found no
Critical or Important blocker for this additive schema slice. No commit made.

Integration gates remain: typed paired-run writers must validate the entire
manifest against the owning run tuple and validate source processing role;
task 5.6 must extend restore's explicit table/ID-remapping lists to preserve
populated sidecars. There is no production paired-run writer yet. This schema
evidence does not claim refinement, restore integration, or device acceptance.

## Parent compatibility links — task 8.3

Parent change: [bootstrap task status](../../../openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md).
This new evidence complements, but does not complete, parent tasks:

- 4.4/4.5: additive schema v5, parallel-run metadata, migration/content/restore
  failure tests; future typed writers and portability integration remain open.
- 10.1–10.3: v2 inventory parsing/import/materialization while v1 remains
  readable; production inputs have not gained an unapproved candidate.
- 10.4: the previous completed smoke-input task is historical. Its bilingual
  coverage claim is not endorsed by the new audit; coverage annotation v2
  explicitly requires human review and supplies no accuracy corpus.
- 11.5–11.8 and 12.1–12.8: session contracts and reducer are reusable tested
  infrastructure, not accuracy, true native streaming, durable paired workflow,
  or near-real-time qualification evidence. Those parent tasks remain open.
- 14.6/14.7 and 15.1–15.10: no newly completed device, license, release, or
  long-run gate. Existing recorder evidence is unchanged.

Both changes remain in progress and must not be archived. Candidate discovery
limitations are recorded in [candidate provenance](candidate-provenance.md).

Fresh `openspec validate` passed for both `bootstrap-loquiris-offline-recorder`
and `offline-streaming-two-pass-transcription`; diff whitespace check passed.
Parent task completion remains 78/116. New change completion is 7/41:
1.1, 3.1, 3.2, 3.3, 4.1, 5.1, and 8.3 only.

## Pause boundary — 2026-10-14 (historical)

Candidate selection cannot be established without the declared evidence phone,
held-out human-verified rights-cleared corpus, and complete fixed candidate
provenance/license records. Task 2.1 discovery is deliberately not treated as
an eligible imported model set; tasks 2.2–2.4 cannot be measured with an absent
device and corpus. These prerequisites gate selected-runtime integration and
the paired end-to-end workflow. Generic seams tested above do not satisfy those
downstream tasks, which remain unchecked; further implementation remains, not
merely an unrecorded acceptance result.

Specific external acceptance blockers:

- 1.2/4.5/6.2–6.4/7.1–7.3: target `M2104K10AC`/`chopin` is not reachable.
  No authorized microphone, controlled/default settings, cold starts, sustained
  live run, or long-run measurement can be substituted with JVM/Dart tests.
- 1.3–1.7/6.1: smoke coverage has no human reference and no frozen qualifying
  Chinese, English, and within-utterance mixed corpus has been supplied.
  Public catalog labels and model outputs cannot fill that evidence gap.
- 2.1/7.4: upstream source revisions, fixed terms/snapshots for every converted
  weight/tokenizer/configuration, dependency correspondence, and independent
  redistribution review remain unresolved. No production import approval.

Resume with the target phone attached, qualifying corpus/reference/rights
inputs, and candidate provenance review. Preserve the current experimental/
unwired state and all original audio while those inputs are absent. No release
or archival approval is granted by the infrastructure tests.

## Connected-device continuation — 2026-10-15

The target phone is now reachable. The fresh [device snapshot](device-baseline-2026-10-15.json)
records `M2104K10AC`/`chopin`, Android 13 / MIUI `V14.0.8.0.TKPCNXM`,
the actual memory/storage readings, and observed app background restrictions.
The user reports approximately 25°C ambient temperature and memory extension
enabled. The phone was charging. No device setting, installed app, microphone
permission, or user recording was changed. This resolves the previous device
connectivity blocker, not the controlled/default-configuration gate in 1.2.

As requested, probes reuse the retained authorized 45-second WAV. Its original
source manifest describes 301577 ms, not 30 minutes per language stratum; the
full source file and a human reference transcript were not found. No new audio
or accuracy corpus is inferred from that request.

The isolated [native compatibility evidence](native-candidate-smoke-2026-10-15.json)
pins the Sherpa-ONNX 1.13.8 Android runtime, unchanged upstream C examples,
model inputs, host/device hashes, and logs. The bilingual int8 Zipformer
completed the 45-second file with incremental text (whole-process wall time
5.735 s, repeat 5.627 s). The initial HF Paraformer encoder failed because
required `vocab_size` metadata was missing. The separately published prepared
Paraformer int8 package completed with incremental text (11.071 s).
The failed input remains recorded, rather than being silently replaced.

These are compatibility probes, not a fair ranking: the unchanged examples
use different endpoint policies, unpaced file feeding, and debug logging.
Wall times include loading and cleanup and do not establish sustained RTF,
first-text p95, accuracy, continuous memory, battery, microphone/Flutter
delivery, offline-mode behavior, or four-hour stability. Task 2.1/2.2 and all
qualification gates remain open. Runtime/model redistribution review and the
prepared archive's reproducible source chain are still incomplete. No candidate
was added to production assets or wired into the application.

## Paired-run restore preservation — task 5.6 partial

Restore now includes populated `transcript_processing_metadata` sidecars in
meeting aggregates, content comparison, insertion order, and ID remapping.
Conflicting copies retain independent draft/refinement runs, source links,
complete v2 bundle snapshots, coverage, authoritative-audio hashes, human text
corrections/revision history, explicit current selection, and media-anchored
bookmarks. The selected draft is not automatically replaced by refinement.
Model catalog ID remapping does not rewrite the immutable bundle snapshot.

Regression tests first exposed missing sidecars, metadata-only changes being
skipped, unstable row order after remapping, and changed legacy fingerprints
from a new empty table. Canonical aggregates now sort rows by ID and omit only
an empty newly optional sidecar, retaining the independently fixed pre-v5 UUID
vector. Review also found cross-table ID collisions in the inherited unqualified
mapping. Both meeting/metadata and run/metadata collisions were reproduced by
failing tests; references now map through their owning/referenced tables.
The original UUID derivation is unchanged for non-colliding identities.

Read-only review found no remaining Important blocker for this restore slice.
Task 5.6 remains unchecked: selected-version search/playback/export and full
workflow switching still require integration tests. The paired writer,
scheduler, Android recognizer, and live UI remain unwired. No release, task
completion, or archive status changes are implied by these partial results.

Fresh restore verification: **607 Flutter tests passed**, including seven new
paired-restore scenarios; analyzer **no issues**, format check unchanged, JSON
evidence syntax valid, and both OpenSpec changes validate with `--strict`.
The first full-suite attempts failed three privacy tests because their child
processes could not find `dart`; after setting the SDK `PATH`, the entire suite
passed. No test or privacy policy was relaxed. `git diff --check` passed.
GitNexus change-scope review reports MEDIUM for the complete dirty worktree
(57 tracked symbols, three flows, including pre-existing recorder edits), not
an isolated risk rating for this slice; new untracked symbols are not covered
by that count. No commit was made.

## Deterministic score arithmetic — task 1.7 partial

The stdlib-only [host scoring core](../../../tool/transcription_quality/README.md)
computes exact substitution/deletion/insertion counts for explicitly supplied
tokens, pooling counts within each stratum and weighting the three language
rates equally. Unit-cost alignment has a documented deterministic tie policy.
Rational arithmetic enforces the unchanged specification ceilings, ≥15% relative
improvement, and ≤2 percentage-point per-language regression without display
rounding. Empty/mismatched references and invalid/non-conserving counts are
rejected; zero live error does not manufacture a relative improvement.

**14 Python unittest tests passed**, including hand-computed operation vectors,
exact gate boundaries and all 961 pairs of two-symbol sequences of length 0–4
against an independent recursive distance oracle. The tests also assert count
conservation and repeated-call equality. This follows the testing/deterministic
vector skills' independent-oracle discipline; Python keeps this host arithmetic
independent of Flutter, native inference, or additional dependencies.

Task 1.7 remains unchecked. Raw/normalized tokenization and its frozen version,
corpus-aware pairing/hash validation, name/code-switch annotation breakdowns,
report CLI and frozen qualifying corpus inputs are not implemented here. The
core deliberately does not translate, convert script, rewrite numbers, or guess
language units to hide lexical errors. It cannot grant corpus or release status.
Independent read-only review found no Important arithmetic blocker and reran
all 14 Python tests successfully; that conclusion does not cover the missing
tokenizer, normalization, corpus pairing, annotation reporting, or qualification.

## Durable role writers and explicit configuration — 2026-10-15 continuation

The paired repository now atomically saves closed live text with its full v1/v2
snapshot, or queues a separate refinement run/job with coverage, audio identity,
and an optional validated same-meeting live source. Legacy jobs cannot acquire
new role metadata by replaying an old ID. Malformed snapshots, mismatching runtime
tuples, foreign/legacy/refinement sources, and overlapping stable live intervals
are rejected. Real SQLite trigger failures prove run/job/segment publication rolls
back with failed metadata publication.

Completion validates stored provenance and source provenance before any writes.
Refinement is never selected automatically, including when it is the first result.
Coverage is committed with the run/job/result transaction; warnings retain
incomplete coverage. Review found the missing completion validation and the live
overlap gap; failing regressions reproduced both before the shared validator fix.
Read-only re-review found no remaining Important blocker for that slice.

Schema v6 adds only `meeting_processing_selections` and its unique meeting-owner
index. Existing migration steps are unchanged. New recording-only, post-session,
and two-pass choices carry complete independent role profiles with exact runtimes
and canonical parameter JSON. Changes are allowed only while the meeting is draft
and has no run; exact retries remain idempotent after capture starts. Legacy
absence stays absence; malformed stored profiles fail closed rather than selecting
current defaults. A file-close/reopen test proves the choice is durable.

Era-correct v6 snapshots/classes and migration helpers were generated with
`drift_dev`, followed by `build_runner` before analysis. All 15 version-upgrade
pairs through v6 pass shape validation. Content tests preserve every v5 table,
including hostile Unicode/whitespace text, corrections, bookmarks, current
selection and v2 metadata, without inventing an opt-in. A failure after table
creation during index publication restores the closed v5 file byte-for-byte.
New-table tests cover profile presence, SQLite JSON/parameter-version checks,
foreign keys, uniqueness, owner-query index use and whole-meeting cascading.
The pinned build runner warns that `--delete-conflicting-outputs` is now ignored;
the canonical command still succeeds and no generated file was hand edited.

Restore includes populated new configuration rows in comparison, insertion and
table-qualified ID mapping, retaining full frozen profile bytes. A configuration-
only change now produces a conflicting copy rather than an identical skip, and
repeat restore skips the same copy. Empty new tables preserve the old UUID vector.

Fresh verification after the configuration/restore slice: **644 Flutter tests
passed**, analyzer **no issues**, diff whitespace clean. Read-only schema/profile/
restore review found no Important blocker. No phone database was opened/migrated,
microphone activated, app installed, production model added, or commit made.

Tasks 5.2–5.5 remain in progress: finalization scheduling, strict original-audio
inventory verification, model binding, execution/resource yielding, readiness UI
and explicit version-switch integration still require implementation. In
particular, a restored catalog may remap model IDs while frozen snapshots keep
their original IDs; the scheduler must resolve the actual local binding rather
than treating a snapshot ID as a local foreign key. Configuration-only backups
need not have an already registered model catalog row. The new configuration is
not yet wired into capture or inference. No additional acceptance checkbox is
claimed by these persistence prerequisites.

## Strict refinement inventory and queue construction

The strict complete-original-audio boundary and versioned queue identity are
documented in [refinement-audio-inventory.md](refinement-audio-inventory.md) and
[refinement-identity.md](refinement-identity.md). The native read-only inspection
channel is registered without touching capture callbacks, opening a database,
or returning file paths. It is not yet installed into Dart application startup.

`RefinementScheduler` now reads explicit durable selection, finalized meeting
state, every committed database segment, and complete native inventory before
queuing. It checks per-segment geometry, bytes, and opaque reference binding,
not just aggregate duration. It binds a complete matching catalog alias or
registers an absent catalog projection, preserves original frozen snapshot
bytes, links an available matching live version, and atomically publishes the
new run/job/metadata without selecting a transcript. It reuses semantically
identical retained jobs even when restore remaps job, run, and model IDs. A
different retained decoding configuration is a separate identity, not a
provenance conflict. Repeated/concurrent notifications, file reopen, and failed
publication followed by retry are covered by real-database tests.

Legacy job recovery/list/start/retry now exclude every run carrying new role
metadata, including deleted metadata, so optional new work cannot silently use
the legacy runtime or partial-audio path. A running paired job is not rewritten
by legacy startup recovery. Explicit paired claim/recovery/retry and worker
execution remain pending, as do finalization routing and startup wiring. This
is intentional role isolation, not a claim that paired execution is available.

Both scheduler review findings (different settings incorrectly blocked, and
aggregate-only audio agreement) and the legacy orphan-recovery gap were
reproduced before fixing. Subsequent read-only review found no remaining
Important issue in these slices. Fresh host verification: **676 Flutter tests
passed**, **329 native JVM tests passed**, analyzer **no issues**, codegen
completed, whitespace check clean, and the new OpenSpec change validates in
strict mode. The codegen tool reports that the canonical legacy
`--delete-conflicting-outputs` option is removed/ignored. No device app install,
microphone activation, device database migration, or production enablement was
performed. Tasks 5.2–5.4 remain incomplete until integration and execution gates
are exercised; overall completion remains **7/41**.

## Refinement lifecycle and isolated execution core

Explicit paired claim, orphan recovery, resource pause and retry now preserve
their own role and frozen provenance. Claim/retry validate a currently finalized,
nondeleted owner inside the write transaction; moving a queued or failed meeting
to trash prevents either operation without mutating its job/run. Pause and orphan
recovery retain independent cleanup semantics. Failed pause publication rolls
back both rows. Legacy operations remain isolated from paired work.

The new native `RefinementPostSessionWorker` is an **unwired execution core**,
not an enabled product path. It checks the pinned engine version and complete
original inventory, copies each journal-authorized compressed segment into a
private disposable read-only snapshot while verifying the copied SHA/byte count,
and feeds only that snapshot to the existing Whisper decoder/engine. It requires
contiguous complete PCM coverage, retains untrimmed raw output, rechecks durable
source identity before accepting results, and releases native handles before
deleting its own temporary copies. Originals are never rewritten or deleted.

Recording ownership now has a native cancellation-only observation seam; the
worker can yield without waiting on Flutter or a database. Tests cover the real
native ownership signal, another thread's cancellation callback, JNI cancellation
failure, capture during model materialization, partial-copy cancellation, and
independent cleanup after callback exceptions. Four review findings were first
reproduced, then fixed: cleanup exceptions, cancellation escaping onto capture,
allocation after cancellation during model loading, and original-audio A→B→A
mutation passing pre/post hashes. A verified private snapshot fixes the latter
by binding decoding to the exact validated copied bytes. Read-only rereview found
no remaining Important issue in this slice.

Fresh verification: **684 Flutter tests passed**, analyzer **no issues**; **347
native JVM tests across 82 suites passed**, with no failures, errors or skips.
Logs are under `build/streaming_spike/`: `flutter-refinement-trash-verification.log`,
`refinement-worker-analyze.log`, and
`refinement-worker-reviewed-native-verification.log`.

Still pending: process-death cleanup of abandoned snapshot copies, resource
qualification while an already-started context load finishes, the execution
channel/Dart worker and root wiring, finalization routing, and user-facing mode /
version readiness integration. These tests do not prove actual model inference,
microphone streaming, device priority latency, or long-run qualification. No
device app was installed, device database migrated, microphone activated,
production model enabled, or commit made for this slice. Tasks 5.2–5.4 remain
incomplete and overall completion remains **7/41**.

Subsequent device check on 2026-10-15: the existing read-only refinement-audio
round-trip integration test **passed** on `M2104K10AC`. It replaced only the
separate `com.loquiris.debug` test package and requested a deliberately absent
meeting; the actual native strict resolver returned `transcription_audio_missing`.
No application database or microphone was started, and the test process exited.
The Flutter test runner also removed `com.loquiris.debug` during teardown;
the separate `com.loquiris` package remains installed at version `0.1.0+1`.
The retained test APK SHA-256 is
`c22d1d1fae8b1031f4f5990f86e9adbcd65f3ab326535b613f3a5c1c15a2fb2c`.
Future device runs must snapshot an existing target package's data before using
this runner; package removal is part of its observed teardown behavior.
Log: `build/streaming_spike/refinement-audio-device-round-trip.log`. This proves
negative-path channel delivery, not full original-audio inference or the live
microphone acceptance gate.

## Snapshot recovery without reclaiming active input

Snapshot storage now holds an exclusive OS file lock until decoding and cleanup
finish. A canonical-root process registry rejects local contention before opening
another descriptor: a real two-JVM regression reproduced that closing a rejected
duplicate descriptor on POSIX otherwise releases the active owner's system lock.
The fixed test keeps the second process out and preserves the active copy.

A forcibly terminated helper JVM leaves real private copies without running
cleanup. The next owner acquires the automatically released system lock and
removes only abandoned `refinement-*` directories carrying the exact module
marker and exclusively ordinary recognized segment files. Unknown entries and
directory/file symbolic links are preserved. Original audio is outside this
cleanup namespace. Failed segment-file deletion keeps the marker for a later
retry; after all audio has been removed, a final directory-removal failure can
leave an empty directory. The persistent lock file contains no audio.

Both process-death recovery and duplicate-owner bugs were reproduced before
fixing. Busy work returns a typed deferred result before model allocation.
Fresh native verification: **353 tests, 82 suites, zero failures/errors/skips**
(`build/streaming_spike/refinement-snapshot-recovery-native-verification.log`).
Read-only lease/recovery rereview found no Important issue. This closes the
private-copy orphan handling gap, not the remaining production wiring, resource
policy, real-device process-recovery or full task-5.4 acceptance gates.

## Frozen refinement execution channel

The separate `refinement_execution_v1` channel now delegates to the strict
complete-pass worker on the existing transcription executor. Native validation
matches every field of an exact pinned v1 manifest and all four supported
decoding parameters before allocating work. Base remains allowlisted; small is
accepted only with both native DEBUG and the explicit experimental-small build
flag. Unknown settings, runtime changes and v2 profiles are rejected, not silently
reinterpreted as a single-weight execution. V2 materialization support by itself
does not mean a v2 inference adapter is implemented.

One meeting/run owner remains reserved through cleanup; cancellation bypasses
the inference queue and Activity teardown latches cancellation. The Dart boundary
returns typed unavailable/deferred/cancelled outcomes, validates echoed identity,
runtime, ordered nonoverlapping timestamps within all original samples, and
unchanged raw/display text. A timeout requests owner-scoped cancellation but
does not claim that native resources have already been released.

Review found and tests reproduced integer-overflow timestamp acceptance and an
escaping ordinary I/O exception that stranded the owner. Division-first bounds
and a guaranteed owner-release finally block fixed both. Six Dart boundary tests
and six native boundary tests pass; rereview found no remaining Important issue.
Fresh full verification: **690 Flutter tests**, **359 native tests / 83 suites**,
zero test failures/errors/skips; static analysis reports no issues. Logs:
`build/streaming_spike/flutter-refinement-execution-verification.log` and
`build/streaming_spike/refinement-execution-native-verification.log`.

`integration_test/refinement_execution_channel_round_trip_test.dart` is authored
but **not run on the phone**. It exercises the real channel's missing-input path
without database bootstrap or microphone capture. A future run must back up any
existing target package data before invoking Flutter's device test runner because
the prior runner automatically uninstalled its debug package. Actual refinement
inference, resource-pressure policy, scheduler execution and user-facing opt-in
remain separate gates; tasks 5.2–5.5 are not marked complete by this slice.

## Durable refinement runner, isolated from legacy jobs

The headless runner now claims only validated refinement metadata, rebuilds the
full original frozen profile, reinspects the expected complete audio identity and
checks each durable/native segment's geometry and opaque reference binding. It
persists native input failures, resumable resource deferrals and completed raw
versions through the existing repository transactions. Duplicate same-job calls
join one owner; failed work requires explicit retry and interrupted running work
requires explicit startup recovery. Completion still never selects the new version.

The completion transaction now rechecks a refinement meeting's finalized,
nondeleted lifecycle. Four real-database regressions reproduced successful writes
after lifecycle changes before adding the check, then passed with no partial
segment/job/coverage mutations. Legacy completion behavior remains unchanged.

Cancellation during verification skips engine allocation. Cancellation during
inference retains running ownership until the original native completion reply
confirms cleanup, and late successful text is discarded. All durable final-state
transitions reserve finishing before their first asynchronous write; cancellation
at that stage returns an explicit finishing rejection rather than a false success.
Observation times are sampled once and clamped to the claimed start, including
failure, pause and cancellation when the wall clock moves backward.

The actual method adapter's timeout now requests cancellation and waits for its
original terminal reply before returning an ordinary timeout failure. A missing,
malformed, wrong-owner or lost acknowledgement instead returns typed `Unsettled`:
the runner preserves durable running and its process-local owner, blocking retries
until process recovery. A cancel acknowledgement alone never establishes cleanup.
Real-adapter/real-database tests reproduced premature timeout finalization and
wrong-owner release, and pass after the fixes. The fake's conditional asynchronous
return initially exercised a codec error instead of the timeout path; it was
corrected and the actual timeout bug was separately reproduced before verification.

Fresh full verification: **715 Flutter tests passed**, analyzer **no issues**,
`git diff --check` clean, strict OpenSpec validation passed. The native count is
unchanged at **359 / 83 suites** because this runner slice changes Dart/database
logic only. Latest log:
`build/streaming_spike/flutter-refinement-runner-verification.log`.
Read-only rereview found no remaining Important issue in the runner/channel slice.
It remains intentionally unwired to application startup/finalization until the
remaining resource policy and opt-in routing are integrated; this is not complete
task-5.x, microphone, quality, long-run or production-release acceptance.

## Scoped refinement resource protection

The Android refinement worker now observes severe-or-higher thermal state,
low memory, power-save mode, and battery at or below 15% while not charging.
Unavailable or invalid sensor observations fail closed for optional inference.
The battery threshold is a conservative implementation policy, not a measured
device qualification. Worker polling caches platform reads for at most one second;
thermal, battery and memory callbacks latch cancellation without database, audio,
or model work. Recording takes priority over concurrent resource signals.

Each run owns and unregisters its observers. Partial registration rolls back even
for OOM/linkage errors, and one unregister failure cannot skip the others. The
original registration failure is retained. The registration-owner regression
reproduced two assertion failures with the old RuntimeException-only handling.
Memory trim handling uses pressure thresholds, not exact enum equality, while
excluding the UI-hidden-only hint. Its intermediate/moderate-level omission was
also reproduced before correction. Android's documented trim semantics:
https://developer.android.com/reference/android/content/ComponentCallbacks2#onTrimMemory(int)

Fresh native verification: **375 tests / 86 suites, zero failures**, plus
`compileDebugAndroidTestKotlin` successful; `git diff --check` clean. Logs:
`build/streaming_spike/refinement-resource-scope-error-{red,green}.log` and
`build/streaming_spike/refinement-resource-trim-{red,green}.log`. Read-only rereview
found no remaining Important issue in this slice. Existing Gradle/Kotlin plugin
deprecation warnings remain; this is not a warning-free toolchain claim.

No microphone, installation, device settings, or app data was changed for this
slice. Actual OS signal delivery remains a device gate. Context creation itself
is not interruptible in the current native API; ownership is retained until it
returns and cleanup completes. Application opt-in/recovery routing and complete
task-5.x acceptance are still separate work.

## Explicit-mode application dispatch and startup recovery

Bootstrap now installs both new role/selection repositories and the real read-only
audio-inventory and refinement-execution adapters. Provider construction does not
load a model. The existing process-lifetime coordinator routes finalized explicit
post-session/two-pass selections to the independent scheduler/runner, skips
capture-only selections, and recovers orphan refinements separately from legacy
jobs. Finalized explicit selections with no job are discovered on startup.
Paused refinements can resume the same identity; failed refinements require the
dedicated explicit retry transaction. Neither path selects the resulting text.

Legacy scheduling, recovery/resume and retry require genuine selection absence,
not a missing run sidecar alone. Corrupt selections fail closed. Real-database
regressions reproduced legacy execution for restored aggregates containing both
an explicit selection and historical unextended jobs, plus suppression of the
independent refinement by a historical job. The selection fences now prevent both.
New two-pass live requests currently return a typed unavailable result rather than
using the legacy draft engine; the new streaming engine remains separate work.

A real method-adapter/real-database test also reproduced legacy inference after an
unconfirmed refinement cleanup reply. Cleanup uncertainty now latches a shared
process-local inference barrier. It blocks subsequent queued legacy/refinement
inference and legacy live startup, and survives coordinator reconstruction without
relabeling an active run as an orphan. There is no in-process reset; only a new
process may recover those durable owners.

Fresh verification: **727 Flutter tests passed**, analyzer **no issues**,
`git diff --check` clean and strict OpenSpec validation passed. An initial full run
had three privacy-script failures because child processes could not find `dart`;
rerunning with the pinned SDK on PATH passed all three without privacy-code changes.
Logs: `build/streaming_spike/refinement-dispatch-review-{red,green}.log`,
`flutter-refinement-dispatch-verification-final.log` and
`refinement-dispatch-analyze-clean.log`. Read-only rereview found no remaining
Important issue in this dispatch slice. User-facing pause/resume controls, new
recording opt-in UI, real native round-trip, microphone and release evidence are
still separate gates; no task-5.x completion is claimed here.

## Actionable refinement pause and explicit recovery UI

The meeting status now explains validated refinement pauses in English/Chinese
and offers an explicit resume action. Thermal, battery, memory, battery-saver,
recording-priority and unavailable-resource reasons have safe localized copy;
unknown codes use a generic explanation rather than displaying diagnostic data.
Only a paused job with a validated refinement sidecar receives this control.
Unextended legacy jobs remain unchanged, even with an identical reason code.

Recovery goes through the existing process-lifetime coordinator/inference queue,
revalidates durable state and role, and retains the native-cleanup quarantine.
Repeated taps coalesce, pending actions disable, and no result is auto-selected.
The screen observes repository commits rather than optimistically changing a job.
A real database/widget test exercises the complete tap-to-commit path. Another
real-database test closes the route projection during execution and recreates it
after completion, preserving the durable result without disposed-state writes.

The isolated component tests cover safe reason copy, live-region/button semantics,
disabled Chinese recovery, and computed button/label geometry at 100/200/300%
text scale on a pinned 320dp view. At 300% the test scrolls to the action before
tapping; it does not clamp or truncate text. These are automated regression
checks, not TalkBack/Switch Access device-conformance evidence. Styling reuses the
existing theme and semantic spacing rather than defining a separate visual system.

Verification before the final route-lifecycle test: **741 Flutter tests passed**
and analyzer **no issues**. The expanded pause/dispatch focused run passed
**27 tests**, including the added route-lifecycle regression. Logs:
`build/streaming_spike/refinement-pause-integrated-red.log`,
`refinement-pause-route-verification.log`,
`flutter-refinement-pause-verification.log` and
`refinement-pause-analyze-clean.log`. Read-only review found no Critical/Important
issue in this slice and requested the now-added route-lifecycle coverage.
New-recording opt-in, live runtime, explicit version-selection/readiness UI,
actual OS signal delivery and the remaining acceptance inputs are still open;
no complete task-5.x acceptance or production readiness is claimed.

Final full verification including the route-lifecycle test: **742 Flutter tests
passed**, analyzer **no issues**. Logs:
`build/streaming_spike/flutter-refinement-pause-verification-final.log` and
`refinement-pause-analyze-final.log`; strict OpenSpec validation passed.

## Retained-version readiness and explicit selection UI

Task 5.5 now has a deep-linkable `/sessions/:meetingId/versions` history screen,
an editor history action, and an in-app live-region readiness notice on meeting
detail. The lazy history distinguishes explicit live/refined roles from legacy
transcripts, shows independent coverage and immutable model/runtime/bundle
identity, and never displays stored diagnostic text. Invalid processing metadata
disables selection. Closed failed live evidence can be selected read-only;
queued/running output and unsuccessful refinement cannot be selected.

`TranscriptRepository.watchVersions` observes committed runs, current selection,
corrections, language/speaker associations and processing metadata. The new strict
`selectReadableVersion` transaction revalidates the exact run/sidecar snapshots,
same-meeting source provenance and closed, non-deleted meeting before selecting.
The legacy selection API keeps its prior compatibility semantics. New UI state
does not optimistically publish a current marker. The in-flight selection alone
keeps its route controller alive until commit and consumer invalidation finish,
so returning to an existing editor during the write cannot strand old text.

Real-database tests cover source corrections and raw evidence surviving switches,
failed selection retaining the previous current version, legacy/failed-live
presentation, and actual readiness/button-to-commit behavior. Five adversarial
tests change provenance, delete metadata, reset the run, or restart recording
after the UI validation but before selection; all reject atomically. The first
snapshot race failed against the pre-fix implementation. A blocked-selection /
closed-choice-route / still-mounted-editor test likewise reproduced stale text
before the finite operation-lifetime fix. Automated card tests exercise localized
pending/coverage/error states, semantics and 100/200/300% text on a pinned 320dp
surface, without text clamping or truncation.

Final verification: **761 Flutter tests passed**, analyzer **no issues**;
`git diff --check` clean. Logs:
`build/streaming_spike/flutter-transcript-versions-final.log`,
`transcript-versions-analyze-final.log`, and
`transcript-versions-review-fixes.log`. Read-only review found two Important
issues (atomic revalidation and route-close refresh); both have failing-before /
passing-after regressions and were accepted on re-review. The readiness message
is neutral availability copy, not a claim about the user's selection history.

Scope remains an in-app notice, not OS notification delivery or real-device
assistive-technology certification. The observer currently reloads historical
segments on relevant table updates, including unrelated-meeting updates; this is
an unmeasured performance risk to benchmark with long/multi-version histories,
not evidence that latency or memory acceptance has passed. Task 5.6 consumer
acceptance, actual streaming integration, and all outstanding human/device/release
gates remain open. No full task-5.x or production approval is implied.

## Selected-version consumers and concurrent export guards

Task 5.6's Dart consumer slice now has real-database coverage using a two-segment
live version, a differently segmented one-span refinement, an independent human
correction, and a recording-media highlight at 2.5 seconds. Explicit switching
changes local search and the playback-text/preview projection, while switching
back exposes the original correction and untouched raw output. The media anchor
does not move with either model's segment boundaries.

The first open-search regression failed: fresh repository searches respected the
selection but an already-open search retained its old one-shot results. Additive
`SessionRepository.watchSearch` now observes committed meeting/audio/selection/
run/segment changes, and `SessionsController` consumes it without clearing the
query. A second real-database test covers source text correction without any job
transition. The old one-shot search API and its matching/order/limit rules remain
unchanged.

An additional review finding reproduced absent playback text when refinement had
no job or was queued, paused, or failed: the old projection incorrectly required
a successful job before reading the selected transcript. It now reads the actual
durable selection independently. No selection still produces no empty preview
document. An explicitly selected failed live version remains read-only and its
preview is visibly marked as incomplete; it gains no implicit role or retry.

Actual `LocalExportService` output is checked for TXT, SRT, and JSON across
draft → refinement → draft selections, including selected timestamps, raw versus
corrected text, both retained versions, and the unchanged bookmark. Three real
database mutations at export read boundaries reproduced mismatched selection or
correction snapshots before the fix. Export now durably fails before the picker
if detail/current-version IDs disagree or selected run/segments/language/speaker
data disagree with the retained-current projection. The payload is constructed
synchronously after those guards. This is a selected-text consistency guarantee,
not an atomic snapshot of every historical revision or meeting field.

TXT/SRT require an explicitly selected current version rather than creating empty
files from an unselected document. The export screen provides localized recovery
copy and a direct version-history action. ZIP export without a current selection
retains JSON/history/audio but omits empty TXT/SRT entries; that omission also has
a failing-before/passing-after regression. Only native destination I/O is faked
in these service tests; assertions inspect the generated documents themselves.

For both current selections, a real `DriftBackupSnapshotPlanner` VACUUM snapshot
is opened and imported into another database by `DriftRestoreImporter`. Both
segmentations, current selection, source revision, bookmark, linkage, completeness
and byte-identical frozen v2 inventory remain readable, including strict explicit
selection after restore. This verifies the database snapshot/import consumers;
it does not newly qualify Android archive packaging, picker I/O or audio restore.

Final verification: **778 Flutter tests passed**, analyzer **no issues**, and
`git diff --check` clean. Logs:
`build/streaming_spike/flutter-paired-consumers-final.log`,
`paired-consumers-analyze-final.log`, and `paired-consumers-focused.log` (the
focused log precedes the final playback/archive review regressions). Independent
read-only review accepted the playback and empty-archive fixes, with no remaining
Important issue in the slice. Both OpenSpec changes validate strictly.

GitNexus change-scope review over the entire pre-existing dirty worktree reports
HIGH risk: 188 indexed changed symbols, 75 tracked files and 9 affected flows,
including bootstrap, inventory and native recording ownership from earlier work.
That is not a narrowly isolated consumer diff, and new unindexed files are not
proved safe by this report. No commit or unrelated cleanup was performed.
The new reactive reads also add unmeasured query work; long-recording performance
and all outstanding actual streaming, device, corpus and release gates remain
open. These consumer tests do not turn the overall feature into an approved
two-pass runtime.

## Complete configuration snapshots and explicit new-recording choices

The manifest domain now emits complete schema-specific JSON copies, rather than
using the digest inventory or `InstalledModel` as a lossy role snapshot. V1 emits
its original single-file schema; v2 includes the exact runtime version and every
artifact's own source and license snapshot. Two failing-before/passing-after
tests cover round-trip parsing, profile restoration and independent mutable
inputs/outputs. The manifest-focused suite passed 30 tests; independent read-only
review found no issue in this narrow method slice.

New recordings now distinguish recording-only and post-session processing from
legacy timing preferences. The live-draft-plus-refinement choice is visible but
disabled, with a localized reason: no qualified pair and wired streaming adapter
are currently available. The controller also rejects two-pass requests rather
than silently starting another processing mode. Historical meetings and their
legacy absence of explicit configuration are not rewritten.

For post-session capture, the exact complete manifest, runtime and decoding
parameters are frozen as a `ProcessingModelProfile`. The controller commits a
draft meeting, its explicit selection, then the preparing lifecycle before
calling native capture. These are separate commits, not a claim of one global
atomic transaction; a crash before capture can leave an unstarted draft. A
selection-store failure fails closed and uses guarded unstarted-meeting cleanup.
Recording-only needs no model provider. A missing post-session profile requires
an explicit recording-only choice; it never implicitly downgrades the request.
Definitive microphone/storage failures retain the existing cleanup/retry rules;
an ambiguous native outcome still prohibits direct start retry.

Eight real-database orchestration tests cover persisted state at the native
boundary, rejected configuration writes, preparing-write failure and changed-mode
retry, model-independent recording, unavailable two-pass rejection, unchanged
legacy timing preferences, and pending-start completion after leaving setup.
The latter verifies the authoritative recording snapshot, committed recording
lifecycle and eventual disposal of the finite start keep-alive. English/Chinese
widget tests exercise 100%, 200% and 300% text, disabled semantics, authored
traversal priority and tapping the flexible recording-only card without clamping
its text. These are not real-device TalkBack/Switch Access conformance evidence.

Final verification: **794 Flutter tests passed**, analyzer **no issues**, both
OpenSpec changes strictly valid, and `git diff --check` clean. Logs:
`build/streaming_spike/flutter-new-recording-choices-final.log`,
`new-recording-choices-analyze-final.log`, and
`new-recording-choices-layout-lifecycle.log`. Independent read-only review found
no Critical/Important issue; its requested pending-start lifecycle regression
was added. GitNexus reports HIGH scope over the entire existing dirty worktree:
207 indexed symbols, 81 tracked files and 10 affected flows. No commit was made.
The coarse 5.2/8.1 boxes remain open: actual live integration and complete
end-to-end qualification are still missing. No model was approved, no microphone
capture was initiated, and no device settings were changed by these host tests.

## Unique-audio backlog policy primitive (not yet wired)

`StreamingBacklogGuard` now accepts a bounded worker-side snapshot of queued and
in-flight half-open canonical PCM sample intervals. It computes their union,
not the sum of overlapping decode windows, and uses an integer sample threshold
strictly greater than five seconds. Three accepted observations spaced at least
one second apart trigger a latched failure. Early/stale observations cannot
accelerate the count; a gap of two seconds or more breaks the streak, as does
recovery to at most five seconds. Invalid intervals or more than 512 intervals
fail closed without retaining PCM. Non-negative sample coordinates keep the
union length safe even at `Long.MAX_VALUE`.

Seven new real Kotlin tests all failed against the placeholder implementation
before the policy was added, then passed. The full Android JVM suite passed
**382 tests, zero failures/errors** (`build/streaming_spike/backlog-red.log`,
`backlog-green.log`, `backlog-native-final.log`). Gradle still emits existing
Kotlin-plugin/Gradle deprecation warnings. Independent read-only review found no
issue in this narrow helper contract.

This is not a scheduler, queue implementation or engine adapter. Its caller must
provide a complete atomic queue-plus-in-flight snapshot on an independent
monotonic clock, apply degradation, and acknowledge native resource release.
Capture backpressure, pressure/model errors, UI fallback and real streaming
qualification remain unproved. Task 4.3 therefore stays open; legacy rolling
Whisper behavior was not relabelled or modified, and no live mode was enabled.

## Exact paired pre-tokenized quality reports (task 1.7 partial)

The stdlib-only `paired_report.py` CLI now binds live/refined output to exact
corpus and frozen-rule file bytes, unique utterance IDs, complete matching ID
sets and per-utterance audio hashes. Invalid schemas, duplicate JSON keys,
nonfinite numbers, implicit token strings and missing strata fail closed.
It reports raw/normalized S/D/I/correct counts and exact rational rates for each
utterance, then pools within each acoustic condition and language stratum before
equal language weighting. Conditions are never combined. Only normalized scores
drive the independently reported numerical gates; report generation success is
not a passing gate, and `qualificationStatus` is always `not-assessed`.

Seven initial test methods (20 failing subcases against the placeholder) became
green with the implementation. Independent review reproduced one Minor package
import issue; an additional real root-module invocation regression failed before
the relative/script dual import fix. Final **22 Python tests pass**, including
the unchanged 14 arithmetic tests and real-file CLI/rejection/determinism checks.
Logs: `build/streaming_spike/paired-report-red.log`,
`paired-report-module-red.log`, and `paired-report-final.log`.

The schema/command and limitations are documented in the scoring README. These
hashes bind supplied claims; the tool does not open audio/model files, implement
or certify normalization, establish actual language coverage, or audit rights,
human reference quality or minimum durations. Model-manifest digests are labelled
declared. Annotation attribution and versioned tokenization are still absent;
task 1.7 remains open. No qualifying corpus or candidate approval was invented.

Cross-stack verification after these two slices: **794 Flutter tests**, **382
Android JVM tests**, and **22 Python tests** passed; Flutter analysis reports no
issues. Flutter logs: `build/streaming_spike/flutter-backlog-report-final.log`
and `backlog-report-analyze-final.log`. Both OpenSpec changes remain strictly
valid, with coarse progress still **7/41**. Whole-worktree GitNexus review still
reports HIGH (207 indexed symbols, 81 tracked files, 10 flows); new unindexed
helpers/reports are not covered by that count. No commit, microphone capture,
model import, candidate promotion, or device-setting change was performed.

The next selected-runtime integration depends on a defensible development-pair
decision, not ranking the incomparable upstream compatibility timings. The
existing candidate evidence explicitly leaves that decision open; human-verified,
rights-cleared Chinese/English/within-utterance mixed references have not been
supplied. Corpus paths, reference/annotation material and rights information have
been requested. Physical qualification and independent artifact-terms review
remain separate manual gates; no production approval is inferred from host tests.

## Reuse of the previously supplied audio — 2026-10-16

The user requested using the previous input rather than supplying a new corpus.
The existing authorized 45-second WAV remains available with the same SHA-256;
its exact bytes were verified on host and at both candidate input paths on the
connected evidence phone. The original full-source duration is still only a
manifest claim here, not newly recovered audio or an artificial 90-minute corpus.

Both existing isolated candidate probes were rerun unchanged. Zipformer exited
0 with incremental text in **6.121281 s** whole-process wall time; the prepared
Paraformer exited 0 with incremental text in **11.914982 s**. Runtime libraries,
probe binaries and actual model/tokenizer files were checked against their pins.
The prepared Paraformer was run from its own directory; the earlier incompatible
HF artifact was not silently overwritten. Exact paths, hashes and scope are in
[reuse evidence](native-candidate-reuse-2026-10-16.json).

These differently endpointed, unpaced upstream probes remain compatibility
regressions, not a fair ranking, quality score or live qualification. No app was
installed, microphone started, recording data modified or device setting changed.
Existing audio is sufficient to continue experimental development and smoke
checks: obtaining the full formal qualification corpus is not imposed as a
prerequisite for independent implementation. Formal accuracy and release gates
remain open, without asking the user to resupply the same audio again.

## Canonical PCM positions and real pending-audio ownership

The production capture pipeline now stamps canonical mono PCM16 frames with
exact half-open sample coordinates calculated from successful variable-length
reads. Sequence numbers are not converted to an assumed 20 ms duration. The
metadata survives both isolated fan-out copies. Legacy callers may omit the
position, which stays unknown rather than becoming a fabricated coordinate.
Explicit positions reject odd PCM16 byte lengths, negative offsets/epochs and
coordinate overflow. The producer rejects an unaligned read before publication.

Successful pause/resume advances a capture generation without inserting samples
for the pause; redundant resume does not advance it. This is not a recognizer
owner epoch or a full media-time gap mapping. Review exposed a real race between
the initial generation check and publication. A timestamp-hook gate reproduced
it: pause/resume completed while the old read was waiting, then that read still
published. The final recording-state/generation check, bounded fan-out admission
and sample/sequence commit now share the pause/resume lifecycle lock. Timestamp
queries, native decoding and encoding remain outside that lock. The regression
first failed, then verified old-frame rejection and the resumed frame's original
sequence/sample origin with the new capture generation. Re-review accepted the
fix without a remaining Important issue.

Fan-out now exposes immutable metadata for every queued **and in-flight**
derived frame. An identity ledger registers the same queue/worker frame before
offer and retains it through dequeue until consumer completion/failure. Overflow
and queue cleanup remove only actually discarded queued identities. A stalled
consumer remains visible after queue clearing or canonical shutdown; this does
not falsely acknowledge recognizer resource release. Manual `drainInference`
explicitly transfers ownership outside this ledger and is documented as unsuitable
for a decoder whose pending work must remain observable. Snapshot sorting occurs
outside the short metadata lock; observation creates no PCM copies. Persistent
ownership is bounded by queue capacity plus the one inference worker.

`StreamingBacklogGuard.observeBacklog` consumes that actual snapshot, rejects
unknown/inconsistent/oversized metadata, then applies the existing interval union
and monotonic observation policy. A real stalled-consumer test keeps six seconds
of already-dequeued audio visible at three injected one-second observations and
triggers sustained-backlog failure while canonical processing still completes.
Other tests cover variable reads, immutable historical snapshots, overflow,
clear/shutdown, eventual in-flight removal and legacy unknown coordinates.

TDD logs: `pcm-position-red.log` (4 new-behavior failures, 1 legacy compatibility
pass), `pcm-position-race-red.log` (new deterministic race failure),
`pcm-backlog-ledger-red.log` (3 failures), and `pcm-backlog-adapter-red.log`
(2 failures). Final full Android JVM suite: **393 tests, zero failures/errors**,
`build/streaming_spike/pcm-backlog-native-final.log`. Flutter: **794 tests passed**,
`flutter-pcm-backlog-final.log`; analyzer: **no issues**,
`pcm-position-analyze-final.log`; scoring tools: **22 Python tests passed**,
`pcm-position-python-final.log`. Both OpenSpec changes validate strictly and
`git diff --check` is clean. Existing Gradle deprecation warnings remain.

Independent read-only review accepted the position race fix, ledger and guard
adapter, while explicitly excluding a periodic observer, degradation/resource
actions, real microphone behavior and complete 4.2/4.3 qualification. Those tasks
stay open. The HIGH GitNexus warning for shutdown (5 direct callers, 3 affected
flows) was reported before its cleanup edit; other affected frame/pipeline/
fan-out symbols were LOW, while new unindexed symbols were UNKNOWN. No model,
microphone, application installation or device setting was enabled/changed.

Final GitNexus scope review over the entire dirty worktree reports HIGH:
238 indexed changed symbols, 83 tracked files and 10 affected flows. This includes
earlier work, is not an isolated rating for this slice, and does not cover every
new unindexed symbol. No commit was made. The adapter review also suggested
additional count-limit boundary tests as a Minor follow-up; no remaining
Critical/Important issue was reported. Coarse progress remains 7/41, not a claim
that this prerequisite completes the periodic observer or streaming runtime.

## Independent backlog observation and release acknowledgement

`StreamingInferenceOwner` owns an already-created resource for one inference
worker. Closing rejects new inference, discards a result whose operation lost
the close race, and asynchronously releases exactly once after in-flight work
exits. A successful acknowledgement means `resource.close()` returned, not just
that cancellation was requested. Failed cleanup or executor rejection returns
the stable release failure and cannot authorize a replacement resource. Caller
completion of a returned future copy cannot forge the owner's acknowledgement.
The wrapper uses API-24 `CompletionStage` operations; it does not depend on
API-31 `minimalCompletionStage` on the application's API-29 minimum.

`StreamingBacklogWatchdog` samples actual queue-plus-in-flight metadata on an
inference-independent timer. Sustained backlog, malformed PCM metadata, memory,
thermal, engine and unavailable-model causes request owner closure once. Timer
registration races and notification failures cannot prevent that request.
Neither closure nor degradation waits for native inference or an already-blocked
snapshot. Cleanup executors must dispatch asynchronously (no direct/caller-runs
executor), ticker subscription/cancellation must be nonblocking, and the caller
owns executor lifetime through release acknowledgement. Adapter-level event
filtering and actual native-resource creation remain outside these classes.

A wall-clock integration test stalls a real fan-out consumer holding six seconds
of unique PCM. Three independent observations trigger degradation while canonical
processing and shutdown remain available. Resource acknowledgement stays pending
until the gated operation exits. Other tests cover exceptional inference,
synthetic OOM, cleanup failure, rejected dispatch, late ticks, blocked snapshots,
and explicit thermal/model failure. Review caught fixed-rate scheduler jitter:
1001/2000/3001 ms could repeatedly miss the guard's one-second minimum and break
the consecutive streak. A regression failed before changing to fixed-delay
scheduling, which avoids catch-up bursts without relaxing the guard's cadence.

The initial owner/watchdog assertions and the jitter regression were observed
failing before implementation/fix. Independent review accepted the final narrow
contracts without a remaining Critical/Important finding; it did not qualify
application wiring, microphone input or actual native interruption. Full JVM
verification: **403 tests, zero failures/errors**, plus Android `lintDebug`,
`build/streaming_spike/streaming-watchdog-native-full.log`. Flutter: **794 tests
passed**, `flutter-streaming-watchdog.log`; analyzer: **no issues**,
`streaming-watchdog-analyze.log`. Existing Gradle deprecation warnings remain.
These classes are not yet registered in the application. Tasks 3.4/4.2/4.3 remain
open; no model or live feature is enabled by this slice.

## Runtime process-exit boundary — design confirmation required

On 2026-10-16, the unchanged incompatible HF Paraformer probe was rerun as an
isolated shell child on the already-connected target phone. The command was:

```sh
adb -s j75tmvsovouchmlj shell 'cd /data/local/tmp/loquiris-streaming-spike-20261015 && LD_LIBRARY_PATH=lib ./streaming-paraformer-probe'
```

It again exited **255**, with `vocab_size` missing from encoder metadata. Log:
`build/streaming_spike/paraformer-fatal-recheck-2026-10-16.log`, SHA-256
`c4ae37e1131bcb938f02b50909c3d002acdf6c425baeea7819a83ace36adf87a`.
The probe/runtime/model pins are recorded in the earlier candidate evidence;
neither binary nor model was replaced. This is a compatibility failure, not
evidence that the separate published runtime-ready Paraformer package fails.

At the pinned runtime source revision, the
[Paraformer loader](https://github.com/k2-fsa/sherpa-onnx/blob/11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf/sherpa-onnx/csrc/online-paraformer-model.cc)
requires that metadata, and
[the metadata macro](https://github.com/k2-fsa/sherpa-onnx/blob/11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf/sherpa-onnx/csrc/macros.h)
calls `_Exit(-1)` when it is absent. Source-build correspondence has not been
independently reproduced, but the observed exit and pinned-source behavior agree.
A thread boundary and Kotlin/C++ exception handlers cannot contain process exit.
Thus the generic owner/watchdog is not a process-failure containment guarantee.

Before integrating a real candidate in task 3.4, the proposed design adjustment
needs confirmation: run experimental ASR in an application-private, non-exported
separate Android process, keep recording authoritative in the existing process,
and map Binder death to incomplete-draft degradation. A separate process adds
IPC and lifecycle complexity, does not isolate total device memory/CPU pressure,
and still requires bounded admission, remote inference acknowledgements,
owner/epoch filtering, death/release handling and device regressions. An oneway
IPC return must not masquerade as completed inference or release. Rebuilding and
auditing the runtime to eliminate fatal exits is another option, not performed.

No separate service/process, JNI integration, common comparison probe or runtime
fork has been created while this architectural choice is pending. No microphone,
application install/data change, device setting change or production model import
was performed. Missing formal accuracy corpus is not the development blocker.
Coarse OpenSpec progress remains **7/41**. The final GitNexus scope review still
reports **HIGH**, 238 indexed symbols / 83 tracked files / 10 flows over the
entire dirty worktree, not just these new unindexed classes. No commit was made.

Final handoff recheck: `:app:testDebugUnitTest :app:lintDebug` succeeded
(`streaming-watchdog-final-recheck.log`); both OpenSpec changes validate strictly,
all **22 Python scoring tests** pass, and `git diff --check` is clean. On-device
SHA-256 rechecks match the existing probe (`4bdb3c0d…`), C API library
(`c85e2382…`) and incompatible encoder (`00b5f905…`) pins.

## Confirmed private-process design and debug IPC implementation

The user confirmed proceeding with the private-process proposal on 2026-10-16.
The design artifact now explicitly distinguishes this process boundary from an
Android isolated-UID sandbox and from device-wide CPU/memory protection.

New plain Kotlin core (`StreamingRemoteSession`, `StreamingRemoteWorker`,
`StreamingRemoteWire`) establishes one outstanding PCM request, at most 16,000
canonical mono samples per message, fresh run/binding identity, strict versioned
primitive fields and matching request acknowledgements. Queue admission and IPC
send are not inference completion. The original fan-out consumer must wait for
the returned stage so its actual in-flight ledger continues owning the frame;
that application adapter is not yet installed. Closing suppresses text and
rejects new work. Only a matching explicit release, confirmed process death, or
positive pre-readiness rejection of a never-adopted owner settles resources.
Ambiguous transport errors retain pending ownership. Returned future copies
cannot complete the internal roots.

The worker closes an engine created after a concurrent close request, and never
acknowledges release before busy inference exits and native close succeeds.
Review found three real core bugs, each reproduced before fixing: pending-result
callbacks could block the subsequent release acknowledgement; a fast next request
could arrive while the old busy flag was still set; and owner-allocation failure
could hide a failed native cleanup. Release is now published first; continuation
callbacks must remain nonblocking or use async variants. Busy reservation clears
before acknowledgement delivery without an old finally clearing a newer request.
Failed owner adoption plus failed cleanup latches uncertain release until death.

Debug-only Messenger glue uses same-UID checks and a shared strict codec, tracks
the service Binder's death before admitting Open, filters diagnostic replies by
identity and does not reconnect a settled owner. The default service in
`:streaming` returns `MODEL_UNAVAILABLE`: no sherpa kernel/catalog is wired.
Two separate debug fixture services exercise synthetic PCM/child-process SIGKILL
and injected death-registration OOM. These are test fixtures, not ASR engines.
All three services are non-exported and assert their exact private process name
before constructing the host. Subsequent device validation below supersedes the
initial destruction policy: normal destruction retires a host rather than killing
a process that may already be creating the next service. Failed active-peer reply
delivery can still fall back to private-process death, not a fabricated release
acknowledgement.

Review also exposed overlapping bindings: a new Open could reach the still-live
old service before its queued unbind, then wait forever. The server now explicitly
rejects never-adopted owners while retaining the active owner's resources. A
failed refusal to a foreign peer does not close the active worker. Failed death
registration for a still-live new sender sends typed rejection; if that cannot
be delivered, the private process exits so actual Binder death can settle it.
The Android lifecycle checks below are compiled, not yet device-verified.

Local verification: **420 JVM tests, zero failures/errors** (17 new core/wire
tests), **794 Flutter tests passed**, analyzer **no issues**, Android lint and
debug application/test APK builds succeeded. Evidence logs:
`streaming-remote-client-red.log`, `streaming-remote-worker-red.log`,
`streaming-remote-wire-red.log`, `streaming-remote-client-callback-red.log`,
`streaming-remote-worker-next-red.log`, `streaming-remote-worker-adoption-red.log`,
`streaming-remote-client-preopen-red.log`, `streaming-remote-rejection-red.log`,
`streaming-messenger-build-final.log`, `flutter-streaming-messenger.log`, and
`streaming-messenger-analyze.log`, all under `build/streaming_spike/`.
Existing Gradle deprecation warnings remain.

Pre-device debug APK SHA-256:
`c503fd84af49ffbca48c7f15b2d215b88016386e98a1c2de72e720bb9bebee0a`.
Instrumentation APK SHA-256:
`3ab44782f7cb049bc08df30252d728f30b65d8bc76ea5a448a88cf25323bc1c6`.
The generated release manifest contains none of the streaming services, and the
debug APK contains no sherpa/ONNX Runtime library. This is not a release build,
installed-footprint measurement or offline-networking qualification.

At that local-only checkpoint, `StreamingRemoteProcessInstrumentedTest` contained
**six unexecuted device tests**:
real Bundle/Parcel round trip, synthetic PCM in a different PID, confirmed child
death with surviving caller, unconfigured runtime rejection, overlapping/immediate
rebindings, and injected death-registration failure. They require replacing the
target debug APK and installing its test APK. Permission has been requested to
back up existing private application data before that replacement; no installation,
microphone use, recording/database mutation or device setting change has occurred.
Do not count compilation as proof of actual Binder lifecycle or crash isolation.

The next gate is that narrowly scoped device test, before real runtime integration.
Tasks 3.4/3.5/4.5 remain incomplete and live remains unavailable; no model selection,
production redistribution approval or formal accuracy result is implied. Coarse
progress stays **7/41**. That GitNexus review reports **HIGH** over the whole dirty
worktree (238 indexed symbols, 84 tracked files, 10 flows), including prior work
and excluding some new unindexed files. No commit was made.

## Authorized synthetic IPC device validation — 2026-10-16

After explicit user approval, package checks found **no installed
`com.loquiris.debug`** and no active recording service. The separate original
`com.loquiris` package remained installed. The old `com.loquiris.debug.test` APK
was signed with a different debug certificate; it was not uninstalled or replaced.
Its APK and complete accessible private directory were backed up under the ignored
local directory `build/streaming_spike/ipc-device-backup-O4BzmO/` (mode 0700;
files 0600). The readable tar contained only the root, cache and code_cache
directories. Backup hashes:

- `previous-test.apk`: `6bb0eb1b13927113e9eac57ba68f2d1a8d471ce2a73bdfbe6c71027c4005feb4`.
- `test-private.tar`: `b880b347b3de6b9b345e33dec5e40f421601ff950a5daa2e462836c173ae1df3`.

The opt-in Gradle property `-PloquirisIsolatedStreamingIpcTests=true` builds the
instrumentation APK as `com.loquiris.debug.streamingtest`, leaving normal test
package IDs unchanged. Both new packages were installed for user 0 with `-r -t`,
without granting microphone permission, clearing data or changing settings.
Only `StreamingRemoteProcessInstrumentedTest` was selected through `am instrument`;
other recorder/microphone/destructive-recovery tests were not run.

The first actual run was **5 passed / 1 failed**, not a successful qualification:
`streaming-ipc-device-first.log`, SHA-256
`998f20b72ba92fe33639880a8dc41e05e0b9d67b9f632fbc69c62a476e095a45`.
The overlapping-binding test failed waiting for its first Ready. Scoped system
logs showed `Application dead when creating service` immediately after the previous
service's normal destruction killed its entire private process. Android had already
begun the next service creation in that same process. The fix removes unconditional
process termination from normal `onDestroy` in all three services. A retired host
closes its own worker/control/inference resources, retaining cleanup dispatch until
actual Released. Late old-peer death/reply failure cannot terminate a normally
released/retired host's successor merely because the old service was destroyed.

Three consecutive full class runs then passed **6/6**:
`streaming-ipc-device-lifecycle-green.log` (1.943 s),
`streaming-ipc-device-repeat-1.log` (2.111 s),
`streaming-ipc-device-repeat-2.log` (2.066 s). This demonstrated why compile-only
checks and pure owner tests could not replace the actual Android lifecycle test.

Before real kernel integration, `StreamingProcessLease` adds one recognizer
admission lease per OS process, shared across replacement host instances. A ticket
is allocated before CAS admission; duplicate/late release can only clear that
ticket, never a successor. A new host is refused while an old engine is busy or
its release is uncertain. Service destruction does not release the lease. Only
actual worker Released, or failed registration before any adoption, returns it.
Host lifecycle admission and disposal are serialized. Two JVM regressions first
failed, then passed; the complete suite now has **422 tests, zero failures/errors**,
with Android lint and APK builds successful (`streaming-process-lease-green.log`).
Independent read-only review found no remaining Important issue in this narrow
change. A direct gated-close/replacement-host wiring test remains a Minor follow-up;
the new lease unit tests alone are not that integration test.

The lease-enabled APK also passed the entire **6/6** device class in 2.044 s,
`streaming-ipc-device-lease-final.log`, SHA-256
`aac004966dddfac19040e37b18f59a8ded335b7b140a1f193a6f965a247c93ef`.
Final installed debug APK SHA-256:
`d9db22aa7d4961aa807dced1d5d10d01c424bd9007cf655f72d0e8e8ccfbff9b`;
side-by-side instrumentation APK SHA-256:
`8b8d0f43e5f89d405298bb0c68633db180a7ddf20b6caaed84878318607c5bfb`.
The six assertions cover real Parcel primitives, different-PID synthetic PCM,
confirmed child-process death while the caller survives, unavailable real-service
configuration, overlapping/immediate rebindings and injected link-registration OOM.
They do not execute sherpa inference or capture microphone audio.

Post-test checks show no remaining debug services. Original `com.loquiris` APK
SHA-256 is unchanged before/after:
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
The old test package remains at its original path with only its original cache
directories; the backup remains available. Debug `RECORD_AUDIO` app-op is still
`ignore`; no grant was requested or applied. No package was uninstalled, no
recording was deleted, and no runtime/model or production input was added. The
new debug app and side-by-side test package are left installed for continued
authorized development. The generated release manifest still excludes all three
services. This clears a synthetic IPC smoke gate, not tasks 3.4/3.5/4.5, native
resource qualification, model selection, real-microphone or release acceptance.

Final cross-stack recheck after the device fixes: **794 Flutter tests passed**,
analyzer **no issues**, **22 scoring-tool tests passed**; both OpenSpec changes
validate strictly and `git diff --check` is clean. GitNexus whole-dirty-tree
scope is **HIGH**, 239 indexed symbols / 84 tracked files / 10 flows, including
the opt-in test-package Gradle configuration and prior work. These numbers are
not an isolated risk rating for the new unindexed IPC classes. No commit was made.

### Shared C-API file-input probe — 2026-10-16

`tool/streaming_probe/streaming_probe.cc` now owns the same input loop for both
eligible development candidates. It is standalone shell-process tooling, **not
app/JNI integration or a production input**. Both request 16 kHz / 80 features,
CPU / one thread / greedy search, 3,200-sample chunks and endpoint detection
enabled with explicit 2.4 / 1.2 / 20-second rules. Runtime-specific endpoint
semantics may still differ. The historical Zipformer directory name is an alias,
not a model identity; candidate identities remain the previously recorded hashes.
Paraformer uses the eligible `paraformer-published` directory, not the incompatible
earlier Hugging Face files.

The existing immutable WAV SHA-256 remains
`83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7`.
Both unpaced runs accepted exactly 720,000 original samples in 225 chunks. A
4,800-sample silence tail is separate, followed by InputFinished and final flush.
The paced Zipformer path waits for each complete chunk's file-clock availability,
starting after model loading, without skipping/duplicating audio. Text events
carry ordered sequence, utterance identity and real input-through sample position;
this position is not a recognized word boundary. Empty results are not utterances.
Endpoint reset follows result destruction. Stream, recognizer and wave are RAII
owned and explicitly destroyed before the success summary.

TDD: the two candidate subtests first failed with actual executable exit code 2
(`common-probe-red.log`); the paced test independently failed on unsupported CLI
mode (`common-probe-paced-red.log`). After implementation the complete opt-in
device suite passed twice: 2 tests / three real model runs in 64.905 s, then a
final 65.361 s run after strengthening partial/final/endpoint sequence checks.
Final log `build/streaming_spike/common-probe-final.log`, SHA-256
`13d5d617745f19bffa9d391cbfd3708f6868bb02db34c33c0d4ef36717c303f3`.
The test checks nonempty partial/final output, monotonic sequence/input positions,
multiple endpoint utterances, no events after a given utterance is final, separate
tail accounting and no delivery of future file-clock audio. Without an explicitly
selected device these tests are skipped; that is not evidence of a device pass.

Final-run observations (one run each; not percentiles or acceptance):

| Candidate / feed | Load ms | Accept/decode/result ms | Feed wall ms | First nonempty since feed start ms |
| --- | ---: | ---: | ---: | ---: |
| Zipformer / unpaced | 2821.244 | 4084.924 | 4084.985 | 356.740 |
| Paraformer / unpaced | 1975.833 | 8244.717 | 8244.746 | 200.340 |
| Zipformer / paced | 1580.895 | 14687.048 | 45180.834 | 4076.869 |

Processing includes tail flush and event work but excludes paced sleeping and
model loading. Total-file processing ratios (0.091 / 0.183 / 0.326) include
silence and **do not qualify speech-bearing sustained RTF**. First nonempty is not
first voiced, stable latency, UI delivery or p95. The pacing-dependent difference
also makes extrapolating unpaced throughput inappropriate. Outputs differ visibly;
there are no human labels here, so neither accuracy nor a model winner is claimed.
`release_calls_completed` proves only that void destroy calls returned, not RSS
recovery, absence of leaks, or physical release under a native hang.

NDK 28.2.13676358 / Android API 29 arm64 compile uses C++17, static libc++, and
`-Wall -Wextra -Werror`; compilation passed. Executable SHA-256 is
`355427acf84a00fe9a081c6d4c337abebe6765089258263cc8aacea4b9151279`.
Local/device C-API library SHA-256 remains
`c85e2382e2ca12b0513826be926eaccfea896b4cbf568182e287671ba526f80d`,
ONNX Runtime remains
`33847ad43bffe204699fd4a27f7f3603452a8cdaf2f9a44983a0bc31ffcf2da1`;
local C-API header SHA-256 is
`2a1b95084be8fd1deb3228fcad2fd3f7f0258b64582f7402281ec174c7b7f4ce`.
Build/run prerequisites and metric limitations are in the tool README. No native
library/model was added to the app, no new APK installed, no microphone used, no
device setting changed and no source audio rewritten in this slice.

Independent read-only review found no Critical/Important issue; its Minor sequence
test gap was addressed before the final run. The scoring-tool suite still passes
22 tests. GitNexus new-symbol impact is UNKNOWN/unindexed, not zero-risk; the
whole existing dirty scope remains HIGH, 239 symbols / 84 tracked files / 10 flows.
This advances the candidate spike only; tasks 2.2, 3.4, 3.5 and 4.5 remain open.

### Canonical PCM kernel adapter — 2026-10-16

`StreamingPcmKernel` is a plain Kotlin adapter over an injected, already-created
`StreamingNativeSession`. It converts signed little-endian PCM16 to floats using
the full `/32768f` scale, accepts only 1..16,000 canonical samples, and checks
contiguous sample positions and an unchanged capture epoch before native accept.
The first frame may begin at a nonzero position; diagnostic sequence gaps do not
invent sample gaps. Discontinuities/epoch changes currently fail closed, rather
than silently concatenating audio. Proper pause/finalize/reset policy remains 4.2.

After an accept/decode exception, the stream may already contain the frame. The
adapter therefore retains that failure and rejects further decode, preventing an
unsafe retry from duplicating native audio. Closure remains possible. It marks
close requested before calling native close; successful close is idempotent,
while a failed close is cached/rethrown rather than retried or reported as a
successful release. Decode/close methods serialize on the adapter monitor; the
existing `StreamingInferenceOwner` remains the intended lifetime owner.

Five initial JUnit tests produced actual assertion failures against the stub
(`streaming-pcm-kernel-red.log`), then passed. A sixth regression demonstrated
duplicate accept after uncertain inference (`streaming-pcm-kernel-inference-red.log`)
before the poison-on-failure fix. Final complete Android suite: **428 tests, zero
failures/errors**, plus debug APK / AndroidTest APK builds and Android lint passed
(`streaming-pcm-kernel-final.log`, 18 s; existing Gradle deprecation warnings remain).
These are pure boundary tests using a contract-specific fake session, **not JNI
inference tests**. Review found no Critical/Important issue; a direct concurrent
decode/close gate test remains a Minor follow-up.

Fresh cross-stack regression: **794 Flutter tests passed**, analyzer **no issues**,
**22 scoring tests passed**, both OpenSpec changes strictly valid, and
`git diff --check` clean. No new APK was installed in this adapter slice. The
installed debug APK remains the previously device-tested lease version, not the
newly built APK. No runtime/model packaging, native library loading, real JNI
implementation, model catalog or service wiring is claimed: the default debug
service still returns MODEL_UNAVAILABLE. The native session interface is an
unfinished integration seam with its fake, not a complete live implementation.

The next real-JNI validation needs a new debug-only runtime/model install and
private test fixture directory. Separate authorization was requested for that
scope; the earlier approval covered backup/install and six synthetic IPC tests.
Until that authorization, do not substitute compile-only checks for an actual
JNI round-trip, enable microphone capture, or change production model inputs.

### Authorized debug JNI file-input round-trip — 2026-10-16

The user subsequently approved the new debug/runtime/model/test installation.
This section supersedes the preceding pending-authorization and no-JNI statements
for this later slice only. It does not approve microphone capture or production
model distribution. The original default service is still MODEL_UNAVAILABLE.

Before the first installation, the installed debug and side-by-side test APKs
and their private data were backed up under the task-owned local
`build/streaming_spike/jni-device-backup-bslRri` directory (0700; files 0600).
Local APK hashes matched the device: debug
`d9db22aa7d4961aa807dced1d5d10d01c424bd9007cf655f72d0e8e8ccfbff9b`,
test `8b8d0f43e5f89d405298bb0c68633db180a7ddf20b6caaed84878318607c5bfb`.
Private tar hashes were respectively
`bcddcafa1b59a308319d692a8dfd2ec118528d0b9c0f4230ecc90b2c978255ef` and
`c9107674b064a8c10e4d90e681520edbc16cd4725c9ce384dca20db00f6ca705`.
Every installed APK had the existing certificate SHA-256
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`;
updates used in-place `install -r -t --user 0`, without uninstall or data clearing.

The new debug-only `StreamingNativeKernelProbeService` runs in the separate
`:streaming_native_probe` process. It accepts a fixed experiment fixture key,
not arbitrary Binder paths or a production catalog entry. Four pinned model
files and the unchanged WAV were copied into a newly created private
`files/streaming-native-spike-20261016` directory after absence checks, with
0600 files. Source fixtures and existing user data were not overwritten.
Zipformer model hashes remain the prior `db6f5155…` encoder, `4b618d38…` decoder,
`bdda356d…` joiner and `a8e0e4ec…` tokens; full hashes are fixed in the factory.
This first JNI integration is not a candidate quality ranking or pair selection.

The version-1 bridge is enabled only by
`-PloquirisStreamingNativeSpike=true` for debug. It uses a bounded, locked handle
registry rather than raw pointer IDs, permits one native recognizer, validates
1..16,000 finite normalized samples per call, destroys result before endpoint
reset and stream before recognizer, and constructs Java text from standard UTF-8
bytes. C++ exceptions become fixed engine/memory errors; upstream native fatal
termination remains confined to the child process. The existing PCM adapter
preserves canonical input positions and poisons uncertain inference before retry.
Close acknowledges only after native destroy calls return, not after an IPC send.

Actual failures were retained rather than reported as successful builds:

- The initial real instrumentation test failed because the stub service could
  not create a model (`jni-device-red.log`, 20.148 s).
- The first native build succeeded but APK inspection found no new libraries.
  Its configure command used lowercase `CMAKE_BUILD_TYPE=debug`; the original
  case-sensitive `Debug` guard was false. The guard now normalizes case.
- The next device test failed MODEL_UNAVAILABLE before JNI allocation. A scoped
  diagnostic showed the app namespace canonicalizes `/data/user/0` to
  `/data/data`. Only the OS-supplied filesDir parent is now canonicalized first;
  fixed fixture directory/file redirection and hash checks remain enforced.
- Temporary path/exception diagnostics were removed after diagnosis.

After the fixes, the real JNI test passed in 10.610 s. The six existing synthetic
IPC/death/admission/unavailable tests plus real JNI then passed together twice:
**7 tests / 13.733 s**, and **7 tests / 12.137 s after diagnostic removal**.
Final log `build/streaming_spike/jni-device-clean-final.log`, SHA-256
`aef5baaba34027f1d445d170ae7c46a8ae4c59b435e4cf2550c8f722d57cf7ec`.
The real test sends all **225 chunks / 720,000 original samples**, checks
nonempty text and endpoint results, confirms a distinct child PID, waits for
release acknowledgement and rejects PCM after close. In the earlier combined
run 100 chunk results were nonempty and 12 endpoint flags were observed; those
counts are not utterance-accuracy or latency measurements. The native test
explicitly skips when the debug native-spike flag is absent.

Final installed debug APK SHA-256 is
`0bc7a7bf6bddd8f61991276c66bf198bde5cfddea78df21a5a4cb07bca036c8d`;
test APK is `a90373dc7e25ab100fe1def88de6a845a50562d33b226969d834337ddaaaee16`.
The C-API packaged hash equals its pinned source-runtime hash. Android packaging
strips ONNX ELF metadata: its packaged hash is
`7a2fb92eb67037837c3f0e428bd732fd0d05ced0546d9e740090c07573d8249a`,
separate from the original runtime hash `33847ad4…`. No upstream runtime file
was replaced. Normal debug APK inspection confirmed no experiment JNI, C-API or
ONNX library after an opt-out build. A real Flutter release build, even with the
Gradle experiment property set true, also contains none of those libraries and
has BuildConfig false. That release APK (not installed) is 85,606,030 bytes,
SHA-256 `6387860b6c4572d5eaa7aa521831e57645647081e90fa39a1ac34993a4c7818e`;
it is the existing base-model production configuration, not a selected-pair
footprint qualification. Source/dependency and release network-permission gates
passed (`jni-release-privacy.log`).

Release verification first exposed a stale generated integration_test registrant
when Gradle was invoked directly, and then an invalid globally configured JDK.
The regular Flutter release build regenerated plugin registration and succeeded
using the repository-local tooling configuration; no generated file or global
configuration was manually edited. Existing Gradle/Kotlin deprecation and
Cupertino-font warnings remain and are not described as warning-free.

Fresh checks: **428 Android unit tests / zero failures or errors**, Android lint,
debug/test APK builds, **794 Flutter tests**, analyzer **no issues**, and
**22 scoring tests** passed. One earlier Flutter test run had three failures
because subprocesses could not find `dart`; the full suite passed after adding
the pinned SDK to PATH. Read-only review found no Critical/Important issue.
Four-byte Unicode and same-process real-JNI re-creation remain explicit Minor
coverage gaps. These are not claims of physical release, leak freedom or quality.

RECORD_AUDIO remains `ignore`; no microphone, device settings, uninstall, data
clearing, source-audio rewrite, production installation or default live selection
occurred. The installed production APK remains byte-identical at
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
Final-input flush, pause/gap lifecycle, canonical recorder/Dart integration,
verified production catalog, Paraformer JNI, actual microphone validation and
qualification remain separate unfinished work; tasks 3.4 / 3.5 / 4.2 / 4.5 are
not marked complete by this file-input experiment.

### Explicit utterance finish/reset foundation — 2026-10-16

This later slice adds explicit finish/reset; it supersedes the preceding absence
of final-input flushing, but **not** the unfinished recorder/Dart/UI lifecycle
integration or task 4.2 as a whole. Normal close remains cancellation/release:
it does not silently manufacture final text. The debug JNI ABI is now **2**.

`StreamingPcmKernel.finishUtterance()` runs under the same synchronization as
decode/close. It flushes an open native utterance without releasing its one
recognizer. On success the next frame may start at or after the previous
canonical end with the same or a newer capture epoch; overlap, replay and a
backward epoch remain invalid. A gap without an explicit finish still fails.
The flush does not advance canonical media positions. Empty/repeated finish
produces no duplicate text or fake input. An uncertain finish poisons subsequent
finish/decode with the same failure; explicit close can still release resources.

The IPC `Finish(owner, requestId)` is a strict primitive-only command, acknowledged
independently from release. PCM and finish share the same single in-flight slot
and monotonic request counter. Finish has no pending captured frame, so its
padding cannot inflate unique-audio backlog. Wrong owner/request replies remain
stale; a nonfinal active finish reply is an engine failure and does not settle
ownership before release/death. The worker executes finish through its existing
inference owner, rejects overlap/duplicate identity, suppresses late text after
close, and does not forge release while native work is running.

The JNI implementation adds 4,800 zero samples as tail context only when there
is unfinished input, signals InputFinished, decodes, copies/destroys the result,
destroys the old stream, and creates a replacement stream on the same recognizer.
An explicit boundary after a natural endpoint also requires a new stream, even
when no text needs publishing. This last case was initially wrong and was caught
in review: the pinned runtime's ordinary endpoint Reset preserves context and
underlying audio, rather than providing a discontinuity boundary. See the
[official pinned implementation](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.8/sherpa-onnx/csrc/online-recognizer-transducer-impl.h#L358-L402).
The corrected empty branch creates a fresh stream without padding or repeating
the already-final result. Creation failure remains a failure, not a successful
boundary acknowledgement.

Actual TDD evidence:

- Three kernel-boundary tests failed against the stub, then the complete suite
  passed (`utterance-kernel-red.log` / `utterance-kernel-green.log`).
- Four wire/session/worker tests failed against missing finish admission/dispatch,
  then the complete suite passed (`utterance-protocol-red.log` / `…green.log`).
- Two tests exposed accepted nonfinal finish replies; client and worker checks
  fixed them (`utterance-final-shape-red-build.log` / `…green-build.log`).
- The real device test first failed at “flush must retain the unfinished text”
  in **3.167 s**, before implementing native flush (`utterance-native-red.log`,
  SHA-256 `8fd269057b8280c523172eaf1096bea53fe41cd0c815ec48efd2e06b52487a53`).
  It then passed together with the previous IPC/file tests: 8 tests / 15.608 s.
- The review-discovered endpoint branch got its own real failing test in
  **4.432 s** (`utterance-endpoint-red.log`, SHA-256
  `ca2c7b36ff02582e6b9aa90920ded2082bf116f5526d3d9759a2d324d431ef9f`).
  It compares all 20 chunk results from an untouched fresh stream against the
  natural-endpoint→explicit-finish→media-gap path using the same fixed input.
  The buggy path changed endpoint timing and lost the first nonempty text.
  The fix was applied only after observing that failure.

Final combined device regression: **9 tests / 17.554 s, all passed**, including
the six original IPC tests, full 45-second JNI input, unfinished-prefix flush
across an explicit gap, and endpoint/fresh-stream equivalence.
`build/streaming_spike/utterance-native-final.log` SHA-256 is
`b23ec755b6d513b5ce249b479a8e681316190ccad964074bbf03e082832b3024`.
The prefix cases use in-memory copies of the existing WAV in artificial media
intervals; they are lifecycle regressions, not additional corpus minutes.
The source WAV and all four private model hashes were rechecked unchanged.

Final installed debug APK SHA-256 is
`7183178843e337faff07380de091b725a316b93b17d3c4f33a16c1a4763164ed`,
test APK `01ca985df44ea3b7eb9df9bb927d3fac9efaaf5c776d317c883fdcca5776b71f`;
both device APK hashes match the built files. Original pre-install backups remain
available. No microphone, settings change, source rewrite, uninstall or clear was
used; RECORD_AUDIO remains `ignore`.

Fresh full verification: **438 Android unit tests / zero failures or errors**,
debug/test builds and lint passed; **794 Flutter tests passed**, analyzer reported
**no issues**. A further release build with the experiment property true succeeded
in 10.6 s and remains byte-identical to the preceding 85,606,030-byte base release
(`6387860b…`), with no experiment JNI/C-API/ONNX libraries. Source/dependency and
release network-permission gates passed again. The production package was not
installed or altered. Existing toolchain warnings remain as previously recorded.

Read-only review confirmed the Important endpoint issue was fixed and found no
new Critical/Important issue. It did not run builds/device tests; the results above
are separately executed evidence. Actual recorder pause/resume/focus/stop wiring,
media-gap UI mapping, Dart integration, authorized microphone input, production
bundle selection and qualification remain unfinished. No additional coarse
OpenSpec task is marked complete solely from these low-level primitives.

### PCM-to-capture-event consumer foundation — 2026-10-16

`StreamingPcmConsumer` connects the existing synchronous fan-out consumer seam
to the remote single-flight session and `StreamingCaptureTimeline`. It is not
registered with the actual recorder or a Dart channel in this slice. All PCM and
explicit-finish calls wait on an inference worker for matching remote ACKs, so
dequeue does not prematurely remove in-flight sample ownership. The only added
session accessor exposes its immutable owner identity; it cannot change it.

Forward sample gaps or newer capture epochs first flush/reset the old utterance,
then admit the new frame. Replay, backward epochs, unknown positions and payloads
larger than one second fail without further inference. Capture events retain
canonical samples and raw text; no wall-clock timestamp or flush padding is
counted as media. Explicit PAUSE/FOCUS/STOP use finish; cancellation only closes.
Natural endpoints and empty hypotheses retain the separate timeline semantics.

`closeAsync` does not acquire the worker/publication lock. Success requires both
the actual remote release/death acknowledgement and drain of already-started
event/degradation callbacks. It fences new publication immediately, and exposed
future copies cannot forge the root ACK. Callbacks may request closure, but must
not synchronously wait for the ACK which intentionally waits on those callbacks.
First typed failure wins and preserves prior draft output; listener exceptions
cannot strand native resources. This is an in-process callback contract, not yet
a claim about paused Dart stream subscribers or recorder control timing.

Evidence:

- Eight new consumer tests first failed against the literal no-op stub
  (`pcm-consumer-red.log`), then passed with the complete Android suite. A ninth
  regression added after review directly checks degradation-notification drain,
  reentrant close requests and the inability to complete the root ACK via a copy.
- Final Android unit tests: **455 tests, zero failures/errors**. Debug/test builds
  and lint passed; full Flutter suite **794 passed**, analyzer **no issues**.
  Existing Kotlin/Gradle toolchain deprecation warnings remain; the new inferred
  return-type warning was removed by explicitly declaring the worker return type.
- Real device combined IPC/JNI regression: **10 tests / 20.818 s, all passed**.
  The added case routes two 4-second copies of the unchanged fixture prefix
  through the real consumer and native process. It verifies nonempty provisional
  and final output, distinct utterance ids, ordered owner events, final bounds at
  samples 64,000 and 164,000, a PAUSE gap [64,000, 100,000), and no post-close
  publication. These artificial intervals are not additional corpus minutes.
- `build/streaming_spike/pcm-consumer-device-final.log` SHA-256:
  `32a09a5f663e8ba82df8de62d5dc3339195bd3ddbdef20752b84734930b27db5`.
- Installed debug APK:
  `693a9fb54784ebd444b719a076bc063b1d6b359d99fbc61e9e921c44720696c3`;
  test APK:
  `b94d4f2b2e74ac98c233a2a4dfba76df63e2ebc245dd42f5b314ae9455d2dbef`.
  Device hashes match these built files. Same-signature in-place installs kept
  data; original backups remain. Source WAV and all four private model hashes
  remain unchanged. No active debug service remained; RECORD_AUDIO stays `ignore`.
- Release build with the experiment property true passed in **13.0 s**; its
  SHA-256 remains `6387860b6c4572d5eaa7aa521831e57645647081e90fa39a1ac34993a4c7818e`.
  Only the five baseline libraries are present, not streaming JNI/C-API/ONNX.
  Installed production APK remains `db4713f8…`, unchanged and never reinstalled.

Read-only review found no Critical/Important finding in this primitive slice.
Its two Minor suggestions produced the explicit callback contract and the ninth
test above. Actual microphone/recorder lifecycle, Dart/UI event delivery, native
thermal/memory wiring, production bundle catalog and qualification remain
unfinished. This does not complete tasks 3.4, 4.2, 4.3 or 4.5; coarse progress
remains **7/41**. No commit, staging or automatic index rebuild was performed.

### Microphone test prepared, not executed — 2026-10-16

The user subsequently authorized debug-only microphone use and new test
recordings, selected self-playback of the previous 45-second fixture, and then
explicitly chose **not to start yet**. That readiness decision is respected:
no microphone grant/app-op change or actual capture has been performed.

The new opt-in `StreamingMicrophoneInstrumentedTest` prepares an isolated,
UUID-named recording through the existing AudioRecord/AAC pipeline and streaming
consumer, with a pause/resume boundary and remote release verification. It does
not use the destructive legacy test reset or touch earlier recording paths.
It requires a separately granted permission and `authorizedMicrophone=true`;
ordinary file-input tests cannot start it. This is native-pipeline coverage only,
not the still-missing Dart/UI round-trip. No new task checkbox is completed.

Before in-place debug/test installation, a fresh private backup was taken under
`build/streaming_spike/mic-device-backup-ZqZaOO/` (directory mode 0700, files 0600):

- Installed debug APK: `693a9fb5…`, test APK: `b94d4f2b…` (same as preceding slice).
- Debug private archive SHA-256:
  `352de9cc858415a73cac5d82d3c503b7a83474d99235261038188214d919a922`.
- Test private archive SHA-256:
  `c9107674b064a8c10e4d90e681520edbc16cd4725c9ce384dca20db00f6ca705`.

Archive listing and installed APK hashes were checked. Fresh builds still use
the same debug signing certificate; no uninstall, data clear or production APK
installation occurred. Repeated file-input device regression passed **10 tests
in 20.964 s** (`microphone-preflight-file-regression.log`). Android unit tests
remain **455 / zero failures/errors**, and debug/test builds plus lint pass.
Existing toolchain warnings remain. None of these is a microphone test result.

Read-only review found and corrected an Important test-harness cleanup problem:
source/encoder cleanup responsibility now remains explicit until pipeline
adoption, subsequent cleanup/report attempts survive earlier cleanup errors,
and the original failure remains primary. Finish has a separate daemon-worker
10-second harness wait, without inventing a release ACK on timeout. Report flags
distinguish failed assertions and any cleanup error, including suppressed errors.
The actual speech/pause/resume run awaits human playback readiness.

### Authorized microphone/native-pipeline smoke — 2026-10-16

The user later explicitly said **start**, after choosing to play the previous
45-second sample themselves. Only `com.loquiris.debug` received temporary
microphone permission/app-op access. The scoped microphone test completed:
**1 test passed / 24.238 s**. This supersedes the preceding pending-readiness
state, not its limitations or the missing Dart/UI integration.

The test performed two approximately ten-second AudioRecord captures with a
one-second pause, feeding the existing durable AAC pipeline and real streaming
JNI consumer. Its assertions passed for nonempty text before and after resume,
the new capture epoch, a PAUSE gap, zero canonical rejected/sink-failure frames,
accepted/processed frame equality, a readable segment manifest and actual remote
release acknowledgement. The report records **25 text events, 1 gap event**, no
typed failure, `assertionsPassed=true`, `cleanupFailed=false`, and control samples
of **88 ms pause / 32 ms resume**. These are two short control measurements,
not percentile or sustained-latency evidence. Canonical stored bytes total
**160,352**; the ADTS file itself is **159,920 bytes**. Neither value is PCM sample
coverage or an independently decoded AAC integrity measurement.

New retained directory:
`files/streaming-mic-efb65cac-ed49-4e28-bdf1-8b1abd4d1fba/`.
No old recording directory was reset, overwritten or deleted. Raw audio/text
was not put in the test log. A private local archive of this new directory is
retained at `build/streaming_spike/mic-evidence-mHMrjP/new-microphone-recording.tar`
(directory 0700, archive 0600), SHA-256
`eadc2f38f89f316cc851d809894d5404d23f06a713cfd862a454d6bcfb20df82`.

Evidence hashes:

- Instrumentation log `build/streaming_spike/microphone-actual-first.log`:
  `610b19abdf4fa242fadf4552e0129e34b0891cef151dcc90bc1b0630d5bc3cd3`.
- `probe-report.json`:
  `2824dc6b61a61d25c3f1ad547bdbdc964dd7bcbf9f4d645d5bb01c80319c49fd`.
- `segment-00000.adts`:
  `7647cebab43a23b3c2b818f2b8593de1dc4bbfe490c0ee7948f6ed3c32ac6b60`.
- `segment-00000.commit`:
  `50382ce6cdde9aad9978deedf64935ce7c115abb895f180dfb5235f764833e74`.
- `segments.manifest`:
  `aa17933f6d791dc970bdac04afa257d405ba5699cf70d52bf88f7018c2f682eb`.

After successful native closure, microphone runtime permission was revoked and
both UID/package RECORD_AUDIO app-ops restored to `ignore`; the final permission
query reports `granted=false`, with no active debug service. No production APK
was installed and no additional microphone run is scheduled automatically.

This is a successful authorized native-pipeline smoke only. It does not prove
Dart/UI delivery, human-verified bilingual/code-switch lexical correctness,
first-voiced-sample latency, audio-focus behavior, resource-pressure handling,
long-run stability or production approval. Task 4.5 explicitly includes the
Dart-to-Android path and therefore remains unchecked; coarse progress is 7/41.

### Dart streaming channel boundary — adapter-only, not yet registered

Added the mirrored `streaming_v1` Dart/Kotlin primitive contract, an injectable
platform transport, and the Dart streaming engine adapter. The payload pins
meeting/run/epoch, model bundle identity and parameters; PCM and arbitrary file
paths do not cross the Flutter boundary. Ordered raw-text, finalized-utterance,
gap and released-terminal events are validated before delivery. Sample values
remain exact and bounded for conversion; the maximum signed sequence value is
reserved so a locally generated terminal sequence cannot overflow on Android.

The adapter reserves ownership before acquisition and never reuses a retired
wire identity. Cancel/replacement fences queued and late text; stop permits
final text. Wrong or failed close acknowledgements retain ownership and permit
retry. Confirmed terminal release can settle pending close and open calls even
when their original platform replies are lost. Dispose dispatches closure to
all owners before waiting for any one acknowledgement. Subscriber pause/drain
does not manufacture or delay native resource-release acknowledgement.

Review found and regression tests first reproduced acquisition hangs and lost
pre-open final/gap events. The first-listener buffer now preserves at most 64
text/gap events; overflow requests typed degradation/close, preserves buffered
evidence, and retains the lease until actual release. A final independent review
reported no remaining Critical/Important findings for this adapter-only slice.

Fresh verification on 2026-10-16: `flutter test` **817 passed** (30 seconds),
`flutter analyze lib test integration_test tool` **no issues** (6.3 seconds),
Android debug unit tests **458 tests / 0 failures / 0 errors** plus lint/build
successful (38 seconds). An earlier unrestricted analyzer invocation included
the locally restored Flutter SDK below `build/tooling/`; its SDK-example
diagnostics are not application findings. Four actual test style hints were
corrected before the scoped clean analysis. Logs are local under
`build/streaming_spike/streaming-buffer-bound-{red,full-green,analyze}.log` and
`streaming-platform-contract-green.log`.

No application composition root or MainActivity registers the new channel yet;
no physical-device cross-language run, new microphone capture, APK installation,
UI delivery, release build equivalence or production qualification is claimed
for this slice. GitNexus returned UNKNOWN for these new unindexed symbols, not
an established low-risk blast radius. Existing recordings and installed packages
were not changed by this adapter work. Progress remains 7/41.

### Debug Dart-to-native file wire — registered and device-verified

The later debug source-set `StreamingDebugBridge` now registers `streaming_v1`
through MainActivity only when DEBUG and the explicit native-spike flag are
both enabled. The production composition root does not select this engine.
`StreamingChannelController` reserves ownership before asynchronous factory
creation, serializes platform replies/events, fences cancellation, and retains
ownership until real release acknowledgement. Concurrent start/close and
duplicate-owner regressions were reproduced before fixes. Unknown owners and
identities from an earlier controller instance return `released=false`; only
locally confirmed release is idempotently acknowledged. Cached/retained Flutter
engine lifecycle support is not claimed.

The file-only lease accepts `debug-native-file-probe` with canonical sorted
path/role/byte-count/SHA inventory digest
`18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b`.
It rechecks the existing 1,440,044-byte WAV fixture and the remote child verifies
all four model files. It reuses the same four-second prefix twice, placing it
at canonical samples [0,64000) and [100000,164000), with PAUSE then STOP.
This is not new corpus duration, a qualified model bundle, or microphone input.

The actual Dart integration case passed on the connected device, including
nonempty final text in both epochs, final ends at 4 s / 10.25 s, a 4 s–6.25 s
gap, owner/sequence validation, real close ACK and no post-close publication.
Final log `build/streaming_spike/streaming-file-final-device.log` SHA-256:
`4b844f2083606750aeba0d4136c11fd9147356ef8857b6402c5d9f1cc8ca500e`.
This is **one integration case**, plus framework teardown, not two cases.
The ten non-microphone native device cases also passed (21.818 s).
At that checkpoint, Android unit tests were 469/0/0, Flutter tests 817 passed,
and analysis of `lib test integration_test tool test_driver` had no issues.

Backup before debug installation is retained privately under
`build/streaming_spike/dart-wire-backup-hfhq4r/`, including the previously
authorized microphone recording. Installation used an in-place, non-incremental
replacement signed with the existing debug certificate; no uninstall, data
clear, microphone grant or old-recording reset was used. The final installed
debug APK SHA-256 is
`8f9bd3195cdc15e216953c291abbc4d9d91529c927d54c635e69ab68c5e522ef`.
An initial incremental installation crashed in Flutter before ASR; reinstalling
the identical APK non-incrementally allowed startup. This is an installation
observation, not a proven native-ASR defect or a functional RED result.
The real pre-registration functional RED was a Dart acquisition error.
Only this task's debugger forward ports were removed afterward.

The rebuilt release is 85,606,018 bytes, SHA-256
`57b4dff8ac568699a6a6bdefa7d3fb9818868a70d7cbc923d2ec6b412617ba3a`.
It contains the five existing native libraries and no streaming JNI/C API/ONNX
spike; source/dependency/APK privacy checks passed. It is **not byte-identical**
to the earlier 85,606,030-byte release baseline. It was not installed, and the
installed production APK hash remained unchanged. Debug microphone permission
remained denied, app-ops ignored, and no debug capture service was active.

This supersedes the preceding adapter-only registration status, not its scope
limitations. Normal recorder routing, microphone delivery through Dart/UI,
accuracy/latency/long-run qualification and release approval remain pending.
Task 4.5 and coarse progress remain unchanged at 7/41.

### Dart microphone probe prepared — awaiting fresh playback readiness

Added a separate opt-in microphone channel case,
`integration_test/streaming_microphone_channel_test.dart`, and a debug-only
microphone route. It requires the pinned probe inventory, explicit test build
define `LOQUIRIS_AUTHORIZED_STREAMING_MIC=true`, native-spike DEBUG build, and
already granted RECORD_AUDIO permission. Neither Dart nor native probe code
grants permission. The installed test entry has **not been launched**; no new
microphone recording or end-to-end microphone result is claimed here. The user
previously selected the old 45-second sample, but preparation was not complete
at their early start message; fresh timing confirmation is required now.

Scheduling and ownership are plain-Kotlin tested separately from Android I/O.
`StreamingMicrophoneProbeRunner` uses the real recording pipeline with injected
hardware boundaries, drains canonical/inference work before PAUSE/STOP, and
never substitutes wall time for canonical samples. Cancellation during capture
construction is checked before start. STOP drains/finalizes; cancellation does
not manufacture a final. Stopping while paused does not resume or duplicate
final text. Native release requests precede capture cleanup but ACK waits occur
only after independent microphone cleanup. No timeout is release proof.

`StreamingMicrophoneProbeOwner` wakes capture windows with a latch rather than
uninterruptible ten-second sleeps. STOP→CANCEL/REPLACED is a one-way escalation,
including while native work is pending. Regression-first fixes propagate this
upgrade through Dart and the native channel controller without duplicate
settlement or an auxiliary failure falsely settling the original pending ACK.
Late model readiness after close cannot restart capture. Caller completion of a
copied future cannot forge owner release. Direct and completion-wrapped cleanup
OOM retain the first MEMORY cause rather than becoming generic ENGINE failures.

Hardware wiring creates only `streaming-dart-mic-<UUID>` directories and retains
new AAC/report files. A source/encoder creator can throw after allocating an
object it never returns; the new single-use `StreamingProbeCaptureFactory`
therefore records uncertainty before any creator, independently cleans known
objects, and clears uncertainty only after whole-pipeline adoption. Any creation
throw conservatively retains unconfirmed ownership, even when known objects
were cleaned. The adapter cannot ACK unknown partial construction as released.
Reports contain metrics/status rather than raw transcript/audio. Their
completeness checks concern accepted/processed canonical frames and a readable
manifest, not an independent decoded-AAC sample audit. A valid resumed PAUSE
boundary may have zero length: paused wall time creates no captured samples.

Independent review closed the construction-cancellation, close-escalation,
zero-gap assertion and partial-native-allocation findings, with no remaining
Critical/Important findings for this prepared slice. Hardware execution itself,
normal recorder integration, cached/retained engine support, language accuracy,
long-run and release eligibility remain outside that result.

Verification: Android unit tests **488 / 0 failures / 0 errors** plus lint passed
in `streaming-microphone-factory-green.log` (14 s). Flutter tests **818 passed**
in `streaming-microphone-prewire-flutter-green.log` (28 s); scoped analysis of all
five project Dart folders had **no issues** (3 s). The first Flutter invocation
had three privacy-test failures because child processes could not find `dart`
on PATH; the corrected environment passed the complete suite, without changing
the privacy tests. Actual RED logs cover construction cancellation, direct and
async cleanup OOM, stop semantics, latch/ACK ownership, cross-layer escalation,
route gates and source/encoder creation uncertainty. The debug APK built in
9.6 s; release rebuilt in 16.4 s with native-spike opt-in still excluded and
the same current release hash `57b4dff8ac568699a6a6bdefa7d3fb9818868a70d7cbc923d2ec6b412617ba3a`.
Source/dependency/APK privacy gates and both strict OpenSpec validations passed.

Before the in-place, non-incremental debug install, fresh backups were verified
under `build/streaming_spike/dart-mic-backup-7M1v5i/` (directory 0700, files 0600):
debug APK `8f9bd3195cdc15e216953c291abbc4d9d91529c927d54c635e69ab68c5e522ef`,
debug private archive `194e8b5cf6fff8d7f1ac27bb85423f6d15389e419f7a7a824328a0bc8f991cc0`,
test APK `ecd72236aa3a5499228ac2ed69a68d24b1dad141cb424cd0c2dd3e1174c977be`,
test private archive `c9107674b064a8c10e4d90e681520edbc16cd4725c9ce384dca20db00f6ca705`.
The prepared debug APK hash is
`949e327e23146717686fa11aa0d7dff8a098c74f3016372ee84008ef31eb09b0`,
matching the installed APK, signed with the unchanged existing debug certificate.
Only the debug app was replaced; no app was uninstalled or data cleared. Model,
fixture, prior microphone AAC/report hashes and installed production APK hash
were rechecked unchanged. Microphone permission remains denied, UID/package
app-ops remain ignored, and no debug service is active. No coarse task is marked
complete; progress remains 7/41 pending actual authorized microphone delivery.

### Authorized Dart-to-native microphone smoke — passed 2026-10-16

After the prepared entry was installed, the user freshly confirmed **start**.
Only `com.loquiris.debug` received temporary microphone permission/app-op access.
The existing app was launched manually and the driver attached without building,
installing, uninstalling or resetting application data. The actual microphone
channel integration case passed in approximately **27 seconds**, including
nonempty finalized text from both capture epochs, a nonnegative PAUSE boundary,
matching owner/sequence, verified STOP release and no post-close publication.
This is **one case plus framework teardown**, not two integration cases.
The Android activity-launch waiter itself reported timeout after 10.102 seconds;
this was not a test timeout: the attached Flutter case completed successfully.

The new retained run is
`files/streaming-dart-mic-15590e89-0634-4ed4-8da4-abb02c4d88ab/`.
Its report records `COMPLETED`, `cleanupFailed=false`, `resourcesReleased=true`,
no typed failure, **989 canonical accepted / 989 processed frames**, zero
canonical rejected frames or sink failures, **15 text events / 1 gap event**,
and **89 ms pause / 38 ms resume** control samples. These two measurements are
not a latency percentile. Canonical stored bytes are 160,813 and the ADTS file
is 160,376 bytes; neither is PCM sample coverage or an independent AAC decode.

Evidence SHA-256:

- Driver log `build/streaming_spike/streaming-dart-microphone-actual.log`:
  `7960af8c6017105efb7a624c1437d74aa48dec6bd598cbbabd639493de3582e3`.
- Report: `fe6f0423a03d4b551b6bb109fc778657b43dac3f519ee4b943532f04a3750eba`.
- ADTS: `927bbfba12d1d796fcb056a48ea9677babb48c708e0bcdf54ebe347549dfe132`.
- Commit: `80a4f8e1d95a2a5f407454cff2fe8f906d9762ed9b24849684c2e7c105d5d8af`.
- Manifest: `face3b5654f4f25a03e5b8bc6227514860691052ddcd605333c1204f0b05a417`.
- Private archive
  `build/streaming_spike/dart-mic-evidence-kSnpxt/new-recording.tar`:
  `181dbb45487e3e052ad5cb39a755948fa128252c2b461e36c9e757cdf018d740`.

The archive is mode 0600 in a 0700 directory and contains only this new run.
Logs containing debugger capabilities remain private; no raw audio/transcript
was intentionally emitted. After verified resource release and no active debug
service, runtime microphone permission was revoked and UID/package app-ops
restored to `ignore`. The test's debugger forwarding port was removed. Existing
microphone AAC/report hashes and installed production APK hash were rechecked
unchanged. No second capture is started automatically.

This supersedes pending microphone-delivery readiness above. It proves the
short authorized microphone/native/Dart event path, not normal recorder UI,
human-verified Chinese/English lexical fidelity, code-switch accuracy, focus or
background behavior, latency percentiles, long-run stability, decoded AAC
integrity or production qualification. Task 4.5 includes actual language-content
coverage that this count-only smoke does not establish; it remains unchecked
and coarse progress remains 7/41.

## Normal-recorder streaming integration prepared (2026-10-16; not captured yet)

Continued tasks 3.4/4.2/4.3 without another microphone run. The recorder's bounded
fan-out now supports ordered, bounded control markers independent of the PCM
overflow queue. Retained/in-flight PCM precedes PAUSE/focus/discontinuity/STOP;
later resumed PCM cannot overtake the boundary. Terminal drain seals only the
derived input. Recorder audio finalization never waits for native decoding.
Failure/abort cancels derived ownership independently, including a STOP action
that already returned but has not proven native resource release. Legacy
Whisper consumers do not implement the optional capability and retain their
immediate-close behavior.

`CaptureInferenceEndpoint` exposes only the existing pipeline's consumer swap,
terminal worker control and immutable unique-audio backlog. Registry stop fences
prevent delayed model startup from reattaching after stop; capture finalization
removes binding metadata without detaching an admitted ordered terminal drain.
Old finalization cleanup cannot remove a fresh binding installed by a cleanup
callback. Expected endpoint identity is checked before runtime startup and
atomically before attachment, preventing a new capture's PCM from being guarded
by an old capture's backlog. Matching-session cleanup cannot cancel another
owner that reused a run ID.

`StreamingRecorderDraftSession` distinguishes worker STOP completion from native
release. `StreamingRecorderPlatformLease` serializes construction, attachment
and cleanup; cancellation upgrades a blocked STOP immediately. Protected future
copies cannot fabricate STOP or resource release. Typed startup failure remains
owned by the startup worker, even when registry rejection first closes its
session. The debug hardware composition acquires the shared process Whisper
arbiter before native binding and releases it only after consumer/binding ACK;
uncertain construction stays fail-closed. Its independent one-second watchdog
samples the same exact recorder fan-out. Focus-loss boundaries are AUDIO_FOCUS;
call/microphone interruptions are DISCONTINUITY, not manual PAUSE.

Regression development observed literal assertion REDs before implementation:
ordered boundary/terminal/pipeline tests (earlier logs in this continuation),
registry endpoint (5 failures), terminal-owner abort (1), capture endpoint (1),
lifecycle (1), cleanup rebinding (1), recorder session (7), recorder lease (6),
duplicate owner (1), interruption reasons (4), startup typed cause (1), recorder
route (1), and exact endpoint rebind (1). Independent read-only review found the
terminal-owner, cleanup-rebind, startup-cause and exact-endpoint issues; all were
reproduced and fixed. Review also required capture-first integration teardown,
now one cleanup coordinator with independent finally blocks.

Fresh verification: **537 Android unit tests, zero failures/errors**, plus lint;
the final native command also assembles the updated Android test APK with the
explicit debug spike/IPC gates. Full **818 Flutter tests passed** (30 s).
Analysis of lib/test/tool/integration_test/test_driver has no issues (3.1 s).
The first post-cleanup analysis found a subscription-alias cancellation lint;
direct ownership assignment fixed it without suppressing the lint. The new
opted-in Dart integration entry compiles but has **not executed**. It runs the
normal foreground recorder for 10 s / pause 1 s / 10 s, stops that recorder,
then checks nonempty finals across both epochs, pause gap, owner/sequence,
native release and no late publication. Cleanup stops only the matching new
recording before waiting for inference ACK, including an open failure.

The fresh arm64 release built with the spike property deliberately true is
85,606,018 bytes, SHA-256
`3a709ab1e77731c36c3816716be24127a2287fc35b4b6b52e411017d3e2cb8fe`.
It contains only the five existing native libraries, no experimental JNI/C API/
ONNX, and passes source/dependency/APK privacy checks. It is not byte-identical
to the previous release hash, despite the equal size. Both OpenSpec changes
validate strictly. GitNexus cumulative uncommitted scope is HIGH: 301 symbols,
89 tracked files, 15 affected flows; this includes preceding work and is not
the size of this slice. The user was warned; nothing is staged or committed.
New symbols remain unindexed/UNKNOWN, never represented as proven LOW risk.

This proves local ordering/ownership contracts, not real normal-recorder native
inference, visible UI, lexical Chinese/English fidelity, physical focus events,
memory-pressure delivery, p95, decoded AAC coverage or production qualification.
No additional microphone permission, app-op change, recording start or model
promotion occurs during preparation. Coarse progress remains 7/41; fresh human
playback readiness is required before executing the new microphone entry.

### Standby installation and non-microphone device regression

Before any replacement, debug/test APKs and their complete app-private data were
archived in `build/streaming_spike/recorder-mic-backup-KnEuMA` (directory 0700,
files 0600); both tar inventories were readable. The backed-up debug APK is the
previous `949e327e…` package, test APK `ecd72236…`. Backup data archive SHA-256:
debug `f7b8544627e3188d35e40bc9c229774dde16dc1b55f1d85a70ffa938723a491b`,
test `c9107674b064a8c10e4d90e681520edbc16cd4725c9ce384dca20db00f6ca705`.
No active debug service existed before install. Existing certificate SHA-256
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`
was verified against both newly signed APKs. In-place `--no-incremental -r -t
--user 0` installs succeeded; there was no uninstall, data clear or fallback.

The installed standby debug APK matches
`74f848a70612fe30d37c8d5f945a9ba355ceccc4c7d2a0eb5fe4d73dc4122843`;
test APK matches
`6cc8453601805aee422e18d9f3155370c94a866765631c5e4b442f07c77c2dca`.
Only the explicitly selected file/synthetic native classes ran:
`StreamingNativeKernelInstrumentedTest` and
`StreamingRemoteProcessInstrumentedTest`: **10 passed in 20.181 s**. No Flutter
Activity or opted-in microphone entry was launched. Afterward all 13 existing
model/fixture/recording/report files matched their preinstall hashes; only the
Android profile-installer bookkeeping file changed among the 14 inspected
files. The installed production APK remains
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
Runtime RECORD_AUDIO and POST_NOTIFICATIONS remain ungranted; UID and operation
RECORD_AUDIO app-ops both remain `ignore`, with no active debug services.

Final evidence log SHA-256:

- `streaming-recorder-prepared-native-final.log` (537/0/0 + lint/test APK):
  `f20a15dd47cc50648eab9963e3e633a7f9df9dd652290fc4bac1c7b5bed3d632`.
- `streaming-recorder-prepared-flutter.log` (818 passed):
  `e30ec77a026135d72974bc20e2843f267c2512addd5b72c25ec1548ae2369640`.
- `streaming-recorder-prepared-analyze-clean.log`:
  `0b0c1dbd95d6db0d7c17d9329ced34dd5d2c3d7ee1fe0ce2d8cfb000ce4b8c89`.
- `streaming-recorder-prepared-file-regression.log` (10 device passes):
  `2b87a1ab214da74f56188b41d389a0f1ad5a2ea580aebb69dc58b241082d5354`.
- `streaming-recorder-prepared-release-build.log`:
  `884abd69ac2dd9a997e2d44dd5656eeec01b244d79d311fc3a580471bf3247d5`.
- `streaming-recorder-prepared-release-privacy.log`:
  `855ce1511cb8d39bf8c3cf405fd1d3ed122065471e182a6945759c57aa4ffa5c`.
- `streaming-recorder-prepared-debug-final.log` (enabled integration compile):
  `4569329de7063c1c068e2276a344538131708f4e1cd17bdd5b6d093f31926bb3`.

The new normal-recorder microphone case is now installed and waiting for fresh
human readiness. It is not a passed integration case. Existing microphone
permission authorization is not an instruction to begin sampling automatically.

## Authorized normal-recorder Dart microphone case passed (2026-10-17)

After a fresh user **开始**, the already installed standby APK was verified as
`74f848a70612fe30d37c8d5f945a9ba355ceccc4c7d2a0eb5fe4d73dc4122843`.
Neither the debug nor production recording service was active. Only the debug
microphone permission and its UID/operation app-ops were temporarily enabled.
The prebuilt opted-in entry was launched manually; the existing Flutter driver
attached without building, reinstalling, uninstalling or clearing any data.

The actual integration case passed in approximately **24 seconds**, including
normal Dart recording-control → foreground recorder → canonical PCM fan-out →
private native recognizer → Dart streaming events. It verified nonempty finalized
utterances in capture epochs 0 and 1, a nonnegative PAUSE boundary, owner and
contiguous sequence identity, finalized normal capture, successful native STOP
release, and no late publication. This is **one actual case plus framework
teardown**, not two integration cases. The activity-launch waiter reported timeout
after 10.091 seconds; the actual attached test passed and its driver exited 0.

The new retained recording is `streaming-recorder-1792166427014498`, stored under
the normal recorder's SHA-256 directory:
`files/recordings/27263c3c7709809d6f376698132e606650d2b298f2ae097fbbadc855dc167948/`.
It contains ADTS (173,866 bytes), commit journal (280), manifest (137), an
M4A (174,753), and playback status (117; native status `ready`). These are stored
artifact sizes, not an independent AAC decode or proof of exact captured-sample
coverage. The initial lookup by unhashed meeting ID was corrected to the
established hashed storage path; no recording was missing or moved.

Evidence SHA-256:

- Actual driver log `build/streaming_spike/streaming-recorder-actual-driver.log`:
  `473417202aee38a2c627dfdf8c8e42d44fff5395f679d1598ebb48a8629506ec`.
- Private initial device log (contains debugger capability; mode 0600):
  `f7110c57396d4ba6a89161315b80090658368132187a488602aaab9fe1ea2e0d`.
- ADTS: `da245e388a4f4b1e49f063a9f36a076bbc407973cfe5038cc601db156c20f779`.
- Commit: `ea36a70767aba7f229191b12a740c9e83f741d57723e7a72ac55b6432404e12f`.
- M4A: `592fa3bf935a4b7d92b479c93975449a5cb8fb20fa03a319020e159ca0201c53`.
- Manifest: `58fe3595330c215ddd3f26700458f47d9c04a0abf92e0e659b12d0ceaa7913ef`.
- Playback status: `b48a430edcbd77073f2f02fbe999a4fc8ea7f52a54dee1d7889787573e98c5ee`.
- Only-new-recording archive
  `build/streaming_spike/recorder-mic-evidence-MRqgPB/new-recording.tar`:
  `ff17d7bdcb9092d6aa287d4ffd17e2943329eaf3275241d26b36fa13d7ec749f`.

The archive is 0600 in a 0700 directory, with five files plus their directory.
After release ACK and no active debug services, runtime RECORD_AUDIO was revoked
and UID/operation app-ops restored to `ignore`; POST_NOTIFICATIONS remains
ungranted. Only this test's debugger forwarding port was removed. All 13 old
model/fixture/recording/report hashes still match their preinstall values, and
the installed production APK remains `db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
No second recording starts automatically. No source, APK or permission default
was changed by this execution.

This supersedes standby readiness for this one run. It proves the short normal
recorder/service/native/Dart chain, not visible recording widgets, human-verified
Chinese/English or code-switch lexical fidelity, hardware focus/background
behavior, latency percentiles, independently decoded AAC integrity, long-run
stability or production eligibility. Task 4.5 still includes language-content
coverage absent from this count-only smoke; coarse progress remains 7/41.

## Read-only UI bridge and normal STOP (2026-10-17; host-verified)

The explicitly injected `StreamingLiveTranscriptAdapter` now projects untouched
streaming provisional/final utterances onto the existing read-only recording UI.
It does not choose a model, start capture, translate text, persist a transcript,
or change the default live source. `liveTranscriptSessionStarterProvider` retains
the legacy coordinator unless a composition root explicitly overrides it. An
enabled root must retain the adapter outside route lifetimes so failed-release
quarantine remains reachable.

The adapter buffers a bounded early prefix, rejects stale/sealed rewrites through
`StreamingDraft`, preserves prior text on typed failure, and marks positive media
gaps incomplete without fabricating text. Zero-media PAUSE boundaries are not
claimed as missing coverage. The English/Chinese gap message now explains that
later live text can continue instead of falsely saying the engine stopped.

Native ownership is retained until actual release acknowledgement, including
failed handoff and failed release after a page disappears. A later open first
retries quarantined cleanup. Controller stop/dispose cannot lose native cleanup
when view subscription cancellation throws. Late startup and provider replacement
cannot attach the old owner or finish the replacement owner.

Normal recorder STOP has a separate optional session `finish` callback, compatible
with legacy constructors. It retains endpoint events through native STOP ACK and
ends the projected stream without waiting for a paused external view. The live
controller keeps itself alive across immediate finalized navigation, drains queued
finals, and releases its keep-alive afterward. This also covers STOP while startup
is pending. Explicit cancellation wins over pending finish and discards late text;
it never manufactures a final hypothesis or a release acknowledgement.

Host widget tests exercise the real recording screen with the injected streaming
source: provisional→final replacement, read-only semantics, gap continuation,
incomplete coverage, an operable 48 dp pause control, finalized navigation, and
final drain across route exit. These are synthetic native inputs, not a new
microphone run or automated accessibility-conformance proof. Review found no
remaining Critical/Important issue in this slice after the startup STOP fix.

The new opt-in `integration_test/streaming_recorder_ui_test.dart` is prepared but
**not executed**. It uses normal native capture and real widgets with an isolated
in-memory session repository and disabled refinement scheduling. Consequently its
future detail-route assertion will prove navigation, not loaded detail content or
database persistence. The PAUSE endpoint has a bounded condition wait; the short
case does not impose or measure a one-second model-latency acceptance threshold.

Offline preparation only: no device command, APK install, microphone start,
permission change or old recording operation was performed in this UI continuation.
The enabled APK compiled successfully, with the existing Kotlin-plugin migration
warning; it is not claimed warning-free. The default build's debug certificate
differs from the prior installed certificate, so it was not selected for install.
A separately signed candidate verifies certificate SHA-256
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`:

- Candidate `build/streaming_spike/streaming-ui-prepared-cIGJeY/streaming-recorder-ui-signed.apk`:
  `1f2d1dd62be83a427742af04975e278955e01062c8f4e1bad83a6dff328ebf57`.
- Final enabled build log `build/streaming_spike/streaming-ui-prepared-debug-final.log`:
  `a7cc8d9f43b190974a07e3fc604f269fcaa916c135d6cdea3eac404b0fad3d11`.
- Static analysis, all four project Dart roots, no issues:
  `4271eaca9b7fad036b3ffef2e576b672bc7a2fa8ab4554ac75471525f47dcf50`
  (`build/streaming_spike/streaming-ui-stop-analyze-final.log`).
- Final Flutter suite: **845 passed**, log
  `build/streaming_spike/streaming-ui-final-flutter.log`, SHA-256
  `a315ac6b5cb792da56ffd7347303fb9df74e887226738a8bba7b87066b6cb65d`.

Both OpenSpec changes validate with `--strict`; no acceptance checkbox was
changed by this slice. No commit or staging operation was performed.

Fresh human playback readiness and a new target/certificate/idle-state preflight
are required before installing or launching this opted-in entry. A prior passed
microphone run is not readiness for this new UI run. Numeric native backlog
observations are still absent from the UI adapter (zero values are placeholders,
not latency measurements); durable live/refined persistence and production
selection remain unimplemented in this slice. Tasks 4.2/4.4/4.5 and overall release
qualification are not marked complete; coarse progress remains **7/41**.

## First authorized visible-UI run failed (2026-10-17)

After a fresh user **开始**, target `j75tmvsovouchmlj` was rechecked as Redmi
M2104K10AC/chopin, Android 13 build `V14.0.8.0.TKPCNXM`. Neither debug nor
production recording/inference services were active. The prior debug APK
(`74f848a7…`) and a private app-data archive were backed up before the signed
candidate was installed in place with `--no-incremental -r -t --user 0`.
Both APK certificates matched `6a50cd66…`; the newly installed APK matched
`1f2d1dd62be83a427742af04975e278955e01062c8f4e1bad83a6dff328ebf57`.
All 25 inspected existing files were unchanged immediately after installation.
No uninstall, data clear or destructive fallback was used.

Following the playback cue, only the debug microphone permission and
UID/operation RECORD_AUDIO app-ops were temporarily enabled. The manually
launched opted-in test failed after approximately 38 seconds at
`_awaitNonemptyFinal`: **no nonempty endpoint arrived within its wait budget**.
This is one failed microphone/UI case, not a pass. It reached authoritative
pause, but did not reach resume, visible-final, normal-STOP UI or final-navigation
assertions. The initial driver invocation omitted the explicit device/target and
spent time preparing host SDK caches; the subsequent correctly scoped attachment
retrieved the failure and exited 1. Both attached to the same already-running app;
no second recording or automatic retest was launched. A driver process exit 0 from
the first attachment is not accepted as evidence that the device case passed.

Independent teardown stopped/finalized this new paused recording and completed
session/engine release without a separate cleanup failure. A fresh service check
found no active debug recording/inference service before restoring permissions.
Runtime RECORD_AUDIO is again false and both UID/operation app-ops are `ignore`;
POST_NOTIFICATIONS remains false. Only the forward created for this run was
removed. The 18 old protected model/fixture/recording files retain their hashes;
expected debug kernel/profile/timestamp and recorder-receipt/state metadata changed.
The production APK still matches
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.

Retained new recording: `streaming-ui-1792171530155103`, normal storage directory
`files/recordings/2088c780be8578319a21bfb75a1855cef9027d69ddad59f7fe4617470412d4f2/`.
Its ADTS is 123,004 bytes and M4A is 124,577 bytes. Local FFmpeg decoded the M4A
without an error: 15.168 seconds, 16 kHz mono AAC, 242,688 decoded samples;
volumedetect reported mean −35.3 dB and maximum −18.3 dB. This shows nonzero
captured audio, not verified speech content, lexical quality, complete capture
coverage, or proof that any recognition callback reached Flutter. Current
evidence cannot distinguish empty recognizer output from a delivery problem.
No code fix or additional microphone run is claimed.

Private evidence directory `build/streaming_spike/streaming-ui-actual-KvKM2P/`
is 0700; recordings, backups and driver/device logs are 0600. Logs containing
debugger capabilities must remain private. SHA-256:

- Prior app data archive: `d520df06aedebf822da5dd995544c968c84502a512facdc658e243fd5c91f7e9`.
- Only-new-recording archive: `54dd62846fd1bf9e322817da230ea3c722bdfa81b6c1536391e1a46ea0b504ed`.
- Final driver log: `6715e31d6f90185d4439a70b4bdac7c1f6322e30d3284073730fe6d0df6c650a`.
- Final device log: `64b95c256c98045c8c6830087dc6322c79de881482e58bcba585bb7f70d37332`.
- New M4A: `a3ea688f28e0bab192e2bffcfc8081c7108861a49f69e9c513b0c0a74e66fb02`.

The prepared-only status above is superseded for this one attempt. UI acceptance
remains unpassed and coarse progress stays 7/41. Further investigation can use
the retained artifacts without a new microphone run; any future live attempt
requires fresh readiness, not reuse of this authorization.

### Content-free delivery diagnosis and fixed-file UI run (2026-10-17)

The subsequent `continue` work did not authorize another microphone run. Added
test-only boundary observations count open requests/acceptance/errors, decoded
wire events, projected events and view-state finals. Reports contain counts,
enums and allowlisted reason codes, not transcript text, owner identities or
paths. The wrapper retains the original request Future and raw event object.
A regression first failed with synchronous open errors counted as zero; the
minimal catch/count/rethrow correction now preserves the original thrown error.

The new fixed-file UI case initially timed out with no open request. Host-state
observations narrowed this to a live-provider AsyncError before native open.
Propagating that error exposed `Guarded function conflict`: the test starter
called Flutter's guarded `expect()` from a callback overlapping `tester.pump()`.
Changing its callback assertions to `expectSync()` removed that test-harness
failure. This is not evidence of a production decoder defect, nor an explanation
of the earlier microphone run, which reached authoritative PAUSE.

The fixed-file case then passed on the target device: one open accepted, four
wire/projected text events, two nonempty finals at wire/projection/view, one
intentional discontinuity, no rejected wire events and no native failure reason.
The real recording panel rendered the finals read-only; normal finish and
session/engine release assertions passed. One scenario passed in approximately
five seconds; the framework's tearDownAll increment is not another scenario.
Capture was fake, inference used the pinned native file route, and no app DB
or authoritative recording was written by this case. This is not microphone,
accuracy, latency-percentile, numeric-backlog or durable-persistence acceptance.

Private directory: `build/streaming_spike/streaming-file-ui-diagnostic-qKS9fH/`.
Passing installed fixed-file debug APK SHA-256:
`13263b8c165bf5fd60f44893c49d154d61b2e8f326dc1214d4dbbfa5111b7aec`.
Private `guard-fix-driver-private.log` SHA-256:
`e53e6478d953ceb0dff1b0d4e48a4fee760cab0a68d331b4e3bef9cecce489f5`;
private `guard-fix-device-private.log` SHA-256:
`9690b5eb16f1ba570a1f8ae968ee3f36ef8076aa081899c54e5c2e29869705ac`.
Debugger-capability logs remain 0600 within the 0700 directory.

Fresh final host verification: 849 Flutter tests passed; analysis of `lib`,
`test`, `integration_test`, `test_driver` reported no issues; both OpenSpec
changes passed strict validation. Logs are
`streaming-delivery-diagnostic-flutter-final.log`,
`streaming-delivery-diagnostic-analyze-final.log`,
`streaming-delivery-diagnostic-spec-final.log` and
`streaming-delivery-diagnostic-parent-spec-final.log` under
`build/streaming_spike/`. The Android debug build succeeded with the existing
Kotlin Gradle Plugin future-migration warning, not warning-free output.

The recorder UI test also uses `expectSync()` in its asynchronous starter and
has the content-free boundary trace for the next authorized attempt. Its updated
opt-in package was built and separately signed with the matching debug
certificate, but **not installed or launched**. Candidate:
`recorder-ui-delivery-prepared-signed.apk` in the private directory above,
SHA-256 `b75213b055aa8ab979d9cedc1f9e84ce53ebab1e3d5adcd0c552f08878f1fd83`.
Do not install the default Flutter-signed APK. A fresh readiness/preflight and
non-destructive in-place workflow remain required before microphone capture.

Post-diagnosis checks found no active recording/inference service; debug runtime
microphone permission remains false with UID/operation app-ops `ignore`. All 18
previously protected model/fixture/recording hashes match, and the production
APK remains `db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
Only owned debugger forwarding was removed. No microphone retry, production
promotion, commit or task checkbox change occurred. Coarse progress stays 7/41.

### Authorized diagnostic microphone UI attempt (2026-10-17 12:44)

Fresh human `start` readiness authorized one attempt using the prepared diagnostic
package. Preflight reconfirmed the same M2104K10AC/chopin, Android 13,
V14.0.8.0.TKPCNXM; no Loquiris service was active and the prior authoritative
snapshot was finalized. Runtime microphone and notification permissions were
false, with microphone UID/operation app-ops `ignore`. Preserved the installed
fixed-file debug APK and current app data before non-destructive in-place install
of the separately signed diagnostic recorder UI candidate
`b75213b055aa8ab979d9cedc1f9e84ce53ebab1e3d5adcd0c552f08878f1fd83`.
Its certificate matches `6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
All 30 prelaunch file hashes remained unchanged across installation. No uninstall,
clear-data operation, production-app update or database reset occurred.

After the explicit playback cue, enabled microphone permission/app-ops only for
the debug package and launched the opted-in test once. Attached the driver to the
existing application with the explicit recorder UI target/device; no rebuild or
second capture was started by the driver. The driver returned failure at about
30 seconds, at `streaming_recorder_ui_test.dart:252`, which expected the entire
`TranscriptionDraftDegraded` collection to be empty.

Unlike the first attempt, this run reached and passed the earlier assertions for
nonempty PAUSE finals rendered in the read-only real panel, resume, authoritative
normal STOP, successful finish acknowledgement, detail-route navigation,
`finishCalls == 1`, `cancelCalls == 0` before teardown, and additional post-resume
final text at a later media end. The subsequent no-degradation assertion failed.
The post-assertion no-late-events check was therefore not reached; independent
teardown's release and engine-dispose assertions produced no further failure.

The content-free trace reported one accepted open, 37 wire/projected text events,
five nonempty finals at wire/projection/view, two gap events, zero rejected wire
events and no native failure reason. Projection/view reasons contained only
`transcription_live_discontinuity`; the final observed view status was `stopped`.
Source inspection confirms that every positive-duration `StreamingGap` maps to
that incomplete-coverage event without closing inference. The timeline can emit
both initial attachment coverage gaps and boundary gaps. This trace does not
retain gap reasons/intervals, so it cannot establish the origin or acceptability
of these two gaps. Do not suppress all degradation checks or call this case
passed. It also does not explain the first attempt's absent nonempty endpoint.

Authoritative capture finalized with elapsed 26,200 ms. Retained new recording
`streaming-ui-1792212254993030` under
`files/recordings/76ae4111b7d592634c33143dc2c7c455c6bbaf07997f580209373e8e8e1bbeb0/`.
ADTS is 210,257 bytes; M4A is 210,654 bytes. No playback, upload, speech-content
verification, audio decode-integrity or language-accuracy claim was made.
The original files remain on-device and a private only-new-recording archive was
validated. This UI case still uses an in-memory repository and no-op refinement
handler, not durable transcript persistence.

After teardown, fresh service checks found no active Loquiris recording/inference
service before restoring microphone UID/operation app-ops to `ignore` and
revoking runtime microphone permission. Notification permission remains false.
Removed only this attempt's debugger forward. All 23 pre-existing protected
model/fixture/recording hashes match, including the first failed UI recording;
only expected debug kernel/profile/timestamps and recorder metadata changed.
The production APK remains
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.

Private evidence directory: `build/streaming_spike/streaming-ui-diagnostic-actual-94u6oU/`
(0700, backups/recording archive/debugger-capability logs 0600). SHA-256:

- Prior installed APK: `13263b8c165bf5fd60f44893c49d154d61b2e8f326dc1214d4dbbfa5111b7aec`.
- Prior app data archive: `687b338148ad70af82c69f047d7533b859a94c1a27b7a33e856c8caf33133ff0`.
- New recording archive: `43cb52511859575e50163386e9f95b670250e22c1bcc52e49e4f8d212d2faa4a`.
- Driver log: `8ae9eab95d31af87d5b0dcafdd4f0532876224da430f5148460fce03eebbbdd9`.
- Final device log: `f9b5d985df3d861641f6558e604aab2f12f34a96ea1ad052b1958eb3a3c8c753`.

No code/expectation was changed during this attempt, and no automatic microphone
retry occurred. The prepared-only status is superseded for this package, but UI
acceptance remains unpassed and coarse progress remains 7/41. Next work should
distinguish and validate gap reasons/intervals without changing release gates;
any further microphone run requires fresh readiness.

### Offline coverage-oracle correction after the diagnostic attempt (2026-10-17)

The next `continue` work performed no device install, permission change, launch
or microphone operation. Changes are confined to test support, regression tests,
the opt-in recorder UI test and documentation. Production gap/degradation,
recording, IPC and release-selection behavior are unchanged.

The content-free trace now keeps at most 32 gap observations, each containing
only sequence, allowlisted reason, capture epoch and decoded media start/end in
microseconds. An exact dropped-detail count prevents truncated evidence from
being treated as complete. Snapshots copy the stored rows; external mutation
cannot change later evidence. Added projected positive-gap notice counts and
the observed view incomplete flag. No raw text, owner IDs, paths or PCM are
retained by these new fields. Both new diagnostic tests first failed because
the metadata was absent, then passed after the bounded implementation.

Replaced the impossible blanket no-degradation expectation in this specific
fresh-recording/one-PAUSE smoke with an independently tested coverage oracle:

- Optional initial attachment gap: discontinuity, sequence zero, capture epoch
  zero, start zero, positive end no later than the first finalized text start.
- Exactly one PAUSE boundary: capture epoch one, ordered non-backward media
  interval between the last PAUSE final end and first resumed final start.
- Unexpected causes, duplicate/missing boundaries, malformed/rejected wire
  events, native failures and truncated evidence all fail the case.
- Every positive-duration gap must have exactly one projected incomplete notice;
  the view must retain the incomplete flag and discontinuity cause after STOP.
  The real panel must render localized incomplete, cause and fallback messages.
- Zero-length boundaries do not invent missing-media warnings. Normal finish,
  release acknowledgement, post-resume finals, navigation and no-late-event
  assertions remain in force. A successful case with gaps is labelled
  `passed_incomplete_coverage`, never complete-coverage qualification.

This oracle has no absolute gap-duration or coverage-ratio acceptance budget.
It validates structure and honest disclosure for this smoke only, not lexical
quality, first-text/endpoint p95, numeric backlog, complete live coverage or
production eligibility. It cannot reconstruct the two gaps from the earlier
count-only log; that actual run remains recorded as failed, not retroactively
passed under the new test.

Review identified an Important residual timing conflict: the old endpoint wait
still immediately failed on any degradation before a final arrived. Extracted
the actual waiter into test support and first reproduced two RED regressions:
an initial gap preceding a delayed PAUSE final, and a gap with no final that
must time out rather than be mislabeled a native failure. The corrected waiter
only immediately fails for non-discontinuity degradation, retains the 200 by
100-ms bounded integration wait, and leaves gap validity to the strict oracle.
A native failure still fails before returning even an available final. Added
privacy/fail-fast, missing-PAUSE, repeated-zero-PAUSE and view-cause regressions;
the latter two view-reason cases also first failed before their checks were added.
A real MethodChannel engine -> adapter -> controller host chain verifies that
both positive-gap notices, final text and incomplete state survive normal STOP.
Independent read-only re-review found the Important issue closed and no new
Critical/Important/Minor issue; it did not judge device results or release gates.

Fresh verification: 32 focused diagnostic/oracle tests passed; full Flutter
suite 877 passed; analysis of `lib test integration_test test_driver` reported no
issues; both OpenSpec changes passed strict validation. Log SHA-256 under
`build/streaming_spike/`:

- `streaming-gap-coverage-target-final.log`: `51ed0cfc5b303b8e561207b6ce29e48584bd96df929a98e9a20c36a2b37e43b7`.
- `streaming-gap-coverage-flutter-final.log`: `b961cfc02513985fb85a6ef6a626c330ae6b1de04f7349506ef4de4e56f0cc74`.
- `streaming-gap-coverage-analyze-final.log`: `0cdfb1fa99a24ade210599d5002649e13789b82f618787c28bff168fcf929692`.
- `streaming-gap-coverage-prepared-final-build.log`: `70df1c1e37460f492284c4089db1d7f44a66733ff20c1c78192c3813917c21c7`.

Updated opt-in debug package compiled successfully with the existing Kotlin
Gradle Plugin future-migration warning. Separately signed candidate:
`build/streaming_spike/streaming-ui-coverage-prepared-Q8VzND/recorder-ui-coverage-signed.apk`,
SHA-256 `96811eb9992d1ae012da001ed92056c9eaae8e7bf53fbe6042480be450c028d0`,
matching debug certificate
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
It has not been installed or launched. Do not install the default Flutter-signed
APK or reuse old microphone readiness. Fresh identity/idle-state/certificate/data
preflight remains required before the next in-place authorized run.
Coarse progress remains 7/41; no task checkbox, release availability or commit
was changed by this offline correction.

### Authorized coverage-instrumented UI attempt (2026-10-17 14:58)

Fresh `start` readiness authorized one run of the revised coverage-instrumented
package. Reconfirmed the same target hardware/firmware and idle Loquiris
services, prior finalized recording, microphone/notification permission false,
and microphone UID/operation app-ops `ignore`. Backed up the installed diagnostic
APK and current app data before non-destructive in-place installation of
`96811eb9992d1ae012da001ed92056c9eaae8e7bf53fbe6042480be450c028d0`.
Verified the matching `6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`
certificate; all 35 prelaunch file hashes remained unchanged across installation.
No uninstall, clear-data operation, production-app update or database reset.

After the playback cue, enabled only debug microphone permission/app-ops and
launched the opted-in test once. The driver attached to that existing app with
the explicit recorder UI target/device and did not start a second capture.
The case **failed** at about 27 seconds while awaiting authoritative
`pausedByUser`, at `streaming_recorder_ui_test.dart:203` via `_awaitCaptureState`.
The preceding `tester.tap` produced a hit-test-missed warning for the pause
control. The new recording's persisted command receipts contain successful
start and teardown stop only, not a pause receipt. This establishes a missed
test gesture and absent recorded pause command, not a demonstrated failure of
the native pause implementation. Whether moving layout, an obstruction or
another hit-test condition caused the miss still needs an offline reproduction.
Do not hide the warning or call the controller directly to manufacture a UI pass.

The trace independently exposes a real live-coverage problem: one discontinuity
from 320,000 to 4,020,000 microseconds (capture epoch zero, sequence zero), a
3.7-second interval. It does not start at media zero and therefore is not the
optional initial attachment prefix allowed by the new oracle. That oracle was
not reached because the earlier pause-state assertion failed. The gap must not
be relabelled as a benign prefix or removed from evidence. Its precise upstream
cause is not established by this trace; no speech-content, latency-percentile or
authoritative-audio-integrity conclusion follows from the live coverage marker.

One open was accepted; 17 wire/projected text events and six nonempty finals
were observed, with five nonempty finals in the last view state. There were no
rejected wire events, no terminal native failure reason, no truncated gap detail,
and one projected incomplete notice. The last view status was `degraded` with
incomplete coverage and the discontinuity cause. The read-only PAUSE-final,
resume, visible incomplete-message, normal STOP/navigation, no-late-event and
final oracle assertions were not reached. Do not count this as UI acceptance or
claim all six finals were visibly rendered.

Independent teardown stopped/finalized only the new recording and acknowledged
session release and engine disposal without an additional failure. Fresh service
checks found no active Loquiris service before restoring microphone UID/operation
app-ops to `ignore` and revoking microphone permission; notification permission
remains false. Removed only this run's debugger forward. All 28 pre-existing
protected model/fixture/recording hashes match, including earlier failed-run
recordings. Expected debug profile/kernel/timestamps and recorder metadata
changed. Production APK remains
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.

Retained new recording `streaming-ui-1792220319665848` finalized with authoritative
elapsed 26,455 ms and reported bytesWritten 213,777. Directory:
`files/recordings/d5183833b04a2447fccd2d700b724717d272b4f333b7f7d6dabae0a1b9be3cea/`.
ADTS is 213,310 bytes and M4A 213,665 bytes; original files remain on device and
the private only-new-recording archive validates. No playback, upload, decode
integrity or lexical/language verification was performed. The test still uses
an in-memory meeting repository and no-op refinement handler, not durable
transcript persistence.

Private evidence directory `build/streaming_spike/streaming-ui-coverage-actual-l15UjU/`
is 0700; backups, recording archive and debugger-capability logs are 0600.
SHA-256:

- Prior installed debug APK: `b75213b055aa8ab979d9cedc1f9e84ce53ebab1e3d5adcd0c552f08878f1fd83`.
- Prior app data archive: `1b1806aa98d7f3a3e5f35e7642c37ac782f8c8e2ec46a9be5228061f6d33d2e8`.
- New recording archive: `64e33a74d14c834c302f453ff97f12045a83f0234543d2a806088b27ee9699a3`.
- Driver log: `19b6cf41fe12f95f31eeac880ff08cd07263210b48f42ef6be7164a09669bf17`.
- Final device log: `445a066ea9ba828c539660b1b2b42c6c2768c17e8a7da0c867dbac9ec76ff139`.

No source code/expectation changed during this attempt and no automatic retry
occurred. The prepared-only status is superseded for this package, but acceptance
remains unpassed and progress remains 7/41. Next work should independently
reproduce control hit-testing under live layout updates and trace the non-prefix
PCM discontinuity offline before requesting any further microphone run.

### Offline control stability and bounded startup retention (2026-10-17)

The subsequent `continue` authorized offline work only. No device, permission,
installation, launch or microphone operation was performed. The installed
diagnostic package and microphone-off state are last known from the prior
attempt; this section does not claim a fresh device observation.

Reproduced the UI layout defect with real streaming adapter/controller updates:
the live section preceded the recorder controls, so a 40-line provisional
hypothesis moved the pause target. Three regression cases failed before the fix
(320x640, 640x320, and compact text scale 2). Moving the live section after all
control groups preserves their layout origin without clipping captions, reducing
text scale, changing button semantics or bypassing UI taps. All 11 recording
screen tests then passed. New cases save the original button rectangle, deliver
the growing hypothesis, require a stable/hit-testable target and tap its original
center to reach authoritative paused state. The device helper also now requires
a hit-testable target before tapping; warnings are not suppressed.

Independently reproduced the observed gap coordinates in the real native fanout:
with no consumer, the existing 16-frame derived FIFO retains the oldest full
640-byte reads and drops later frames. After 201 startup frames and consumer
attachment, the next live frame follows sample 5,120 with sample 64,320, matching
0.32 to 4.02 seconds at 16 kHz. Canonical input remains complete in this fixture.
The hardware lease waits for runtime readiness before consumer attachment, which
makes this a reproducible causal path, not proof of the failed attempt's unique
upstream cause. Its trace did not contain a startup-phase timing profile.

Added a bounded queue policy wired only into foreground capture construction:
`DEBUG && LOQUIRIS_STREAMING_NATIVE_SPIKE` selects 256 derived frames; all other
combinations keep the existing 16. Default pipeline capacity, canonical queue,
fanout scheduling, capture coordinates and overload/degradation rules are
unchanged. At full reads this retains 5.12 seconds / 160 KiB of queued PCM
payload; short reads retain less duration, and frame/object overhead plus a
possible in-flight frame are outside that payload figure. This is not an
end-to-end backlog bound or evidence of cold latency, memory/PSS or sustained
capacity qualification. Slower startup or inference can still overflow and must
remain visible as incomplete coverage. The strict gap oracle is unchanged.

Native red/green: four policy tests initially had two expected assertion failures
with the legacy-capacity stub, then all passed. They cover legacy gap reproduction,
201 retained startup frames with contiguous next input, a 256-frame hard bound
with 44 drops after 300 pre-attachment frames, and unchanged ordinary-debug and
release behavior; canonical sequences remain complete in each fixture.
Independent read-only review found no new Critical, Important or Minor issue.
Its exclusions (actual device outcome, model accuracy, latency/resource gates,
slower-start overflow, and production promotion) remain unqualified, not waived.

Fresh verification: full Flutter **880 passed**; native debug **541 tests, zero
failures/errors**; `lintDebug` successful with 20 warnings (not a zero-warning
claim); analysis of `lib test integration_test test_driver` found no issues;
both OpenSpec changes passed strict validation; formatting unchanged and
`git diff --check` clean. First full Flutter invocation had three process-launch
failures because child processes could not find `dart`; supplying the pinned SDK
on PATH yielded the full 880-test pass without changing tests/privacy policy.

Evidence SHA-256, under `build/streaming_spike/`:

- `streaming-control-stability-red.log`: `67b759a38857fdd223486757f4073bfd96fb469b305d197dc6e5f64abdece49f`.
- `streaming-control-stability-green.log`: `f25cfa9300ac6fd135995fc8a73cd03cd24390ca737d4ed375c9b6c5824c840f`.
- `streaming-startup-buffer-red.log`: `92e9f5f631dc7a3e0bc395d50194ae5314f85e13fc0270dec3c1dcf6569ab296`.
- `streaming-startup-buffer-green.log`: `0f1cf917a12ce85751428b7fcf6177e85d3b0d6cee96d17849396288a0a0687d`.
- `streaming-controls-startup-flutter-final-v2.log`: `1bc5e4a47e6f91d5eead35ab958d967c61ba84d6afc8016ed88b5eed9bc5a150`.
- `streaming-controls-startup-native-final.log`: `0705465b279a88bfb6bd4a423bf64b92432f4b42e25e5993d6b6987cc85008e7`.
- `streaming-controls-startup-analyze-final.log`: `9e1a15605c7853186255559effc0d425d872f16fe600598b507f5a8d31ebd3fd`.
- `streaming-controls-startup-prepared-build.log`: `af59e582f4f6903f3677841dc8631f5c4df06b15a640ec7509f1473a89d48799`.

Prepared only (not installed/launched):
`build/streaming_spike/streaming-controls-startup-prepared-RPG0h1/recorder-ui-controls-startup-signed.apk`,
SHA-256 `3ce96cf8fa34ef8fbf3e2ba5b7b20aebab478ad95610ad3ddbc3fd5ffd8f6039`,
verified certificate
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
Do not install the default Flutter-signed APK. A fresh authorized attempt must
repeat identity, idle-state, certificate and data-backup preflight, then evaluate
actual control taps and gap details without retroactively passing the previous
failed recording. Coarse progress remains 7/41; no task checkbox, production
availability, staging or commit changed.

### Authorized controls/startup-retention UI attempt (2026-10-17 15:36)

Fresh `start` authorized one run, not automatic retries. Reconfirmed
`j75tmvsovouchmlj`, `M2104K10AC`/`chopin`, firmware
`V14.0.8.0.TKPCNXM`, idle Loquiris services, finalized prior capture, microphone
and notification permission false, microphone UID/operation app-ops `ignore`.
Backed up the prior installed diagnostic APK and app data before in-place
`-r -t --no-incremental` installation of the signed controls/startup package
`3ce96cf8fa34ef8fbf3e2ba5b7b20aebab478ad95610ad3ddbc3fd5ffd8f6039`.
Both old and new certificates freshly matched
`6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
The installed hash matched, and all 40 prelaunch file hashes were unchanged.
No uninstall, clear-data, production update or database reset occurred.

After the playback cue, enabled only debug microphone permission/app-ops,
launched once, and attached the explicit recorder UI driver to that existing
app. The one scenario **passed** in about 29 seconds; the framework's additional
tearDownAll count is not a second scenario. Actual UI pause/resume and normal
STOP/navigation, read-only final text, finish acknowledgement, additional
post-resume final with later media end, disposal acknowledgement and no-late-event
assertions passed. Native persisted command receipts independently confirm
successful `start -> pause -> resume -> stop`, with `pausedByUser` and final
`finalized` snapshots. No missed-test-tap warning was found.

Content-free trace: phase `passed`, one accepted open, 22 wire/projected text
events, seven nonempty finals at wire/projection/view, zero rejected events,
zero open transport errors and no failure causes. The sole boundary is
`pause`, sequence 12, epoch 1, start=end=15,200,000 us. There is no positive-length
gap in this run: projected gap notices zero, stopped view incomplete=false,
gap-detail truncation zero. The strict coverage oracle passed unchanged; the
positive-gap incomplete-message branch was not exercised. The former 0.32–4.02s
gap did not recur in this attempt, which is not proof against all startup or
overload conditions or a retrospective pass for earlier failed recordings.

Logs also contain pointer gestures and debug finder output during the run.
This was not treated as a controlled, interference-free performance experiment.
No lexical/language scoring, decode-integrity check, capture-feedback bound,
numeric backlog, latency percentile, memory/battery/thermal or long-run claim
follows. The integration entry still uses an in-memory meeting repository and
no-op refinement handler; durable transcript persistence is not validated.

Independent teardown release/disposal assertions passed. Fresh service checks
found no Loquiris service before microphone UID/operation app-ops were restored
to `ignore` and permission revoked. Notification permission remained false.
Removed only this run's debugger forward. All 33 prior protected model,
fixture and recording hashes match; expected profile/kernel/timestamp and
recording metadata changed. Production APK remained
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.

Retained new recording `streaming-ui-1792222609193572`: finalized elapsed
26,149 ms, bytesWritten 210,663; directory
`files/recordings/2b50231bd105f8defbfce60d383eecd8c7f0c59f87981523f84428206ca46d17/`.
ADTS 210,196 bytes, M4A 210,593 bytes, plus commit/manifest/playback status.
Original files remain on device and the private only-new-recording archive
validates (six tar entries). No audio was played, decoded or uploaded by the
agent. Private directory
`build/streaming_spike/streaming-controls-startup-actual-28yCKj/` is 0700;
backup/archive/debugger-capability logs are 0600. SHA-256:

- Prior installed APK: `96811eb9992d1ae012da001ed92056c9eaae8e7bf53fbe6042480be450c028d0`.
- Prior app data: `3a0925236ddeba5bb1a66340535a0f2e9e854d71fee88e88cf35799f4544dfae`.
- New recording archive: `32c934855ee3a3a965e106fa33bd2859ef0b61dd516ed67e113a8dc148a29b8e`.
- Driver log: `d5ff7c0d251059ef83bd0a1e9538bb06c7245df3112499c1dd7a93dffa45c741`.
- Final device log: `472e3a2157107a475495b07b8369b7d6444670411dff80a5cf97a6105cb18359`.

The package is now installed (its prepared-only status above is superseded),
but microphone is off. No source/test changes, further capture, staging or
commit occurred during this attempt. Coarse progress remains 7/41: this scoped
smoke does not satisfy the bilingual, sustained/resource or persistence gates.

### Offline backlog coverage during remote model readiness (2026-10-17)

The following `continue` was offline only: no device/permission/installation/
launch/microphone operations. Auditing task 4.3 found existing unique-interval
union accounting, queued-plus-in-flight fanout ownership, an independent ticker,
and real remote-ACK tests. Those implementations were reused, not replaced.
The debug hardware composition, however, started its watchdog only after remote
Ready. Thus retained PCM during remote model loading was exempt from observations.

Extracted the worker-only readiness wait into the debug-only
`awaitStreamingRuntimeReady` helper. After successful bind, the hardware lease
now creates/owns the timer and watchdog, and the helper starts observation before
polling Ready. The five-second threshold, three one-second observations,
256/16-frame policy, canonical path, event contract and release acknowledgement
rules are unchanged. Cancellation remains polled, and the hardware path still
checks cancellation and endpoint identity again before attachment. Timer and
watchdog cleanup remain in the lease's acknowledged runtime-release path.

Actual RED: with the extracted legacy ordering, the new regression failed
`Observe retained capture before model Ready` (one of two tests). GREEN:
the actual helper now observes a real fanout's 256 retained full reads = 81,920
unique samples / 5.12 seconds while Ready remains incomplete; three observations
request backlog degradation. Real `StreamingRemoteSession` Close is sent but
release remains pending until matching Released, while all 256 canonical frames
finish. Ready/warm startup and existing memory/thermal/model/engine result codes
remain tested. Related guard/watchdog/platform-lease tests passed as well.

Read-only review found no blocking issue and suggested a late-Ready cancellation
regression. Added a characterization using the actual helper, registry, fanout
and platform lease: cancel during loading, then complete Ready; no consumer
attaches, canonical input finishes, and closure still awaits its independent
release ACK. This additional characterization was not represented as a new RED
cycle. The final focused four-class run has 28 passing tests; review then closed
its Minor with no remaining Critical/Important/Minor finding.

Limits remain explicit: prebinding inference-arbiter waiting is still before
this monitor; this slice does not implement numeric backlog transport/UI or
prove physical-device overload behavior, latency, memory, accuracy or sustained
capacity. Requesting degradation is not proof of native release: a hung remote
owner remains quarantined until actual ACK/death, not freed by a timeout. No
threshold, gap oracle or production availability gate was relaxed. Task 4.3 and
coarse progress remain uncompleted at 7/41, not certified by these host tests.

Fresh verification: **544 native tests, zero failures/errors**, `lintDebug`
successful with 20 warnings; **880 Flutter tests passed**; analysis of
`lib test integration_test test_driver` found no issues; both OpenSpec changes
passed strict validation and `git diff --check` was clean. GitNexus target
impact/context queries could not resolve the debug/new symbols (UNKNOWN, not
LOW). Whole-worktree `detect_changes(all)` reports HIGH risk, 346 changed indexed
symbols, 92 files and 15 affected processes across cumulative work; it cannot
isolate/certify this four-file slice, particularly unindexed new files. The user
was warned, existing changes were preserved, and nothing was staged/committed.

Evidence SHA-256, under `build/streaming_spike/`:

- `streaming-loading-backlog-red.log`: `ce7b19219136609adbab761f0dafa9a6c85e72c676531602be60b7b0a9c4a4f0`.
- `streaming-loading-backlog-green.log`: `774149176e2b12b472b8a7d5561ea18b1993dc8448698e7b21efb68d6a6e3ea9`.
- `streaming-loading-backlog-race-green.log`: `1f9e7b0ef818e2d81db586d25dd1f2f3c42018bfa3c88eabe2c49db47347b960`.
- `streaming-loading-backlog-native-final-v2.log`: `1c414a0aedb73567ce305ed3039013f34bec7b1e9f6ccf3ba8f30d6ddc12a877`.
- `streaming-loading-backlog-flutter-final.log`: `664354aaf9f980b0a3791561c09be433b5679aaec3be36987dcad863534c5d9a`.
- `streaming-loading-backlog-analyze-final.log`: `ca3d3c9cc72502bdf08281eaf6a5fccbb0d7af779ba8c91af194d48d86c85d11`.
- `streaming-loading-backlog-prepared-build.log`: `62de35bc33dd476a69180ab66dd7c16b294b57d5608f298016c3634e6ee28c15`.

Prepared and signature-verified only, not installed/launched:
`build/streaming_spike/streaming-loading-backlog-prepared-K6dgPi/recorder-ui-loading-backlog-signed.apk`,
SHA-256 `4e4a12b665cd9026711212e0d7662ac9891c76ae1eb5149d17f23705da64f267`,
certificate `6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
Build succeeded with Kotlin Gradle Plugin migration and SDK XML version warnings.
The last device-pass result belongs to the previously installed controls/startup
package, not this new artifact. Fresh readiness and full non-destructive preflight
remain necessary before any future physical-device attempt.

### Install-only handoff (2026-10-17)

An explicit `install` request authorized installation only. Fresh target/idle/
finalized-capture/permission checks passed; prior and candidate signatures matched
the debug certificate above. Backed up the prior installed `3ce96cf8...` APK
and current app data before successful in-place `-r -t --no-incremental` update.
Fresh installed SHA-256 is
`4e4a12b665cd9026711212e0d7662ac9891c76ae1eb5149d17f23705da64f267`.
All 45 app file hashes are identical before/after; production APK is unchanged.
The app was not launched and no capture/test or permission grant occurred.
Microphone/notification permissions remain false, microphone UID/operation
app-ops remain `ignore`, and fresh Loquiris service inventory is empty.
This supersedes prepared-only status for the loading-backlog package; it is
installed but not device-tested. The entry is a diagnostic integration-test
package, not a normal production launch. Do not infer microphone/run authorization
from installation alone.

Private rollback backup directory:
`build/streaming_spike/streaming-install-only-E9Rziz/` (0700; files 0600).
Prior APK SHA-256:
`3ce96cf8fa34ef8fbf3e2ba5b7b20aebab478ad95610ad3ddbc3fd5ffd8f6039`.
App-data tar: 134,922,752 bytes, 58 valid entries, SHA-256
`82565f122b7a5d22dd47a7e47f24423330372d4e495696176976d6e08b93f77e`.
No clear-data/uninstall, source/test edit, staging or commit occurred.

### User-approved diagnostic app removal (2026-10-18)

The user confirmed keeping `com.loquiris` and removing the duplicate diagnostic
`com.loquiris.debug` after backup. Fresh service checks were empty, but the
diagnostic capture snapshot was `recoverable`, not the earlier finalized state.
No capture/recovery/finalization operation was attempted. The user was informed;
the diagnostic package was force-stopped only after confirming no active service,
and its raw recording/recovery state was preserved without modification.

Private backup `build/streaming_spike/diagnostic-removal-backup-HJJASo/` (0700)
contains the exact diagnostic APK and `files`, `app_flutter`, `shared_prefs`
archive (0600). Every one of the archive's 48 regular-file hashes matches the
device pre-removal hash inventory; the tar has 62 entries. APK SHA-256:
`4e4a12b665cd9026711212e0d7662ac9891c76ae1eb5149d17f23705da64f267`,
certificate `6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`.
Data archive SHA-256:
`338b8c066037ff49991d49757fc19f7335eb8be48686c30d0be32ffe7a920534`.
No audio was decoded, played or uploaded.

`pm uninstall -k --user 0 com.loquiris.debug` returned Success. The exact
diagnostic package is absent from user-0 installed-package inventory and
`pm path --user 0 com.loquiris.debug` returns no APK path. Keep-data settings
metadata may still appear in package dumps/queries; those are not proof of an
installed APK. The `-k` request retains data for recovery, and the independently
verified local backup remains available. No clear-data operation was performed.
The non-launcher instrumentation helper packages were left untouched.

The normal `com.loquiris` launcher remains installed, with APK SHA-256 unchanged:
`db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98`.
No production-app data operation, app launch, permission grant, recording test,
source/test change, staging or commit occurred. The previously installed
loading-backlog diagnostic is now removed, not ready for launch. Reinstallation
and any microphone test require an explicit new request; restoring a backup
must not overwrite surviving data without a separate checked recovery plan.
