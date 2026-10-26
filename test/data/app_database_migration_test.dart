import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:path/path.dart' as path;

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v1.dart' as v1;
import '../drift/generated/schema_v2.dart' as v2;
import '../drift/generated/schema_v3.dart' as v3;
import '../support/database_fixtures.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test(
    'current database matches the committed latest schema snapshot',
    () async {
      final latest = GeneratedHelper.versions.last;
      final connection = await verifier.startAt(latest);
      final database = AppDatabase(connection);

      await verifier.migrateAndValidate(database, latest);

      expect(
        database.schemaVersion,
        GeneratedHelper.versions.last,
        reason: 'schemaVersion must match the latest committed Drift snapshot',
      );
      await database.close();
    },
  );

  test(
    'v2 to v3 preserves meeting content and adds canonical setup defaults',
    () async {
      final schema = await verifier.schemaAt(2);
      addTearDown(schema.close);
      final oldDatabase = v2.DatabaseAtV2(schema.newConnection());
      await oldDatabase
          .into(oldDatabase.meetings)
          .insert(DatabaseFixtures.meetingV2());
      await oldDatabase.close();

      final database = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(database, 3);
      final meeting = await (database.select(
        database.meetings,
      )..where((row) => row.id.equals('meeting-hostile'))).getSingle();

      expect(
        meeting.title,
        DatabaseFixtures.hostileMeetingTitle,
        reason: 'v2 Unicode and whitespace title must survive byte-for-byte',
      );
      expect(
        meeting.transcriptionMode,
        'postSession',
        reason: 'existing meetings need the conservative canonical mode',
      );
      expect(
        meeting.expectedSpeakerCount,
        isNull,
        reason: 'existing meetings must retain automatic speaker estimation',
      );
      expect(
        await database.select(database.recordingPreferences).get(),
        isEmpty,
        reason: 'migration must not invent a user preference',
      );
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
        reason: 'v3 database must remain internally consistent',
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
        reason: 'v3 migration must not leave dangling references',
      );
      await database.close();
    },
  );

  test(
    'v3 to v4 preserves exports and permits path-free SAF completion',
    () async {
      final schema = await verifier.schemaAt(3);
      addTearDown(schema.close);
      final oldDatabase = v3.DatabaseAtV3(schema.newConnection());
      await oldDatabase
          .into(oldDatabase.meetings)
          .insert(
            v3.MeetingsCompanion.insert(
              id: 'meeting-export',
              createdAt: 1,
              updatedAt: 1,
              title: DatabaseFixtures.hostileMeetingTitle,
              lifecycle: 'finalized',
              languageMode: 'mixed',
            ),
          );
      await oldDatabase
          .into(oldDatabase.exportRecords)
          .insert(
            v3.ExportRecordsCompanion.insert(
              id: 'export-staged',
              createdAt: 2,
              updatedAt: 2,
              meetingId: 'meeting-export',
              format: 'archive',
              exportState: 'completed',
              relativePath: const Value('exports/meeting-export.zip'),
              bytes: const Value(400),
            ),
          );
      await oldDatabase
          .into(oldDatabase.exportRecords)
          .insert(
            v3.ExportRecordsCompanion.insert(
              id: 'export-legacy-text',
              createdAt: 2,
              updatedAt: 2,
              meetingId: 'meeting-export',
              format: 'plainText',
              exportState: 'failed',
              failureCode: const Value('legacy_failure'),
            ),
          );
      await oldDatabase.close();

      final database = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(database, 4);
      final retained =
          await (database.select(database.exportRecords)..where(
                (row) => row.id.equals('export-staged'),
              ))
              .getSingle();
      expect(
        retained.relativePath,
        'exports/meeting-export.zip',
        reason: 'private staged export metadata must survive the v4 rebuild',
      );
      expect(
        retained.bytes,
        400,
        reason: 'completed byte count must survive the v4 rebuild',
      );
      final migratedLegacy = await (database.select(
        database.exportRecords,
      )..where((row) => row.id.equals('export-legacy-text'))).getSingle();
      expect(
        migratedLegacy.format,
        'text',
        reason: 'v3 plain-text exports must migrate to the canonical v4 name',
      );
      await database
          .into(database.exportRecords)
          .insert(
            ExportRecordsCompanion.insert(
              id: 'export-saf',
              createdAt: 3,
              updatedAt: 3,
              meetingId: 'meeting-export',
              format: 'archive',
              exportState: 'completed',
              bytes: const Value(500),
            ),
          );
      expect(
        await database.select(database.exportRecords).get(),
        hasLength(3),
        reason: 'direct SAF completion must not require an external path',
      );
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
        reason: 'the v4 database must remain internally consistent',
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
        reason: 'the v4 rebuild must preserve foreign-key ownership',
      );
      await database.close();
    },
  );

  test('v1 hostile fixture remains byte-for-byte readable', () async {
    final schema = await verifier.schemaAt(1);
    addTearDown(schema.close);
    final oldDatabase = v1.DatabaseAtV1(schema.newConnection());
    await oldDatabase
        .into(oldDatabase.meetings)
        .insert(
          DatabaseFixtures.meetingV1(),
        );
    await oldDatabase.close();

    final database = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(database, 1);
    final integrity = await database
        .customSelect('PRAGMA integrity_check')
        .get();
    final foreignKeyFailures = await database
        .customSelect('PRAGMA foreign_key_check')
        .get();
    await database.close();
    final eraDatabase = v1.DatabaseAtV1(schema.newConnection());
    final meeting = await (eraDatabase.select(
      eraDatabase.meetings,
    )..where((row) => row.id.equals('meeting-hostile'))).getSingle();

    expect(
      integrity.single.data.values.single,
      'ok',
      reason: 'the committed v1 schema must remain internally consistent',
    );
    expect(
      foreignKeyFailures,
      isEmpty,
      reason: 'the baseline fixture must not contain dangling references',
    );
    expect(
      meeting.title,
      DatabaseFixtures.hostileMeetingTitle,
      reason: 'Unicode, quotes, slashes, and whitespace must survive intact',
    );
    expect(
      meeting.mediaDurationUs,
      1234567,
      reason: 'canonical integer media units must remain unchanged',
    );
    await eraDatabase.close();
  });

  test(
    'v1 to v2 preserves meeting content and creates recovery findings',
    () async {
      final schema = await verifier.schemaAt(1);
      addTearDown(schema.close);
      final oldDatabase = v1.DatabaseAtV1(schema.newConnection());
      await oldDatabase
          .into(oldDatabase.meetings)
          .insert(
            DatabaseFixtures.meetingV1(),
          );
      await oldDatabase.close();

      final database = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(database, 2);
      final findings = await database
          .customSelect(
            'SELECT code FROM recovery_findings',
          )
          .get();
      final integrity = await database
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      final foreignKeyFailures = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      await database.close();
      final eraDatabase = v2.DatabaseAtV2(schema.newConnection());
      final meeting = await (eraDatabase.select(
        eraDatabase.meetings,
      )..where((row) => row.id.equals('meeting-hostile'))).getSingle();

      expect(
        meeting.title,
        DatabaseFixtures.hostileMeetingTitle,
        reason: 'v1 meeting content must survive the append-only v2 migration',
      );
      expect(
        findings,
        isEmpty,
        reason: 'migration must not invent recovery diagnostics',
      );
      expect(
        integrity.data.values.single,
        'ok',
        reason: 'v2 database must remain internally consistent',
      );
      expect(
        foreignKeyFailures,
        isEmpty,
        reason: 'v2 migration must not leave dangling references',
      );
      await eraDatabase.close();
    },
  );

  test(
    'failed guarded open restores the exact WAL database snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'loquiris-migration-guard-',
      );
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final databaseFile = File('${directory.path}/loquiris.sqlite');
      final empty = await openMigratedDatabaseFile(databaseFile);
      await empty.close();
      final fixtureResult = await _runCrashedWalFixture(databaseFile);
      expect(
        fixtureResult.exitCode,
        0,
        reason:
            'the crash fixture must leave a committed WAL bundle: '
            '${fixtureResult.stderr}',
      );
      const suffixes = <String>['', '-wal', '-shm'];
      final beforeFailure = <String, List<int>>{};
      for (final suffix in suffixes) {
        final file = File('${databaseFile.path}$suffix');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'the crash fixture must preserve database$suffix',
        );
        beforeFailure[suffix] = file.readAsBytesSync();
      }

      await expectLater(
        openMigratedDatabaseFile(
          databaseFile,
          verifyOpen: (database) async {
            await database.customStatement(
              "UPDATE meetings SET title = 'corrupted' WHERE id = 'meeting-hostile'",
            );
            throw StateError('forced migration failure');
          },
        ),
        throwsA(isA<StateError>()),
      );

      for (final suffix in suffixes) {
        final file = File('${databaseFile.path}$suffix');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'failed migration must restore database$suffix',
        );
        expect(
          file.readAsBytesSync(),
          beforeFailure[suffix],
          reason: 'failed migration must restore exact database$suffix bytes',
        );
      }
      final restored = await openMigratedDatabaseFile(databaseFile);
      final meeting = await (restored.select(
        restored.meetings,
      )..where((row) => row.id.equals('meeting-hostile'))).getSingle();
      expect(
        meeting.title,
        DatabaseFixtures.hostileMeetingTitle,
        reason: 'the failed migration must not leak partially committed rows',
      );
      expect(meeting.mediaDurationUs, 1234567);
      await restored.close();
    },
  );

  for (final from in GeneratedHelper.versions) {
    for (final to in GeneratedHelper.versions.where(
      (version) => version > from,
    )) {
      test('schema shape v$from -> v$to', () async {
        final connection = await verifier.startAt(from);
        final database = AppDatabase(connection);

        await verifier.migrateAndValidate(database, to);

        await database.close();
      });
    }
  }
}

Future<({int exitCode, String stderr})> _runCrashedWalFixture(
  File databaseFile,
) async {
  final process = await Process.start(
    _dartExecutableForFlutterTest(),
    <String>[
      '--packages=.dart_tool/package_config.json',
      'test/support/create_wal_fixture.dart',
      databaseFile.path,
      DatabaseFixtures.hostileMeetingTitle,
    ],
    workingDirectory: Directory.current.path,
  );
  var exited = false;
  final stderr = process.stderr.transform(systemEncoding.decoder).join();
  final stdoutDone = process.stdout.drain<void>();
  try {
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 10),
    );
    exited = true;
    await stdoutDone;
    return (exitCode: exitCode, stderr: await stderr);
  } finally {
    await process.stdin.close();
    if (!exited) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}

String _dartExecutableForFlutterTest() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final executable = File(
      path.join(
        directory.path,
        'dart-sdk',
        'bin',
        Platform.isWindows ? 'dart.exe' : 'dart',
      ),
    );
    if (executable.existsSync()) return executable.path;
    directory = directory.parent;
  }
  throw StateError('flutter_test_dart_executable_not_found');
}
