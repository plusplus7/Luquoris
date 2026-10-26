import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  final crossMeeting =
      jsonDecode(
            File(
              'contracts/remote_transcription/v1/fixtures/result.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  crossMeeting['meetingId'] = 'other-meeting';
  for (final malformed in ['{broken', jsonEncode(crossMeeting)]) {
    test(
      'reject invalid remote result before restore writes: $malformed',
      () async {
        final source = AppDatabase(NativeDatabase.memory());
        final target = AppDatabase(NativeDatabase.memory());
        addTearDown(source.close);
        addTearDown(target.close);
        await source
            .into(source.meetings)
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
        await source.customStatement(
          'INSERT INTO remote_transcript_versions(id,meeting_id,result_json,created_at_utc_ms,created_at,updated_at) VALUES (?,?,?,?,?,?)',
          ['run-1', 'meeting-1', malformed, 1, 1, 1],
        );
        final result =
            await DriftRestoreImporter(
              liveDatabase: target,
              restoredCopyTitle: (v) => v,
            ).import(
              source,
              sourceAudioFingerprints: {'meeting-1': 'a' * 64},
              liveAudioFingerprint: (_) async => null,
            );
        expect(result, isA<Err<RestoreImportReceipt, RestoreImportFailure>>());
        expect(await target.select(target.meetings).get(), isEmpty);
      },
    );
  }
  test(
    'restore preserves remote corrections while disabling all remote work',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      await source
          .into(source.meetings)
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
      await source
          .into(source.remoteTranscriptionTasks)
          .insert(
            RemoteTranscriptionTasksCompanion.insert(
              id: 'run-1',
              meetingId: 'meeting-1',
              endpoint: 'https://server.example',
              credentialRef: 'secret-reference',
              profileId: 'qwen-1.7b',
              createdAtUtcMs: 1,
              updatedAtUtcMs: 1,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final json = File(
        'contracts/remote_transcription/v1/fixtures/result.json',
      ).readAsStringSync();
      await source.customStatement(
        'INSERT INTO remote_transcript_versions(id,meeting_id,result_json,edited_text,created_at_utc_ms,created_at,updated_at) VALUES (?,?,?,?,?,?,?)',
        ['run-1', 'meeting-1', json, 'human correction', 1, 1, 1],
      );
      final importer = DriftRestoreImporter(
        liveDatabase: target,
        restoredCopyTitle: (value) => '$value restored',
      );
      final result = await importer.import(
        source,
        sourceAudioFingerprints: {'meeting-1': 'a' * 64},
        liveAudioFingerprint: (_) async => null,
      );
      expect(result, isA<Ok<RestoreImportReceipt, RestoreImportFailure>>());
      final tasks = await target.select(target.remoteTranscriptionTasks).get();
      expect(tasks.single.state, 'restored');
      expect(tasks.single.credentialRef, isEmpty);
      final versions = await target
          .select(target.remoteTranscriptVersions)
          .get();
      expect(versions.single.resultJson, json);
      expect(versions.single.editedText, 'human correction');
      expect(await target.select(target.modelManifests).get(), isEmpty);
      await (target.update(target.meetings)
            ..where((r) => r.id.equals('meeting-1')))
          .write(const MeetingsCompanion(title: Value('local correction')));
      final conflict = await importer.import(
        source,
        sourceAudioFingerprints: {'meeting-1': 'a' * 64},
        liveAudioFingerprint: (_) async => null,
      );
      final receipt =
          (conflict as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      expect(receipt.meetings.single.wasConflictingCopy, isTrue);
      final copyId = receipt.meetings.single.meetingId;
      final repository = DriftRemoteTranscriptionRepository(
        target,
        service: _UnusedPlatform(),
        newId: () => 'unused',
        nowUtcMs: () => 1,
      );
      final copy = await repository.load(copyId);
      switch (copy) {
        case Ok(:final value):
          expect(value.$2.single.displayedText, 'human correction');
        case Err():
          fail('restored copy cannot read original result identity');
      }
      final repeated = await importer.import(
        source,
        sourceAudioFingerprints: {'meeting-1': 'a' * 64},
        liveAudioFingerprint: (_) async => 'a' * 64,
      );
      expect(
        (repeated as Ok<RestoreImportReceipt, RestoreImportFailure>)
            .value
            .skippedCount,
        1,
      );
    },
  );
}

final class _UnusedPlatform implements RemoteTranscriptionService {
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  ) => saveCredential(endpoint, token);

  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async => const Ok(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
