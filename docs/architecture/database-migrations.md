# Database migrations

Loquiris uses forward-only Drift migrations. The database is the only source of
truth for recordings and human corrections, so a failed upgrade is recovered by
restoring a closed-file snapshot, never by running a down migration.

## Current baseline

- The latest schema is version 1. This is the greenfield baseline; there is no
  fabricated `v0 -> v1` migration.
- `drift_schemas/drift_schema_v1.json` is the committed schema snapshot.
- `test/drift/generated/` contains era-correct v1 data classes and companions.
- `lib/data/database/schema_versions.dart` is generated and append-only once a
  migration step ships.
- Every index is declared with `@TableIndex`; hand-written creation SQL is not
  allowed because it would be absent from the exported schema snapshot.

## Mandatory workflow for the first and every later schema change

1. Design the schema change and bump `AppDatabase.schemaVersion` by exactly one.
2. Run `dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/`.
3. Run `dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/drift/generated/`.
4. Run `dart run drift_dev schema steps drift_schemas/ lib/data/database/schema_versions.dart`.
5. Add only the new `fromNToNPlus1` step. Never edit a step that has shipped,
   never add a down migration, and never reuse a schema version.
6. Run `dart run build_runner build --delete-conflicting-outputs`.
7. Add a hostile-content test that writes through the old era companion, runs
   the real migration, and reads through the new era class.
8. Run every `from -> to` pair, including skipped-version paths, plus
   `PRAGMA integrity_check` and `PRAGMA foreign_key_check`.
9. Force a mid-open failure through the guarded opener and prove the original
   database bytes and rows are restored.

The schema snapshot, generated era classes, step file, codegen output, tests,
and documentation are one indivisible change.

## Open and recovery boundary

`openMigratedDatabaseFile` runs before repositories are constructed. With no
live connection, it copies the main SQLite file and any `-wal` and `-shm`
sidecars, opens the database eagerly so Drift must run migrations, and discards
the snapshot only after the open succeeds. On any thrown object it closes the
failed connection, removes the partially migrated files, restores every
pre-open file, and rethrows with the original stack trace.

No code may overwrite a database while a connection is live. A future flow
that keeps a handle alive before upgrade must checkpoint it with
`PRAGMA wal_checkpoint(TRUNCATE)`, close it, and only then call the guarded
opener.

## Test fixtures and failure injection

`DatabaseFixtures` owns deterministic hostile values containing apostrophes,
Chinese text, emoji, quotes, backslashes, newlines, and boundary whitespace.
Migration tests compare these values exactly and use canonical integer units.

Repository transaction tests install temporary SQLite triggers that abort a
child write. They prove that a failed model capability insert leaves no model
manifest and that a failed revision insert rolls back the visible transcript
correction. These triggers exist only in in-memory test databases.

## Prohibited shortcuts

- Do not edit an existing schema JSON or shipped migration step by hand.
- Do not use `eraseDatabaseOnSchemaChange` in any build.
- Do not copy only the main database while WAL sidecars may contain commits.
- Do not accept schema-shape validation as evidence that rows survived.
- Do not auto-delete or rebuild authoritative audio, transcripts, or revisions
  to make a migration pass.
