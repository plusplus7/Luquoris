import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/session_write_transactions.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('initial schema contains every durable versioned entity', () async {
    expect(database.schemaVersion, 1);

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>{
        'meetings',
        'audio_segments',
        'session_events',
        'bookmarks',
        'transcript_runs',
        'transcript_segments',
        'language_decisions',
        'diarization_runs',
        'speakers',
        'speaker_assignments',
        'revisions',
        'processing_jobs',
        'model_manifests',
        'model_capability_entries',
        'model_mode_entries',
        'export_records',
        'backup_records',
      }),
    );

    final strictRows = await database.customSelect('PRAGMA table_list').get();
    final strictByName = <String, int>{
      for (final row in strictRows)
        row.read<String>('name'): row.read<int>('strict'),
    };
    for (final name in names.where((name) => !name.startsWith('sqlite_'))) {
      expect(strictByName[name], 1, reason: '$name must be STRICT');
      final columns = await database
          .customSelect('PRAGMA table_info($name)')
          .get();
      final columnNames = columns
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        columnNames,
        containsAll(<String>{
          'id',
          'created_at',
          'updated_at',
          'row_revision',
          'is_deleted',
          'deleted_at',
        }),
        reason: '$name must include shared audit columns',
      );
    }
  });

  test(
    'connection enforces foreign keys and declares durability pragmas',
    () async {
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      final synchronous = await database
          .customSelect('PRAGMA synchronous')
          .getSingle();
      final busyTimeout = await database
          .customSelect('PRAGMA busy_timeout')
          .getSingle();

      expect(foreignKeys.read<int>('foreign_keys'), 1);
      expect(synchronous.read<int>('synchronous'), 2);
      expect(busyTimeout.read<int>('timeout'), 5000);
      expect(
        AppDatabase.connectionPragmas,
        containsAll(<String>[
          'PRAGMA foreign_keys = ON',
          'PRAGMA journal_mode = WAL',
          'PRAGMA synchronous = FULL',
          'PRAGMA busy_timeout = 5000',
        ]),
      );
    },
  );

  test('meeting-owned rows cascade and unsafe paths fail checks', () async {
    await _insertMeeting(database, 'meeting-1');
    await database.customStatement(
      '''
      INSERT INTO audio_segments (
        id, created_at, updated_at, meeting_id, sequence,
        relative_path, media_start_us, media_duration_us,
        committed_bytes, state
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object>[
        'audio-1',
        1,
        1,
        'meeting-1',
        0,
        'meetings/meeting-1/0000.aac',
        0,
        1000000,
        1024,
        'committed',
      ],
    );

    await expectLater(
      database.customStatement(
        '''
        INSERT INTO audio_segments (
          id, created_at, updated_at, meeting_id, sequence,
          relative_path, media_start_us, media_duration_us,
          committed_bytes, state
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object>[
          'audio-unsafe',
          1,
          1,
          'meeting-1',
          1,
          '../escape.aac',
          1000000,
          1000000,
          1024,
          'committed',
        ],
      ),
      throwsA(isA<SqliteException>()),
    );

    await database.customStatement(
      'DELETE FROM meetings WHERE id = ?',
      <Object>['meeting-1'],
    );
    final remaining = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM audio_segments',
        )
        .getSingle();
    expect(remaining.read<int>('count'), 0);
  });

  test('query indexes cover owner plus timeline access patterns', () async {
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        )
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>{
        'idx_meetings_created',
        'ux_audio_segments_meeting_sequence',
        'ux_session_events_meeting_sequence',
        'idx_bookmarks_meeting_media',
        'idx_transcript_runs_meeting_created',
        'idx_transcript_segments_run_start',
        'idx_diarization_runs_meeting_created',
        'idx_speaker_assignments_run_start',
        'idx_revisions_meeting_created',
        'idx_processing_jobs_meeting_created',
        'idx_export_records_meeting_created',
      }),
    );
  });

  test('query planner uses owner plus timeline indexes', () async {
    final meetingPlan = await database.customSelect(
      '''
      EXPLAIN QUERY PLAN
      SELECT * FROM meetings
      WHERE is_deleted = 0
      ORDER BY created_at DESC, id DESC
      LIMIT 50
      ''',
    ).get();
    final transcriptPlan = await database
        .customSelect(
          '''
      EXPLAIN QUERY PLAN
      SELECT * FROM transcript_segments
      WHERE transcript_run_id = ?
      ORDER BY start_us
      ''',
          variables: <Variable<Object>>[const Variable<String>('run-1')],
        )
        .get();

    expect(
      meetingPlan.map((row) => row.read<String>('detail')).join(' '),
      contains('idx_meetings_created'),
    );
    expect(
      transcriptPlan.map((row) => row.read<String>('detail')).join(' '),
      contains('idx_transcript_segments_run_start'),
    );
  });

  test('meeting and initial event are one atomic transaction', () async {
    final writes = SessionWriteTransactions(database);

    await expectLater(
      writes.createMeetingWithInitialEvent(
        MeetingsCompanion.insert(
          id: 'meeting-atomic',
          createdAt: 1,
          updatedAt: 1,
          title: 'Atomic',
          lifecycle: 'draft',
          languageMode: 'mixed',
        ),
        SessionEventsCompanion.insert(
          id: 'event-invalid',
          createdAt: 1,
          updatedAt: 1,
          meetingId: 'meeting-atomic',
          sequence: 0,
          type: 'not-a-real-event',
          wallClockUtcMs: 1,
          monotonicElapsedUs: 0,
          mediaOffsetUs: 0,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );

    final remaining = await database
        .customSelect(
          "SELECT COUNT(*) AS count FROM meetings WHERE id = 'meeting-atomic'",
        )
        .getSingle();
    expect(remaining.read<int>('count'), 0);
  });
}

Future<void> _insertMeeting(AppDatabase database, String id) =>
    database.customStatement(
      '''
      INSERT INTO meetings (
        id, created_at, updated_at, title, media_duration_us,
        lifecycle, language_mode
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object>[id, 1, 1, 'Meeting', 0, 'draft', 'mixed'],
    );
