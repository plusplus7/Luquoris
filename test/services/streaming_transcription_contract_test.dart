import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';
import 'package:loquiris/services/streaming_transcription_provider.dart';

import '../support/fake_streaming_transcription_engine.dart';

void main() {
  const owner = StreamingOwner(meetingId: 'meeting', runId: 'draft', epoch: 1);
  const request = StreamingStartRequest(
    owner: owner,
    modelId: 'bilingual',
    bundleSha256: 'digest',
    parameterVersion: 1,
  );

  test(
    'paused listener retains terminal failure without explicit cancellation',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final session =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
                  .value
              as FakeStreamingSession;
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add)..pause();
      const failure = StreamingFailed(
        owner: owner,
        sequence: 1,
        failure: StreamingUnavailable(StreamingFailureReason.thermal),
      );
      expect(session.deliver(failure), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(engine.activeOwners, isEmpty);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [failure]);
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      await subscription.cancel();
    },
  );

  test(
    'listener-triggered cancellation returns a typed close result',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final session =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
                  .value
              as FakeStreamingSession;
      Future<Result<void, StreamingFailure>>? closing;
      final subscription = session.events.listen((_) {
        closing = session.close(StreamingCloseReason.cancelled);
      });
      session.deliver(
        const StreamingFailed(
          owner: owner,
          sequence: 1,
          failure: StreamingUnavailable(StreamingFailureReason.engine),
        ),
      );
      expect((await closing!).isOk, isTrue);
      expect(engine.activeOwners, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'paused listener does not delay native release acknowledgement',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final session =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
                  .value
              as FakeStreamingSession;
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add)..pause();
      session.deliver(
        const StreamingFailed(
          owner: owner,
          sequence: 1,
          failure: StreamingUnavailable(StreamingFailureReason.memory),
        ),
      );
      final closed = await session
          .close(StreamingCloseReason.cancelled)
          .timeout(const Duration(milliseconds: 100));
      expect(closed.isOk, isTrue);
      expect(engine.activeOwners, isEmpty);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'terminal worker failure releases ownership and rejects later events',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final session =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
                  .value
              as FakeStreamingSession;
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      const failure = StreamingFailed(
        owner: owner,
        sequence: 1,
        failure: StreamingUnavailable(StreamingFailureReason.thermal),
      );
      expect(session.deliver(failure), isTrue);
      expect(seen, [failure]);
      expect(engine.activeOwners, isEmpty);
      expect(
        session.deliver(
          const StreamingFailed(
            owner: owner,
            sequence: 2,
            failure: StreamingUnavailable(StreamingFailureReason.engine),
          ),
        ),
        isFalse,
      );
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      expect(engine.releaseCount, 1);
      await subscription.cancel();
    },
  );

  test(
    'opening owns one recognizer until idempotent cancellation closes it',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final result = await engine.open(request);
      expect(result, isA<Ok<StreamingSession, StreamingFailure>>());
      final session = (result as Ok<StreamingSession, StreamingFailure>).value;
      expect(engine.activeOwners, {owner});
      expect(
        await engine.open(request),
        isA<Err<StreamingSession, StreamingFailure>>(),
      );
      expect(
        await session.close(StreamingCloseReason.cancelled),
        isA<Ok<void, StreamingFailure>>(),
      );
      expect(
        await session.close(StreamingCloseReason.cancelled),
        isA<Ok<void, StreamingFailure>>(),
      );
      expect(engine.activeOwners, isEmpty);
      expect(engine.releaseCount, 1);
    },
  );

  test('native preparation failure does not acquire ownership', () async {
    final engine = FakeStreamingTranscriptionEngine()
      ..nextOpenFailure = const StreamingUnavailable(
        StreamingFailureReason.modelUnavailable,
      );
    final result = await engine.open(request);
    expect(
      (result as Err<StreamingSession, StreamingFailure>).failure.code,
      'streaming_modelUnavailable',
    );
    expect(engine.activeOwners, isEmpty);
    expect(engine.releaseCount, 0);
  });

  test(
    'replacement epoch cannot acquire the same meeting before closure',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final first =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
              .value;
      const replacement = StreamingStartRequest(
        owner: StreamingOwner(meetingId: 'meeting', runId: 'new', epoch: 2),
        modelId: 'bilingual',
        bundleSha256: 'digest',
        parameterVersion: 1,
      );
      expect(
        await engine.open(replacement),
        isA<Err<StreamingSession, StreamingFailure>>(),
      );
      final closed = await first.close(StreamingCloseReason.replaced);
      expect(closed.isOk, isTrue);
      final next =
          (await engine.open(replacement)
                  as Ok<StreamingSession, StreamingFailure>)
              .value;
      expect(next.owner, replacement.owner);
      expect((await next.close(StreamingCloseReason.stopped)).isOk, isTrue);
    },
  );

  test(
    'partial and final events keep capture times and close delivery',
    () async {
      final engine = FakeStreamingTranscriptionEngine();
      final session =
          (await engine.open(request) as Ok<StreamingSession, StreamingFailure>)
                  .value
              as FakeStreamingSession;
      final seen = <StreamingEvent>[];
      var done = false;
      final subscription = session.events.listen(
        seen.add,
        onDone: () => done = true,
      );
      final partial = StreamingUtterance(
        owner: owner,
        sequence: 1,
        utteranceId: 'u1',
        start: const Duration(seconds: 12),
        end: const Duration(seconds: 13),
        rawText: '讨论 API',
        status: StreamingUtteranceStatus.provisional,
      );
      final finalized = StreamingUtterance(
        owner: owner,
        sequence: 2,
        utteranceId: 'u1',
        start: const Duration(seconds: 12),
        end: const Duration(seconds: 14),
        rawText: '讨论 API latency',
        status: StreamingUtteranceStatus.finalized,
      );
      expect(session.deliver(partial), isTrue);
      expect(session.deliver(finalized), isTrue);
      expect(session.deliver(partial), isFalse);
      expect(seen, [partial, finalized]);
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      expect(done, isTrue);
      expect(session.deliver(finalized), isFalse);
      await subscription.cancel();
    },
  );

  test('provider requires wiring and accepts an injected contract fake', () {
    final unwired = ProviderContainer.test();
    expect(
      () => unwired.read(streamingTranscriptionEngineProvider),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'underlying error',
          isA<UnimplementedError>(),
        ),
      ),
    );
    final fake = FakeStreamingTranscriptionEngine();
    final wired = ProviderContainer.test(
      overrides: [streamingTranscriptionEngineProvider.overrideWithValue(fake)],
    );
    expect(wired.read(streamingTranscriptionEngineProvider), same(fake));
  });
}
