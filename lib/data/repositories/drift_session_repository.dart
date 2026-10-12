import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart'
    as processing;
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
  Future<Result<SessionDetail, SessionRepositoryFailure>> loadDetail(
    String meetingId,
  ) async {
    try {
      final detail = await database.transaction(() async {
        final meeting = await _findMeeting(meetingId);
        if (meeting == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        final segments =
            await (database.select(database.audioSegments)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
                .get();
        final events =
            await (database.select(database.sessionEvents)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
                .get();
        final bookmarks =
            await (database.select(database.bookmarks)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.mediaOffsetUs),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        final jobs =
            await (database.select(database.processingJobs)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([
                    (row) => OrderingTerm.desc(row.createdAt),
                    (row) => OrderingTerm.desc(row.id),
                  ]))
                .get();
        final findings =
            await (database.select(database.recoveryFindings)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.segmentSequence),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return SessionDetail(
          meeting: meeting,
          segments: segments
              .map(
                (row) => domain.AudioSegment(
                  id: row.id,
                  meetingId: row.meetingId,
                  sequence: row.sequence,
                  relativePath: switch (AppRelativePath.tryParse(
                    row.relativePath,
                  )) {
                    Ok(:final value) => value,
                    Err() => throw StateError(
                      'database path invariant violated',
                    ),
                  },
                  mediaStart: Duration(microseconds: row.mediaStartUs),
                  mediaDuration: Duration(microseconds: row.mediaDurationUs),
                  committedBytes: row.committedBytes,
                  state: domain.AudioSegmentState.values.byName(row.state),
                ),
              )
              .toList(),
          events: events
              .map(
                (row) => domain.SessionEvent(
                  id: row.id,
                  meetingId: row.meetingId,
                  sequence: row.sequence,
                  type: domain.SessionEventType.values.byName(row.type),
                  wallClockUtcMs: row.wallClockUtcMs,
                  monotonicElapsed: Duration(
                    microseconds: row.monotonicElapsedUs,
                  ),
                  mediaOffset: Duration(microseconds: row.mediaOffsetUs),
                ),
              )
              .toList(),
          bookmarks: bookmarks
              .map(
                (row) => domain.Bookmark(
                  id: row.id,
                  meetingId: row.meetingId,
                  mediaOffset: Duration(microseconds: row.mediaOffsetUs),
                  kind: domain.BookmarkKind.values.byName(row.kind),
                  createdAtUtcMs: row.createdAt,
                ),
              )
              .toList(),
          processingJobs: jobs.map(_readProcessingJob).toList(),
          recoveryDiagnostics: findings
              .map(
                (row) => SessionRecoveryDiagnostic(
                  code: row.code,
                  segmentSequence: row.segmentSequence,
                ),
              )
              .toList(),
        );
      });
      return Ok(detail);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_detail_load_failed', error, stackTrace),
      );
    }
  }

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
                  database.audioSegments,
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
  Future<Result<domain.Bookmark, SessionRepositoryFailure>> saveBookmark(
    domain.Bookmark bookmark,
  ) async {
    try {
      return database.transaction(() async {
        final meeting = await _findMeeting(bookmark.meetingId);
        if (meeting == null) return const Err(SessionNotFound());
        if (meeting.lifecycle == domain.MeetingLifecycle.trashed ||
            meeting.lifecycle == domain.MeetingLifecycle.deleting) {
          return const Err(SessionInvalidLifecycle());
        }
        await database
            .into(database.bookmarks)
            .insert(
              db.BookmarksCompanion.insert(
                id: bookmark.id,
                createdAt: bookmark.createdAtUtcMs,
                updatedAt: bookmark.createdAtUtcMs,
                meetingId: bookmark.meetingId,
                mediaOffsetUs: bookmark.mediaOffset.inMicroseconds,
                kind: bookmark.kind.name,
              ),
            );
        return Ok(bookmark);
      });
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('bookmark_save_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  loadRecordingDefaults() async {
    try {
      final row =
          await (database.select(database.recordingPreferences)
                ..where((entry) => entry.id.equals('recording-defaults')))
              .getSingleOrNull();
      if (row == null) return const Ok(RecordingDefaults());
      return Ok(
        RecordingDefaults(
          transcriptionMode: domain.MeetingTranscriptionMode.values.byName(
            row.transcriptionMode,
          ),
          languageMode: domain.MeetingLanguageMode.values.byName(
            row.languageMode,
          ),
          expectedSpeakerCount: row.expectedSpeakerCount,
        ),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('recording_defaults_load_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  saveRecordingDefaults(
    RecordingDefaults defaults, {
    required int atUtcMs,
  }) async {
    try {
      final existing =
          await (database.select(database.recordingPreferences)
                ..where((entry) => entry.id.equals('recording-defaults')))
              .getSingleOrNull();
      await database
          .into(database.recordingPreferences)
          .insertOnConflictUpdate(
            db.RecordingPreferencesCompanion.insert(
              id: 'recording-defaults',
              createdAt: existing?.createdAt ?? atUtcMs,
              updatedAt: atUtcMs,
              rowRevision: Value((existing?.rowRevision ?? -1) + 1),
              transcriptionMode: defaults.transcriptionMode.name,
              languageMode: defaults.languageMode.name,
              expectedSpeakerCount: Value(defaults.expectedSpeakerCount),
            ),
          );
      return Ok(defaults);
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('recording_defaults_save_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>>
  synchronizeRecordingProgress(
    String meetingId, {
    required domain.MeetingLifecycle lifecycle,
    required Duration mediaDuration,
    required int atUtcMs,
  }) async {
    if (!_isNativeRecordingLifecycle(lifecycle)) {
      return const Err(SessionInvalidLifecycle());
    }
    try {
      late domain.Meeting updated;
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        if (current.lifecycle == domain.MeetingLifecycle.trashed ||
            current.lifecycle == domain.MeetingLifecycle.deleting) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        final monotonicDuration = mediaDuration > current.mediaDuration
            ? mediaDuration
            : current.mediaDuration;
        await database.customStatement(
          '''
          UPDATE meetings
          SET lifecycle = ?, media_duration_us = ?, updated_at = ?,
              row_revision = row_revision + 1
          WHERE id = ?
          ''',
          <Object>[
            lifecycle.name,
            monotonicDuration.inMicroseconds,
            atUtcMs,
            meetingId,
          ],
        );
        updated = (await _findMeeting(meetingId))!;
      });
      return Ok(updated);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('recording_progress_sync_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<void, SessionRepositoryFailure>> discardUnstartedMeeting(
    String meetingId,
  ) async {
    try {
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) return;
        if (current.lifecycle != domain.MeetingLifecycle.draft &&
            current.lifecycle != domain.MeetingLifecycle.preparing) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        final audioCount = await database
            .customSelect(
              'SELECT COUNT(*) AS count FROM audio_segments '
              'WHERE meeting_id = ?',
              variables: <Variable<Object>>[Variable<String>(meetingId)],
            )
            .getSingle();
        if (audioCount.read<int>('count') != 0) {
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
      return Err(
        _storeFailure('unstarted_meeting_cleanup_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>> renameMeeting(
    String meetingId,
    String title, {
    required int atUtcMs,
  }) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return const Err(SessionRepositoryUnavailable('session_title_invalid'));
    }
    try {
      late domain.Meeting renamed;
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        if (current.lifecycle == domain.MeetingLifecycle.deleting) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        await database.customStatement(
          '''
          UPDATE meetings
          SET title = ?, updated_at = ?, row_revision = row_revision + 1
          WHERE id = ?
          ''',
          <Object>[normalized, atUtcMs, meetingId],
        );
        renamed = (await _findMeeting(meetingId))!;
      });
      return Ok(renamed);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('session_rename_failed', error, stackTrace));
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
                committedAudioBytes: row.read<int>('committed_audio_bytes'),
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
    if (switch (meeting.lifecycle) {
      domain.MeetingLifecycle.preparing ||
      domain.MeetingLifecycle.recording ||
      domain.MeetingLifecycle.pausedByUser ||
      domain.MeetingLifecycle.pausedByInterruption ||
      domain.MeetingLifecycle.stopping ||
      domain.MeetingLifecycle.deleting => true,
      domain.MeetingLifecycle.draft ||
      domain.MeetingLifecycle.finalized ||
      domain.MeetingLifecycle.recoverable ||
      domain.MeetingLifecycle.failedFinalization ||
      domain.MeetingLifecycle.trashed => false,
    }) {
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
  Future<Result<SessionRecoveryDetails, SessionRepositoryFailure>>
  recoveryDetails(String meetingId) async {
    try {
      if (await _findMeeting(meetingId) == null) {
        return const Err(SessionNotFound());
      }
      final findingRows = await database
          .customSelect(
            '''
        SELECT code, segment_sequence
        FROM recovery_findings
        WHERE meeting_id = ? AND is_deleted = 0
        ORDER BY segment_sequence IS NULL, segment_sequence, id
        ''',
            variables: <Variable<Object>>[Variable<String>(meetingId)],
          )
          .get();
      final audioRows = await database
          .customSelect(
            '''
        SELECT sequence, relative_path, committed_bytes, state
        FROM audio_segments
        WHERE meeting_id = ? AND is_deleted = 0
        ORDER BY sequence
        ''',
            variables: <Variable<Object>>[Variable<String>(meetingId)],
          )
          .get();
      final rawExportSegments = <SessionRecoveryRawExportSegment>[];
      var hasDamagedSegment = false;
      for (final row in audioRows) {
        final state = domain.AudioSegmentState.values.byName(
          row.read<String>('state'),
        );
        if (state == domain.AudioSegmentState.corrupt ||
            state == domain.AudioSegmentState.missing) {
          hasDamagedSegment = true;
        }
        if (state != domain.AudioSegmentState.committed) {
          continue;
        }
        final committedBytes = row.read<int>('committed_bytes');
        if (committedBytes == 0) continue;
        final path = switch (AppRelativePath.tryParse(
          row.read<String>('relative_path'),
        )) {
          Ok(:final value) => value,
          Err() => throw const _RecoveryDetailsInvariantError(),
        };
        rawExportSegments.add(
          SessionRecoveryRawExportSegment(
            sequence: row.read<int>('sequence'),
            relativePath: path,
            committedBytes: committedBytes,
          ),
        );
      }
      final diagnostics = findingRows
          .map(
            (row) => SessionRecoveryDiagnostic(
              code: row.read<String>('code'),
              segmentSequence: row.readNullable<int>('segment_sequence'),
            ),
          )
          .toList(growable: false);
      return Ok(
        SessionRecoveryDetails(
          integrityState: diagnostics.isNotEmpty || hasDamagedSegment
              ? RecoveryIntegrityState.partial
              : RecoveryIntegrityState.complete,
          diagnostics: diagnostics,
          rawExportSegments: rawExportSegments,
        ),
      );
    } on _RecoveryDetailsInvariantError catch (error, stackTrace) {
      return Err(
        _storeFailure('session_recovery_details_invalid', error, stackTrace),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_recovery_details_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<domain.Meeting, SessionRepositoryFailure>> resolveRecovery(
    String meetingId,
    RecoveryResolution resolution, {
    required int atUtcMs,
  }) async {
    try {
      late domain.Meeting resolved;
      await database.transaction(() async {
        final current = await _findMeeting(meetingId);
        if (current == null) {
          throw const _RepositoryStateError('session_not_found');
        }
        final target = switch (resolution) {
          RecoveryResolution.save => domain.MeetingLifecycle.finalized,
          RecoveryResolution.continueRecording =>
            domain.MeetingLifecycle.recording,
        };
        if (current.lifecycle == target) {
          resolved = current;
          return;
        }
        if (current.lifecycle != domain.MeetingLifecycle.recoverable) {
          throw const _RepositoryStateError('session_invalid_lifecycle');
        }
        await database.customStatement(
          '''
          UPDATE meetings
          SET lifecycle = ?, updated_at = ?, row_revision = row_revision + 1
          WHERE id = ?
          ''',
          <Object>[target.name, atUtcMs, meetingId],
        );
        resolved = (await _findMeeting(meetingId))!;
      });
      return Ok(resolved);
    } on _RepositoryStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_recovery_resolution_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
    Set<String> liveMeetingIds = const <String>{},
    Set<String> invalidStorageKeys = const <String>{},
  }) async {
    try {
      final marked = <String>[];
      final created = <String>[];
      final unchanged = <String>[];
      final partial = <String>[];
      var reconciledSegmentCount = 0;
      await database.transaction(() async {
        await database.customStatement(
          '''
          UPDATE processing_jobs
          SET job_state = 'queued', progress = NULL, reason_code = NULL,
              failure_code = NULL, updated_at = ?,
              row_revision = row_revision + 1
          WHERE job_kind IN ('audioMerge', 'waveform')
            AND job_state = 'running'
          ''',
          <Object>[observedAtUtcMs],
        );

        for (final item in evidence) {
          if (liveMeetingIds.contains(item.meetingId)) {
            unchanged.add(item.meetingId);
            continue;
          }
          if (item.isPartial) partial.add(item.meetingId);
          var meeting = await _findMeeting(item.meetingId);
          if (meeting == null && !item.hasCommittedAudio) {
            unchanged.add(item.meetingId);
            continue;
          }
          if (meeting == null) {
            await database.customStatement(
              '''
              INSERT INTO meetings (
                id, created_at, updated_at, is_deleted, row_revision,
                title, media_duration_us, lifecycle, language_mode
              ) VALUES (?, ?, ?, 0, 0, 'Recovered recording', 0,
                        'recoverable', 'mixed')
              ''',
              <Object>[item.meetingId, observedAtUtcMs, observedAtUtcMs],
            );
            meeting = await _findMeeting(item.meetingId);
            created.add(item.meetingId);
          }

          await _reconcileManifestSegments(item, observedAtUtcMs);
          await _replaceRecoveryFindings(
            item.meetingId,
            item.diagnostics,
            observedAtUtcMs,
          );
          reconciledSegmentCount += item.segments.length;
          final mediaDurationUs = item.segments.fold<int>(
            0,
            (maximum, segment) => math.max(
              maximum,
              segment.mediaStart.inMicroseconds +
                  segment.mediaDuration.inMicroseconds,
            ),
          );
          await database.customUpdate(
            '''
            UPDATE meetings
            SET media_duration_us = ?, updated_at = ?,
                row_revision = row_revision + 1
            WHERE id = ? AND media_duration_us != ?
            ''',
            variables: <Variable<Object>>[
              Variable<int>(mediaDurationUs),
              Variable<int>(observedAtUtcMs),
              Variable<String>(item.meetingId),
              Variable<int>(mediaDurationUs),
            ],
            updates: <TableInfo<Table, Object?>>{database.meetings},
          );

          if (created.contains(item.meetingId)) {
            await _insertRecoveryEvent(item.meetingId, observedAtUtcMs);
            continue;
          }
          final hasDamagedSegment =
              item.segments.any(
                (segment) =>
                    segment.state != domain.AudioSegmentState.committed,
              ) ||
              item.isPartial;
          final shouldRecover =
              _needsRecovery(meeting!.lifecycle) ||
              (meeting.lifecycle == domain.MeetingLifecycle.finalized &&
                  hasDamagedSegment);
          if (!shouldRecover) {
            unchanged.add(item.meetingId);
            continue;
          }
          if (await _markRecoverable(
            item.meetingId,
            meeting.lifecycle,
            observedAtUtcMs,
          )) {
            marked.add(item.meetingId);
          } else {
            unchanged.add(item.meetingId);
          }
        }

        await _reconcileUnobservedDatabaseMeetings(
          observedMeetingIds: evidence.map((item) => item.meetingId).toSet(),
          liveMeetingIds: liveMeetingIds,
          invalidStorageKeys: invalidStorageKeys,
          observedAtUtcMs: observedAtUtcMs,
          markedRecoverableIds: marked,
        );
      });
      return Ok(
        SessionRecoveryReport(
          markedRecoverableIds: marked,
          createdRecoverableIds: created,
          unchangedIds: unchanged,
          partialMeetingIds: partial,
          reconciledSegmentCount: reconciledSegmentCount,
        ),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('session_reconciliation_failed', error, stackTrace),
      );
    }
  }

  Future<void> _reconcileManifestSegments(
    SessionRecoveryEvidence item,
    int observedAtUtcMs,
  ) async {
    final sequences = item.segments.map((segment) => segment.sequence).toList();
    if (sequences.isEmpty) {
      await database.customStatement(
        'DELETE FROM audio_segments WHERE meeting_id = ?',
        <Object>[item.meetingId],
      );
    } else {
      await database.customStatement(
        'DELETE FROM audio_segments WHERE meeting_id = ? AND sequence NOT IN '
        '(${List.filled(sequences.length, '?').join(',')})',
        <Object>[item.meetingId, ...sequences],
      );
    }
    for (final segment in item.segments) {
      await database.customStatement(
        '''
        INSERT INTO audio_segments (
          id, created_at, updated_at, is_deleted, row_revision,
          meeting_id, sequence, relative_path, media_start_us,
          media_duration_us, committed_bytes, state
        ) VALUES (?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(meeting_id, sequence) DO UPDATE SET
          relative_path = excluded.relative_path,
          media_start_us = excluded.media_start_us,
          media_duration_us = excluded.media_duration_us,
          committed_bytes = excluded.committed_bytes,
          state = excluded.state,
          updated_at = excluded.updated_at,
          row_revision = audio_segments.row_revision + 1
        WHERE audio_segments.relative_path IS NOT excluded.relative_path
           OR audio_segments.media_start_us IS NOT excluded.media_start_us
           OR audio_segments.media_duration_us IS NOT excluded.media_duration_us
           OR audio_segments.committed_bytes IS NOT excluded.committed_bytes
           OR audio_segments.state IS NOT excluded.state
        ''',
        <Object>[
          'recovery-${item.meetingId}-${segment.sequence}',
          observedAtUtcMs,
          observedAtUtcMs,
          item.meetingId,
          segment.sequence,
          segment.relativePath.value,
          segment.mediaStart.inMicroseconds,
          segment.mediaDuration.inMicroseconds,
          segment.committedBytes,
          segment.state.name,
        ],
      );
    }
  }

  Future<void> _replaceRecoveryFindings(
    String meetingId,
    List<SessionRecoveryDiagnostic> diagnostics,
    int observedAtUtcMs,
  ) async {
    final existing = await database
        .customSelect(
          '''
      SELECT code, segment_sequence
      FROM recovery_findings
      WHERE meeting_id = ? AND is_deleted = 0
      ORDER BY id
      ''',
          variables: <Variable<Object>>[Variable<String>(meetingId)],
        )
        .get();
    final unchanged =
        existing.length == diagnostics.length &&
        existing.indexed.every((entry) {
          final diagnostic = diagnostics[entry.$1];
          return entry.$2.read<String>('code') == diagnostic.code &&
              entry.$2.readNullable<int>('segment_sequence') ==
                  diagnostic.segmentSequence;
        });
    if (unchanged) return;
    await database.customStatement(
      '''
      UPDATE recovery_findings
      SET is_deleted = 1, deleted_at = ?, updated_at = ?,
          row_revision = row_revision + 1
      WHERE meeting_id = ? AND is_deleted = 0
      ''',
      <Object>[observedAtUtcMs, observedAtUtcMs, meetingId],
    );
    for (final entry in diagnostics.indexed) {
      await database.customStatement(
        '''
        INSERT INTO recovery_findings (
          id, created_at, updated_at, is_deleted, row_revision,
          meeting_id, segment_sequence, code
        ) VALUES (?, ?, ?, 0, 0, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          updated_at = excluded.updated_at,
          is_deleted = 0,
          deleted_at = NULL,
          row_revision = recovery_findings.row_revision + 1,
          meeting_id = excluded.meeting_id,
          segment_sequence = excluded.segment_sequence,
          code = excluded.code
        ''',
        <Object?>[
          'recovery-finding-$meetingId-${entry.$1}',
          observedAtUtcMs,
          observedAtUtcMs,
          meetingId,
          entry.$2.segmentSequence,
          entry.$2.code,
        ],
      );
    }
  }

  Future<void> _reconcileUnobservedDatabaseMeetings({
    required Set<String> observedMeetingIds,
    required Set<String> liveMeetingIds,
    required Set<String> invalidStorageKeys,
    required int observedAtUtcMs,
    required List<String> markedRecoverableIds,
  }) async {
    final meetings = await database.select(database.meetings).get();
    for (final meeting in meetings) {
      if (observedMeetingIds.contains(meeting.id) ||
          liveMeetingIds.contains(meeting.id)) {
        continue;
      }
      final audioRows = await (database.select(
        database.audioSegments,
      )..where((row) => row.meetingId.equals(meeting.id))).get();
      for (final audio in audioRows) {
        final storageKey = _recordingStorageKey(audio.relativePath);
        final state = invalidStorageKeys.contains(storageKey)
            ? domain.AudioSegmentState.corrupt.name
            : domain.AudioSegmentState.missing.name;
        if (audio.state == state && audio.committedBytes == 0) continue;
        await database.customStatement(
          '''
          UPDATE audio_segments
          SET state = ?, committed_bytes = 0, updated_at = ?,
              row_revision = row_revision + 1
          WHERE id = ?
          ''',
          <Object>[state, observedAtUtcMs, audio.id],
        );
      }
      if (audioRows.isNotEmpty) {
        await _replaceRecoveryFindings(
          meeting.id,
          audioRows
              .map(
                (audio) => SessionRecoveryDiagnostic(
                  code:
                      invalidStorageKeys.contains(
                        _recordingStorageKey(audio.relativePath),
                      )
                      ? 'recording_recovery_segment_corrupt'
                      : 'recording_recovery_segment_missing',
                  segmentSequence: audio.sequence,
                ),
              )
              .toList(growable: false),
          observedAtUtcMs,
        );
      }
      final lifecycle = domain.MeetingLifecycle.values.byName(
        meeting.lifecycle,
      );
      if (audioRows.isEmpty && !_needsRecovery(lifecycle)) continue;
      if (await _markRecoverable(
        meeting.id,
        lifecycle,
        observedAtUtcMs,
      )) {
        markedRecoverableIds.add(meeting.id);
      }
    }
  }

  Future<bool> _markRecoverable(
    String meetingId,
    domain.MeetingLifecycle lifecycle,
    int observedAtUtcMs,
  ) async {
    if (lifecycle == domain.MeetingLifecycle.recoverable ||
        lifecycle == domain.MeetingLifecycle.trashed ||
        lifecycle == domain.MeetingLifecycle.deleting) {
      return false;
    }
    await database.customStatement(
      '''
      UPDATE meetings
      SET lifecycle = 'recoverable', updated_at = ?,
          row_revision = row_revision + 1
      WHERE id = ?
      ''',
      <Object>[observedAtUtcMs, meetingId],
    );
    await _insertRecoveryEvent(meetingId, observedAtUtcMs);
    return true;
  }

  Future<void> _insertRecoveryEvent(
    String meetingId,
    int observedAtUtcMs,
  ) async {
    final eventPosition = await database
        .customSelect(
          '''
          SELECT COALESCE(MAX(sequence), -1) + 1 AS next_sequence,
                 COALESCE(MAX(monotonic_elapsed_us), 0) AS monotonic_us,
                 COALESCE(MAX(media_offset_us), 0) AS media_us
          FROM session_events WHERE meeting_id = ?
          ''',
          variables: <Variable<Object>>[Variable<String>(meetingId)],
        )
        .getSingle();
    await database
        .into(database.sessionEvents)
        .insert(
          db.SessionEventsCompanion.insert(
            id: 'recovery-$meetingId-$observedAtUtcMs',
            createdAt: observedAtUtcMs,
            updatedAt: observedAtUtcMs,
            meetingId: meetingId,
            sequence: eventPosition.read<int>('next_sequence'),
            type: 'recovered',
            wallClockUtcMs: observedAtUtcMs,
            monotonicElapsedUs: eventPosition.read<int>('monotonic_us'),
            mediaOffsetUs: eventPosition.read<int>('media_us'),
          ),
        );
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
            transcriptionMode: Value(updated.transcriptionMode.name),
            expectedSpeakerCount: Value(updated.expectedSpeakerCount),
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
            transcriptionMode: Value(meeting.transcriptionMode.name),
            expectedSpeakerCount: Value(meeting.expectedSpeakerCount),
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
  final items = pageRows
      .map(
        (row) => SessionLibraryItem(
          meeting: _readMeeting(row),
          committedAudioBytes: row.read<int>('committed_audio_bytes'),
        ),
      )
      .toList(growable: false);
  final last = items.isEmpty ? null : items.last.meeting;
  return SessionLibraryPage(
    items: items,
    nextCursor: hasMore && last != null
        ? SessionLibraryCursor(createdAtUtcMs: last.createdAtUtcMs, id: last.id)
        : null,
  );
}

processing.ProcessingJob _readProcessingJob(
  db.ProcessingJob row,
) => processing.ProcessingJob(
  id: row.id,
  meetingId: row.meetingId,
  kind: processing.ProcessingJobKind.values.byName(row.jobKind),
  createdAtUtcMs: row.createdAt,
  state: switch (row.jobState) {
    'queued' => const processing.ProcessingQueued(),
    'running' => processing.ProcessingRunning(progress: row.progress!),
    'paused' => processing.ProcessingPaused(reasonCode: row.reasonCode!),
    'succeeded' =>
      processing.TranscriptionCompletionWarning.tryParse(row.checkpoint) == null
          ? const processing.ProcessingSucceeded()
          : processing.ProcessingSucceededWithWarning(
              warningCode: processing.TranscriptionCompletionWarning.tryParse(
                row.checkpoint,
              )!.warningCode,
            ),
    'failed' => processing.ProcessingFailed(
      failureCode: row.failureCode!,
    ),
    _ => throw StateError('unknown processing state'),
  },
  targetRunId: row.transcriptRunId ?? row.diarizationRunId,
  modelId: row.modelId,
  checkpoint: row.checkpoint,
);

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
  transcriptionMode: domain.MeetingTranscriptionMode.values.byName(
    row.read<String>('transcription_mode'),
  ),
  expectedSpeakerCount: row.readNullable<int>('expected_speaker_count'),
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
  transcriptionMode: domain.MeetingTranscriptionMode.values.byName(
    row.transcriptionMode,
  ),
  expectedSpeakerCount: row.expectedSpeakerCount,
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

bool _isNativeRecordingLifecycle(domain.MeetingLifecycle lifecycle) =>
    switch (lifecycle) {
      domain.MeetingLifecycle.preparing ||
      domain.MeetingLifecycle.recording ||
      domain.MeetingLifecycle.pausedByUser ||
      domain.MeetingLifecycle.pausedByInterruption ||
      domain.MeetingLifecycle.stopping ||
      domain.MeetingLifecycle.finalized ||
      domain.MeetingLifecycle.recoverable ||
      domain.MeetingLifecycle.failedFinalization => true,
      domain.MeetingLifecycle.draft ||
      domain.MeetingLifecycle.trashed ||
      domain.MeetingLifecycle.deleting => false,
    };

String? _recordingStorageKey(String relativePath) {
  final parts = relativePath.split('/');
  return parts.length >= 3 && parts.first == 'recordings' ? parts[1] : null;
}

const String _meetingSelect = '''
SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
       m.language_mode, m.transcription_mode, m.expected_speaker_count,
       m.trashed_at_utc_ms, m.lifecycle_before_trash,
       tr.id AS current_transcript_run_id,
       COALESCE((
         SELECT SUM(a.committed_bytes)
         FROM audio_segments AS a
         WHERE a.meeting_id = m.id AND a.is_deleted = 0
       ), 0) AS committed_audio_bytes
FROM meetings AS m
LEFT JOIN meeting_transcript_selections AS mts
  ON mts.meeting_id = m.id AND mts.is_deleted = 0
LEFT JOIN transcript_runs AS tr
  ON tr.id = mts.transcript_run_id AND tr.is_deleted = 0
''';

const String _searchSql = '''
WITH hits AS (
  SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
         m.language_mode, m.transcription_mode, m.expected_speaker_count,
         m.trashed_at_utc_ms, m.lifecycle_before_trash,
         tr.id AS current_transcript_run_id,
         NULL AS segment_id, NULL AS media_offset_us, 0 AS match_kind,
         COALESCE((
           SELECT SUM(a.committed_bytes)
           FROM audio_segments AS a
           WHERE a.meeting_id = m.id AND a.is_deleted = 0
         ), 0) AS committed_audio_bytes
  FROM meetings AS m
  LEFT JOIN meeting_transcript_selections AS mts
    ON mts.meeting_id = m.id AND mts.is_deleted = 0
  LEFT JOIN transcript_runs AS tr
    ON tr.id = mts.transcript_run_id AND tr.is_deleted = 0
  WHERE m.is_deleted = 0 AND instr(lower(m.title), lower(?)) > 0
  UNION ALL
  SELECT m.id, m.created_at, m.title, m.media_duration_us, m.lifecycle,
         m.language_mode, m.transcription_mode, m.expected_speaker_count,
         m.trashed_at_utc_ms, m.lifecycle_before_trash,
         tr.id AS current_transcript_run_id,
         ts.id AS segment_id, ts.start_us AS media_offset_us, 1 AS match_kind,
         COALESCE((
           SELECT SUM(a.committed_bytes)
           FROM audio_segments AS a
           WHERE a.meeting_id = m.id AND a.is_deleted = 0
         ), 0) AS committed_audio_bytes
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

final class _RecoveryDetailsInvariantError implements Exception {
  const _RecoveryDetailsInvariantError();
}

SessionRepositoryFailure _stateFailure(_RepositoryStateError error) =>
    switch (error.code) {
      'session_not_found' => const SessionNotFound(),
      'session_invalid_lifecycle' => const SessionInvalidLifecycle(),
      _ => throw StateError('unknown repository state failure'),
    };
