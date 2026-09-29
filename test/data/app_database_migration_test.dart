import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:path/path.dart' as path;

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v1.dart' as v1;
import '../support/database_fixtures.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test(
    'current database matches the committed latest schema snapshot',
    () async {
      final connection = await verifier.startAt(1);
      final database = AppDatabase(connection);

      await verifier.migrateAndValidate(database, 1);

      expect(
        database.schemaVersion,
        GeneratedHelper.versions.last,
        reason: 'schemaVersion must match the latest committed Drift snapshot',
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
    final meeting = await (database.select(
      database.meetings,
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
    await database.close();
  });

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
