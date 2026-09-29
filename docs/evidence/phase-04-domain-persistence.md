# Phase Evidence: Domain Model and Drift Persistence

## Scope

- OpenSpec change: `bootstrap-loquiris-offline-recorder`
- Task IDs: 4.1–4.7
- Commit/build identifier: repository has no initial commit; Flutter build `0.1.0+1`
- Date and operator: 2026-09-28, Codex

## Completed

- Added immutable meeting, audio, event, bookmark, transcript, language,
  speaker, revision, processing, model, and export entities with canonical
  integer time/size units, typed state, provenance, and explicitly clearable
  nullable corrections.
- Added the matching Drift v1 schema with foreign-key actions, checked
  invariants, declarative indexes, WAL/foreign-key/synchronous PRAGMAs, and
  cross-table transaction boundaries.
- Added Drift repositories for the session library, local search, trash,
  durable permanent-deletion reservations, storage accounting, recovery
  reconciliation, model manifests, parallel transcript versions,
  explicit current transcript selection, and non-destructive revisions. Added
  the diarization-version schema and its atomic write boundary; the complete
  diarization repository remains later work.
- Added a forward-only schema workflow, committed v1 snapshot and era classes,
  hostile fixtures, transaction-failure rollback tests, and a guarded opener
  that restores exact main/WAL/SHM bytes after an open or migration failure.
- Added deterministic dual-timeline evidence proving that a 60-second pause is
  retained in wall-clock and monotonic event time while media time remains
  frozen, then resumes to a final 30-second media duration.

## Verification

| Command or procedure | Environment | Result | Evidence path |
|---|---|---|---|
| TDD red/green for repository, transaction, migration, and timeline behavior | Flutter host tests | Expected failures observed before the corresponding minimal implementations; timeline test initially failed on a private generated table type and passed after context inference | `test/data/` |
| `dart run build_runner build --delete-conflicting-outputs` | Dart 3.12.0, build_runner 2.15.1 | Passed; legacy option reported ignored; generator reported 2 outputs | `lib/data/database/app_database.g.dart` |
| `dart format --output=none --set-exit-if-changed lib test tool` | Pinned Flutter toolchain | Passed; 80 files, 0 changes | `lib/`, `test/`, `tool/` |
| `flutter analyze --fatal-infos` | Flutter 3.44.0 / Dart 3.12.0, macOS | Passed; 0 issues | Command output in implementation session |
| `flutter test --test-randomize-ordering-seed=random --reporter=expanded` | Flutter host test runner | Passed; seed `1753422250`, 114 tests | `test/` |
| `dart run tool/release_privacy_policy.dart` | Locked resolved dependencies | Passed; structured manifest and dependency policy | `tool/release_privacy_policy.dart` |
| Drift confinement and persistence-ban scripts | macOS workspace | Passed; Drift confined to data layer, no sqflite, unsafe DB copy, OFFSET pagination, or missing PRAGMAs | `lib/data/` |
| Fresh `drift_dev schema dump` followed by `diff -u` against the committed v1 snapshot | Drift 2.35.0 / drift_dev 2.35.0 | Passed; no schema difference | `drift_schemas/drift_schema_v1.json` |
| Forced guarded-open failure with a committed uncheckpointed WAL | Locked `sqlite3` 3.5.2 child process using the pinned Flutter SDK Dart VM | Passed; main, WAL, and SHM restored byte-for-byte and hostile row reopened intact | `test/data/app_database_migration_test.dart` |
| Independent read-only reviews of repository boundaries, migration recovery, and dual-timeline evidence | Review agent | Passed; no remaining blocker | Implementation-session review record |
| `openspec validate bootstrap-loquiris-offline-recorder --type change --strict --json --no-interactive` | OpenSpec 1.0 CLI | Passed; 1 change, 0 issues | Active OpenSpec change |

## Unverified assumptions

- Version 1 is the greenfield baseline. The harness exercises every available
  version pair, but no non-trivial production upgrade can be claimed until a
  version 2 schema and real `v1 -> v2` migration exist.
- The WAL rollback fixture proves host SQLite bundle restoration. Android
  process death, device restart, filesystem behavior, and native manifest
  reconciliation remain phase 7 and phase 14 instrumented work.
- Dual-timeline persistence is verified with externally supplied deterministic
  values. The Android foreground service remains the future clock authority;
  native pause/resume timing and four-hour drift are not yet implemented or
  measured.
- File deletion ordering is covered with host fakes and a private temporary
  store. Scoped-storage behavior and user-selected export destinations are not
  claimed.
- No microphone capture, audio encoding, physical-device stability,
  transcription, language identification, diarization, thermal, energy, or
  model-quality behavior is delivered or claimed by this phase.

## Risks

- R-07 is partially mitigated by durable deletion reservation, database
  transactions, guarded migration rollback, and recovery reconciliation;
  database-to-native-manifest reconciliation remains open.
- R-21 and R-22 remain open for backup/restore and cleanup. Current repository
  tests prove only that permanent deletion is explicit and does not remove
  metadata before authoritative audio deletion succeeds.
- R-23 is partially mitigated by canonical microsecond media offsets and the
  deterministic pause mapping test. Native long-run drift and segment-boundary
  agreement remain open.
- R-19 and R-20 remain partially mitigated by structured diagnostics and the
  release dependency/permission policy; later retention, native/model, and
  runtime audits remain required.
- R-01 through R-06 and R-08 through R-18 remain open because this phase does
  not implement or physically validate recording or AI behavior.

## Recommendation

- Proceed to phase 5 only as an Android native audio architecture spike.
- Do not begin the production recorder state machine until the spike proves
  recoverable AAC/container behavior, a maximum five-second crash-loss window,
  and bounded fan-out that cannot back-pressure canonical capture.
- Keep all transcription and diarization capabilities experimental and
  disabled until their later license, benchmark, and target-device gates pass.
