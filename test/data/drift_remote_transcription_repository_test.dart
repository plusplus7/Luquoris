import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  late AppDatabase db;
  late DriftRemoteTranscriptionRepository repository;
  var ids = 0;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.meetings)
        .insert(
          MeetingsCompanion.insert(
            id: 'meeting-1',
            title: 'meeting',
            lifecycle: 'finalized',
            languageMode: 'mixed',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    repository = DriftRemoteTranscriptionRepository(
      db,
      service: _Platform(),
      newId: () => 'run-${++ids}',
      nowUtcMs: () => 2,
    );
  });
  tearDown(() => db.close());
  test(
    'rejects insecure destination before any durable task is created',
    () async {
      final result = await repository.enqueue(
        'meeting-1',
        destination: const RemoteDestination(
          'http://server',
          'credential',
          'qwen-1.7b',
        ),
      );
      expect(result, isA<Err<String, RemoteTranscriptionFailure>>());
      expect(await db.select(db.remoteTranscriptionTasks).get(), isEmpty);
    },
  );
  test(
    'missing configuration preserves intent without installing local models',
    () async {
      expect(
        await repository.enqueue('meeting-1'),
        isA<Ok<String, RemoteTranscriptionFailure>>(),
      );
      final rows = await db.select(db.remoteTranscriptionTasks).get();
      expect(rows.single.state, 'waitingSetup');
      expect(await db.select(db.modelManifests).get(), isEmpty);
    },
  );
  test('binding and cancellation retain request identity', () async {
    final result =
        await repository.enqueue('meeting-1')
            as Ok<String, RemoteTranscriptionFailure>;
    expect(
      await repository.configure(
        'meeting-1',
        const RemoteDestination('https://server.example', 'ref', 'qwen-1.7b'),
      ),
      isA<Ok<void, RemoteTranscriptionFailure>>(),
    );
    await repository.cancel(result.value);
    expect(
      (await db.select(db.remoteTranscriptionTasks).get()).single.state,
      'cancelled',
    );
    await repository.configure(
      'meeting-1',
      const RemoteDestination('https://other.example', 'other', 'qwen-1.7b'),
    );
    expect(
      (await db.select(db.remoteTranscriptionTasks).get()).single.endpoint,
      'https://server.example',
    );
  });
  test('human edit never replaces raw remote result', () async {
    final json = File(
      'contracts/remote_transcription/v1/fixtures/result.json',
    ).readAsStringSync();
    await db
        .into(db.remoteTranscriptVersions)
        .insert(
          RemoteTranscriptVersionsCompanion.insert(
            id: 'run-1',
            meetingId: 'meeting-1',
            resultJson: json,
            createdAtUtcMs: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await repository.edit('run-1', 'human correction');
    final row = (await db.select(db.remoteTranscriptVersions).get()).single;
    expect(row.resultJson, json);
    expect(row.editedText, 'human correction');
    final loaded = await repository.load('meeting-1');
    expect(
      loaded,
      isA<
        Ok<(List<RemoteTask>, List<RemoteVersion>), RemoteTranscriptionFailure>
      >(),
    );
  });
}

class _Platform implements RemoteTranscriptionService {
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  ) => saveCredential(endpoint, token);

  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async => const Ok(null);

  @override
  Future<Result<void, RemoteTranscriptionFailure>> prepareDatabase() async =>
      const Ok(null);
  @override
  Future<Result<void, RemoteTranscriptionFailure>> resume(String path) async =>
      const Ok(null);
  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() async =>
      const Ok(null);
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveCredential(
    String endpoint,
    String token,
  ) async => const Ok('ref');
}
