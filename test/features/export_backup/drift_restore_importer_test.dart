import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';

void main() {
  late AppDatabase live;
  late AppDatabase source;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    live = AppDatabase(NativeDatabase.memory());
    source = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await live.close();
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  test(
    'imports once and skips an identical meeting on repeat restore',
    () async {
      await _insertMeeting(source, id: 'meeting-a', title: 'Source');
      await _insertBookmark(source, id: 'bookmark-a', meetingId: 'meeting-a');
      final liveFingerprints = <String, String>{};
      final importer = _importer(live);

      final first = await importer.import(
        source,
        sourceAudioFingerprints: const <String, String>{
          'meeting-a': _audioFingerprint,
        },
        liveAudioFingerprint: (meetingId) async => liveFingerprints[meetingId],
      );
      expect(first, isA<Ok<RestoreImportReceipt, RestoreImportFailure>>());
      final firstReceipt =
          (first as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      expect(firstReceipt.importedCount, 1);
      expect(firstReceipt.meetings.single.meetingId, 'meeting-a');
      liveFingerprints['meeting-a'] = _audioFingerprint;

      final second = await importer.import(
        source,
        sourceAudioFingerprints: const <String, String>{
          'meeting-a': _audioFingerprint,
        },
        liveAudioFingerprint: (meetingId) async => liveFingerprints[meetingId],
      );
      final secondReceipt =
          (second as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      expect(secondReceipt.importedCount, 0);
      expect(secondReceipt.skippedCount, 1);
      expect(await _count(live, 'meetings'), 1);
      expect(await _count(live, 'bookmarks'), 1);
    },
  );

  test(
    'duplicates a changed meeting ID and labels the restored copy',
    () async {
      await _insertMeeting(source, id: 'meeting-a', title: 'Backup title');
      await _insertBookmark(source, id: 'bookmark-a', meetingId: 'meeting-a');
      await _insertAudioSegment(
        source,
        id: 'audio-a',
        meetingId: 'meeting-a',
        storageKey:
            '7959c765f2ac5d6f4e75f18fa56177d2826e66700c5cc0f3d542858b1abc87d6',
      );
      await _insertMeeting(live, id: 'meeting-a', title: 'Local title');
      final liveFingerprints = <String, String>{
        'meeting-a': 'b' * 64,
      };
      final importer = _importer(live);

      final restored = await importer.import(
        source,
        sourceAudioFingerprints: const <String, String>{
          'meeting-a': _audioFingerprint,
        },
        liveAudioFingerprint: (meetingId) async => liveFingerprints[meetingId],
      );
      final receipt =
          (restored as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      final copy = receipt.meetings.single;
      expect(copy.imported, isTrue);
      expect(copy.wasConflictingCopy, isTrue);
      expect(copy.meetingId, isNot('meeting-a'));
      final title = await live
          .customSelect(
            'SELECT title FROM meetings WHERE id = ?',
            variables: [Variable<String>(copy.meetingId)],
          )
          .getSingle();
      expect(title.read<String>('title'), 'Backup title — Restored copy');
      final bookmark = await live
          .customSelect(
            'SELECT id, meeting_id FROM bookmarks WHERE meeting_id = ?',
            variables: [Variable<String>(copy.meetingId)],
          )
          .getSingle();
      expect(bookmark.read<String>('id'), isNot('bookmark-a'));
      expect(bookmark.read<String>('meeting_id'), copy.meetingId);
      final audio = await live
          .customSelect(
            'SELECT relative_path FROM audio_segments WHERE meeting_id = ?',
            variables: [Variable<String>(copy.meetingId)],
          )
          .getSingle();
      expect(audio.read<String>('relative_path'), startsWith('recordings/'));
      expect(
        audio.read<String>('relative_path'),
        isNot(
          contains(
            '7959c765f2ac5d6f4e75f18fa56177d2826e66700c5cc0f3d542858b1abc87d6',
          ),
        ),
      );
    },
  );

  test(
    'repeated collision restore skips the deterministic restored copy',
    () async {
      await _insertMeeting(source, id: 'meeting-a', title: 'Backup title');
      await _insertMeeting(live, id: 'meeting-a', title: 'Local title');
      final liveFingerprints = <String, String>{
        'meeting-a': 'b' * 64,
      };
      final importer = _importer(live);

      final first = await importer.import(
        source,
        sourceAudioFingerprints: const <String, String>{
          'meeting-a': _audioFingerprint,
        },
        liveAudioFingerprint: (meetingId) async => liveFingerprints[meetingId],
      );
      final copyId = (first as Ok<RestoreImportReceipt, RestoreImportFailure>)
          .value
          .meetings
          .single
          .meetingId;
      liveFingerprints[copyId] = _audioFingerprint;

      final repeated =
          await DriftRestoreImporter(
            liveDatabase: live,
            restoredCopyTitle: (title) => '$title — 恢复的副本',
          ).import(
            source,
            sourceAudioFingerprints: const <String, String>{
              'meeting-a': _audioFingerprint,
            },
            liveAudioFingerprint: (meetingId) async =>
                liveFingerprints[meetingId],
          );
      final receipt =
          (repeated as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      expect(receipt.importedCount, 0);
      expect(receipt.meetings.single.meetingId, copyId);
      expect(await _count(live, 'meetings'), 2);
    },
  );

  test(
    'rolls back all meetings when a later source model is missing',
    () async {
      await _insertMeeting(source, id: 'meeting-a', title: 'First');
      await _insertMeeting(source, id: 'meeting-b', title: 'Second');
      await source.customStatement('PRAGMA foreign_keys = OFF');
      await source.customStatement(
        'INSERT INTO transcript_runs '
        '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
        'meeting_id,engine_id,engine_version,model_id,model_version,'
        'model_sha256,parameters_json,run_state,started_at_utc_ms,'
        'ended_at_utc_ms,progress,failure_code) '
        "VALUES ('run-b',1,1,0,0,NULL,'meeting-b','engine','1', "
        "'missing-model','1','${'c' * 64}','{}','queued',NULL,NULL,0,NULL)",
      );
      final importer = _importer(live);

      final result = await importer.import(
        source,
        sourceAudioFingerprints: const <String, String>{
          'meeting-a': _audioFingerprint,
          'meeting-b': _audioFingerprint,
        },
        liveAudioFingerprint: (_) async => null,
      );

      expect(result, isA<Err<RestoreImportReceipt, RestoreImportFailure>>());
      expect(
        (result as Err<RestoreImportReceipt, RestoreImportFailure>)
            .failure
            .code,
        'restore_model_missing',
      );
      expect(await _count(live, 'meetings'), 0);
    },
  );

  test('remaps conflicting model and capability identities', () async {
    await _insertMeeting(source, id: 'meeting-a', title: 'Backup');
    await _insertModel(source, sha256: 'a' * 64);
    await _insertTranscriptRun(source);
    await _insertModel(live, sha256: 'b' * 64);
    final importer = _importer(live);

    final result = await importer.import(
      source,
      sourceAudioFingerprints: const <String, String>{
        'meeting-a': _audioFingerprint,
      },
      liveAudioFingerprint: (_) async => null,
    );

    expect(result, isA<Ok<RestoreImportReceipt, RestoreImportFailure>>());
    final run = await live
        .customSelect(
          "SELECT model_id FROM transcript_runs WHERE id = 'run-a'",
        )
        .getSingle();
    final restoredModelId = run.read<String>('model_id');
    expect(restoredModelId, isNot('model-a'));
    final restoredCapability = await live
        .customSelect(
          'SELECT id FROM model_capability_entries WHERE model_id = ?',
          variables: <Variable<Object>>[Variable<String>(restoredModelId)],
        )
        .getSingle();
    expect(restoredCapability.read<String>('id'), isNot('capability-a'));
    expect(await _count(live, 'model_manifests'), 2);
  });
}

DriftRestoreImporter _importer(AppDatabase live) => DriftRestoreImporter(
  liveDatabase: live,
  restoredCopyTitle: (title) => '$title — Restored copy',
);

Future<void> _insertMeeting(
  AppDatabase database, {
  required String id,
  required String title,
}) => database.customStatement(
  'INSERT INTO meetings '
  '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,title,'
  'media_duration_us,lifecycle,language_mode,transcription_mode,'
  'expected_speaker_count,trashed_at_utc_ms,lifecycle_before_trash) '
  "VALUES (?,?,?,0,0,NULL,?,1000,'finalized','mixed', "
  "'postSession',NULL,NULL,NULL)",
  <Object?>[id, 1, 1, title],
);

Future<void> _insertBookmark(
  AppDatabase database, {
  required String id,
  required String meetingId,
}) => database.customStatement(
  'INSERT INTO bookmarks '
  '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
  'meeting_id,media_offset_us,kind) '
  "VALUES (?,?,?,0,0,NULL,?,500,'bookmark')",
  <Object?>[id, 1, 1, meetingId],
);

Future<void> _insertAudioSegment(
  AppDatabase database, {
  required String id,
  required String meetingId,
  required String storageKey,
}) => database.customStatement(
  'INSERT INTO audio_segments '
  '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
  'meeting_id,sequence,relative_path,media_start_us,media_duration_us,'
  'committed_bytes,state) '
  "VALUES (?,?,?,0,0,NULL,?,0,?,0,1000,100,'committed')",
  <Object?>[
    id,
    1,
    1,
    meetingId,
    'recordings/$storageKey/segment-00000.adts',
  ],
);

Future<void> _insertModel(
  AppDatabase database, {
  required String sha256,
}) async {
  await database.customStatement(
    'INSERT INTO model_manifests '
    '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
    'version,source,sha256,bytes,expected_engine_id,license_id,'
    'license_snapshot_path) '
    "VALUES ('model-a',1,1,0,0,NULL,'1','bundled',?,100,'engine', "
    "'Apache-2.0','licenses/model.txt')",
    <Object?>[sha256],
  );
  await database.customStatement(
    'INSERT INTO model_capability_entries '
    '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
    'model_id,capability) '
    "VALUES ('capability-a',1,1,0,0,NULL,'model-a','transcription')",
  );
}

Future<void> _insertTranscriptRun(AppDatabase database) =>
    database.customStatement(
      'INSERT INTO transcript_runs '
      '(id,created_at,updated_at,row_revision,is_deleted,deleted_at,'
      'meeting_id,engine_id,engine_version,model_id,model_version,'
      'model_sha256,parameters_json,run_state,started_at_utc_ms,'
      'ended_at_utc_ms,progress,failure_code) '
      "VALUES ('run-a',1,1,0,0,NULL,'meeting-a','engine','1','model-a', "
      "'1','${'a' * 64}','{}','queued',NULL,NULL,0,NULL)",
    );

Future<int> _count(AppDatabase database, String table) async =>
    (await database
            .customSelect('SELECT COUNT(*) AS count FROM $table')
            .getSingle())
        .read<int>('count');

const _audioFingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
