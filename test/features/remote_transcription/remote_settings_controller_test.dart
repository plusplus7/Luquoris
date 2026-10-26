import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/features/remote_transcription/application/remote_settings_controller.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  test(
    'saving server settings persists a default without creating a meeting or job',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        remoteSettingsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(remoteSettingsControllerProvider.future);
      await fixture.container
          .read(remoteSettingsControllerProvider.notifier)
          .save('http://192.168.1.20:18000', 'a' * 32);
      expect(
        (await fixture.repository.latestDestination()
                as Ok<RemoteDestination?, RemoteTranscriptionFailure>)
            .value
            ?.endpoint,
        'http://192.168.1.20:18000',
      );
      expect(
        await fixture.database.select(fixture.database.meetings).get(),
        isEmpty,
      );
      expect(
        await fixture.database
            .select(fixture.database.remoteTranscriptionTasks)
            .get(),
        isEmpty,
      );
    },
  );
  test(
    'leaving settings during credential save does not abandon opted-in pending work',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.database
          .into(fixture.database.meetings)
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
      await fixture.repository.enqueue('meeting');
      fixture.platform.gate = Completer<void>();
      final subscription = fixture.container.listen(
        remoteSettingsControllerProvider,
        (_, _) {},
      );
      await fixture.container.read(remoteSettingsControllerProvider.future);
      final saving = fixture.container
          .read(remoteSettingsControllerProvider.notifier)
          .save('http://192.168.1.20:18000', 'a' * 32);
      subscription.close();
      await fixture.container.pump();
      fixture.platform.gate!.complete();
      await saving;
      expect(
        (await fixture.database
                .select(fixture.database.remoteTranscriptionTasks)
                .get())
            .single
            .state,
        'waitingAudio',
      );
    },
  );
  test(
    'reopening settings reconciles a saved connection with pending consented work',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      fixture.platform.saved = const RemoteSavedConnection(
        'http://192.168.1.20:18000',
        'reference',
      );
      await fixture.database
          .into(fixture.database.meetings)
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
      await fixture.repository.enqueue('meeting');
      final subscription = fixture.container.listen(
        remoteSettingsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(remoteSettingsControllerProvider.future);
      expect(
        (await fixture.database
                .select(fixture.database.remoteTranscriptionTasks)
                .get())
            .single
            .state,
        'waitingAudio',
      );
    },
  );
}

final class _Fixture {
  _Fixture() {
    repository = DriftRemoteTranscriptionRepository(
      database,
      service: platform,
      newId: () => 'run',
      nowUtcMs: () => 2,
    );
    container = ProviderContainer(
      overrides: [
        remoteTranscriptionServiceProvider.overrideWithValue(platform),
        remoteTranscriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }
  final database = AppDatabase(NativeDatabase.memory());
  final platform = _Platform();
  late final DriftRemoteTranscriptionRepository repository;
  late final ProviderContainer container;
  Future<void> close() async {
    container.dispose();
    await database.close();
  }
}

final class _Platform implements RemoteTranscriptionService {
  RemoteSavedConnection? saved;
  Completer<void>? gate;
  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async => Ok(saved);
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  ) async {
    if (gate != null) await gate!.future;
    saved = RemoteSavedConnection(endpoint, 'reference');
    return const Ok('reference');
  }

  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() async =>
      const Ok(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
