import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

import '../test/support/fakes/fake_services.dart';
import '../test/support/streaming_delivery_trace.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'pinned native file finals reach the real recording panel without microphone',
    (tester) async {
      final meetingId =
          'streaming-file-ui-${DateTime.now().microsecondsSinceEpoch}';
      final owner = StreamingOwner(
        meetingId: meetingId,
        runId: 'file-ui',
        epoch: 1,
      );
      final trace = StreamingDeliveryTrace(owner);
      var passed = false;
      var host = <String, Object>{};
      addTearDown(() {
        // Counts and allowlisted codes only; never hypothesis text or identities.
        // ignore: avoid_print
        print(
          'streaming_file_ui_delivery_trace=${jsonEncode({'passed': passed, ...host, ...trace.snapshot})}',
        );
      });
      final engine = MethodChannelStreamingTranscriptionEngine(
        port: trace.wrapPort(MethodChannelStreamingPort()),
      );
      final adapter = StreamingLiveTranscriptAdapter(engine);
      final capture = FakeAudioCaptureService()
        ..currentResult = Ok(
          AudioCaptureSnapshot(
            sessionId: meetingId,
            state: AudioCaptureState.recording,
            elapsed: Duration.zero,
            bytesWritten: 0,
            revision: 1,
          ),
        );
      final seen = <TranscriptionEvent>[];
      LiveTranscriptionSession? owned;
      addTearDown(() async {
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
            try {
              expect(
                (await engine.dispose().timeout(
                  const Duration(seconds: 20),
                )).isOk,
                isTrue,
              );
            } finally {
              await capture.dispose();
            }
          }
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioCaptureServiceProvider.overrideWithValue(capture),
            sessionRepositoryProvider.overrideWithValue(
              FakeSessionRepository(),
            ),
            transcriptionFinalizationHandlerProvider.overrideWithValue((_) {}),
            liveTranscriptSessionStarterProvider.overrideWithValue((id) async {
              expectSync(id, meetingId);
              final result = await adapter.open(
                StreamingStartRequest(
                  owner: owner,
                  modelId: 'debug-native-file-probe',
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
              return Ok(
                LiveTranscriptionSession(
                  meetingId: meetingId,
                  runId: session.runId,
                  events: session.events.map((event) {
                    trace.recordProjection(event);
                    seen.add(event);
                    return event;
                  }),
                  finish: session.finish,
                  release: session.release,
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
      await _waitForProjectedFinals(tester, seen, trace, () {
        final recording = container.read(recordingControllerProvider);
        final liveExists = container.exists(
          liveTranscriptControllerProvider(meetingId),
        );
        host = {
          'activePage': find
              .byKey(ValueKey<String>('active-recording:$meetingId'))
              .evaluate()
              .isNotEmpty,
          'recordingReady': recording.hasValue,
          'recordingError': recording.hasError,
          'recordingMatches': recording.value?.snapshot?.sessionId == meetingId,
          'liveExists': liveExists,
          'liveError':
              liveExists &&
              container
                  .read(liveTranscriptControllerProvider(meetingId))
                  .hasError,
        };
        if (liveExists) {
          final live = container.read(
            liveTranscriptControllerProvider(meetingId),
          );
          if (live.hasError) {
            Error.throwWithStackTrace(
              live.error!,
              live.stackTrace ?? StackTrace.current,
            );
          }
        }
      });
      await tester.pump();
      final finals = seen
          .whereType<TranscriptionDraftUpdated>()
          .where(
            (event) =>
                event.chunk.stability == TranscriptStability.stable &&
                event.chunk.rawText.trim().isNotEmpty,
          )
          .toList();
      expect(finals, hasLength(2), reason: jsonEncode(trace.snapshot));
      expect(trace.snapshot['wireNonemptyFinals'], 2);
      expect(trace.snapshot['viewNonemptyFinals'], 2);
      expect(trace.snapshot['wireFailureReasons'], isEmpty);
      final displayedCounts = <String, int>{};
      for (final event in finals) {
        expect(event.chunk.displayText, event.chunk.rawText);
        displayedCounts.update(
          event.chunk.displayText,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final entry in displayedCounts.entries) {
        final text = find.text(entry.key);
        expect(text, findsNWidgets(entry.value));
        await tester.ensureVisible(text.last);
        await tester.pump();
        expect(text.hitTestable(), findsWidgets);
      }
      expect(find.byKey(const Key('live-transcript-panel')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('live-transcript-panel')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('active-recording-pause')), findsOneWidget);
      expect(find.byKey(const Key('active-recording-stop')), findsOneWidget);
      await container
          .read(liveTranscriptControllerProvider(meetingId).notifier)
          .finish()
          .timeout(const Duration(seconds: 20));
      await tester.pump();
      expect(
        container
            .read(liveTranscriptControllerProvider(meetingId))
            .requireValue
            .status,
        LiveTranscriptStatus.stopped,
      );
      passed = true;
    },
  );
}

Future<void> _waitForProjectedFinals(
  WidgetTester tester,
  List<TranscriptionEvent> seen,
  StreamingDeliveryTrace trace,
  void Function() sampleHost,
) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    sampleHost();
    final failures = seen.whereType<TranscriptionDraftDegraded>().where(
      (event) => event.reason != 'transcription_live_discontinuity',
    );
    if (failures.isNotEmpty) {
      fail('Live degradation: ${jsonEncode(trace.snapshot)}');
    }
    final finals = seen.whereType<TranscriptionDraftUpdated>().where(
      (event) =>
          event.chunk.stability == TranscriptStability.stable &&
          event.chunk.rawText.trim().isNotEmpty,
    );
    if (finals.length >= 2) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(
    'Native file finals did not reach projection: ${jsonEncode(trace.snapshot)}',
  );
}
