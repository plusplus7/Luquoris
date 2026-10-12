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
      await _save(
        repository,
        _meeting(
          'newer',
          createdAt: 2,
          transcriptionMode: MeetingTranscriptionMode.nearRealTime,
          expectedSpeakerCount: 4,
        ),
      );
      await _insertAudio(database, 'audio-newer', 'newer', 1536000);

      final firstPage = await _ok(
        repository.queryLibrary(
          const SessionLibraryQuery(kind: SessionLibraryKind.active, limit: 1),
        ),
      );
      expect(firstPage.meetings.map((meeting) => meeting.id), ['newer']);
      expect(firstPage.items.single.committedAudioBytes, 1536000);
      expect(
        firstPage.meetings.single.transcriptionMode,
        MeetingTranscriptionMode.nearRealTime,
      );
      expect(firstPage.meetings.single.expectedSpeakerCount, 4);
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
    'recording defaults are local, durable, and explicitly replaceable',
    () async {
      expect(
        await _ok(repository.loadRecordingDefaults()),
        const RecordingDefaults(),
      );

      const selected = RecordingDefaults(
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        languageMode: MeetingLanguageMode.english,
        expectedSpeakerCount: 6,
      );
      await _ok(repository.saveRecordingDefaults(selected, atUtcMs: 9));

      expect(await _ok(repository.loadRecordingDefaults()), selected);
    },
  );

  test('authoritative recording progress preserves setup metadata', () async {
    await _save(
      repository,
      _meeting(
        'meeting-progress',
        createdAt: 1,
        title: 'Stable setup',
        lifecycle: MeetingLifecycle.preparing,
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        expectedSpeakerCount: 4,
      ),
    );

    final updated = await _ok(
      repository.synchronizeRecordingProgress(
        'meeting-progress',
        lifecycle: MeetingLifecycle.recording,
        mediaDuration: const Duration(seconds: 12),
        atUtcMs: 20,
      ),
    );

    expect(updated.title, 'Stable setup');
    expect(updated.lifecycle, MeetingLifecycle.recording);
    expect(updated.mediaDuration, const Duration(seconds: 12));
    expect(updated.transcriptionMode, MeetingTranscriptionMode.nearRealTime);
    expect(updated.expectedSpeakerCount, 4);
  });

  test(
    'unstarted cleanup deletes only zero-audio draft or preparing rows',
    () async {
      await _save(
        repository,
        _meeting(
          'empty-preparing',
          createdAt: 1,
          lifecycle: MeetingLifecycle.preparing,
        ),
      );
      await _ok(repository.discardUnstartedMeeting('empty-preparing'));
      expect(await _count(database, 'meetings'), 0);

      await _save(
        repository,
        _meeting(
          'with-audio',
          createdAt: 2,
          lifecycle: MeetingLifecycle.preparing,
        ),
      );
      await _insertAudio(database, 'audio-started', 'with-audio', 1024);

      final refused = await repository.discardUnstartedMeeting('with-audio');
      expect(refused, isA<Err<void, SessionRepositoryFailure>>());
      expect(
        (refused as Err<void, SessionRepositoryFailure>).failure.code,
        'session_invalid_lifecycle',
      );
      expect(await _count(database, 'meetings'), 1);
    },
  );

  test(
    'search returns title and current-transcript media hits locally',
    () async {
      await _save(
        repository,
        _meeting('meeting-1', createdAt: 1, title: 'Roadmap'),
      );
      await _insertAudio(database, 'audio-search', 'meeting-1', 2048);
      await _insertCurrentTranscript(database);

      final titleHits = await _ok(repository.search('Road'));
      expect(titleHits, hasLength(1));
      expect(titleHits.single.transcriptSegmentId, isNull);
      expect(titleHits.single.committedAudioBytes, 2048);

      final transcriptHits = await _ok(repository.search('世界'));
      expect(transcriptHits, hasLength(1));
      expect(transcriptHits.single.transcriptSegmentId, 'segment-1');
      expect(transcriptHits.single.mediaOffset, const Duration(seconds: 2));
      expect(transcriptHits.single.committedAudioBytes, 2048);
    },
  );

  test(
    'rename updates only the title after concurrent lifecycle changes',
    () async {
      await _save(
        repository,
        _meeting(
          'meeting-1',
          createdAt: 1,
          title: 'Original',
          lifecycle: MeetingLifecycle.recoverable,
        ),
      );
      await _ok(repository.moveToTrash('meeting-1', atUtcMs: 10));

      final renamed = await _ok(
        repository.renameMeeting(
          'meeting-1',
          '  Renamed  ',
          atUtcMs: 11,
        ),
      );

      expect(renamed.title, 'Renamed');
      expect(renamed.lifecycle, MeetingLifecycle.trashed);
      expect(renamed.lifecycleBeforeTrash, MeetingLifecycle.recoverable);
      expect(renamed.trashedAtUtcMs, 10);
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

  test('native-active meetings cannot enter trash', () async {
    const activeLifecycles = <MeetingLifecycle>[
      MeetingLifecycle.preparing,
      MeetingLifecycle.recording,
      MeetingLifecycle.pausedByUser,
      MeetingLifecycle.pausedByInterruption,
      MeetingLifecycle.stopping,
    ];
    for (final lifecycle in activeLifecycles) {
      final meetingId = 'meeting-${lifecycle.name}';
      await _save(
        repository,
        _meeting(meetingId, createdAt: 1, lifecycle: lifecycle),
      );

      final result = await repository.moveToTrash(meetingId, atUtcMs: 2);

      expect(
        (result as Err<Meeting, SessionRepositoryFailure>).failure.code,
        'session_invalid_lifecycle',
        reason: lifecycle.name,
      );
      expect(await _lifecycle(database, meetingId), lifecycle.name);
    }
  });

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

  test(
    'permanent deletion removes private audio and preserves external copies',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'loquiris-audio-',
      );
      final externalDirectory = await Directory.systemTemp.createTemp(
        'loquiris-external-export-',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
        if (externalDirectory.existsSync()) {
          await externalDirectory.delete(recursive: true);
        }
      });
      final audioFile = File('${directory.path}/meetings/meeting-1/0000.aac');
      final externalCopy = File('${externalDirectory.path}/exported-copy.m4a');
      await audioFile.parent.create(recursive: true);
      await audioFile.writeAsBytes(const <int>[1, 2, 3], flush: true);
      await externalCopy.writeAsBytes(const <int>[1, 2, 3], flush: true);
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
      expect(externalCopy.readAsBytesSync(), const <int>[1, 2, 3]);
      expect(await _count(database, 'meetings'), 0);
    },
  );

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
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'unfinished',
              storageKey: 'unfinished',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/unfinished/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 5),
                  committedBytes: 100,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
            SessionRecoveryEvidence(
              meetingId: 'final',
              storageKey: 'final',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/final/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 5),
                  committedBytes: 100,
                  state: AudioSegmentState.committed,
                ),
              ],
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

  test(
    'recovery reconciliation mirrors manifest segments and requeues derived jobs',
    () async {
      await _save(
        repository,
        _meeting(
          'unfinished',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recording,
        ),
      );
      await _insertAudio(database, 'stale-audio', 'unfinished', 20);
      await database.customStatement('''
        INSERT INTO processing_jobs (
          id, created_at, updated_at, is_deleted, row_revision,
          meeting_id, job_kind, job_state, progress
        ) VALUES ('merge-1', 1, 1, 0, 0, 'unfinished', 'audioMerge', 'running', 0.5)
      ''');

      final report = await _ok(
        repository.reconcileRecovery(
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'unfinished',
              storageKey: 'hash',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/hash/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 4),
                  committedBytes: 40,
                  state: AudioSegmentState.committed,
                ),
                SessionRecoverySegmentEvidence(
                  sequence: 1,
                  relativePath: _path(
                    'recordings/hash/segment-00001.adts',
                  ),
                  mediaStart: const Duration(seconds: 4),
                  mediaDuration: const Duration(seconds: 2),
                  committedBytes: 20,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
          ],
          observedAtUtcMs: 20,
        ),
      );

      expect(report.markedRecoverableIds, ['unfinished']);
      expect(report.reconciledSegmentCount, 2);
      final segments = await database.customSelect('''
        SELECT sequence, relative_path, media_duration_us, committed_bytes, state
        FROM audio_segments WHERE meeting_id = 'unfinished' ORDER BY sequence
      ''').get();
      expect(segments.map((row) => row.read<int>('sequence')), [0, 1]);
      expect(
        segments.map((row) => row.read<String>('relative_path')),
        [
          'recordings/hash/segment-00000.adts',
          'recordings/hash/segment-00001.adts',
        ],
      );
      expect(segments.map((row) => row.read<int>('committed_bytes')), [40, 20]);
      expect(await _meetingDurationUs(database, 'unfinished'), 6000000);
      final job = await database
          .customSelect(
            "SELECT job_state, progress FROM processing_jobs WHERE id = 'merge-1'",
          )
          .getSingle();
      expect(job.read<String>('job_state'), 'queued');
      expect(job.readNullable<double>('progress'), isNull);
    },
  );

  test(
    'recovery creates a visible meeting for orphan committed audio',
    () async {
      final report = await _ok(
        repository.reconcileRecovery(
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'orphan-meeting',
              storageKey: 'orphan',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/orphan/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 3),
                  committedBytes: 30,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
          ],
          observedAtUtcMs: 99,
        ),
      );

      expect(report.createdRecoverableIds, ['orphan-meeting']);
      expect(await _lifecycle(database, 'orphan-meeting'), 'recoverable');
      expect(await _count(database, 'audio_segments'), 1);
    },
  );

  test(
    'recovery invalidates Drift-only audio and requeues derived work',
    () async {
      await _save(repository, _meeting('stale-final', createdAt: 1));
      await _save(
        repository,
        _meeting(
          'empty-active',
          createdAt: 2,
          lifecycle: MeetingLifecycle.recording,
        ),
      );
      await _insertAudio(database, 'stale-audio', 'stale-final', 100);
      await database.customStatement(
        "UPDATE audio_segments SET relative_path = 'recordings/missing-key/segment-00000.adts' WHERE id = 'stale-audio'",
      );
      await database.customStatement('''
        INSERT INTO processing_jobs (
          id, created_at, updated_at, is_deleted, row_revision,
          meeting_id, job_kind, job_state, progress
        ) VALUES ('orphan-waveform', 1, 1, 0, 0, 'stale-final',
                  'waveform', 'running', 0.25)
      ''');

      final report = await _ok(
        repository.reconcileRecovery(
          const <SessionRecoveryEvidence>[],
          observedAtUtcMs: 30,
          invalidStorageKeys: const <String>{'missing-key'},
        ),
      );

      expect(
        report.markedRecoverableIds,
        containsAll(<String>['stale-final', 'empty-active']),
      );
      final audio = await database
          .customSelect(
            "SELECT state, committed_bytes FROM audio_segments WHERE id = 'stale-audio'",
          )
          .getSingle();
      expect(audio.read<String>('state'), 'corrupt');
      expect(audio.read<int>('committed_bytes'), 0);
      final job = await database
          .customSelect(
            "SELECT job_state, progress FROM processing_jobs WHERE id = 'orphan-waveform'",
          )
          .getSingle();
      expect(job.read<String>('job_state'), 'queued');
      expect(job.readNullable<double>('progress'), isNull);
    },
  );

  test(
    'repeating identical recovery evidence performs no durable writes',
    () async {
      await _save(
        repository,
        _meeting(
          'repeatable',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recording,
        ),
      );
      final evidence = <SessionRecoveryEvidence>[
        SessionRecoveryEvidence(
          meetingId: 'repeatable',
          storageKey: 'repeatable-key',
          segments: <SessionRecoverySegmentEvidence>[
            SessionRecoverySegmentEvidence(
              sequence: 0,
              relativePath: _path(
                'recordings/repeatable-key/segment-00000.adts',
              ),
              mediaStart: Duration.zero,
              mediaDuration: const Duration(seconds: 4),
              committedBytes: 40,
              state: AudioSegmentState.committed,
            ),
          ],
        ),
      ];
      await _ok(
        repository.reconcileRecovery(evidence, observedAtUtcMs: 20),
      );
      final before = await _recoveryRevisions(database, 'repeatable');

      final second = await _ok(
        repository.reconcileRecovery(evidence, observedAtUtcMs: 30),
      );
      final after = await _recoveryRevisions(database, 'repeatable');

      expect(second.markedRecoverableIds, isEmpty);
      expect(after, before);
      expect(await _count(database, 'session_events'), 1);
    },
  );

  test(
    'finalized meeting becomes recoverable when journal authorizes no audio',
    () async {
      await _save(repository, _meeting('false-final', createdAt: 1));

      final report = await _ok(
        repository.reconcileRecovery(
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'false-final',
              storageKey: 'false-final-key',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/false-final-key/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: Duration.zero,
                  committedBytes: 0,
                  state: AudioSegmentState.open,
                ),
              ],
            ),
          ],
          observedAtUtcMs: 20,
        ),
      );

      expect(report.markedRecoverableIds, ['false-final']);
      expect(await _lifecycle(database, 'false-final'), 'recoverable');
      final details = await _ok(repository.recoveryDetails('false-final'));
      expect(details.integrityState, RecoveryIntegrityState.complete);
      expect(details.diagnostics, isEmpty);
      expect(details.rawExportSegments, isEmpty);
    },
  );

  test(
    'finalized meeting becomes recoverable when native timeline is partial',
    () async {
      await _save(repository, _meeting('partial-final', createdAt: 1));

      final report = await _ok(
        repository.reconcileRecovery(
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'partial-final',
              storageKey: 'partial-key',
              integrityState: RecoveryIntegrityState.partial,
              diagnostics: const <SessionRecoveryDiagnostic>[
                SessionRecoveryDiagnostic(
                  code: 'recording_recovery_timeline_gap',
                  segmentSequence: 1,
                ),
              ],
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/partial-key/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 1),
                  committedBytes: 10,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
          ],
          observedAtUtcMs: 20,
        ),
      );

      expect(report.markedRecoverableIds, ['partial-final']);
      expect(report.partialMeetingIds, ['partial-final']);
      expect(await _lifecycle(database, 'partial-final'), 'recoverable');

      final details = await _ok(
        repository.recoveryDetails('partial-final'),
      );
      expect(details.integrityState, RecoveryIntegrityState.partial);
      expect(
        details.diagnostics.single.code,
        'recording_recovery_timeline_gap',
      );
      expect(details.diagnostics.single.segmentSequence, 1);
      expect(details.rawExportSegments.single.committedBytes, 10);

      await _ok(
        repository.reconcileRecovery(
          <SessionRecoveryEvidence>[
            SessionRecoveryEvidence(
              meetingId: 'partial-final',
              storageKey: 'partial-key',
              segments: <SessionRecoverySegmentEvidence>[
                SessionRecoverySegmentEvidence(
                  sequence: 0,
                  relativePath: _path(
                    'recordings/partial-key/segment-00000.adts',
                  ),
                  mediaStart: Duration.zero,
                  mediaDuration: const Duration(seconds: 1),
                  committedBytes: 10,
                  state: AudioSegmentState.committed,
                ),
              ],
            ),
          ],
          observedAtUtcMs: 30,
        ),
      );
      final repaired = await _ok(repository.recoveryDetails('partial-final'));
      expect(repaired.integrityState, RecoveryIntegrityState.complete);
      expect(repaired.diagnostics, isEmpty);
      expect(repaired.rawExportSegments.single.committedBytes, 10);
    },
  );

  test(
    'recovery resolution allows only explicit idempotent outcomes',
    () async {
      await _save(
        repository,
        _meeting(
          'resolve-me',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recoverable,
        ),
      );

      final saved = await _ok(
        repository.resolveRecovery(
          'resolve-me',
          RecoveryResolution.save,
          atUtcMs: 20,
        ),
      );
      final repeated = await _ok(
        repository.resolveRecovery(
          'resolve-me',
          RecoveryResolution.save,
          atUtcMs: 30,
        ),
      );

      expect(saved.lifecycle, MeetingLifecycle.finalized);
      expect(repeated.lifecycle, MeetingLifecycle.finalized);
      expect(await _lifecycle(database, 'resolve-me'), 'finalized');
    },
  );

  test(
    'recovery continuation is idempotent and rejects active sessions',
    () async {
      await _save(
        repository,
        _meeting(
          'continue-me',
          createdAt: 1,
          lifecycle: MeetingLifecycle.recoverable,
        ),
      );
      await _save(
        repository,
        _meeting(
          'already-final',
          createdAt: 2,
        ),
      );

      final continued = await _ok(
        repository.resolveRecovery(
          'continue-me',
          RecoveryResolution.continueRecording,
          atUtcMs: 20,
        ),
      );
      final repeated = await _ok(
        repository.resolveRecovery(
          'continue-me',
          RecoveryResolution.continueRecording,
          atUtcMs: 30,
        ),
      );
      final invalid = await repository.resolveRecovery(
        'already-final',
        RecoveryResolution.continueRecording,
        atUtcMs: 40,
      );

      expect(continued.lifecycle, MeetingLifecycle.recording);
      expect(repeated.lifecycle, MeetingLifecycle.recording);
      expect(await _lifecycle(database, 'continue-me'), 'recording');
      expect(invalid, isA<Err<Meeting, SessionRepositoryFailure>>());
      expect(
        (invalid as Err<Meeting, SessionRepositoryFailure>).failure.code,
        'session_invalid_lifecycle',
      );
      expect(await _lifecycle(database, 'already-final'), 'finalized');
    },
  );
}

