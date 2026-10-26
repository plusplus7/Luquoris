import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v4.dart' as v4;
import '../support/model_bundle_fixture.dart';

void main() {
  test(
    'full v2 inventory and per-file provenance survive SQLite storage',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedRuns(database);
      final original = modelBundleFixture();
      final encoded = jsonEncode(original);
      await _insertMetadata(database, manifest: encoded);
      final stored =
          (await database
                  .customSelect(
                    'SELECT bundle_manifest_json FROM transcript_processing_metadata',
                  )
                  .getSingle())
              .read<String>('bundle_manifest_json');
      expect(
        stored,
        encoded,
        reason: 'all source/license bytes must remain exact',
      );
      expect(
        (BundledModelManifest.tryParse(jsonDecode(stored))
                as Ok<BundledModelManifest, InvalidModelManifest>)
            .value,
        (BundledModelManifest.tryParse(original)
                as Ok<BundledModelManifest, InvalidModelManifest>)
            .value,
        reason:
            'stored provenance must decode to the same validated full bundle',
      );
      final decoded = jsonDecode(stored) as Map<String, Object?>;
      expect(
        decoded['artifacts'],
        hasLength(3),
        reason: 'the encoder, tokenizer and configuration must all be retained',
      );
    },
  );

  test('mid-v5 index publication failure restores exact closed v4 bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loquiris-v5-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/database.sqlite');
    final old = v4.DatabaseAtV4(NativeDatabase(file));
    await _seedRuns(old);
    // A table in the index namespace forces a real failure after table creation.
    await old.customStatement(
      'CREATE TABLE ux_transcript_processing_run (obstacle TEXT)',
    );
    await old.close();
    final before = file.readAsBytesSync();
    await expectLater(
      openMigratedDatabaseFile(file),
      throwsA(isA<DriftRemoteException>()),
      reason: 'failed schema publication must not return an open new database',
    );
    expect(
      file.readAsBytesSync(),
      before,
      reason:
          'the pre-open closed-file snapshot must be restored byte-for-byte',
    );
    final restored = v4.DatabaseAtV4(NativeDatabase(file));
    addTearDown(restored.close);
    expect(
      (await restored.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      4,
      reason: 'failed v5 publication must leave the original schema version',
    );
    expect(
      await restored.customSelect('SELECT id FROM transcript_runs').get(),
      hasLength(3),
      reason: 'forced migration failure must not destroy historical runs',
    );
    expect(
      await restored
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'transcript_processing_metadata'",
          )
          .get(),
      isEmpty,
      reason: 'partially created v5 objects must not leak into v4',
    );
  });

  test(
    'v4 upgrade preserves legacy content and invents no paired provenance',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(4);
      addTearDown(schema.close);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await _seedRuns(old);
      await old.customStatement(
        'INSERT INTO meeting_transcript_selections (id, created_at, updated_at, meeting_id, transcript_run_id) VALUES (?, 1, 1, ?, ?)',
        ['selection', 'meeting', 'draft'],
      );
      await old.customStatement(
        'INSERT INTO transcript_segments (id, created_at, updated_at, meeting_id, transcript_run_id, start_us, end_us, raw_model_text, displayed_text, revision_state) VALUES (?, 1, 1, ?, ?, 0, 1234567, ?, ?, ?)',
        [
          'segment',
          'meeting',
          'draft',
          '  O\'Brien — 中英 🎙️ "quoted" \\ path\n  ',
          '人类 correction',
          'corrected',
        ],
      );
      await old.customStatement(
        'INSERT INTO bookmarks (id, created_at, updated_at, meeting_id, media_offset_us, kind) VALUES (?, 1, 1, ?, 123456, ?)',
        ['bookmark', 'meeting', 'highlight'],
      );
      const retainedTables = [
        'meetings',
        'model_manifests',
        'transcript_runs',
        'meeting_transcript_selections',
        'transcript_segments',
        'bookmarks',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in retainedTables) {
        before[table] =
            (await old.customSelect('SELECT * FROM $table ORDER BY id').get())
                .map((row) => row.data)
                .toList();
      }
      await old.close();
      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 5);
      for (final table in retainedTables) {
        expect(
          (await database
                  .customSelect('SELECT * FROM $table ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList(),
          before[table],
          reason: 'v5 must preserve every legacy $table field exactly',
        );
      }
      expect(
        await database
            .customSelect('SELECT * FROM transcript_processing_metadata')
            .get(),
        isEmpty,
        reason: 'legacy runs must not be misclassified as a new role',
      );
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
        reason: 'v5 must preserve database integrity',
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
        reason: 'v5 must preserve all owner relationships',
      );
    },
  );

  test(
    'paired-run metadata has checked role, linkage and bundle snapshot',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          )
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        contains('transcript_processing_metadata'),
        reason: 'new paired runs require separate durable provenance metadata',
      );
    },
  );

  test('invalid role, completeness and manifest cannot be stored', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedRuns(database);
    for (final invalid in [
      (
        role: 'batch',
        completeness: 'complete',
        manifest: _manifest,
        audio: _hash,
      ),
      (
        role: 'liveDraft',
        completeness: 'unknown',
        manifest: _manifest,
        audio: null,
      ),
      (
        role: 'liveDraft',
        completeness: 'incomplete',
        manifest: '[]',
        audio: null,
      ),
      (
        role: 'liveDraft',
        completeness: 'incomplete',
        manifest: '{}',
        audio: null,
      ),
      (
        role: 'liveDraft',
        completeness: 'incomplete',
        manifest: '{',
        audio: null,
      ),
      (
        role: 'refinement',
        completeness: 'incomplete',
        manifest: _manifest,
        audio: null,
      ),
      (
        role: 'refinement',
        completeness: 'complete',
        manifest: _manifest,
        audio: 'bad',
      ),
    ]) {
      await expectLater(
        _insertMetadata(
          database,
          role: invalid.role,
          completeness: invalid.completeness,
          manifest: invalid.manifest,
          audio: invalid.audio,
        ),
        throwsA(isA<SqliteException>()),
        reason: 'invalid processing provenance must be rejected by SQLite',
      );
    }
  });

  test(
    'source and run links are meeting-local and never self-referential',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedRuns(database);
      for (final source in ['draft-other', 'refined', 'absent']) {
        await expectLater(
          _insertMetadata(database, source: source),
          throwsA(isA<SqliteException>()),
          reason:
              'foreign, self and missing draft links are not valid provenance',
        );
      }
      await _insertMetadata(database, source: 'draft');
      final rows = await database
          .customSelect(
            'SELECT source_run_id, bundle_manifest_json FROM transcript_processing_metadata',
          )
          .get();
      expect(
        rows.single.read<String>('source_run_id'),
        'draft',
        reason: 'refinement must retain its explicit source run',
      );
      expect(
        rows.single.read<String>('bundle_manifest_json'),
        _manifest,
        reason: 'bundle provenance must not be rewritten on storage',
      );
      await expectLater(
        _insertMetadata(database, source: 'draft'),
        throwsA(isA<SqliteException>()),
        reason: 'one run cannot acquire contradictory processing metadata',
      );
      await database.customStatement(
        "DELETE FROM meetings WHERE id = 'meeting'",
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
        reason: 'whole-meeting deletion must not leave source-link orphans',
      );
    },
  );
}

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _manifest = '{"schemaVersion":2,"sha256":"$_hash"}';

