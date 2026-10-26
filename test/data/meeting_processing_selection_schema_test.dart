import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';

void main() {
  test(
    'meeting processing selection survives as an optional durable table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'meeting_processing_selections'",
          )
          .get();
      expect(
        tables,
        hasLength(1),
        reason:
            'a process restart must not erase two-pass model role selection',
      );
    },
  );

  test(
    'SQLite rejects partial roles, malformed profiles, and duplicate choices',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement(
        "INSERT INTO meetings (id,created_at,updated_at,title,lifecycle,language_mode) VALUES ('meeting',1,1,'meeting','draft','mixed')",
      );
      for (final invalid in <Map<String, Object?>>[
        {'processing_mode': 'unknown'},
        {'live_bundle_manifest_json': null},
        {'live_engine_version': ''},
        {'live_parameters_json': '{}'},
        {'live_parameters_json': '{"parameterVersion":1.0}'},
        {'refinement_parameters_json': '[]'},
        {'refinement_parameters_json': '{"parameterVersion":0}'},
        {'refinement_bundle_manifest_json': '{'},
        {'refinement_bundle_manifest_json': '{"schemaVersion":3}'},
        {'meeting_id': 'absent'},
      ]) {
        await expectLater(
          _insert(database, 'twoPass', overrides: invalid),
          throwsA(isA<SqliteException>()),
          reason: invalid.keys.join(','),
        );
      }
      for (final mode in ['recordingOnly', 'postSession', 'twoPass']) {
        await _insert(database, mode);
        expect(
          await database
              .customSelect('SELECT id FROM meeting_processing_selections')
              .get(),
          hasLength(1),
          reason: '$mode must have one complete role selection',
        );
        await expectLater(
          _insert(database, mode, overrides: {'id': 'duplicate'}),
          throwsA(isA<SqliteException>()),
          reason: 'a meeting cannot acquire two competing selections',
        );
        await database.customStatement(
          'DELETE FROM meeting_processing_selections',
        );
      }
      await expectLater(
        _insert(
          database,
          'recordingOnly',
          overrides: {'live_engine_version': '1'},
        ),
        throwsA(isA<SqliteException>()),
        reason: 'recording-only selection cannot hide a partial live profile',
      );
      await expectLater(
        _insert(
          database,
          'postSession',
          overrides: {'live_engine_version': '1'},
        ),
        throwsA(isA<SqliteException>()),
        reason: 'post-session mode cannot implicitly enable a live engine',
      );
    },
  );

  test(
    'selection owner query uses its index and whole-meeting deletion cascades',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customStatement(
        "INSERT INTO meetings (id,created_at,updated_at,title,lifecycle,language_mode) VALUES ('meeting',1,1,'meeting','draft','mixed')",
      );
      await _insert(database, 'twoPass');
      final plan = await database
          .customSelect(
            "EXPLAIN QUERY PLAN SELECT * FROM meeting_processing_selections WHERE meeting_id = 'meeting'",
          )
          .get();
      expect(
        plan.map((row) => row.read<String>('detail')).join(' '),
        contains('ux_meeting_processing_selection'),
      );
      await database.customStatement(
        "DELETE FROM meetings WHERE id = 'meeting'",
      );
      expect(
        await database
            .customSelect('SELECT id FROM meeting_processing_selections')
            .get(),
        isEmpty,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}

Future<void> _insert(
  AppDatabase database,
  String mode, {
  Map<String, Object?> overrides = const {},
}) async {
  final values = <String, Object?>{
    'id': 'selection',
    'meeting_id': 'meeting',
    'created_at': 1,
    'updated_at': 1,
    'processing_mode': mode,
    if (mode == 'twoPass') ...{
      'live_bundle_manifest_json': '{"schemaVersion":2}',
      'live_engine_version': '1',
      'live_parameters_json': '{"parameterVersion":1}',
    },
    if (mode != 'recordingOnly') ...{
      'refinement_bundle_manifest_json': '{"schemaVersion":1}',
      'refinement_engine_version': '1',
      'refinement_parameters_json': '{"parameterVersion":1}',
    },
    ...overrides,
  };
  await database.customStatement(
    'INSERT INTO meeting_processing_selections (${values.keys.join(',')}) VALUES (${List.filled(values.length, '?').join(',')})',
    values.values.toList(),
  );
}
