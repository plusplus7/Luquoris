import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'authorized microphone delivers both capture epochs through Dart',
    (tester) async {
      final engine = MethodChannelStreamingTranscriptionEngine();
      addTearDown(() async {
        expect(
          (await engine.dispose().timeout(const Duration(seconds: 20))).isOk,
          isTrue,
        );
      });
      final owner = StreamingOwner(
        meetingId: 'mic-wire-${DateTime.now().microsecondsSinceEpoch}',
        runId: 'authorized-native-microphone',
        epoch: 1,
      );
      final result = await engine
          .open(
            StreamingStartRequest(
              owner: owner,
              modelId: 'debug-native-microphone-probe',
              bundleSha256:
                  '18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b',
              parameterVersion: 1,
            ),
          )
          .timeout(const Duration(seconds: 30));
      expect(result, isA<Ok<StreamingSession, StreamingFailure>>());
      final session = (result as Ok<StreamingSession, StreamingFailure>).value;
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      addTearDown(() async {
        expect(
          (await session
                  .close(StreamingCloseReason.cancelled)
                  .timeout(const Duration(seconds: 20)))
              .isOk,
          isTrue,
        );
      });
      // The native probe owns the 10 s / pause 1 s / 10 s schedule. Natural
      // endpoint finals are not proof that the second capture window finished.
      await Future<void>.delayed(const Duration(seconds: 25));
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
    },
    skip: !const bool.fromEnvironment('LOQUIRIS_AUTHORIZED_STREAMING_MIC'),
  );
}
