import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

import '../test/support/fakes/fake_services.dart';
import '../test/support/streaming_delivery_trace.dart';
import '../test/support/streaming_recorder_ui_coverage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'authorized recorder UI renders native drafts and drains normal STOP',
    (tester) async {
      final capture = NativeAudioCaptureService(
        const MethodChannelRecordingControlGateway(),
        commandTimeout: const Duration(seconds: 30),
      );
      final prior = await capture.current();
      expect(prior.isOk, isTrue);
      final before =
          (prior as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
      expect(
        before.state,
        isIn([AudioCaptureState.idle, AudioCaptureState.finalized]),
        reason: 'Never interrupt active or recoverable capture.',
      );
      final meetingId = 'streaming-ui-${DateTime.now().microsecondsSinceEpoch}';
      final trace = StreamingDeliveryTrace(
        StreamingOwner(
          meetingId: meetingId,
          runId: 'recorder-ui',
          epoch: 1,
        ),
      );
      var phase = 'opening';
      addTearDown(() {
        // Content-free counts only, including failures before normal assertions.
        // ignore: avoid_print
        print(
          'streaming_ui_delivery_trace=${jsonEncode({'phase': phase, ...trace.snapshot})}',
        );
      });
      final engine = MethodChannelStreamingTranscriptionEngine(
        port: trace.wrapPort(MethodChannelStreamingPort()),
      );
      // This adapter outlives every route, including failed-release quarantine.
      final adapter = StreamingLiveTranscriptAdapter(engine);
      LiveTranscriptionSession? owned;
      var ownsCapture = false;
      var finishCalls = 0;
      var cancelCalls = 0;
      final opened = Completer<void>();
      final finishAck = Completer<Result<void, TranscriptionFailure>>();
      final seen = <TranscriptionEvent>[];
      addTearDown(() async {
        // Stop only this new recording before any potentially blocked ASR ACK.
        try {
          if (ownsCapture) {
            final current = await capture.current();
            expect(current.isOk, isTrue);
            if (current case Ok<AudioCaptureSnapshot, AudioCaptureFailure>(
              :final value,
            )) {
              if (value.sessionId == meetingId &&
                  value.state != AudioCaptureState.finalized) {
                expect((await capture.stop()).isOk, isTrue);
              }
            }
          }
        } finally {
          try {
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            try {
              final session = owned;
              if (session != null) {
                expect(
                  (await session.release().timeout(
                    const Duration(seconds: 20),
                  )).isOk,
                  isTrue,
                );
              }
            } finally {
              expect(
                (await engine.dispose().timeout(
                  const Duration(seconds: 20),
                )).isOk,
                isTrue,
              );
            }
          }
        }
      });
      ownsCapture = true; // A missing start confirmation can still own this id.
      expect(
        (await capture.start(AudioCaptureRequest(sessionId: meetingId))).isOk,
        isTrue,
      );
      final repository = FakeSessionRepository()
        ..savedMeetings.add(
          Meeting(
            id: meetingId,
            title: 'Authorized streaming UI smoke',
            createdAtUtcMs: 1,
            mediaDuration: Duration.zero,
            lifecycle: MeetingLifecycle.recording,
            languageMode: MeetingLanguageMode.mixed,
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(repository),
            // UI/channel smoke only: do not enqueue a refinement or touch the app DB.
            transcriptionFinalizationHandlerProvider.overrideWithValue((_) {}),
            liveTranscriptSessionStarterProvider.overrideWithValue((id) async {
              final result = await adapter.open(
                StreamingStartRequest(
                  owner: StreamingOwner(
                    meetingId: id,
                    runId: 'recorder-ui',
                    epoch: 1,
                  ),
                  modelId: 'debug-native-recorder-probe',
                  bundleSha256:
                      '18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b',
                  parameterVersion: 1,
                ),
              );
              expectSync(result.isOk, isTrue);
              final session =
                  (result as Ok<LiveTranscriptionSession, TranscriptionFailure>)
                      .value;
              owned = session;
              opened.complete();
              return Ok(
                LiveTranscriptionSession(
                  meetingId: id,
                  runId: session.runId,
                  events: session.events.map((event) {
                    trace.recordProjection(event);
                    seen.add(event);
                    return event;
                  }),
                  finish: () async {
                    finishCalls++;
                    final outcome = await session.finish!();
                    if (!finishAck.isCompleted) finishAck.complete(outcome);
                    return outcome;
                  },
                  release: () {
                    cancelCalls++;
                    return session.release();
                  },
                ),
              );
            }),
          ],
          child: const LoquirisApp(),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(LoquirisApp));
      final container = ProviderScope.containerOf(context);
      final observer = container.listen(
        liveTranscriptControllerProvider(meetingId),
        (_, next) => trace.recordView(next.value),
        weak: true,
      );
      addTearDown(observer.close);
      container
          .read(appRouterProvider)
          .go(AppRoutes.activeRecording(meetingId));
      await tester.pump();
      await opened.future.timeout(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(seconds: 10));
      await _tapRecordingControl(tester, 'active-recording-pause');
      await _awaitCaptureState(
        capture,
        meetingId,
        AudioCaptureState.pausedByUser,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      phase = 'waiting_pause_final';
      final firstFinals = await _awaitNonemptyFinal(seen, trace);
      await tester.pump();
      expect(firstFinals, isNotEmpty);
      expect(find.text(firstFinals.last.chunk.displayText), findsOneWidget);
      expect(find.byKey(const Key('live-transcript-panel')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('live-transcript-panel')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      await _tapRecordingControl(tester, 'active-recording-pause');
      phase = 'resuming';
      await _awaitCaptureState(capture, meetingId, AudioCaptureState.recording);
      await Future<void>.delayed(const Duration(seconds: 10));
      await tester.pump();
      if ((trace.snapshot['projectedGapNotices']! as int) > 0) {
        final panel = find.byKey(const Key('live-transcript-panel'));
        final l10n = AppLocalizations.of(tester.element(panel));
        final incomplete = find.descendant(
          of: panel,
          matching: find.text(l10n.liveTranscriptIncomplete),
        );
        await tester.ensureVisible(incomplete);
        await tester.pump();
        expect(incomplete.hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: panel,
            matching: find.text(l10n.liveTranscriptDiscontinuity),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.text(l10n.liveTranscriptPostSessionFallback),
          ),
          findsOneWidget,
        );
      }
      await _tapRecordingControl(tester, 'active-recording-stop');
      await tester.pump(const Duration(milliseconds: 400));
      await _tapRecordingControl(tester, 'confirm-stop-recording');
      phase = 'waiting_stop_ack';
      await _awaitCaptureState(capture, meetingId, AudioCaptureState.finalized);
      ownsCapture = false;
      expect(
        (await finishAck.future.timeout(const Duration(seconds: 20))).isOk,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(ValueKey<String>('session-detail:$meetingId')),
        findsOneWidget,
      );
      expect(finishCalls, 1);
      expect(cancelCalls, 0);
      final finals = seen
          .whereType<TranscriptionDraftUpdated>()
          .where(
            (event) =>
                event.chunk.stability == TranscriptStability.stable &&
                event.chunk.rawText.trim().isNotEmpty,
          )
          .toList();
      expect(finals.length, greaterThan(firstFinals.length));
      expect(finals.last.chunk.end, greaterThan(firstFinals.last.chunk.end));
      expect(
        (await engine.dispose().timeout(const Duration(seconds: 20))).isOk,
        isTrue,
      );
      final count = seen.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, hasLength(count));
      expect(
        recorderUiCoverageProblems(
          trace: trace.snapshot,
          firstFinalStart: firstFinals.first.chunk.start,
          pausedFinalEnd: firstFinals.last.chunk.end,
          resumedFinalStart: finals[firstFinals.length].chunk.start,
        ),
        isEmpty,
        reason: jsonEncode(trace.snapshot),
      );
      phase = trace.snapshot['viewIncomplete']! as bool
          ? 'passed_incomplete_coverage'
          : 'passed';
      // Identifier only; never raw audio/text or debugger capabilities.
      // ignore: avoid_print
      print('streaming_recorder_ui_smoke_meeting=$meetingId');
    },
    skip: !const bool.fromEnvironment(
      'LOQUIRIS_AUTHORIZED_STREAMING_RECORDER_UI',
    ),
  );
}

Future<void> _tapRecordingControl(WidgetTester tester, String key) async {
  final control = find.byKey(Key(key));
  await tester.ensureVisible(control);
  await tester.pump();
  expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
  expect(
    control.hitTestable(),
    findsOneWidget,
    reason: 'Recorder controls must remain tappable as live captions grow.',
  );
  await tester.tap(control);
  await tester.pump();
}

Future<void> _awaitCaptureState(
  AudioCaptureService capture,
  String meetingId,
  AudioCaptureState state,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final result = await capture.current();
    if (result case Ok<AudioCaptureSnapshot, AudioCaptureFailure>(
      :final value,
    )) {
      if (value.sessionId == meetingId && value.state == state) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('The new recording did not reach the expected authoritative state.');
}

Future<List<TranscriptionDraftUpdated>> _awaitNonemptyFinal(
  List<TranscriptionEvent> seen,
  StreamingDeliveryTrace trace,
) => waitForRecorderUiFinal(
  events: seen,
  snapshot: () => trace.snapshot,
  wait: () => Future<void>.delayed(const Duration(milliseconds: 100)),
);
