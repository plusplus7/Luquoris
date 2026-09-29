import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('durability pragmas protect irreplaceable user data', () {
    expect(
      AppDatabase.connectionPragmas,
      containsAll(<String>[
        'PRAGMA foreign_keys = ON',
        'PRAGMA journal_mode = WAL',
        'PRAGMA synchronous = FULL',
        'PRAGMA busy_timeout = 5000',
      ]),
    );
  });

  test('audit columns reject invalid timestamps and soft deletes', () async {
    await _insertMeeting(database, 'meeting-1');

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO bookmarks (
          id, created_at, updated_at, meeting_id, media_offset_us, kind
        ) VALUES ('negative-created', -1, 1, 'meeting-1', 0, 'bookmark')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO bookmarks (
          id, created_at, updated_at, meeting_id, media_offset_us, kind
        ) VALUES ('backwards-update', 2, 1, 'meeting-1', 0, 'bookmark')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO bookmarks (
          id, created_at, updated_at, row_revision,
          meeting_id, media_offset_us, kind
        ) VALUES ('negative-revision', 1, 1, -1, 'meeting-1', 0, 'bookmark')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO bookmarks (
          id, created_at, updated_at, is_deleted,
          meeting_id, media_offset_us, kind
        ) VALUES ('missing-delete-time', 1, 1, 1, 'meeting-1', 0, 'bookmark')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO meetings (
          id, created_at, updated_at, is_deleted, deleted_at,
          title, media_duration_us, lifecycle, language_mode, trashed_at_utc_ms,
          lifecycle_before_trash
        ) VALUES ('trash-time-mismatch', 1, 2, 1, 2,
          'Trash', 0, 'trashed', 'mixed', 3, 'recoverable')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO meetings (
          id, created_at, updated_at, is_deleted, deleted_at,
          title, media_duration_us, lifecycle, language_mode, trashed_at_utc_ms
        ) VALUES ('trash-without-previous-state', 1, 2, 1, 2,
          'Trash', 0, 'trashed', 'mixed', 2)
        ''',
      ),
    );
  });

  test('database mirrors every app-relative path rejection', () async {
    await _insertMeeting(database, 'meeting-1');

    final invalidPaths = <String>[
      'C:/audio.aac',
      'a//audio.aac',
      'a/./audio.aac',
      'a\u0000/audio.aac',
    ];
    for (var index = 0; index < invalidPaths.length; index += 1) {
      final path = invalidPaths[index];
      await _expectRejected(
        database.customStatement(
          '''
          INSERT INTO audio_segments (
            id, created_at, updated_at, meeting_id, sequence,
            relative_path, media_start_us, media_duration_us,
            committed_bytes, state
          ) VALUES (?, 1, 1, 'meeting-1', 0, ?, 0, 1, 1, 'committed')
          ''',
          <Object>['audio-$index', path],
        ),
      );
    }

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO model_manifests (
          id, created_at, updated_at, version, source, sha256, bytes,
          expected_engine_id, license_id, license_snapshot_path
        ) VALUES ('bad-model', 1, 1, '1', 'source', 'hash', 1,
          'engine', 'MIT', 'C:/license.txt')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO export_records (
          id, created_at, updated_at, meeting_id, format,
          export_state, relative_path, bytes
        ) VALUES ('bad-export', 1, 1, 'meeting-1', 'audio',
          'completed', '', 0)
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO backup_records (
          id, created_at, updated_at, backup_state,
          relative_path, sha256, bytes
        ) VALUES ('bad-backup', 1, 1, 'completed',
          'a//backup.zip', 'hash', 1)
        ''',
      ),
    );
  });

  test('revision discriminator requires a matching typed payload', () async {
    await _insertMeeting(database, 'meeting-1');

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO revisions (
          id, created_at, updated_at, meeting_id,
          speaker_id, revision_kind, payload_json
        ) VALUES ('unsupported', 1, 1, 'meeting-1',
          'speaker-1', 'speakerMerge', '{}')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO revisions (
          id, created_at, updated_at, meeting_id,
          transcript_segment_id, revision_kind, payload_json
        ) VALUES ('wrong-shape', 1, 1, 'meeting-1',
          'segment-1', 'transcriptText', '{"previousText":1}')
        ''',
      ),
    );
  });

  test('current transcript selection cannot cross meeting ownership', () async {
    await _insertMeeting(database, 'meeting-a');
    await _insertMeeting(database, 'meeting-b');
    await _insertModel(database);
    await _insertTranscriptRun(database, 'run-b', 'meeting-b');

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO meeting_transcript_selections (
          id, created_at, updated_at, meeting_id, transcript_run_id
        ) VALUES ('selection-1', 1, 1, 'meeting-a', 'run-b')
        ''',
      ),
    );
  });

  test('speaker clusters cannot cross meeting or run ownership', () async {
    await _insertMeeting(database, 'meeting-a');
    await _insertMeeting(database, 'meeting-b');
    await _insertModel(database);
    await _insertDiarizationRun(database, 'run-a', 'meeting-a');
    await _insertDiarizationRun(database, 'run-b', 'meeting-b');

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO speakers (
          id, created_at, updated_at, meeting_id, analysis_run_id, label
        ) VALUES ('speaker-invalid', 1, 1, 'meeting-a', 'run-b', 'Speaker 1')
        ''',
      ),
    );

    await database.customStatement(
      '''
      INSERT INTO speakers (
        id, created_at, updated_at, meeting_id, analysis_run_id, label
      ) VALUES ('speaker-a', 1, 1, 'meeting-a', 'run-a', 'Speaker A')
      ''',
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO speaker_assignments (
          id, created_at, updated_at, meeting_id, analysis_run_id, speaker_id,
          speaker_analysis_run_id,
          start_us, end_us, is_overlap, needs_confirmation
        ) VALUES ('assignment-invalid', 1, 1, 'meeting-b', 'run-b', 'speaker-a', 'run-b',
          0, 1, 0, 0)
        ''',
      ),
    );
  });

  test(
    'language and transcript speaker selections remain meeting-local',
    () async {
      await _insertMeeting(database, 'meeting-a');
      await _insertMeeting(database, 'meeting-b');
      await _insertModel(database);
      await _insertTranscriptRun(database, 'transcript-a', 'meeting-a');
      await _insertTranscriptRun(database, 'transcript-b', 'meeting-b');
      await _insertDiarizationRun(database, 'diarization-b', 'meeting-b');
      await database.customStatement(
        '''
      INSERT INTO speakers (
        id, created_at, updated_at, meeting_id, analysis_run_id, label
      ) VALUES ('speaker-b', 1, 1, 'meeting-b', 'diarization-b', 'Speaker B')
      ''',
      );
      await _insertTranscriptSegment(
        database,
        id: 'segment-a',
        meetingId: 'meeting-a',
        runId: 'transcript-a',
      );
      await _insertTranscriptSegment(
        database,
        id: 'segment-b',
        meetingId: 'meeting-b',
        runId: 'transcript-b',
      );
      await database.customStatement(
        '''
      INSERT INTO language_decisions (
        id, created_at, updated_at, transcript_segment_id,
        tag, source, confidence
      ) VALUES ('language-b', 1, 1, 'segment-b', 'english', 'automatic', 0.9)
      ''',
      );

      await _expectRejected(
        database.customStatement(
          '''
        INSERT INTO transcript_language_selections (
          id, created_at, updated_at,
          transcript_segment_id, language_decision_id
        ) VALUES ('language-selection-invalid', 1, 1,
          'segment-a', 'language-b')
        ''',
        ),
      );
      await _expectRejected(
        database.customStatement(
          '''
        INSERT INTO transcript_segments (
          id, created_at, updated_at, meeting_id, transcript_run_id,
          start_us, end_us, raw_model_text, displayed_text, revision_state,
          speaker_id, speaker_meeting_id
        ) VALUES ('segment-speaker-invalid', 1, 1, 'meeting-a', 'transcript-a',
          1, 2, 'raw', 'raw', 'machine', 'speaker-b', 'meeting-a')
        ''',
        ),
      );
    },
  );

  test('revision and processing targets remain meeting-local', () async {
    await _insertMeeting(database, 'meeting-a');
    await _insertMeeting(database, 'meeting-b');
    await _insertModel(database);
    await _insertTranscriptRun(database, 'transcript-b', 'meeting-b');
    await _insertTranscriptSegment(
      database,
      id: 'segment-b',
      meetingId: 'meeting-b',
      runId: 'transcript-b',
    );

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO revisions (
          id, created_at, updated_at, meeting_id,
          transcript_segment_id, revision_kind, payload_json
        ) VALUES ('revision-invalid', 1, 1, 'meeting-a',
          'segment-b', 'transcriptText',
          '{"previousText":"raw","revisedText":"edited"}')
        ''',
      ),
    );
    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO processing_jobs (
          id, created_at, updated_at, meeting_id, job_kind, job_state,
          transcript_run_id, model_id
        ) VALUES ('job-invalid', 1, 1, 'meeting-a', 'transcription', 'queued',
          'transcript-b', 'model-1')
        ''',
      ),
    );
  });

  test('analysis provenance must match its installed model manifest', () async {
    await _insertMeeting(database, 'meeting-1');
    await _insertModel(database);

    await _expectRejected(
      database.customStatement(
        '''
        INSERT INTO transcript_runs (
          id, created_at, updated_at, meeting_id, engine_id, engine_version,
          model_id, model_version, model_sha256, parameters_json, run_state
        ) VALUES ('forged-run', 1, 1, 'meeting-1', 'other-engine', '1',
          'model-1', 'forged-version', 'forged-hash', '{}', 'queued')
        ''',
      ),
    );
  });
}

