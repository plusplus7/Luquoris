import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';

void main() {
  const restored = AudioCaptureSnapshot(
    sessionId: 'meeting-1',
    state: AudioCaptureState.recording,
    elapsed: Duration(minutes: 3),
    bytesWritten: 1440,
    revision: 8,
  );

  test('restores active native state when the view model starts', () async {
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(restored);
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        sessionRepositoryProvider.overrideWithValue(_repositoryWithMeeting()),
      ],
    );

    final state = await container.read(recordingControllerProvider.future);

    expect(state, const RecordingViewState(snapshot: restored));
    expect(capture.currentCalls, 1);
  });

  test(
    'restoration synchronizes authoritative native progress to Drift',
    () async {
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(restored);
      final repository = FakeSessionRepository()
        ..savedMeetings.add(
          const Meeting(
            id: 'meeting-1',
            title: 'Meeting',
            createdAtUtcMs: 1,
            mediaDuration: Duration.zero,
            lifecycle: MeetingLifecycle.preparing,
            languageMode: MeetingLanguageMode.mixed,
          ),
        );
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final state = await container.read(recordingControllerProvider.future);

      expect(state.persistenceFailure, isNull);
      expect(repository.synchronizedRecordingProgress, [
        (
          meetingId: 'meeting-1',
          lifecycle: MeetingLifecycle.recording,
          duration: const Duration(minutes: 3),
        ),
      ]);
    },
  );

  test(
    'persistence warning survives and a later snapshot retries it',
    () async {
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(restored);
      final repository = _repositoryWithMeeting()
        ..synchronizeRecordingProgressFailure =
            const SessionRepositoryUnavailable(
              'recording_progress_sync_failed',
            );
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final initial = await container.read(recordingControllerProvider.future);
      expect(
        initial.persistenceFailure?.code,
        'recording_progress_sync_failed',
      );

      repository.synchronizeRecordingProgressFailure = null;
      capture.emitSnapshot(
        const AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.recording,
          elapsed: Duration(minutes: 4),
          bytesWritten: 1920,
          revision: 9,
        ),
      );
      await pumpEventQueue();

      expect(
        container
            .read(recordingControllerProvider)
            .requireValue
            .persistenceFailure,
        isNull,
      );
      expect(repository.synchronizedRecordingProgress, hasLength(2));
    },
  );

  test('keeps native subscription while screen listeners are absent', () async {
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(restored);
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        sessionRepositoryProvider.overrideWithValue(_repositoryWithMeeting()),
      ],
    );
    final subscription = container.listen(
      recordingControllerProvider,
      (_, _) {},
    );
    await container.read(recordingControllerProvider.future);
    subscription.close();

    const paused = AudioCaptureSnapshot(
      sessionId: 'meeting-1',
      state: AudioCaptureState.pausedByInterruption,
      elapsed: Duration(minutes: 4),
      bytesWritten: 1920,
      revision: 9,
    );
    capture.emitSnapshot(paused);
    await pumpEventQueue();

    expect(
      container.read(recordingControllerProvider).requireValue,
      const RecordingViewState(snapshot: paused),
    );
  });

  test(
    'does not overwrite a newer snapshot observed during restoration',
    () async {
      const newer = AudioCaptureSnapshot(
        sessionId: 'meeting-1',
        state: AudioCaptureState.pausedByUser,
        elapsed: Duration(minutes: 4),
        bytesWritten: 1920,
        revision: 9,
      );
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(restored);
      capture.beforeCurrentResult = () => capture.emitSnapshot(newer);
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(
            _repositoryWithMeeting(),
          ),
        ],
      );

      final state = await container.read(recordingControllerProvider.future);

      expect(state, const RecordingViewState(snapshot: newer));
    },
  );

  test('serializes restoration persistence before a newer snapshot', () async {
    final firstSync = Completer<Result<Meeting, SessionRepositoryFailure>>();
    final secondSync = Completer<Result<Meeting, SessionRepositoryFailure>>();
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(restored);
    final repository = _repositoryWithMeeting();
    var syncIndex = 0;
    repository.synchronizeRecordingProgressOverride =
        (
          meetingId, {
          required lifecycle,
          required mediaDuration,
          required atUtcMs,
        }) {
          syncIndex += 1;
          return syncIndex == 1 ? firstSync.future : secondSync.future;
        };
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final restoring = container.read(recordingControllerProvider.future);
    await pumpEventQueue();
    expect(repository.synchronizedRecordingProgress, hasLength(1));

    const newer = AudioCaptureSnapshot(
      sessionId: 'meeting-1',
      state: AudioCaptureState.pausedByUser,
      elapsed: Duration(minutes: 4),
      bytesWritten: 1920,
      revision: 9,
    );
    capture.emitSnapshot(newer);
    await pumpEventQueue();
    expect(repository.synchronizedRecordingProgress, hasLength(1));

    firstSync.complete(Ok(repository.savedMeetings.single));
    await pumpEventQueue();
    expect(repository.synchronizedRecordingProgress, hasLength(2));
    secondSync.complete(Ok(repository.savedMeetings.single));

    expect(await restoring, const RecordingViewState(snapshot: newer));
  });

  test(
    'command failure remains visible with the last durable snapshot',
    () async {
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(restored)
        ..pauseResult = const Err(AudioCaptureUnavailable('audio_focus_lost'));
      addTearDown(capture.dispose);
      final container = ProviderContainer.test(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(
            _repositoryWithMeeting(),
          ),
        ],
      );
      await container.read(recordingControllerProvider.future);

      container.read(recordingControllerProvider.notifier).pause();
      await pumpEventQueue();

      expect(
        container.read(recordingControllerProvider).requireValue,
        const RecordingViewState(
          snapshot: restored,
          failure: AudioCaptureUnavailable('audio_focus_lost'),
        ),
      );
      expect(capture.pauseCalls, 1);
    },
  );

  test('late command success cannot replace a newer native revision', () async {
    final pauseCompleter =
        Completer<Result<AudioCaptureSnapshot, AudioCaptureFailure>>();
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(restored)
      ..pendingPauseResult = pauseCompleter.future;
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(capture),
        sessionRepositoryProvider.overrideWithValue(_repositoryWithMeeting()),
      ],
    );
    await container.read(recordingControllerProvider.future);

    container.read(recordingControllerProvider.notifier).pause();
    const newest = AudioCaptureSnapshot(
      sessionId: 'meeting-1',
      state: AudioCaptureState.pausedByInterruption,
      elapsed: Duration(minutes: 5),
      bytesWritten: 2400,
      revision: 10,
    );
    capture.emitSnapshot(newest);
    pauseCompleter.complete(
      const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.pausedByUser,
          elapsed: Duration(minutes: 4),
          bytesWritten: 1920,
          revision: 9,
        ),
      ),
    );
    await pumpEventQueue();

    expect(
      container.read(recordingControllerProvider).requireValue,
      const RecordingViewState(snapshot: newest),
    );
  });
}

FakeSessionRepository _repositoryWithMeeting() =>
    FakeSessionRepository()
      ..savedMeetings.add(
        const Meeting(
          id: 'meeting-1',
          title: 'Meeting',
          createdAtUtcMs: 1,
          mediaDuration: Duration.zero,
          lifecycle: MeetingLifecycle.preparing,
          languageMode: MeetingLanguageMode.mixed,
        ),
      );
