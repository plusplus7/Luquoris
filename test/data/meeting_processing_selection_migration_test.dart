import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v5.dart' as v5;
import '../support/model_bundle_fixture.dart';

void main() {
  test(
    'v5 to v6 preserves every old table and invents no processing choice',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(5);
      addTearDown(schema.close);
      final old = v5.DatabaseAtV5(schema.newConnection());
      await _seed(old);
      final names =
          (await old
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toList();
      final before = <String, List<Map<String, Object?>>>{
        for (final name in names) name: await _rows(old, name),
      };
      await old.close();
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      await verifier.migrateAndValidate(upgraded, 6);
      for (final entry in before.entries) {
        expect(
          await _rows(upgraded, entry.key),
          entry.value,
          reason:
              '${entry.key} must survive the additive v6 upgrade byte-for-byte',
        );
      }
      expect(
        await upgraded
            .customSelect('SELECT * FROM meeting_processing_selections')
            .get(),
        isEmpty,
        reason:
            'nearRealTime legacy rows must not be reinterpreted as a new two-pass opt-in',
      );
      expect(
        (await upgraded.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
        reason: 'the upgraded file must remain structurally sound',
      );
      expect(
        await upgraded.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
        reason:
            'all original version/correction/source links must remain valid',
      );
    },
  );

  test('mid-v6 index publication failure restores closed v5 bytes exactly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loquiris-v6-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/database.sqlite');
    final old = v5.DatabaseAtV5(NativeDatabase(file));
    await _seed(old);
    await old.customStatement(
      'CREATE TABLE ux_meeting_processing_selection (obstacle TEXT)',
    );
    await old.close();
    final before = file.readAsBytesSync();
    await expectLater(
      openMigratedDatabaseFile(file),
      throwsA(isA<DriftRemoteException>()),
      reason:
          'a failure after creating the table must abort the guarded migration',
    );
    expect(
      file.readAsBytesSync(),
      before,
      reason:
          'failed migration must restore exact previous file bytes, not just a shape',
    );
    final restored = v5.DatabaseAtV5(NativeDatabase(file));
    addTearDown(restored.close);
    expect(
      (await restored.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      5,
      reason: 'failure must leave schema version at v5',
    );
    expect(
      await restored
          .customSelect('SELECT id FROM transcript_processing_metadata')
          .get(),
      hasLength(2),
      reason: 'paired provenance must remain readable after failure rollback',
    );
    expect(
      await restored
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'meeting_processing_selections'",
          )
          .get(),
      isEmpty,
      reason: 'no partially created v6 table may leak into v5',
    );
  });
}

Future<List<Map<String, Object?>>> _rows(
  GeneratedDatabase database,
  String table,
) async =>
    (await database.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((row) => row.data)
        .toList();

Future<void> _seed(GeneratedDatabase database) async {
  final bundle = modelBundleFixture();
  await database.customStatement(
    '''
    INSERT INTO meetings (id,created_at,updated_at,title,lifecycle,language_mode,transcription_mode)
    VALUES ('meeting',1,1,?,'finalized','mixed','nearRealTime')
  ''',
    ["  O'Brien — 中文 🎙️ \"quoted\" \\ path\n"],
  );
  await database.customStatement(
    '''
    INSERT INTO model_manifests (id,created_at,updated_at,version,source,sha256,bytes,expected_engine_id,license_id,license_snapshot_path)
    VALUES ('test-bundle',1,1,?,?,?,?, 'test-streaming','MIT','models/licenses/test-bundle.txt')
  ''',
    [bundle['version'], bundle['source'], bundle['sha256'], bundle['bytes']],
  );
  for (final run in ['draft', 'refined']) {
    await database.customStatement(
      '''
      INSERT INTO transcript_runs (id,created_at,updated_at,meeting_id,engine_id,engine_version,model_id,model_version,model_sha256,parameters_json,run_state,started_at_utc_ms,ended_at_utc_ms,progress)
      VALUES (?,1,1,'meeting','test-streaming','1.0.0','test-bundle',?,?,'{"parameterVersion":1}','completed',1,2,1)
    ''',
      [run, bundle['version'], bundle['sha256']],
    );
    await database.customStatement(
      '''
      INSERT INTO transcript_processing_metadata (id,created_at,updated_at,transcript_run_id,meeting_id,processing_role,source_run_id,completeness,bundle_manifest_json,audio_inventory_sha256)
      VALUES (?,1,1,?,'meeting',?,?,'incomplete',?,?)
    ''',
      [
        run,
        run,
        if (run == 'draft') 'liveDraft' else 'refinement',
        if (run == 'draft') null else 'draft',
        jsonEncode(bundle),
        if (run == 'draft') null else 'a' * 64,
      ],
    );
  }
  await database.customStatement(
    "INSERT INTO meeting_transcript_selections (id,created_at,updated_at,meeting_id,transcript_run_id) VALUES ('current',1,1,'meeting','draft')",
  );
  await database.customStatement(
    '''
    INSERT INTO transcript_segments (id,created_at,updated_at,meeting_id,transcript_run_id,start_us,end_us,raw_model_text,displayed_text,revision_state)
    VALUES ('segment',1,1,'meeting','draft',0,1000000,?,?,'corrected')
  ''',
    ['  刘国梁 ONNX\n', '  刘国良 ONNX\n'],
  );
  await database.customStatement(
    '''
    INSERT INTO revisions (id,created_at,updated_at,meeting_id,revision_kind,transcript_segment_id,payload_json)
    VALUES ('revision',1,1,'meeting','transcriptText','segment',?)
  ''',
    [
      jsonEncode({
        'previousText': '  刘国梁 ONNX\n',
        'revisedText': '  刘国良 ONNX\n',
      }),
    ],
  );
  await database.customStatement(
    "INSERT INTO bookmarks (id,created_at,updated_at,meeting_id,media_offset_us,kind) VALUES ('bookmark',1,1,'meeting',500000,'highlight')",
  );
}
