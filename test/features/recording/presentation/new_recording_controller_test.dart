import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';

void main() {
  test('loads the locally remembered recording setup', () async {
    final repository = FakeSessionRepository()
      ..recordingDefaults = const RecordingDefaults(
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        languageMode: MeetingLanguageMode.chinese,
        expectedSpeakerCount: 4,
      );
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        audioCaptureServiceProvider.overrideWithValue(capture),
      ],
    );

    final state = await container.read(newRecordingControllerProvider.future);

    expect(
      state,
      const NewRecordingState(
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        languageMode: MeetingLanguageMode.chinese,
        expectedSpeakerCount: 4,
      ),
    );
  });

  test('persists setup and meeting before starting native capture', () async {
    final repository = FakeSessionRepository();
    final capture = FakeAudioCaptureService()
      ..startResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-fixed',
          state: AudioCaptureState.recording,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        audioCaptureServiceProvider.overrideWithValue(capture),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2026, 10, 1, 2, 3)),
        ),
        meetingIdFactoryProvider.overrideWithValue(() => 'meeting-fixed'),
      ],
    );
    final subscription = container.listen(
      newRecordingControllerProvider,
      (_, _) {},
    );
    final recordingSubscription = container.listen(
      recordingControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    addTearDown(recordingSubscription.close);
    await container.read(recordingControllerProvider.future);
    await container.read(newRecordingControllerProvider.future);
    container.read(newRecordingControllerProvider.notifier)
      ..selectTranscriptionMode(MeetingTranscriptionMode.nearRealTime)
      ..selectLanguageMode(MeetingLanguageMode.english)
      ..selectExpectedSpeakerCount(6)
      ..start(title: 'Meeting · October 1, 2026 · 10:03 AM');
    await pumpEventQueue();

    expect(
      repository.recordingDefaults,
      const RecordingDefaults(
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        languageMode: MeetingLanguageMode.english,
        expectedSpeakerCount: 6,
      ),
    );
    expect(repository.savedMeetings, hasLength(2));
    expect(
      repository.savedMeetings.first,
      const Meeting(
        id: 'meeting-fixed',
        title: 'Meeting · October 1, 2026 · 10:03 AM',
        createdAtUtcMs: 1790820180000,
        mediaDuration: Duration.zero,
        lifecycle: MeetingLifecycle.preparing,
        languageMode: MeetingLanguageMode.english,
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        expectedSpeakerCount: 6,
      ),
    );
    expect(capture.startRequests.single.sessionId, 'meeting-fixed');
    expect(repository.savedMeetings.last.lifecycle, MeetingLifecycle.recording);
    expect(repository.synchronizedRecordingProgress, [
      (
        meetingId: 'meeting-fixed',
        lifecycle: MeetingLifecycle.recording,
        duration: Duration.zero,
      ),
    ]);
    expect(
      container.read(newRecordingControllerProvider).requireValue.status,
      NewRecordingStatus.started,
    );
    expect(
      container.read(newRecordingControllerProvider).requireValue.canStart,
      isFalse,
    );
    expect(
      container
          .read(newRecordingControllerProvider)
          .requireValue
          .startedMeetingId,
      'meeting-fixed',
    );
  });

  test(
    'retry reuses the same durable draft identity and creation time',
    () async {
      var now = DateTime.utc(2026, 10, 1, 2, 3);
      var generatedIds = 0;
      final repository = FakeSessionRepository();
      final capture = FakeAudioCaptureService()
        ..startResult = const Err(
          AudioCaptureInsufficientStorage(
            code: 'recording_storage_preflight_insufficient',
            availableBytes: 100,
            requiredBytes: 200,
          ),
        );
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          audioCaptureServiceProvider.overrideWithValue(capture),
          clockProvider.overrideWithValue(Clock(() => now)),
          meetingIdFactoryProvider.overrideWithValue(() {
            generatedIds += 1;
            return 'meeting-$generatedIds';
          }),
        ],
      );
      final subscription = container.listen(
        newRecordingControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(newRecordingControllerProvider.future);

      container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'Stable title');
      await pumpEventQueue();
      expect(
        container.read(newRecordingControllerProvider).requireValue.status,
        NewRecordingStatus.failed,
      );
      final failure = container
          .read(newRecordingControllerProvider)
          .requireValue
          .failure;
      if (failure case NewRecordingCaptureFailure(
        :final availableBytes,
        :final requiredBytes,
      )) {
        expect(availableBytes, 100);
        expect(requiredBytes, 200);
      } else {
        fail('Expected structured storage preflight failure, got $failure');
      }
      expect(repository.discardedUnstartedMeetingIds, ['meeting-1']);

      now = now.add(const Duration(minutes: 5));
      capture.startResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.recording,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );
      container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'Changed retry title');
      await pumpEventQueue();

      expect(generatedIds, 1);
      expect(repository.savedMeetings.map((meeting) => meeting.id).toSet(), {
        'meeting-1',
      });
      expect(
        repository.savedMeetings
            .map((meeting) => meeting.createdAtUtcMs)
            .toSet(),
        {1790820180000},
      );
    },
  );

  test(
    'ambiguous start timeout preserves meeting and disables retry',
    () async {
      final repository = FakeSessionRepository();
      final capture = FakeAudioCaptureService()
        ..startResult = const Err(
          AudioCaptureUnavailable('recording_command_timeout'),
        );
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          audioCaptureServiceProvider.overrideWithValue(capture),
          meetingIdFactoryProvider.overrideWithValue(() => 'meeting-timeout'),
        ],
      );
      final subscription = container.listen(
        newRecordingControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(newRecordingControllerProvider.future);

      container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'Timeout meeting');
      await pumpEventQueue();

      final state = container.read(newRecordingControllerProvider).requireValue;
      expect(repository.discardedUnstartedMeetingIds, isEmpty);
      expect(repository.savedMeetings.single.id, 'meeting-timeout');
      expect(state.failure, isA<NewRecordingCaptureOutcomeUnknown>());
      expect(state.canStart, isFalse);
    },
  );

  test('ambiguous start adopts authoritative active native state', () async {
    final repository = FakeSessionRepository();
    final capture = FakeAudioCaptureService()
      ..startResult = const Err(
        AudioCaptureUnavailable('recording_command_timeout'),
      )
      ..currentResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-active',
          state: AudioCaptureState.recording,
          elapsed: Duration(seconds: 2),
          bytesWritten: 128,
          revision: 2,
        ),
      );
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        audioCaptureServiceProvider.overrideWithValue(capture),
        meetingIdFactoryProvider.overrideWithValue(() => 'meeting-active'),
      ],
    );
    final subscription = container.listen(
      newRecordingControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(newRecordingControllerProvider.future);

    container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Active meeting');
    await pumpEventQueue();

    final state = container.read(newRecordingControllerProvider).requireValue;
    expect(repository.discardedUnstartedMeetingIds, isEmpty);
    expect(state.status, NewRecordingStatus.started);
    expect(state.startedMeetingId, 'meeting-active');
    expect(state.canStart, isFalse);
  });

  test('cleanup refusal cannot return to ordinary start retry', () async {
    final repository = FakeSessionRepository()
      ..discardUnstartedMeetingFailure = const SessionInvalidLifecycle();
    final capture = FakeAudioCaptureService()
      ..startResult = const Err(
        AudioCaptureInsufficientStorage(
          code: 'recording_storage_preflight_insufficient',
          availableBytes: 100,
          requiredBytes: 200,
        ),
      );
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        audioCaptureServiceProvider.overrideWithValue(capture),
        meetingIdFactoryProvider.overrideWithValue(() => 'meeting-protected'),
      ],
    );
    final subscription = container.listen(
      newRecordingControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(newRecordingControllerProvider.future);

    container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Protected meeting');
    await pumpEventQueue();

    final state = container.read(newRecordingControllerProvider).requireValue;
    expect(repository.discardedUnstartedMeetingIds, ['meeting-protected']);
    expect(state.failure, isA<NewRecordingCleanupFailure>());
    expect(state.canStart, isFalse);

    container.read(newRecordingControllerProvider.notifier)
      ..selectLanguageMode(MeetingLanguageMode.chinese)
      ..start(title: 'Unsafe retry');
    await pumpEventQueue();

    final protectedState = container
        .read(newRecordingControllerProvider)
        .requireValue;
    expect(protectedState.failure, isA<NewRecordingCleanupFailure>());
    expect(protectedState.canStart, isFalse);
    expect(capture.startRequests, hasLength(1));
  });
}