Future<void> _seedRuns(GeneratedDatabase database) async {
  for (final meeting in ['meeting', 'other']) {
    await database.customStatement(
      'INSERT INTO meetings (id, created_at, updated_at, title, lifecycle, language_mode) VALUES (?, 1, 1, ?, ?, ?)',
      [meeting, "中英 O'Brien 🎙️", 'finalized', 'mixed'],
    );
  }
  await database.customStatement(
    'INSERT INTO model_manifests (id, created_at, updated_at, version, source, sha256, bytes, expected_engine_id, license_id, license_snapshot_path) VALUES (?, 1, 1, ?, ?, ?, 6, ?, ?, ?)',
    [
      'model',
      '1',
      'pinned',
      _hash,
      'engine',
      'Apache-2.0',
      'models/licenses/model.txt',
    ],
  );
  for (final (run, meeting) in [
    ('draft', 'meeting'),
    ('refined', 'meeting'),
    ('draft-other', 'other'),
  ]) {
    await database.customStatement(
      'INSERT INTO transcript_runs (id, created_at, updated_at, meeting_id, engine_id, engine_version, model_id, model_version, model_sha256, parameters_json, run_state) VALUES (?, 1, 1, ?, ?, ?, ?, ?, ?, ?, ?)',
      [run, meeting, 'engine', '1', 'model', '1', _hash, '{}', 'queued'],
    );
  }
}

Future<void> _insertMetadata(
  AppDatabase database, {
  String role = 'refinement',
  String completeness = 'complete',
  String manifest = _manifest,
  String? audio = _hash,
  String? source,
}) => database.customStatement(
  'INSERT INTO transcript_processing_metadata (id, created_at, updated_at, transcript_run_id, meeting_id, processing_role, source_run_id, completeness, bundle_manifest_json, audio_inventory_sha256) VALUES (?, 1, 1, ?, ?, ?, ?, ?, ?, ?)',
  [
    'metadata',
    'refined',
    'meeting',
    role,
    source,
    completeness,
    manifest,
    audio,
  ],
);
