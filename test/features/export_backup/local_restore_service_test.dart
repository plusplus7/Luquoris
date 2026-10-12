import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';

void main() {
  late Directory root;
  late AppDatabase live;
  late _FakeRestoreGateway gateway;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loquiris-restore-test-');
    live = AppDatabase(NativeDatabase.memory());
    gateway = _FakeRestoreGateway(root);
  });

  tearDown(() async {
    await live.close();
    await root.delete(recursive: true);
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  test(
    'publishes remapped audio and skips the same collision on repeat',
    () async {
      await _writeSourceDatabase(root, const <_MeetingFixture>[
        _MeetingFixture('meeting-a', 'Backup title'),
      ]);
      await _insertMeeting(live, 'meeting-a', 'Local title');
      gateway.liveFingerprints['meeting-a'] = _shaB;
      final service = _service(live, gateway, root);

      final first = await _restore(service);

      final firstReceipt =
          (first as Ok<RestoreImportReceipt, BackupFailure>).value;
      final restored = firstReceipt.meetings.single;
      expect(restored.wasConflictingCopy, isTrue);
      expect(restored.meetingId, isNot('meeting-a'));
      expect(gateway.publishedTargets, <String>[restored.meetingId]);
      expect(gateway.finalizedTargets, <String>[restored.meetingId]);
      expect(gateway.discardedOperations, <String>['restore_1']);
      final title = await live
          .customSelect(
            'SELECT title FROM meetings WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>(restored.meetingId)],
          )
          .getSingle();
      expect(title.read<String>('title'), 'Backup title — Restored copy');

      final repeated = await _restore(service);

      final repeatedReceipt =
          (repeated as Ok<RestoreImportReceipt, BackupFailure>).value;
      expect(repeatedReceipt.importedCount, 0);
      expect(repeatedReceipt.meetings.single.meetingId, restored.meetingId);
      expect(gateway.publishedTargets, <String>[restored.meetingId]);
      expect(await _count(live, 'meetings'), 2);
    },
  );

  test(
    'rolls back DB and earlier audio when later publication fails',
    () async {
      await _writeSourceDatabase(root, const <_MeetingFixture>[
        _MeetingFixture('meeting-a', 'First'),
        _MeetingFixture('meeting-b', 'Second'),
      ]);
      gateway.failSourceMeetingId = 'meeting-b';
      final service = _service(live, gateway, root);

      final result = await _restore(service);

      expect(result, isA<Err<RestoreImportReceipt, BackupFailure>>());
      expect(await _count(live, 'meetings'), 0);
      expect(gateway.rolledBackTargets, <String>['meeting-a']);
      expect(gateway.liveFingerprints['meeting-a'], equals(null));
    },
  );

  test('rejects a staged recording index that disagrees with SQLite', () async {
    await _writeSourceDatabase(root, const <_MeetingFixture>[
      _MeetingFixture('meeting-a', 'Backup title'),
    ]);
    gateway.omitRecordingIndex = true;
    final service = _service(live, gateway, root);

    final result = await _restore(service);

    expect(result, isA<Err<RestoreImportReceipt, BackupFailure>>());
    expect(
      (result as Err<RestoreImportReceipt, BackupFailure>).failure.code,
      'restore_recording_index_mismatch',
    );
    expect(await _count(live, 'meetings'), 0);
    expect(gateway.publishedTargets, isEmpty);
  });
}

LocalRestoreService _service(
  AppDatabase live,
  RestoreGateway gateway,
  Directory root,
) => LocalRestoreService(
  liveDatabase: live,
  gateway: gateway,
  resolveBaseDirectory: () async => root,
);

Future<Result<RestoreImportReceipt, BackupFailure>> _restore(
  LocalRestoreService service,
) => service.restore(
  _request,
  restoredCopyTitle: (title) => '$title — Restored copy',
);

Future<void> _writeSourceDatabase(
  Directory root,
  List<_MeetingFixture> meetings,
) async {
  final file = File(
    '${root.path}/restore_staging/restore_1/database/loquiris.sqlite',
  );
  await file.parent.create(recursive: true);
  final database = AppDatabase(NativeDatabase(file));
  for (final meeting in meetings) {
    await _insertMeeting(database, meeting.id, meeting.title);
    final storageKey = _storageKeys[meeting.id]!;
    await database.customStatement(
      'INSERT INTO audio_segments '
      '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
      'meeting_id,sequence,relative_path,media_start_us,media_duration_us,'
      'committed_bytes,state) '
      "VALUES (?,1,1,0,0,NULL,?,0,?,0,1000,5,'committed')",
      <Object?>[
        'audio-${meeting.id}',
        meeting.id,
        'recordings/$storageKey/segment-00000.adts',
      ],
    );
  }
  await database.close();
}

Future<void> _insertMeeting(
  AppDatabase database,
  String id,
  String title,
) => database.customStatement(
  'INSERT INTO meetings '
  '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,title,'
  'media_duration_us,lifecycle,language_mode,transcription_mode,'
  'expected_speaker_count,trashed_at_utc_ms,lifecycle_before_trash) '
  "VALUES (?,1,1,0,0,NULL,?,1000,'finalized','mixed', "
  "'postSession',NULL,NULL,NULL)",
  <Object?>[id, title],
);

Future<int> _count(AppDatabase database, String table) async =>
    (await database
            .customSelect('SELECT COUNT(*) AS count FROM $table')
            .getSingle())
        .read<int>('count');

AppRelativePath _relativePath(String value) =>
    (AppRelativePath.tryParse(value)
            as Ok<AppRelativePath, InvalidAppRelativePath>)
        .value;

final class _FakeRestoreGateway implements RestoreGateway {
  _FakeRestoreGateway(this.root);

  final Directory root;
  final Map<String, String> liveFingerprints = <String, String>{};
  final List<String> publishedTargets = <String>[];
  final List<String> rolledBackTargets = <String>[];
  final List<String> finalizedTargets = <String>[];
  final List<String> discardedOperations = <String>[];
  String? failSourceMeetingId;
  bool omitRecordingIndex = false;

  @override
  Future<Result<RestoreStaging, BackupFailure>> verifyAndStage(
    RestoreVerificationRequest request,
  ) async {
    final source = AppDatabase(
      NativeDatabase(
        File('${root.path}/restore_staging/restore_1/database/loquiris.sqlite'),
      ),
    );
    final ids = await source
        .customSelect('SELECT id FROM meetings ORDER BY id')
        .get();
    await source.close();
    return Ok(
      RestoreStaging(
        formatVersion: 1,
        schemaVersion: 4,
        exportedAtUtc: '2026-10-01T00:00:00Z',
        databaseRelativePath: _relativePath(
          'restore_staging/restore_1/database/loquiris.sqlite',
        ),
        checksumIndexRelativePath: _relativePath(
          'restore_staging/restore_1/checksums.json',
        ),
        stagingRelativePath: _relativePath('restore_staging/restore_1'),
        recordings: <RestoreRecordingStaging>[
          if (!omitRecordingIndex)
            for (final row in ids)
              RestoreRecordingStaging(
                sourceMeetingId: row.read<String>('id'),
                storageKey: _storageKeys[row.read<String>('id')]!,
                contentFingerprint: row.read<String>('id') == 'meeting-a'
                    ? _shaA
                    : _shaB,
                segments: const <RestoreSegmentStaging>[
                  RestoreSegmentStaging(
                    fileName: 'segment-00000.adts',
                    committedBytes: 5,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  @override
  Future<Result<Map<String, String?>, BackupFailure>> recordingFingerprints(
    List<String> meetingIds,
  ) async => Ok(<String, String?>{
    for (final meetingId in meetingIds) meetingId: liveFingerprints[meetingId],
  });

  @override
  Future<Result<bool, BackupFailure>> publishRecording(
    RestoreRecordingTransfer request,
  ) async {
    if (request.sourceMeetingId == failSourceMeetingId) {
      return const Err(BackupUnavailable('restore_recording_publish_failed'));
    }
    if (liveFingerprints[request.targetMeetingId] ==
        request.contentFingerprint) {
      return const Ok(false);
    }
    liveFingerprints[request.targetMeetingId] = request.contentFingerprint;
    publishedTargets.add(request.targetMeetingId);
    return const Ok(true);
  }

  @override
  Future<Result<void, BackupFailure>> rollbackRecordings(
    String operationId,
    List<String> meetingIds,
  ) async {
    rolledBackTargets.addAll(meetingIds);
    meetingIds.forEach(liveFingerprints.remove);
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupFailure>> finalizeRecordings(
    String operationId,
    List<String> meetingIds,
  ) async {
    finalizedTargets.addAll(meetingIds);
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupFailure>> discardStaging(String operationId) async {
    discardedOperations.add(operationId);
    return const Ok(null);
  }
}

final class _MeetingFixture {
  const _MeetingFixture(this.id, this.title);

  final String id;
  final String title;
}

const _request = RestoreRequest(
  operationId: 'restore_1',
  archiveRelativePath: 'backups/loquiris-backup-backup_1.zip',
);
const _shaA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _shaB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _storageKeys = <String, String>{
  'meeting-a':
      '7959c765f2ac5d6f4e75f18fa56177d2826e66700c5cc0f3d542858b1abc87d6',
  'meeting-b':
      '42bd6ae06ca2f8eb530330f24bc8c9ed666b2a49056ddc96fcd880cf176eb146',
};
