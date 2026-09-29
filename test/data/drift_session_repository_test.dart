import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show
        BatchedStatements,
        QueryExecutor,
        QueryExecutorUser,
        SqlDialect,
        TransactionExecutor,
        Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/files/private_meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  late db.AppDatabase database;
  late DriftSessionRepository repository;
  late _FakeMeetingAudioStore audioStore;
  late _RecordingDiagnosticSink diagnosticSink;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    audioStore = _FakeMeetingAudioStore();
    diagnosticSink = _RecordingDiagnosticSink();
    repository = DriftSessionRepository(
      database,
      audioStore: audioStore,
      diagnosticSink: diagnosticSink,
    );
  });

  tearDown(() => database.close());

  test(
    'library is scoped, keyset-paged, and streams committed writes',
    () async {
      await _save(repository, _meeting('older', createdAt: 1));
      await _save(repository, _meeting('newer', createdAt: 2));

      final firstPage = await _ok(
        repository.queryLibrary(
          const SessionLibraryQuery(kind: SessionLibraryKind.active, limit: 1),
        ),
      );
      expect(firstPage.meetings.map((meeting) => meeting.id), ['newer']);
      expect(firstPage.nextCursor, isNotNull);

      final secondPage = await _ok(
        repository.queryLibrary(
          SessionLibraryQuery(
            kind: SessionLibraryKind.active,
            limit: 1,
            before: firstPage.nextCursor,
          ),
        ),
      );
      expect(secondPage.meetings.map((meeting) => meeting.id), ['older']);

      final iterator = StreamIterator(
        repository.watchLibrary(
          const SessionLibraryQuery(
            kind: SessionLibraryKind.active,
            limit: 10,
          ),
        ),
      );
      expect(await iterator.moveNext(), isTrue);
      final initial = await _value(iterator.current);
      expect(initial.meetings.map((meeting) => meeting.id), ['newer', 'older']);

      final moved = iterator.moveNext();
      await _save(repository, _meeting('latest', createdAt: 3));
      expect(await moved, isTrue);
      final streamed = await _value(iterator.current);
      expect(streamed.meetings.first.id, 'latest');
      await iterator.cancel();
    },
  );

  test('legacy list traverses every keyset page without truncation', () async {
    for (var index = 0; index < 101; index += 1) {
      await _save(
        repository,
        _meeting('meeting-$index', createdAt: index + 1),
      );
    }

    final collection = await _ok(repository.list());
    expect(collection.sessions, hasLength(101));
    expect(collection.sessions.first.id, 'meeting-100');
    expect(collection.sessions.last.id, 'meeting-0');
  });

  test(
    'search returns title and current-transcript media hits locally',
    () async {
      await _save(
        repository,
        _meeting('meeting-1', createdAt: 1, title: 'Roadmap'),
      );
      await _insertCurrentTranscript(database);

      final titleHits = await _ok(repository.search('Road'));
      expect(titleHits, hasLength(1));
      expect(titleHits.single.transcriptSegmentId, isNull);

      final transcriptHits = await _ok(repository.search('世界'));
      expect(transcriptHits, hasLength(1));
      expect(transcriptHits.single.transcriptSegmentId, 'segment-1');
      expect(transcriptHits.single.mediaOffset, const Duration(seconds: 2));
    },
  );

  test('soft-deleted transcript links and segments never reappear', () async {
    await _save(
      repository,
      _meeting('meeting-1', createdAt: 1, title: 'Roadmap'),
    );
    await _insertCurrentTranscript(database);
    await database.customStatement('''
      UPDATE transcript_segments
      SET is_deleted = 1, deleted_at = 2, updated_at = 2
      WHERE id = 'segment-1'
      ''');

    expect(await _ok(repository.search('世界')), isEmpty);

    await database.customStatement('''
      UPDATE meeting_transcript_selections
      SET is_deleted = 1, deleted_at = 3, updated_at = 3
      WHERE id = 'selection-1'
      ''');
    final page = await _ok(
      repository.queryLibrary(
        const SessionLibraryQuery(kind: SessionLibraryKind.active, limit: 10),
      ),
    );
    expect(page.meetings.single.currentTranscriptRunId, isNull);
  });

  test(
    'trash restore preserves lifecycle and permanent delete cascades',
    () async {
      await _save(
        repository,
        _meeting(
          'meeting-1',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recoverable,
        ),
      );
      await database.customStatement('''
      INSERT INTO bookmarks (
        id, created_at, updated_at, meeting_id, media_offset_us, kind
      ) VALUES ('bookmark-1', 1, 1, 'meeting-1', 0, 'bookmark')
      ''');

      final trashed = await _ok(
        repository.moveToTrash('meeting-1', atUtcMs: 10),
      );
      expect(trashed.lifecycle, MeetingLifecycle.trashed);
      expect(trashed.lifecycleBeforeTrash, MeetingLifecycle.recoverable);

      final restored = await _ok(
        repository.restoreFromTrash('meeting-1', atUtcMs: 11),
      );
      expect(restored.lifecycle, MeetingLifecycle.recoverable);
      expect(restored.lifecycleBeforeTrash, isNull);

      await _ok(repository.moveToTrash('meeting-1', atUtcMs: 12));
      await _ok(repository.permanentlyDelete('meeting-1'));
      expect(await _count(database, 'meetings'), 0);
      expect(await _count(database, 'bookmarks'), 0);
    },
  );

  test('permanent deletion keeps metadata when audio removal fails', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
    audioStore.result = const Err(
      MeetingAudioStoreUnavailable('audio_delete_failed'),
    );

    final result = await repository.permanentlyDelete('meeting-1');

    expect(result, isA<Err<void, SessionRepositoryFailure>>());
    expect(
      (result as Err<void, SessionRepositoryFailure>).failure,
      isA<SessionStoreUnavailable>(),
    );
    expect(await _count(database, 'meetings'), 1);
    expect(await _count(database, 'audio_segments'), 1);
    expect(diagnosticSink.events, hasLength(1));
  });

  test('permanent deletion removes private audio before metadata', () async {
    final directory = await Directory.systemTemp.createTemp('loquiris-audio-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final audioFile = File('${directory.path}/meetings/meeting-1/0000.aac');
    await audioFile.parent.create(recursive: true);
    await audioFile.writeAsBytes(const <int>[1, 2, 3], flush: true);
    repository = DriftSessionRepository(
      database,
      audioStore: PrivateMeetingAudioStore(() async => directory),
      diagnosticSink: diagnosticSink,
    );
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 3);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));

    await _ok(repository.permanentlyDelete('meeting-1'));

    expect(audioFile.existsSync(), isFalse);
    expect(await _count(database, 'meetings'), 0);
  });

  test('durable deleting reservation rejects a concurrent restore', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
    Result<Meeting, SessionRepositoryFailure>? restoreResult;
    audioStore.onDelete = () async {
      restoreResult = await repository.restoreFromTrash(
        'meeting-1',
        atUtcMs: 3,
      );
    };

    await _ok(repository.permanentlyDelete('meeting-1'));

    expect(
      (restoreResult! as Err<Meeting, SessionRepositoryFailure>).failure,
      isA<SessionInvalidLifecycle>(),
    );
    expect(await _count(database, 'meetings'), 0);
  });

  test('post-file database failure leaves a retryable deleting row', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
    audioStore.onDelete = () => database.customStatement('''
      CREATE TRIGGER fail_meeting_delete
      BEFORE DELETE ON meetings
      BEGIN
        SELECT RAISE(ABORT, 'simulated delete failure');
      END
      ''');

    final failed = await repository.permanentlyDelete('meeting-1');

    expect(
      (failed as Err<void, SessionRepositoryFailure>).failure,
      isA<SessionStoreUnavailable>(),
    );
    expect(await _lifecycle(database, 'meeting-1'), 'deleting');

    await database.customStatement('DROP TRIGGER fail_meeting_delete');
    audioStore.onDelete = null;
    await _ok(repository.permanentlyDelete('meeting-1'));
    expect(await _count(database, 'meetings'), 0);
  });

  test('ordinary save APIs cannot revive a deleting reservation', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
    audioStore.result = const Err(
      MeetingAudioStoreUnavailable('audio_delete_failed'),
    );
    await repository.permanentlyDelete('meeting-1');
    expect(await _lifecycle(database, 'meeting-1'), 'deleting');

    final aggregateSave = await repository.saveMeeting(
      _meeting('meeting-1', createdAt: 1),
    );
    expect(
      (aggregateSave as Err<Meeting, SessionRepositoryFailure>).failure,
      isA<SessionInvalidLifecycle>(),
    );
    final compatibilitySave = await repository.save(
      const SessionSummary(
        id: 'meeting-1',
        title: 'Revived',
        isRecoverable: true,
      ),
    );
    expect(
      (compatibilitySave as Err<SessionSummary, SessionRepositoryFailure>)
          .failure,
      isA<SessionInvalidLifecycle>(),
    );
    expect(await _lifecycle(database, 'meeting-1'), 'deleting');
  });

  test(
    'compatibility save cannot revive a concurrently hard-deleted id',
    () async {
      await database.close();
      final executor = _PausingQueryExecutor(NativeDatabase.memory());
      database = db.AppDatabase(executor);
      repository = DriftSessionRepository(
        database,
        audioStore: audioStore,
        diagnosticSink: diagnosticSink,
      );
      await _save(repository, _meeting('meeting-1', createdAt: 1));
      await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
      executor.pauseNextMeetingLookup = true;

      final saveFuture = repository.save(
        const SessionSummary(
          id: 'meeting-1',
          title: 'Must not return from deletion',
        ),
      );
      final first = await Future.any<Object>([
        executor.lookupPaused.future.then<Object>((_) => 'paused'),
        saveFuture.then<Object>((_) => 'saved'),
      ]);

      if (first == 'paused') {
        await _ok(repository.permanentlyDelete('meeting-1'));
        executor.resumeLookup.complete();
        expect(
          (await saveFuture as Err<SessionSummary, SessionRepositoryFailure>)
              .failure,
          isA<SessionInvalidLifecycle>(),
        );
      } else {
        await _ok(repository.permanentlyDelete('meeting-1'));
      }
      expect(await _count(database, 'meetings'), 0);
    },
  );

  test('permanent deletion includes soft-deleted audio paths', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await database.customStatement('''
      UPDATE audio_segments
      SET is_deleted = 1, deleted_at = 2, updated_at = 2
      WHERE id = 'audio-1'
      ''');
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 3));

    await _ok(repository.permanentlyDelete('meeting-1'));

    expect(
      audioStore.deletedPaths.map((path) => path.value),
      ['meetings/meeting-1/0000.aac'],
    );
  });

  test(
    'repository distinguishes missing and invalid lifecycle failures',
    () async {
      final missing = await repository.restoreFromTrash('missing', atUtcMs: 2);
      expect(
        (missing as Err<Meeting, SessionRepositoryFailure>).failure,
        isA<SessionNotFound>(),
      );

      await _save(repository, _meeting('active', createdAt: 1));
      final invalid = await repository.restoreFromTrash('active', atUtcMs: 2);
      expect(
        (invalid as Err<Meeting, SessionRepositoryFailure>).failure,
        isA<SessionInvalidLifecycle>(),
      );
    },
  );

  test('programming errors are not disguised as repository failures', () async {
    await _save(repository, _meeting('meeting-1', createdAt: 1));
    await _insertAudio(database, 'audio-1', 'meeting-1', 100);
    await _ok(repository.moveToTrash('meeting-1', atUtcMs: 2));
    audioStore.error = StateError('programming defect');

    await expectLater(
      repository.permanentlyDelete('meeting-1'),
      throwsA(isA<StateError>()),
    );
    expect(await _count(database, 'meetings'), 1);
  });

  test('storage accounting separates active meetings from trash', () async {
    await _save(repository, _meeting('active', createdAt: 1));
    await _save(repository, _meeting('trash', createdAt: 2));
    await _insertAudio(database, 'audio-active', 'active', 100);
    await _insertAudio(database, 'audio-trash', 'trash', 40);
    await _ok(repository.moveToTrash('trash', atUtcMs: 3));

    final accounting = await _ok(repository.accountStorage());
    expect(accounting.activeMeetingBytes, 100);
    expect(accounting.trashBytes, 40);
    expect(accounting.totalMeetingBytes, 140);
  });

  test(
    'recovery reconciliation marks only unfinished evidenced audio',
    () async {
      await _save(
        repository,
        _meeting(
          'unfinished',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recording,
        ),
      );
      await _save(repository, _meeting('final', createdAt: 2));

      final report = await _ok(
        repository.reconcileRecovery(
          const <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'unfinished',
              hasCommittedAudio: true,
            ),
            SessionRecoveryEvidence(
              meetingId: 'final',
              hasCommittedAudio: true,
            ),
          ],
          observedAtUtcMs: 20,
        ),
      );

      expect(report.markedRecoverableIds, ['unfinished']);
      expect(report.unchangedIds, ['final']);
      expect(await _lifecycle(database, 'unfinished'), 'recoverable');
      expect(await _lifecycle(database, 'final'), 'finalized');
      expect(await _count(database, 'session_events'), 1);
    },
  );
}

