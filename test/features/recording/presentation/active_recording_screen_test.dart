import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/recording/application/recording_inventory_synchronizer.dart';
import 'package:loquiris/features/recording/presentation/active_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

import '../../../support/fake_streaming_transcription_engine.dart';
import '../../../support/fakes/fake_meeting_processing_selection_repository.dart';
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

  for (final scenario in [
    (device: TestDevice.compact, scale: 1.0),
    (device: TestDevice.smallLandscape, scale: 1.0),
    (device: TestDevice.compact, scale: 2.0),
  ]) {
    testWidgets(
      'growing live text preserves the pause hit target @ '
      '${scenario.device.name} x${scenario.scale}',
      (tester) async {
        tester.useDevice(scenario.device);
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
        final repository = FakeSessionRepository()
          ..savedMeetings.add(_recordingMeeting);
        final engine = _UiStreamingEngine();
        final adapter = StreamingLiveTranscriptAdapter(engine);
        const owner = StreamingOwner(
          meetingId: 'meeting-1',
          runId: 'stream-ui',
          epoch: 1,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await capture.dispose();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioCaptureServiceProvider.overrideWithValue(capture),
              sessionRepositoryProvider.overrideWithValue(repository),
              liveTranscriptSessionStarterProvider.overrideWithValue(
                (_) => adapter.open(
                  const StreamingStartRequest(
                    owner: owner,
                    modelId: 'explicit-ui-fixture',
                    bundleSha256:
                        '0000000000000000000000000000000000000000000000000000000000000000',
                    parameterVersion: 1,
                  ),
                ),
              ),
            ],
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scenario.scale),
                ),
                child: const LoquirisApp(),
              ),
            ),
          ),
        );
        await tester.pump();
        final context = tester.element(find.byType(LoquirisApp));
        final container = ProviderScope.containerOf(context);
        container.read(appRouterProvider).go('/recordings/meeting-1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        engine.native.deliver(
          StreamingUtterance(
            owner: owner,
            sequence: 0,
            utteranceId: 'u1',
            start: Duration.zero,
            end: const Duration(seconds: 1),
            rawText: 'Short draft',
            status: StreamingUtteranceStatus.provisional,
          ),
        );
        await tester.pump();
        final pause = find.byKey(const Key('active-recording-pause'));
        await tester.ensureVisible(pause);
        await tester.pump();
        final original = tester.getRect(pause);
        expect(original.height, greaterThanOrEqualTo(48));
        expect(pause.hitTestable(), findsOneWidget);
        engine.native.deliver(
          StreamingUtterance(
            owner: owner,
            sequence: 1,
            utteranceId: 'u1',
            start: Duration.zero,
            end: const Duration(seconds: 2),
            rawText: List.filled(40, 'A growing live hypothesis.').join('\n'),
            status: StreamingUtteranceStatus.provisional,
          ),
        );
        await tester.pump();
        expect(
          tester.getRect(pause).top,
          moreOrLessEquals(original.top, epsilon: .5),
          reason: 'A live text update must not move a critical control.',
        );
        expect(pause.hitTestable(), findsOneWidget);
        await tester.tapAt(original.center);
        await tester.pump();
        expect(
          container
              .read(recordingControllerProvider)
              .requireValue
              .snapshot
              ?.state,
          AudioCaptureState.pausedByUser,
        );
      },
    );
  }

  testWidgets(
    'finalized navigation keeps the last endpoint drain alive until ACK',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(recording);
      final repository = FakeSessionRepository()
        ..savedMeetings.add(_recordingMeeting);
      final source = StreamController<TranscriptionEvent>();
      final ack = Completer<Result<void, TranscriptionFailure>>();
      final inventory = _DelayedRecordingInventory();
      var finishes = 0;
      var cancellations = 0;
      addTearDown(capture.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(repository),
            recordingInventorySynchronizerProvider.overrideWithValue(inventory),
            liveTranscriptSessionStarterProvider.overrideWithValue(
              (meetingId) async => Ok(
                LiveTranscriptionSession(
                  meetingId: meetingId,
                  runId: 'endpoint',
                  events: source.stream,
                  finish: () async {
                    finishes++;
                    final result = await ack.future;
                    unawaited(source.close());
                    return result;
                  },
                  release: () async {
                    cancellations++;
                    return const Ok(null);
                  },
                ),
              ),
            ),
          ],
          child: const LoquirisApp(),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(LoquirisApp));
      final container = ProviderScope.containerOf(context);
      container.read(appRouterProvider).go('/recordings/meeting-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      capture.emitSnapshot(
        const AudioCaptureSnapshot(
          sessionId: 'meeting-1',
          state: AudioCaptureState.finalized,
          elapsed: Duration(seconds: 2),
          bytesWritten: 4096,
          revision: 9,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(finishes, 1);
      expect(cancellations, 0);
      expect(
        find.byKey(const ValueKey<String>('session-detail:meeting-1')),
        findsNothing,
      );
      inventory.completion.complete(const Ok(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(finishes, 1);
      expect(
        find.byKey(const ValueKey<String>('session-detail:meeting-1')),
        findsOneWidget,
      );
      source.add(
        const TranscriptionDraftUpdated(
          runId: 'endpoint',
          chunk: TranscriptChunk(
            segmentId: 'u1',
            start: Duration.zero,
            end: Duration(seconds: 2),
            rawText: 'Last endpoint',
            displayText: 'Last endpoint',
            stability: TranscriptStability.stable,
          ),
          backlog: Duration.zero,
        ),
      );
      await tester.pump();
      expect(
        container
            .read(liveTranscriptControllerProvider('meeting-1'))
            .requireValue
            .chunks
            .single
            .rawText,
        'Last endpoint',
      );
      ack.complete(const Ok(null));
      await tester.pump();
      await tester.pump();
      expect(cancellations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'streaming drafts, finals and gaps reach the real recording screen',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      final capture = FakeAudioCaptureService()
        ..currentResult = const Ok(recording);
      final repository = FakeSessionRepository()
        ..savedMeetings.add(_recordingMeeting);
      final engine = _UiStreamingEngine();
      final adapter = StreamingLiveTranscriptAdapter(engine);
      addTearDown(capture.dispose);
      const owner = StreamingOwner(
        meetingId: 'meeting-1',
        runId: 'stream-ui',
        epoch: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(repository),
            liveTranscriptSessionStarterProvider.overrideWithValue(
              (_) => adapter.open(
                const StreamingStartRequest(
                  owner: owner,
                  modelId: 'explicit-ui-fixture',
                  bundleSha256:
                      '0000000000000000000000000000000000000000000000000000000000000000',
                  parameterVersion: 1,
                ),
              ),
            ),
          ],
          child: const LoquirisApp(),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(LoquirisApp));
      ProviderScope.containerOf(
        context,
      ).read(appRouterProvider).go('/recordings/meeting-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      engine.native.deliver(
        StreamingUtterance(
          owner: owner,
          sequence: 0,
          utteranceId: 'u1',
          start: Duration.zero,
          end: const Duration(seconds: 1),
          rawText: '项目 offline draft',
          status: StreamingUtteranceStatus.provisional,
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Draft. 项目 offline draft'), findsOneWidget);
      engine.native.deliver(
        StreamingUtterance(
          owner: owner,
          sequence: 1,
          utteranceId: 'u1',
          start: Duration.zero,
          end: const Duration(seconds: 1),
          rawText: '项目 offline final',
          status: StreamingUtteranceStatus.finalized,
        ),
      );
      await tester.pump();
      expect(find.text('项目 offline draft'), findsNothing);
      expect(find.bySemanticsLabel('Stable. 项目 offline final'), findsOneWidget);
      engine.native.deliver(
        const StreamingGap(
          owner: owner,
          sequence: 2,
          captureEpoch: 1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          reason: StreamingGapReason.discontinuity,
        ),
      );
      await tester.pump();
      expect(find.textContaining('may be incomplete'), findsOneWidget);
      expect(find.text('Live transcription stopped safely.'), findsNothing);
      engine.native.deliver(
        StreamingUtterance(
          owner: owner,
          sequence: 3,
          utteranceId: 'u2',
          captureEpoch: 1,
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 3),
          rawText: 'Text after the gap',
          status: StreamingUtteranceStatus.provisional,
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel('Draft. Text after the gap'),
        findsOneWidget,
      );
      expect(find.text('项目 offline final'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('live-transcript-panel')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      final pause = find.byKey(const Key('active-recording-pause'));
      await tester.ensureVisible(pause);
      await tester.pump();
      expect(tester.getSize(pause).height, greaterThanOrEqualTo(48));
      await tester.tap(pause);
      await tester.pump();
      expect(capture.pauseCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(engine.releases, 1);
    },
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

  for (final inventoryFails in [false, true]) {
    testWidgets(
      'finalized detail waits for audio inventory '
      '${inventoryFails ? 'and surfaces failure' : 'then opens playable audio'}',
      (tester) async {
        tester.useDevice(TestDevice.compact);
        final capture = FakeAudioCaptureService()
          ..currentResult = const Ok(recording);
        final repository = FakeSessionRepository()
          ..savedMeetings.add(_recordingMeeting);
        final inventory = _DelayedRecordingInventory();
        final playback = FakeSessionPlaybackService()
          ..loadResult = const Ok(
            SessionPlaybackSnapshot(
              sessionId: 'meeting-1',
              state: SessionPlaybackState.ready,
              position: Duration.zero,
              duration: Duration(seconds: 12),
            ),
          );
        addTearDown(capture.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioCaptureServiceProvider.overrideWithValue(capture),
              sessionRepositoryProvider.overrideWithValue(repository),
              recordingInventorySynchronizerProvider.overrideWithValue(
                inventory,
              ),
              sessionPlaybackServiceProvider.overrideWithValue(playback),
            ],
            child: const LoquirisApp(),
          ),
        );
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LoquirisApp)),
        );
        container.read(appRouterProvider).go('/recordings/meeting-1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        capture.emitSnapshot(
          const AudioCaptureSnapshot(
            sessionId: 'meeting-1',
            state: AudioCaptureState.finalized,
            elapsed: Duration(seconds: 12),
            bytesWritten: 4096,
            revision: 9,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey<String>('active-recording:meeting-1')),
          findsOneWidget,
          reason: 'Native finalization is not yet a committed Dart inventory.',
        );
        expect(
          find.byKey(const ValueKey<String>('session-detail:meeting-1')),
          findsNothing,
        );
        expect(playback.loadCalls, isEmpty);

        repository.detailResult = Ok(
          SessionDetail(
            meeting: _recordingMeeting.copyWith(
              lifecycle: MeetingLifecycle.finalized,
              mediaDuration: const Duration(seconds: 12),
            ),
            segments: [
              AudioSegment(
                id: 'committed-segment',
                meetingId: 'meeting-1',
                sequence: 0,
                relativePath:
                    (AppRelativePath.tryParse(
                              'recordings/key/segment-00000.adts',
                            )
                            as Ok<AppRelativePath, InvalidAppRelativePath>)
                        .value,
                mediaStart: Duration.zero,
                mediaDuration: const Duration(seconds: 12),
                committedBytes: 4096,
                state: AudioSegmentState.committed,
              ),
            ],
            events: const [],
            bookmarks: const [],
            processingJobs: const [],
            recoveryDiagnostics: const [],
          ),
        );
        inventory.completion.complete(
          inventoryFails
              ? const Err(SessionRepositoryUnavailable('inventory_failed'))
              : const Ok(null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        if (inventoryFails) {
          expect(
            find.byKey(const Key('active-recording-retry-persistence')),
            findsOneWidget,
          );
          expect(
            find.text(
              'Local meeting details could not be updated yet.',
            ),
            findsOneWidget,
          );
          expect(playback.loadCalls, isEmpty);
          inventory.completion = Completer();
          await tester.ensureVisible(
            find.byKey(const Key('active-recording-retry-persistence')),
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const Key('active-recording-retry-persistence')),
          );
          await tester.pump();
          expect(playback.loadCalls, isEmpty);
          inventory.completion.complete(const Ok(null));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
        }
        expect(
          find.byKey(const Key('session-detail-segment:committed-segment')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('session-detail-play')), findsOneWidget);
        expect(playback.loadCalls, ['meeting-1']);
        expect(capture.startRequests, isEmpty);
        expect(capture.stopCalls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
            meetingProcessingSelectionRepositoryProvider.overrideWithValue(
              FakeMeetingProcessingSelectionRepository(),
            ),
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

final class _DelayedRecordingInventory
    implements RecordingInventorySynchronizer {
  Completer<Result<void, SessionRepositoryFailure>> completion = Completer();

  @override
  Future<Result<void, SessionRepositoryFailure>> synchronize({
    String? finalizedMeetingId,
  }) => completion.future;
}

final class _UiStreamingEngine implements StreamingTranscriptionEngine {
  late FakeStreamingSession native;
  int releases = 0;
  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async {
    native = FakeStreamingSession(request.owner, () {
      releases++;
    });
    return Ok(native);
  }
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