Future<void> _expectRejected(Future<void> operation) => expectLater(
  operation,
  throwsA(isA<SqliteException>()),
);

Future<void> _insertMeeting(AppDatabase database, String id) =>
    database.customStatement(
      '''
      INSERT INTO meetings (
        id, created_at, updated_at, title, media_duration_us,
        lifecycle, language_mode
      ) VALUES (?, 1, 1, 'Meeting', 0, 'draft', 'mixed')
      ''',
      <Object>[id],
    );

Future<void> _insertModel(AppDatabase database) => database.customStatement('''
  INSERT OR IGNORE INTO model_manifests (
    id, created_at, updated_at, version, source, sha256, bytes,
    expected_engine_id, license_id, license_snapshot_path
  ) VALUES ('model-1', 1, 1, '1', 'source', 'hash', 1,
    'engine', 'MIT', 'licenses/model.txt')
  ''');

Future<void> _insertTranscriptRun(
  AppDatabase database,
  String id,
  String meetingId,
) => database.customStatement(
  '''
  INSERT INTO transcript_runs (
    id, created_at, updated_at, meeting_id, engine_id, engine_version,
    model_id, model_version, model_sha256, parameters_json, run_state
  ) VALUES (?, 1, 1, ?, 'engine', '1', 'model-1', '1', 'hash', '{}', 'queued')
  ''',
  <Object>[id, meetingId],
);

Future<void> _insertDiarizationRun(
  AppDatabase database,
  String id,
  String meetingId,
) => database.customStatement(
  '''
  INSERT INTO diarization_runs (
    id, created_at, updated_at, meeting_id, engine_id, engine_version,
    model_id, model_version, model_sha256, parameters_json, run_state
  ) VALUES (?, 1, 1, ?, 'engine', '1', 'model-1', '1', 'hash', '{}', 'queued')
  ''',
  <Object>[id, meetingId],
);

Future<void> _insertTranscriptSegment(
  AppDatabase database, {
  required String id,
  required String meetingId,
  required String runId,
}) => database.customStatement(
  '''
  INSERT INTO transcript_segments (
    id, created_at, updated_at, meeting_id, transcript_run_id,
    start_us, end_us, raw_model_text, displayed_text, revision_state
  ) VALUES (?, 1, 1, ?, ?, 0, 1, 'raw', 'raw', 'machine')
  ''',
  <Object>[id, meetingId, runId],
);
