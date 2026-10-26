import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pinned file input round-trips native final text and capture gap', (
    tester,
  ) async {
    final engine = MethodChannelStreamingTranscriptionEngine();
    addTearDown(() async {
      expect(
        (await engine.dispose().timeout(const Duration(seconds: 15))).isOk,
        isTrue,
      );
    });
    final owner = StreamingOwner(
      meetingId: 'file-wire-${DateTime.now().microsecondsSinceEpoch}',
      runId: 'file-native',
      epoch: 1,
    );
    final seen = <StreamingEvent>[];
    final finished = Completer<void>();
    final result = await engine
        .open(
          StreamingStartRequest(
            owner: owner,
            modelId: 'debug-native-file-probe',
            bundleSha256:
                '18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b',
            parameterVersion: 1,
          ),
        )
        .timeout(const Duration(seconds: 30));
    expect(result, isA<Ok<StreamingSession, StreamingFailure>>());
    final session = (result as Ok<StreamingSession, StreamingFailure>).value;
    final subscription = session.events.listen((event) {
      seen.add(event);
      if (event is StreamingFailed) {
        if (!finished.isCompleted) finished.complete();
      } else if (seen
                  .whereType<StreamingUtterance>()
                  .where(
                    (text) => text.status == StreamingUtteranceStatus.finalized,
                  )
                  .length >=
              2 &&
          !finished.isCompleted) {
        finished.complete();
      }
    });
    addTearDown(subscription.cancel);
    addTearDown(() async {
      expect(
        (await session
                .close(StreamingCloseReason.cancelled)
                .timeout(
                  const Duration(seconds: 15),
                ))
            .isOk,
        isTrue,
      );
    });
    await finished.future.timeout(const Duration(seconds: 30));
    expect(seen.whereType<StreamingFailed>(), isEmpty);
    final finals = seen
        .whereType<StreamingUtterance>()
        .where(
          (event) => event.status == StreamingUtteranceStatus.finalized,
        )
        .toList();
    expect(finals, hasLength(2));
    expect(finals.every((event) => event.rawText.trim().isNotEmpty), isTrue);
    expect(finals.map((event) => event.end.inMicroseconds), [
      4000000,
      10250000,
    ]);
    expect(finals[0].utteranceId, isNot(finals[1].utteranceId));
    final gap = seen.whereType<StreamingGap>().single;
    expect(gap.reason, StreamingGapReason.pause);
    expect(gap.start.inMicroseconds, 4000000);
    expect(gap.end.inMicroseconds, 6250000);
    expect(gap.captureEpoch, 1);
    expect(seen.every((event) => event.owner == owner), isTrue);
    expect(
      seen.map((event) => event.sequence),
      List<int>.generate(seen.length, (index) => index),
    );
    expect(
      (await session
              .close(StreamingCloseReason.stopped)
              .timeout(
                const Duration(seconds: 15),
              ))
          .isOk,
      isTrue,
    );
    final count = seen.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, hasLength(count));
  });
}