Meeting _meeting(
  String id, {
  required int createdAt,
  String? title,
  MeetingLifecycle lifecycle = MeetingLifecycle.finalized,
}) => Meeting(
  id: id,
  title: title ?? id,
  createdAtUtcMs: createdAt,
  mediaDuration: Duration.zero,
  lifecycle: lifecycle,
  languageMode: MeetingLanguageMode.mixed,
);

Future<void> _save(DriftSessionRepository repository, Meeting meeting) async {
  await _ok(repository.saveMeeting(meeting));
}

Future<T> _ok<T>(Future<Result<T, SessionRepositoryFailure>> result) async {
  return _value(await result);
}

Future<T> _value<T>(Result<T, SessionRepositoryFailure> result) async {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('Unexpected ${failure.code}'),
  };
}

Future<int> _count(db.AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<String> _lifecycle(db.AppDatabase database, String id) async {
  final row = await database
      .customSelect(
        'SELECT lifecycle FROM meetings WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();
  return row.read<String>('lifecycle');
}

Future<void> _insertAudio(
  db.AppDatabase database,
  String id,
  String meetingId,
  int bytes,
) => database.customStatement(
  '''
  INSERT INTO audio_segments (
    id, created_at, updated_at, meeting_id, sequence, relative_path,
    media_start_us, media_duration_us, committed_bytes, state
  ) VALUES (?, 1, 1, ?, 0, ?, 0, 1, ?, 'committed')
  ''',
  <Object>[id, meetingId, 'meetings/$meetingId/0000.aac', bytes],
);

Future<void> _insertCurrentTranscript(db.AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO model_manifests (
      id, created_at, updated_at, version, source, sha256, bytes,
      expected_engine_id, license_id, license_snapshot_path
    ) VALUES ('model-1', 1, 1, '1', 'source', 'hash', 1,
      'engine', 'MIT', 'licenses/model.txt')
    ''');
  await database.customStatement('''
    INSERT INTO transcript_runs (
      id, created_at, updated_at, meeting_id, engine_id, engine_version,
      model_id, model_version, model_sha256, parameters_json, run_state
    ) VALUES ('run-1', 1, 1, 'meeting-1', 'engine', '1',
      'model-1', '1', 'hash', '{}', 'queued')
    ''');
  await database.customStatement('''
    INSERT INTO meeting_transcript_selections (
      id, created_at, updated_at, meeting_id, transcript_run_id
    ) VALUES ('selection-1', 1, 1, 'meeting-1', 'run-1')
    ''');
  await database.customStatement('''
    INSERT INTO transcript_segments (
      id, created_at, updated_at, meeting_id, transcript_run_id,
      start_us, end_us, raw_model_text, displayed_text, revision_state
    ) VALUES ('segment-1', 1, 1, 'meeting-1', 'run-1',
      2000000, 3000000, 'hello 世界', 'hello 世界', 'machine')
    ''');
}

final class _FakeMeetingAudioStore implements MeetingAudioStore {
  Result<void, MeetingAudioStoreFailure> result =
      const Ok<void, MeetingAudioStoreFailure>(null);
  Error? error;
  Future<void> Function()? onDelete;
  List<AppRelativePath> deletedPaths = const [];

  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    List<AppRelativePath> relativePaths,
  ) async {
    if (error case final error?) throw error;
    await onDelete?.call();
    deletedPaths = List.unmodifiable(relativePaths);
    return result;
  }
}

final class _RecordingDiagnosticSink implements DiagnosticLogSink {
  final List<DiagnosticEvent> events = [];

  @override
  void record(DiagnosticEvent event) => events.add(event);
}

final class _PausingQueryExecutor implements QueryExecutor {
  _PausingQueryExecutor(this.delegate);

  final QueryExecutor delegate;
  final Completer<void> lookupPaused = Completer<void>();
  final Completer<void> resumeLookup = Completer<void>();
  bool pauseNextMeetingLookup = false;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    final rows = await delegate.runSelect(statement, args);
    if (pauseNextMeetingLookup && args.contains('meeting-1')) {
      pauseNextMeetingLookup = false;
      lookupPaused.complete();
      await resumeLookup.future;
    }
    return rows;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      delegate.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      delegate.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      delegate.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      delegate.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => delegate.beginExclusive();

  @override
  Future<void> close() => delegate.close();
}
