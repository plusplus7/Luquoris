import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  test(
    'default connection can be read without a meeting or remote task',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftRemoteTranscriptionRepository(
        db,
        service: _Platform(),
        newId: () => 'run',
        nowUtcMs: () => 2,
      );
      final loaded = await repository.latestDestination();
      final destination =
          (loaded as Ok<RemoteDestination?, RemoteTranscriptionFailure>).value;
      expect(destination?.endpoint, 'http://192.168.1.20:18000');
      expect(await db.select(db.meetings).get(), isEmpty);
      expect(await db.select(db.remoteTranscriptionTasks).get(), isEmpty);
    },
  );
  test(
    'saving settings binds only opted-in unconfigured work, never restored runs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.meetings)
          .insert(
            MeetingsCompanion.insert(
              id: 'meeting',
              title: 'recording',
              lifecycle: 'finalized',
              languageMode: 'mixed',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      for (final state in ['waitingSetup', 'restored', 'cancelled', 'queued']) {
        await db
            .into(db.remoteTranscriptionTasks)
            .insert(
              RemoteTranscriptionTasksCompanion.insert(
                id: state,
                meetingId: 'meeting',
                endpoint: state == 'queued' ? 'https://original.example' : '',
                credentialRef: state == 'queued' ? 'original' : '',
                profileId: 'qwen-1.7b',
                state: Value(state),
                createdAtUtcMs: 1,
                updatedAtUtcMs: 1,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }
      final repository = DriftRemoteTranscriptionRepository(
        db,
        service: _Platform(),
        newId: () => 'unused',
        nowUtcMs: () => 2,
      );
      await repository.configurePending(
        const RemoteDestination(
          'http://192.168.1.20:18000',
          'reference',
          'qwen-1.7b',
        ),
      );
      final rows = await db.select(db.remoteTranscriptionTasks).get();
      expect(rows.length, 4);
      final pending = rows.singleWhere((r) => r.id == 'waitingSetup');
      expect(pending.state, 'waitingAudio');
      expect(pending.endpoint, 'http://192.168.1.20:18000');
      expect(rows.singleWhere((r) => r.id == 'restored').state, 'restored');
      expect(rows.singleWhere((r) => r.id == 'restored').endpoint, isEmpty);
      expect(rows.singleWhere((r) => r.id == 'cancelled').state, 'cancelled');
      expect(
        rows.singleWhere((r) => r.id == 'queued').endpoint,
        'https://original.example',
      );
    },
  );
}

final class _Platform implements RemoteTranscriptionService {
  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async =>
      const Ok(RemoteSavedConnection('http://192.168.1.20:18000', 'reference'));
  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() async =>
      const Ok(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
