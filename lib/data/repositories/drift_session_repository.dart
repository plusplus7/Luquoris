import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart'
    as domain;
import 'package:loquiris/services/service_contracts.dart';

/// Drift-backed single write path for meeting lifecycle and library data.
final class DriftSessionRepository implements SessionRepository {
  /// Creates a repository over the injected local [database].
  const DriftSessionRepository(
    this.database, {
    required this.audioStore,
    required this.diagnosticSink,
  });

  /// Local database owned by the application composition root.
  final db.AppDatabase database;

  /// Private-file deletion boundary coordinated before metadata deletion.
  final MeetingAudioStore audioStore;

  /// Privacy-safe local diagnostic destination for expected store failures.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<SessionCollection, SessionRepositoryFailure>> list() async {
    final meetings = <domain.Meeting>[];
    SessionLibraryCursor? cursor;
    do {
      final result = await queryLibrary(
        SessionLibraryQuery(
          kind: SessionLibraryKind.active,
          limit: 100,
          before: cursor,
        ),
      );
      switch (result) {
        case Ok(:final value):
          meetings.addAll(value.meetings);
          cursor = value.nextCursor;
        case Err(:final failure):
          return Err(failure);
      }
    } while (cursor != null);

    return Ok(
      SessionCollection(
        sessions: meetings
            .map(
              (meeting) => SessionSummary(
                id: meeting.id,
                title: meeting.title,
                isRecoverable:
                    meeting.lifecycle == domain.MeetingLifecycle.recoverable,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Future<Result<SessionSummary, SessionRepositoryFailure>> save(
    SessionSummary session,
  ) async {
    try {
      await database.transaction(() async {
        final existingRow = await (database.select(
          database.meetings,
        )..where((row) => row.id.equals(session.id))).getSingleOrNull();
        if (existingRow?.lifecycle == domain.MeetingLifecycle.deleting.name) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        final existing = existingRow == null
            ? null
            : _readStoredMeeting(existingRow);
        final meeting = existing == null
            ? domain.Meeting(
                id: session.id,
                title: session.title,
                createdAtUtcMs: 0,
                mediaDuration: Duration.zero,
                lifecycle: session.isRecoverable
                    ? domain.MeetingLifecycle.recoverable
                    : domain.MeetingLifecycle.draft,
                languageMode: domain.MeetingLanguageMode.mixed,
              )
            : existing.copyWith(
                title: session.title,
                lifecycle: session.isRecoverable
                    ? domain.MeetingLifecycle.recoverable
                    : existing.lifecycle,
              );
        await _writeMeeting(meeting, existingRow);
      });
      return Ok(session);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_repository_unavailable', error, stackTrace),
      );
    }
  }

  @override
  Stream<Result<SessionLibraryPage, SessionRepositoryFailure>> watchLibrary(
    SessionLibraryQuery query,
  ) async* {
    final statement = _libraryStatement(query);
    try {
      await for (final rows
          in database
              .customSelect(
                statement.sql,
                variables: statement.variables,
                readsFrom: {
                  database.meetings,
                  database.meetingTranscriptSelections,
                  database.transcriptRuns,
                },
              )
              .watch()) {
        yield Ok(_page(rows, query.limit));
      }
    } on SqliteException catch (error, stackTrace) {
      yield Err(
        _storeFailure('session_library_watch_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<SessionLibraryPage, SessionRepositoryFailure>> queryLibrary(
    SessionLibraryQuery query,
  ) async {
    final statement = _libraryStatement(query);
    try {
      final rows = await database
          .customSelect(statement.sql, variables: statement.variables)
          .get();
      return Ok(_page(rows, query.limit));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_library_query_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>> saveMeeting(
    domain.Meeting meeting,
  ) async {
    try {
      await database.transaction(() async {
        final existing = await (database.select(
          database.meetings,
        )..where((row) => row.id.equals(meeting.id))).getSingleOrNull();
        if (existing?.lifecycle == domain.MeetingLifecycle.deleting.name) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        await _writeMeeting(meeting, existing);
      });
      return Ok(meeting);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('session_save_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<List<SessionSearchHit>, SessionRepositoryFailure>> search(
    String query,
  ) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const Ok(<SessionSearchHit>[]);
    try {
      final rows = await database
          .customSelect(
            _searchSql,
            variables: <Variable<Object>>[
              Variable<String>(normalized),
              Variable<String>(normalized),
            ],
          )
          .get();
      return Ok(
        rows
            .map(
              (row) => SessionSearchHit(
                meeting: _readMeeting(row),
                transcriptSegmentId: row.readNullable<String>('segment_id'),
                mediaOffset: switch (row.readNullable<int>('media_offset_us')) {
                  final offset? => Duration(microseconds: offset),
                  null => null,
                },
              ),
            )
            .toList(growable: false),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('session_search_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>> moveToTrash(
    String meetingId, {
    required int atUtcMs,
  }) => _mutateMeeting(meetingId, (meeting) {
    if (meeting.lifecycle == domain.MeetingLifecycle.trashed) return meeting;
    if (meeting.lifecycle == domain.MeetingLifecycle.deleting) {
      throw const _RepositoryStateError('session_invalid_lifecycle');
    }
    return meeting.copyWith(
      lifecycle: domain.MeetingLifecycle.trashed,
      lifecycleBeforeTrash: meeting.lifecycle,
      trashedAtUtcMs: atUtcMs,
    );
  }, updatedAtUtcMs: atUtcMs);

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>> restoreFromTrash(
    String meetingId, {
    required int atUtcMs,
  }) => _mutateMeeting(meetingId, (meeting) {
    if (meeting.lifecycle != domain.MeetingLifecycle.trashed ||
        meeting.lifecycleBeforeTrash == null) {
      throw const _RepositoryStateError('session_invalid_lifecycle');
    }
    return meeting.copyWith(
      lifecycle: meeting.lifecycleBeforeTrash,
      lifecycleBeforeTrash: null,
      trashedAtUtcMs: null,
    );
  }, updatedAtUtcMs: atUtcMs);

  @override
  Future<Result<void, SessionRepositoryFailure>> permanentlyDelete(
    String meetingId,
  ) async {
    late List<AppRelativePath> audioPaths;
    try {
      await database.transaction(() async {
        final meeting = await _findMeeting(meetingId);
        if (meeting == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        if (meeting.lifecycle == domain.MeetingLifecycle.trashed) {
          await database.customStatement(
            '''
            UPDATE meetings
            SET lifecycle = 'deleting', row_revision = row_revision + 1
            WHERE id = ?
            ''',
            <Object>[meetingId],
          );
        } else if (meeting.lifecycle != domain.MeetingLifecycle.deleting) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        audioPaths = await _audioPathsForMeeting(meetingId);
      });
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('session_delete_failed', error, stackTrace));
    }

    final audioDeletion = await audioStore.deleteAuthoritativeAudio(audioPaths);
    switch (audioDeletion) {
      case Err(:final failure):
        diagnosticSink.record(
          DiagnosticEvent(
            code: DiagnosticCode.sessionRepositoryOperationFailed,
            errorType: failure.sourceErrorType,
            stackFingerprint: failure.stackFingerprint,
          ),
        );
        return const Err(
          SessionRepositoryUnavailable('session_audio_delete_failed'),
        );
      case Ok():
        break;
    }

    try {
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        if (current.lifecycle != domain.MeetingLifecycle.deleting) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        await (database.delete(
          database.meetings,
        )..where((row) => row.id.equals(meetingId))).go();
      });
      return const Ok<void, SessionRepositoryFailure>(null);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('session_delete_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
  accountStorage() async {
    try {
      final row = await database.customSelect(_storageSql).getSingle();
      return Ok(
        SessionStorageAccounting(
          activeMeetingBytes: row.read<int>('active_bytes'),
          trashBytes: row.read<int>('trash_bytes'),
        ),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_storage_query_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
  }) async {
    try {
      final marked = <String>[];
      final unchanged = <String>[];
      await database.transaction(() async {
        for (final item in evidence) {
          final meeting = await _findMeeting(item.meetingId);
          if (meeting == null ||
              !item.hasCommittedAudio ||
              !_needsRecovery(meeting.lifecycle)) {
            unchanged.add(item.meetingId);
            continue;
          }
          final eventPosition = await database
              .customSelect(
                '''
            SELECT COALESCE(MAX(sequence), -1) + 1 AS next_sequence,
                   COALESCE(MAX(monotonic_elapsed_us), 0) AS monotonic_us,
                   COALESCE(MAX(media_offset_us), 0) AS media_us
            FROM session_events WHERE meeting_id = ?
            ''',
                variables: <Variable<Object>>[Variable<String>(item.meetingId)],
              )
              .getSingle();
          await database.customStatement(
            '''
            UPDATE meetings
            SET lifecycle = 'recoverable', updated_at = ?,
                row_revision = row_revision + 1
            WHERE id = ?
            ''',
            <Object>[observedAtUtcMs, item.meetingId],
          );
          await database
              .into(database.sessionEvents)
              .insert(
                db.SessionEventsCompanion.insert(
                  id: 'recovery-${item.meetingId}-$observedAtUtcMs',
                  createdAt: observedAtUtcMs,
                  updatedAt: observedAtUtcMs,
                  meetingId: item.meetingId,
                  sequence: eventPosition.read<int>('next_sequence'),
                  type: 'recovered',
                  wallClockUtcMs: observedAtUtcMs,
                  monotonicElapsedUs: eventPosition.read<int>('monotonic_us'),
                  mediaOffsetUs: eventPosition.read<int>('media_us'),
                ),
              );
          marked.add(item.meetingId);
        }
      });
      return Ok(
        SessionRecoveryReport(
          markedRecoverableIds: marked,
          unchangedIds: unchanged,
        ),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_reconciliation_failed', error, stackTrace),
      );
    }
  }

  Future<Result<domain.Meeting, SessionRepositoryFailure>> _mutateMeeting(
    String meetingId,
    domain.Meeting Function(domain.Meeting meeting) transform, {
    required int updatedAtUtcMs,
  }) async {
    try {
      late domain.Meeting updated;
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        updated = transform(current);
        await (database.update(
          database.meetings,
        )..where((row) => row.id.equals(meetingId))).write(
          db.MeetingsCompanion(
            updatedAt: Value(updatedAtUtcMs),
            isDeleted: Value(
              updated.lifecycle == domain.MeetingLifecycle.trashed ||
                  updated.lifecycle == domain.MeetingLifecycle.deleting,
            ),
            deletedAt: Value(updated.trashedAtUtcMs),
            title: Value(updated.title),
            mediaDurationUs: Value(updated.mediaDuration.inMicroseconds),
            lifecycle: Value(updated.lifecycle.name),
            languageMode: Value(updated.languageMode.name),
            trashedAtUtcMs: Value(updated.trashedAtUtcMs),
            lifecycleBeforeTrash: Value(updated.lifecycleBeforeTrash?.name),
          ),
        );
        await database.customStatement(
          'UPDATE meetings SET row_revision = row_revision + 1 WHERE id = ?',
          <Object>[meetingId],
        );
      });
      return Ok(updated);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_lifecycle_update_failed', error, stackTrace),
      );
    }
  }

  Future<void> _writeMeeting(
    domain.Meeting meeting,
    db.Meeting? existing,
  ) async {
    final updatedAt = existing?.updatedAt ?? meeting.createdAtUtcMs;
    final rowRevision = (existing?.rowRevision ?? -1) + 1;
    await database
        .into(database.meetings)
        .insertOnConflictUpdate(
          db.MeetingsCompanion.insert(
            id: meeting.id,
            createdAt: meeting.createdAtUtcMs,
            updatedAt: updatedAt,
            rowRevision: Value(rowRevision),
            isDeleted: Value(
              meeting.lifecycle == domain.MeetingLifecycle.trashed ||
                  meeting.lifecycle == domain.MeetingLifecycle.deleting,
            ),
            deletedAt: Value(meeting.trashedAtUtcMs),
            title: meeting.title,
            mediaDurationUs: Value(meeting.mediaDuration.inMicroseconds),
            lifecycle: meeting.lifecycle.name,
            languageMode: meeting.languageMode.name,
            trashedAtUtcMs: Value(meeting.trashedAtUtcMs),
            lifecycleBeforeTrash: Value(meeting.lifecycleBeforeTrash?.name),
          ),
        );
  }

  Future<domain.Meeting?> _findMeeting(String meetingId) async {
    final rows = await database
        .customSelect(
          '$_meetingSelect WHERE m.id = ?',
          variables: <Variable<Object>>[Variable<String>(meetingId)],
        )
        .get();
    return rows.isEmpty ? null : _readMeeting(rows.single);
  }

  Future<List<AppRelativePath>> _audioPathsForMeeting(String meetingId) async {
    final rows = await database
        .customSelect(
          '''
      SELECT relative_path FROM audio_segments
      WHERE meeting_id = ?
      ORDER BY sequence
      ''',
          variables: <Variable<Object>>[Variable<String>(meetingId)],
        )
        .get();
    return rows
        .map((row) {
          final candidate = row.read<String>('relative_path');
          return switch (AppRelativePath.tryParse(candidate)) {
            Ok(:final value) => value,
            Err() => throw StateError('database path invariant violated'),
          };
        })
        .toList(growable: false);
  }

  SessionStoreUnavailable _storeFailure(
    String code,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.sessionRepositoryOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
    return SessionRepositoryUnavailable(code);
  }
}

final class _LibraryStatement {
  const _LibraryStatement(this.sql, this.variables);

  final String sql;
  final List<Variable<Object>> variables;
}

_LibraryStatement _libraryStatement(SessionLibraryQuery query) {
  final variables = <Variable<Object>>[];
  final where = <String>[
    switch (query.kind) {
      SessionLibraryKind.active => 'm.is_deleted = 0',
      SessionLibraryKind.trash => 'm.is_deleted = 1',
    },
  ];
  final cursor = query.before;
  if (cursor != null) {
    where.add('(m.created_at < ? OR (m.created_at = ? AND m.id < ?))');
    variables
      ..add(Variable<int>(cursor.createdAtUtcMs))
      ..add(Variable<int>(cursor.createdAtUtcMs))
      ..add(Variable<String>(cursor.id));
  }
  variables.add(Variable<int>(query.limit + 1));
  return _LibraryStatement(
    '$_meetingSelect WHERE ${where.join(' AND ')} '
    'ORDER BY m.created_at DESC, m.id DESC LIMIT ?',
    variables,
  );
}

SessionLibraryPage _page(List<QueryRow> rows, int limit) {
  final hasMore = rows.length > limit;
  final pageRows = hasMore ? rows.take(limit).toList() : rows;
  final meetings = pageRows.map(_readMeeting).toList(growable: false);
  final last = meetings.isEmpty ? null : meetings.last;
  return SessionLibraryPage(
    meetings: meetings,
    nextCursor: hasMore && last != null
        ? SessionLibraryCursor(createdAtUtcMs: last.createdAtUtcMs, id: last.id)
        : null,
  );
}

domain.Meeting _readMeeting(QueryRow row) => domain.Meeting(
  id: row.read<String>('id'),
  title: row.read<String>('title'),
  createdAtUtcMs: row.read<int>('created_at'),
  mediaDuration: Duration(microseconds: row.read<int>('media_duration_us')),
  lifecycle: domain.MeetingLifecycle.values.byName(
    row.read<String>('lifecycle'),
  ),
  languageMode: domain.MeetingLanguageMode.values.byName(
    row.read<String>('language_mode'),
  ),
  currentTranscriptRunId: row.readNullable<String>('current_transcript_run_id'),
  lifecycleBeforeTrash: switch (row.readNullable<String>(
    'lifecycle_before_trash',
  )) {
    final lifecycle? => domain.MeetingLifecycle.values.byName(lifecycle),
    null => null,
  },
  trashedAtUtcMs: row.readNullable<int>('trashed_at_utc_ms'),
);

domain.Meeting _readStoredMeeting(db.Meeting row) => domain.Meeting(
  id: row.id,
  title: row.title,
  createdAtUtcMs: row.createdAt,
  mediaDuration: Duration(microseconds: row.mediaDurationUs),
  lifecycle: domain.MeetingLifecycle.values.byName(row.lifecycle),
  languageMode: domain.MeetingLanguageMode.values.byName(row.languageMode),
  lifecycleBeforeTrash: switch (row.lifecycleBeforeTrash) {
    final lifecycle? => domain.MeetingLifecycle.values.byName(lifecycle),
    null => null,
  },
  trashedAtUtcMs: row.trashedAtUtcMs,
);

bool _needsRecovery(domain.MeetingLifecycle lifecycle) => switch (lifecycle) {
  domain.MeetingLifecycle.draft ||
  domain.MeetingLifecycle.preparing ||
  domain.MeetingLifecycle.recording ||
  domain.MeetingLifecycle.pausedByUser ||
  domain.MeetingLifecycle.pausedByInterruption ||
  domain.MeetingLifecycle.stopping ||
  domain.MeetingLifecycle.failedFinalization => true,
  domain.MeetingLifecycle.finalized ||
  domain.MeetingLifecycle.recoverable ||
  domain.MeetingLifecycle.trashed ||
  domain.MeetingLifecycle.deleting => false,
};

const String _meetingSelect = '''
SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
       m.language_mode, m.trashed_at_utc_ms, m.lifecycle_before_trash,
       tr.id AS current_transcript_run_id
FROM meetings AS m
LEFT JOIN meeting_transcript_selections AS mts
  ON mts.meeting_id = m.id AND mts.is_deleted = 0
LEFT JOIN transcript_runs AS tr
  ON tr.id = mts.transcript_run_id AND tr.is_deleted = 0
''';

const String _searchSql = '''
WITH hits AS (
  SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
         m.language_mode, m.trashed_at_utc_ms, m.lifecycle_before_trash,
         tr.id AS current_transcript_run_id,
         NULL AS segment_id, NULL AS media_offset_us, 0 AS match_kind
  FROM meetings AS m
  LEFT JOIN meeting_transcript_selections AS mts
    ON mts.meeting_id = m.id AND mts.is_deleted = 0
  LEFT JOIN transcript_runs AS tr
    ON tr.id = mts.transcript_run_id AND tr.is_deleted = 0
  WHERE m.is_deleted = 0 AND instr(lower(m.title), lower(?)) > 0
  UNION ALL
  SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
         m.language_mode, m.trashed_at_utc_ms, m.lifecycle_before_trash,
         tr.id AS current_transcript_run_id,
         ts.id AS segment_id, ts.start_us AS media_offset_us, 1 AS match_kind
  FROM meetings AS m
  JOIN meeting_transcript_selections AS mts
    ON mts.meeting_id = m.id AND mts.is_deleted = 0
  JOIN transcript_runs AS tr
    ON tr.id = mts.transcript_run_id AND tr.is_deleted = 0
  JOIN transcript_segments AS ts
    ON ts.transcript_run_id = tr.id AND ts.is_deleted = 0
  WHERE m.is_deleted = 0 AND instr(lower(ts.displayed_text), lower(?)) > 0
)
SELECT * FROM hits
ORDER BY created_at DESC, id DESC, match_kind, media_offset_us
LIMIT 200
''';

const String _storageSql = '''
SELECT COALESCE(SUM(CASE WHEN m.is_deleted = 0 THEN a.committed_bytes ELSE 0 END), 0)
         AS active_bytes,
       COALESCE(SUM(CASE WHEN m.is_deleted = 1 THEN a.committed_bytes ELSE 0 END), 0)
         AS trash_bytes
FROM audio_segments AS a
JOIN meetings AS m ON m.id = a.meeting_id
WHERE a.is_deleted = 0
''';

final class _RepositoryStateError implements Exception {
  const _RepositoryStateError(this.code);

  final String code;
}

SessionRepositoryFailure _stateFailure(_RepositoryStateError error) =>
    switch (error.code) {
      'session_not_found' => const SessionNotFound(),
      'session_invalid_lifecycle' => const SessionInvalidLifecycle(),
      _ => throw StateError('unknown repository state failure'),
    };
