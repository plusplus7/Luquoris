import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/recording/presentation/active_recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';
import '../../../support/harness.dart';

void main() {
  const recording = AudioCaptureSnapshot(
    sessionId: 'meeting-1',
    state: AudioCaptureState.recording,
    elapsed: Duration(hours: 1, minutes: 2, seconds: 3),
    bytesWritten: 1536 * 1024,
    revision: 8,
    inputHealth: AudioInputHealthSnapshot(
      readCalls: 48,
      pcmBytes: 196608,
      shortReads: 0,
      zeroReads: 0,
      errorReads: 0,
      maximumReadGap: Duration(milliseconds: 22),
      timestampRegressions: 1,
    ),
  );

  testWidgets('shows authoritative status, timer, size, and input activity', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(recording);
    addTearDown(capture.dispose);
    final repository = FakeSessionRepository()
      ..savedMeetings.add(_recordingMeeting);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(context)
        .read(appRouterProvider)
        .go(
          '/recordings/meeting-1',
        );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-recording-status')), findsOneWidget);
    expect(find.text('01:02:03'), findsOneWidget);
    expect(find.text('Recorded audio size 1.5 MB'), findsOneWidget);
    expect(
      find.byKey(const Key('active-recording-input-activity')),
      findsOneWidget,
    );
    expect(find.text('Microphone data received'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Microphone data received'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('active-recording-pause')), findsOneWidget);
    expect(find.byKey(const Key('active-recording-stop')), findsOneWidget);
  });

  testWidgets('system-interrupted recording offers an explicit resume action', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.pausedByInterruption,
          elapsed: Duration(seconds: 12),
          bytesWritten: 4096,
          revision: 9,
        ),
      )
      ..resumeResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.recording,
          elapsed: Duration(seconds: 12),
          bytesWritten: 4096,
          revision: 10,
        ),
      );
    addTearDown(capture.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/recordings/meeting-1');
    await tester.pumpAndSettle();

    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.byKey(const Key('active-recording-pause')));
    await tester.pump();

    expect(capture.resumeCalls, 1);
  });

  testWidgets('pause, bookmark, highlight, and confirmed stop are explicit', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(recording)
      ..pauseResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.pausedByUser,
          elapsed: Duration(hours: 1, minutes: 2, seconds: 3),
          bytesWritten: 1536 * 1024,
          revision: 9,
        ),
      );
    addTearDown(capture.dispose);
    final repository = FakeSessionRepository()
      ..savedMeetings.add(_recordingMeeting);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(Clock.fixed(DateTime.utc(2026))),
          bookmarkIdFactoryProvider.overrideWithValue(
            (kind) => '${kind.name}-fixed',
          ),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(context)
        .read(appRouterProvider)
        .go(
          '/recordings/meeting-1',
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('active-recording-pause')));
    await tester.pumpAndSettle();
    expect(capture.pauseCalls, 1);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.byKey(const Key('active-recording-bookmark')));
    await tester.tap(find.byKey(const Key('active-recording-highlight')));
    await tester.pumpAndSettle();
    expect(repository.savedBookmarks, [
      const Bookmark(
        id: 'bookmark-fixed',
        meetingId: 'meeting-1',
        mediaOffset: Duration(hours: 1, minutes: 2, seconds: 3),
        kind: BookmarkKind.bookmark,
        createdAtUtcMs: 1767225600000,
      ),
      const Bookmark(
        id: 'highlight-fixed',
        meetingId: 'meeting-1',
        mediaOffset: Duration(hours: 1, minutes: 2, seconds: 3),
        kind: BookmarkKind.highlight,
        createdAtUtcMs: 1767225600000,
      ),
    ]);

    await tester.tap(find.byKey(const Key('active-recording-stop')));
    await tester.pumpAndSettle();
    expect(capture.stopCalls, 0);
    expect(find.byKey(const Key('confirm-stop-recording')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-stop-recording')));
    await tester.pumpAndSettle();
    expect(capture.stopCalls, 1);
  });

  testWidgets('successful stop opens the finalized meeting detail', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(recording)
      ..stopResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.finalized,
          elapsed: Duration(seconds: 12),
          bytesWritten: 4096,
          revision: 9,
        ),
      );
    addTearDown(capture.dispose);
    final repository = FakeSessionRepository()
      ..savedMeetings.add(_recordingMeeting);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/recordings/meeting-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('active-recording-stop')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-stop-recording')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-detail:meeting-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-recording:meeting-1')),
      findsNothing,
    );
  });

  testWidgets('critical controls remain operable at two hundred percent text', (
    tester,
  ) async {
    tester.useDevice(TestDevice.constrained);
    final capture = FakeAudioCaptureService()
      ..currentResult = const Ok(recording);
    addTearDown(capture.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(capture),
          sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const LoquirisApp(),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(context)
        .read(appRouterProvider)
        .go(
          '/recordings/meeting-1',
        );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final key in <String>[
      'active-recording-pause',
      'active-recording-stop',
      'active-recording-bookmark',
      'active-recording-highlight',
    ]) {
      final finder = find.byKey(Key(key));
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets(
    'near-real-time draft appears without replacing recording controls',
    (
      tester,
    ) async {
      tester.useDevice(TestDevice.compact);
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(recording);
      final repository = FakeSessionRepository()
        ..detailResult = Ok(
          SessionDetail(
            meeting: _nearRealTimeMeeting,
            segments: const <AudioSegment>[],
            events: const <SessionEvent>[],
            bookmarks: const <Bookmark>[],
            processingJobs: const [],
            recoveryDiagnostics: const <SessionRecoveryDiagnostic>[],
          ),
        );
      final jobs = FakeTranscriptionJobRepository();
      final engine = FakeTranscriptionEngine();
      addTearDown(capture.dispose);
      addTearDown(engine.dispose);
      addTearDown(jobs.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(repository),
            transcriptionJobRepositoryProvider.overrideWithValue(jobs),
            transcriptionEngineProvider.overrideWithValue(engine),
            transcriptionModelManifestProvider.overrideWithValue(_manifest()),
          ],
          child: const LoquirisApp(),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(LoquirisApp));
      ProviderScope.containerOf(
        context,
      ).read(appRouterProvider).go('/recordings/meeting-1');
      await tester.pumpAndSettle();

      expect(engine.draftRequests, hasLength(1));
      engine.emit(
        TranscriptionDraftUpdated(
          runId: engine.draftRequests.single.runId,
          chunk: const TranscriptChunk(
            segmentId: 'segment-live',
            start: Duration.zero,
            end: Duration(seconds: 1),
            rawText: 'Local draft text',
            displayText: 'Local draft text',
            stability: TranscriptStability.unstable,
          ),
          backlog: Duration.zero,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('live-transcript-panel')), findsOneWidget);
      expect(find.text('Local draft text'), findsOneWidget);
      expect(find.byKey(const Key('active-recording-pause')), findsOneWidget);
      expect(find.byKey(const Key('active-recording-stop')), findsOneWidget);
      expect(
        find.byKey(const Key('active-recording-bookmark')),
        findsOneWidget,
      );
    },
  );
}

const _recordingMeeting = Meeting(
  id: 'meeting-1',
  title: 'Meeting',
  createdAtUtcMs: 1,
  mediaDuration: Duration.zero,
  lifecycle: MeetingLifecycle.recording,
  languageMode: MeetingLanguageMode.mixed,
);

const _nearRealTimeMeeting = Meeting(
  id: 'meeting-1',
  title: 'Meeting',
  createdAtUtcMs: 1,
  mediaDuration: Duration.zero,
  lifecycle: MeetingLifecycle.recording,
  languageMode: MeetingLanguageMode.mixed,
  transcriptionMode: MeetingTranscriptionMode.nearRealTime,
);

BundledModelManifest _manifest() =>
    (BundledModelManifest.tryParse(<String, Object?>{
              'schemaVersion': 1,
              'id': 'whisper-base-q5_1',
              'version': 'model-commit',
              'source': 'https://example.test/model.bin',
              'artifactPath': 'models/whisper-base-q5_1/model.bin',
              'sha256':
                  '0000000000000000000000000000000000000000000000000000000000000000',
              'bytes': 3,
              'runtime': <String, Object?>{
                'engineId': 'whisper_cpp',
                'modelFormat': 'ggml',
              },
              'license': <String, Object?>{
                'id': 'MIT',
                'snapshotPath': 'models/licenses/model.txt',
              },
              'capabilities': <Object?>['transcription'],
              'enabledModes': <Object?>['postSession'],
            })
            as Ok<BundledModelManifest, InvalidModelManifest>)
        .value;
