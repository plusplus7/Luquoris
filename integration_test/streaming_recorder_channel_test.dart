import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'authorized foreground recorder shares canonical PCM with streaming Dart',
    (tester) async {
      final capture = NativeAudioCaptureService(
        const MethodChannelRecordingControlGateway(),
        commandTimeout: const Duration(seconds: 30),
      );
      final before = await capture.current();
      expect(before, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
      final prior =
          (before as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
      expect(
        prior.state,
        isIn(<AudioCaptureState>[
          AudioCaptureState.idle,
          AudioCaptureState.finalized,
        ]),
        reason: 'Never interrupt an existing or recoverable recording.',
      );
      final meetingId =
          'streaming-recorder-${DateTime.now().microsecondsSinceEpoch}';
      var ownsCapture = false;
      MethodChannelStreamingTranscriptionEngine? ownedEngine;
      StreamingSession? ownedSession;
      StreamSubscription<StreamingEvent>? ownedSubscription;
      addTearDown(() async {
        // Stop this capture BEFORE any potentially blocked native ASR ACK.
        // Finally blocks keep every independent cleanup reachable on failure.
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
            final session = ownedSession;
            if (session != null) {
              expect(
                (await session
                        .close(StreamingCloseReason.cancelled)
                        .timeout(const Duration(seconds: 20)))
                    .isOk,
                isTrue,
              );
            }
          } finally {
            try {
              await ownedSubscription?.cancel();
            } finally {
              final engine = ownedEngine;
              if (engine != null) {
                expect(
                  (await engine.dispose().timeout(
                    const Duration(seconds: 20),
                  )).isOk,
                  isTrue,
                );
              }
            }
          }
        }
      });
      // Mark ownership before dispatch: a failed confirmation may still have
      // created this unique recording. Teardown rechecks identity before stop.
      ownsCapture = true;
      expect(
        (await capture.start(AudioCaptureRequest(sessionId: meetingId))).isOk,
        isTrue,
      );
      final engine = MethodChannelStreamingTranscriptionEngine();
      ownedEngine = engine;
      final owner = StreamingOwner(
        meetingId: meetingId,
        runId: 'recorder-channel',
        epoch: 1,
      );
      final result = await engine
          .open(
            StreamingStartRequest(
              owner: owner,
              modelId: 'debug-native-recorder-probe',
              bundleSha256:
                  '18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b',
              parameterVersion: 1,
            ),
          )
          .timeout(const Duration(seconds: 30));
      expect(result, isA<Ok<StreamingSession, StreamingFailure>>());
      final session = (result as Ok<StreamingSession, StreamingFailure>).value;
      ownedSession = session;
      final seen = <StreamingEvent>[];
      ownedSubscription = session.events.listen(seen.add);
      await Future<void>.delayed(const Duration(seconds: 10));
      expect((await capture.pause()).isOk, isTrue);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect((await capture.resume()).isOk, isTrue);
      await Future<void>.delayed(const Duration(seconds: 10));
      // Recorder stop queues the ordered finalizer; Dart does not synthesize
      // a pause or final event and must still wait for native release ACK.
      final stopped = await capture.stop();
      expect(stopped, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
      final snapshot =
          (stopped as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
      expect(snapshot.sessionId, meetingId);
      expect(snapshot.state, AudioCaptureState.finalized);
      ownsCapture = false;
      expect(
        (await session
                .close(StreamingCloseReason.stopped)
                .timeout(const Duration(seconds: 20)))
            .isOk,
        isTrue,
      );
      expect(seen.whereType<StreamingFailed>(), isEmpty);
      final finals = seen.whereType<StreamingUtterance>().where(
        (event) =>
            event.status == StreamingUtteranceStatus.finalized &&
            event.rawText.trim().isNotEmpty,
      );
      expect(finals.any((event) => event.captureEpoch == 0), isTrue);
      expect(finals.any((event) => event.captureEpoch == 1), isTrue);
      expect(
        seen.whereType<StreamingGap>().any(
          (event) =>
              event.reason == StreamingGapReason.pause &&
              event.captureEpoch == 1 &&
              event.end >= event.start,
        ),
        isTrue,
      );
      expect(seen.every((event) => event.owner == owner), isTrue);
      expect(
        seen.map((event) => event.sequence),
        List<int>.generate(seen.length, (index) => index),
      );
      final count = seen.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, hasLength(count));
      // Identifier only, never raw audio/text or a debugger capability.
      // ignore: avoid_print
      print('streaming_recorder_smoke_meeting=$meetingId');
    },
    skip: !const bool.fromEnvironment('LOQUIRIS_AUTHORIZED_STREAMING_RECORDER'),
  );
}
