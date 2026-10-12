import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/export_backup/application/drift_backup_snapshot_planner.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';

void main() {
  late Directory directory;
  late db.AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('loquiris-backup-test-');
    database = db.AppDatabase(NativeDatabase.memory());
    await database
        .into(database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: 'meeting-1',
            createdAt: 1,
            updatedAt: 1,
            title: 'Private title',
            lifecycle: 'finalized',
            languageMode: 'mixed',
          ),
        );
    await database
        .into(database.audioSegments)
        .insert(
          db.AudioSegmentsCompanion.insert(
            id: 'audio-1',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'meeting-1',
            sequence: 0,
            relativePath: 'recordings/$_storageKey/segment-00000.adts',
            mediaStartUs: 0,
            mediaDurationUs: 1000,
            committedBytes: 123,
            state: 'committed',
          ),
        );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('creates WAL-safe snapshot and explicit committed audio plan', () async {
    final planner = DriftBackupSnapshotPlanner(
      database,
      () async => directory,
      afterSnapshotCreated: () async {
        await database.customStatement(
          'UPDATE audio_segments SET committed_bytes = 999',
        );
      },
    );

    final result = await planner.create('backup_1');

    final plan = (result as Ok<BackupSnapshotPlan, BackupFailure>).value;
    expect(plan.snapshotRelativePath, 'backup_staging/backup_1.sqlite');
    expect(
      File('${directory.path}/${plan.snapshotRelativePath}').lengthSync(),
      greaterThan(0),
    );
    expect(plan.audioPlan, [
      const BackupAudioPlanEntry(
        relativePath: 'recordings/$_storageKey/segment-00000.adts',
        committedBytes: 123,
      ),
    ]);
  });

  test('startup cleaner removes only incomplete backup artifacts', () async {
    final staging = Directory('${directory.path}/backup_staging')..createSync();
    final backups = Directory('${directory.path}/backups')..createSync();
    final restoreStaging = Directory('${directory.path}/restore_staging')
      ..createSync();
    File('${staging.path}/backup_1.sqlite').writeAsStringSync('snapshot');
    File('${staging.path}/keep.txt').writeAsStringSync('keep');
    File('${backups.path}/.backup_1.zip.tmp').writeAsStringSync('partial');
    File('${backups.path}/loquiris-backup-backup_1.zip').writeAsStringSync(
      'complete',
    );
    Directory('${restoreStaging.path}/restore_1/database')
      ..createSync(recursive: true)
      ..listSync();
    Directory(
      '${restoreStaging.path}/.restore_2.tmp',
    ).createSync(recursive: true);
    File('${restoreStaging.path}/keep.txt').writeAsStringSync('keep');
    final referencedRecording = Directory(
      '${directory.path}/recordings/$_storageKey',
    )..createSync(recursive: true);
    File('${referencedRecording.path}/.restore-pending').writeAsStringSync(
      'restore_1',
    );
    final orphanRecording = Directory(
      '${directory.path}/recordings/${'b' * 64}',
    )..createSync(recursive: true);
    File('${orphanRecording.path}/.restore-pending').writeAsStringSync(
      'restore_2',
    );
    final temporaryRecording = Directory(
      '${directory.path}/recordings/.restore-restore_3-${'c' * 64}.tmp',
    )..createSync(recursive: true);

    final deleted = await PrivateBackupStartupCleaner(
      () async => directory,
      database,
    ).clean();

    expect(deleted, 7);
    expect(File('${staging.path}/keep.txt').existsSync(), isTrue);
    expect(
      File('${backups.path}/loquiris-backup-backup_1.zip').existsSync(),
      isTrue,
    );
    expect(File('${restoreStaging.path}/keep.txt').existsSync(), isTrue);
    expect(referencedRecording.existsSync(), isTrue);
    expect(
      File('${referencedRecording.path}/.restore-pending').existsSync(),
      isFalse,
    );
    expect(orphanRecording.existsSync(), isFalse);
    expect(temporaryRecording.existsSync(), isFalse);
  });
}

const _storageKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