Meeting _meeting(
  String id, {
  required int createdAt,
  String? title,
  MeetingLifecycle lifecycle = MeetingLifecycle.finalized,
  MeetingTranscriptionMode transcriptionMode =
      MeetingTranscriptionMode.postSession,
  int? expectedSpeakerCount,
}) => Meeting(
  id: id,
  title: title ?? id,
  createdAtUtcMs: createdAt,
  mediaDuration: Duration.zero,
  lifecycle: lifecycle,
  languageMode: MeetingLanguageMode.mixed,
  transcriptionMode: transcriptionMode,
  expectedSpeakerCount: expectedSpeakerCount,
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

Future<int> _meetingDurationUs(db.AppDatabase database, String id) async {
  final row = await database
      .customSelect(
        'SELECT media_duration_us FROM meetings WHERE id = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();
  return row.read<int>('media_duration_us');
}

Future<List<int>> _recoveryRevisions(
  db.AppDatabase database,
  String meetingId,
) async {
  final meeting = await database
      .customSelect(
        'SELECT updated_at, row_revision FROM meetings WHERE id = ?',
        variables: [Variable<String>(meetingId)],
      )
      .getSingle();
  final audio = await database
      .customSelect(
        'SELECT updated_at, row_revision FROM audio_segments WHERE meeting_id = ?',
        variables: [Variable<String>(meetingId)],
      )
      .getSingle();
  return <int>[
    meeting.read<int>('updated_at'),
    meeting.read<int>('row_revision'),
    audio.read<int>('updated_at'),
    audio.read<int>('row_revision'),
  ];
}

AppRelativePath _path(String value) => AppRelativePath.tryParse(value).fold(
  (path) => path,
  (failure) => throw TestFailure('Invalid fixture path: ${failure.code}'),
);

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
