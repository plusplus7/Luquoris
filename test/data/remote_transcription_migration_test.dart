import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v6.dart' as v6;

void main() {
  test(
    'v6 to v7 retains every old row without scheduling any upload',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(6);
      addTearDown(schema.close);
      final old = v6.DatabaseAtV6(schema.newConnection());
      await old
          .into(old.meetings)
          .insert(
            v6.MeetingsCompanion.insert(
              id: 'legacy',
              title: "中文 O'Brien 🎙️",
              lifecycle: 'finalized',
              languageMode: 'mixed',
              createdAt: 1,
              updatedAt: 1,
              mediaDurationUs: const Value(1234567),
            ),
          );
      final rows = await old.customSelect('SELECT * FROM meetings').get();
      final expected = rows.map((r) => r.data).toList();
      await old.close();
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      await verifier.migrateAndValidate(upgraded, 7);
      expect(
        (await upgraded.customSelect('SELECT * FROM meetings').get())
            .map((r) => r.data)
            .toList(),
        expected,
      );
      expect(
        await upgraded.select(upgraded.remoteTranscriptionTasks).get(),
        isEmpty,
      );
      expect(
        (await upgraded.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(
        await upgraded.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test('mid-v7 failure restores the exact closed v6 database', () async {
    final folder = await Directory.systemTemp.createTemp(
      'loquiris-v7-failure-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/db.sqlite');
    final old = v6.DatabaseAtV6(NativeDatabase(file));
    await old
        .into(old.meetings)
        .insert(
          v6.MeetingsCompanion.insert(
            id: 'legacy',
            title: 'retained',
            lifecycle: 'finalized',
            languageMode: 'mixed',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await old.customStatement(
      'CREATE INDEX remote_transcript_versions ON meetings(title)',
    );
    await old.close();
    final before = file.readAsBytesSync();
    await expectLater(
      openMigratedDatabaseFile(file),
      throwsA(isA<Exception>()),
    );
    expect(file.readAsBytesSync(), before);
    final recovered = v6.DatabaseAtV6(NativeDatabase(file));
    expect(
      (await recovered.select(recovered.meetings).get()).single.title,
      'retained',
    );
    await recovered.close();
  });
  test(
    'remote tables exist without creating local model catalog entries',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        containsAll([
          'remote_transcription_tasks',
          'remote_transcript_versions',
        ]),
      );
      expect(await db.select(db.modelManifests).get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        7,
      );
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
