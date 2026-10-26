import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  test('task creation follows the shared LAN origin policy', () async {
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
    var id = 0;
    final repository = DriftRemoteTranscriptionRepository(
      db,
      service: _Platform(),
      newId: () => 'run-${id++}',
      nowUtcMs: () => 2,
    );
    for (final line in File(
      'contracts/remote_transcription/v1/endpoints.tsv',
    ).readAsLinesSync()) {
      if (line.startsWith('#') || line.isEmpty) continue;
      final fields = line.split('\t');
      final before =
          (await db.select(db.remoteTranscriptionTasks).get()).length;
      final result = await repository.enqueue(
        'meeting',
        destination: RemoteDestination(fields[1], 'reference', 'qwen-1.7b'),
      );
      expect(
        result is Ok<String, RemoteTranscriptionFailure>,
        fields[0] == '1',
        reason: fields[1],
      );
      final after = (await db.select(db.remoteTranscriptionTasks).get()).length;
      expect(after - before, fields[0] == '1' ? 1 : 0);
    }
  });
}

final class _Platform implements RemoteTranscriptionService {
  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() async =>
      const Ok(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
