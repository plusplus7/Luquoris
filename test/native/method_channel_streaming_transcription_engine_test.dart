import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  const owner = StreamingOwner(meetingId: 'meeting', runId: 'live', epoch: 7);
  final request = StreamingStartRequest(
    owner: owner,
    modelId: 'debug-zipformer',
    bundleSha256: 'a' * 64,
    parameterVersion: 1,
  );
  test(
    'cancellation upgrades a pending stop without forging release',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final stopping = session.close(StreamingCloseReason.stopped);
      final cancelling = session.close(StreamingCloseReason.cancelled);
      var settled = false;
      unawaited(
        cancelling.then((_) {
          settled = true;
        }),
      );
      try {
        expect(
          port.calls
              .where((call) => call.$1 == 'close')
              .map((call) => call.$2['reason']),
          ['stopped', 'cancelled'],
        );
        await Future<void>.delayed(Duration.zero);
        expect(settled, isFalse);
      } finally {
        ack.complete({..._header(owner), 'ok': true, 'released': true});
        expect((await stopping).isOk, isTrue);
        expect((await cancelling).isOk, isTrue);
        expect((await engine.dispose()).isOk, isTrue);
      }
    },
  );
  test(
    'confirmed terminal release settles an already pending close request',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final closing = session.close(StreamingCloseReason.cancelled);
      port.emit({
        ..._header(owner),
        'sequence': 0,
        'type': 'failure',
        'reason': 'engine',
        'released': true,
      });
      try {
        expect(
          (await closing.timeout(const Duration(milliseconds: 200))).isOk,
          isTrue,
        );
      } finally {
        ack.complete({..._header(owner), 'ok': true, 'released': true});
        expect((await engine.dispose()).isOk, isTrue);
      }
    },
  );

  test('synchronous transport failure leaves native close retryable', () async {
    final port = _Port()..throwOnClose = true;
    final engine = MethodChannelStreamingTranscriptionEngine(port: port);
    final session = await _open(engine, request);
    expect((await session.close(StreamingCloseReason.cancelled)).isErr, isTrue);
    port.throwOnClose = false;
    expect((await session.close(StreamingCloseReason.cancelled)).isOk, isTrue);
    expect((await engine.dispose()).isOk, isTrue);
  });

  Map<String, Object?> text(int sequence) => {
    ..._header(owner),
    'type': 'text',
    'sequence': sequence,
    'utteranceId': 'utterance-1',
    'startSample': 3200,
    'endSampleExclusive': 6400,
    'captureEpoch': 0,
    'rawText': '中文 API',
    'finalized': false,
  };

  test(
    'confirmed release settles open even when readiness reply is lost',
    () async {
      final ready = Completer<Object?>();
      final port = _Port()..opening = ready.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final opening = engine.open(request);
      expect((await engine.dispose()).isOk, isTrue);
      try {
        final result = await opening.timeout(const Duration(milliseconds: 200));
        expect(result, isA<Err<StreamingSession, StreamingFailure>>());
      } finally {
        ready.complete({..._header(owner), 'ok': true, 'released': false});
        await opening;
      }
    },
  );

  test(
    'first subscriber receives finalized text and gap arriving before open ACK',
    () async {
      final ready = Completer<Object?>();
      final port = _Port()..opening = ready.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final opening = engine.open(request);
      port
        ..emit({...text(0), 'finalized': true})
        ..emit({
          ..._header(owner),
          'type': 'gap',
          'sequence': 1,
          'startSample': 6400,
          'endSampleExclusive': 8000,
          'captureEpoch': 1,
          'reason': 'pause',
        });
      ready.complete({..._header(owner), 'ok': true, 'released': false});
      final result = await opening;
      final session = (result as Ok<StreamingSession, StreamingFailure>).value;
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      try {
        expect(seen, hasLength(2));
        expect((seen[0] as StreamingUtterance).rawText, '中文 API');
        expect(
          (seen[0] as StreamingUtterance).status,
          StreamingUtteranceStatus.finalized,
        );
        expect((seen[1] as StreamingGap).reason, StreamingGapReason.pause);
      } finally {
        expect(
          (await session.close(StreamingCloseReason.cancelled)).isOk,
          isTrue,
        );
        await subscription.cancel();
        await engine.dispose();
      }
    },
  );

  test(
    'malformed callback fences later text even if close reply is uncertain',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      port.emit({...text(0), 'unownedField': true});
      ack.complete({
        ..._header(owner),
        'epoch': 6,
        'ok': true,
        'released': true,
      });
      await Future<void>.delayed(Duration.zero);
      port.emit(text(1));
      await Future<void>.delayed(Duration.zero);
      try {
        expect(seen, isEmpty);
      } finally {
        port.closing = null;
        expect(
          (await session.close(StreamingCloseReason.cancelled)).isOk,
          isTrue,
        );
        await subscription.cancel();
        expect((await engine.dispose()).isOk, isTrue);
      }
    },
  );

  test(
    'unsubscribed acquisition buffer degrades at its limit without forging release',
    () async {
      final ready = Completer<Object?>();
      final closeAck = Completer<Object?>();
      final port = _Port()
        ..opening = ready.future
        ..closing = closeAck.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final opening = engine.open(request);
      var settled = false;
      unawaited(
        opening.then((_) {
          settled = true;
        }),
      );
      for (var sequence = 0; sequence < 65; sequence++) {
        port.emit(text(sequence));
      }
      await Future<void>.delayed(Duration.zero);
      try {
        expect(port.calls.map((call) => call.$1), ['open', 'close']);
        expect(settled, isFalse);
        expect((await engine.open(_next(request))).isErr, isTrue);
      } finally {
        closeAck.complete({..._header(owner), 'ok': true, 'released': true});
        await engine.dispose();
        ready.complete({..._header(owner), 'ok': true, 'released': false});
        expect((await opening).isErr, isTrue);
      }
    },
  );

  test(
    'buffer overflow preserves bounded evidence and reports incomplete coverage',
    () async {
      final port = _Port();
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      for (var sequence = 0; sequence < 65; sequence++) {
        port.emit(text(sequence));
      }
      await Future<void>.delayed(Duration.zero);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      try {
        expect(seen.whereType<StreamingUtterance>(), hasLength(64));
        expect(seen.last, isA<StreamingFailed>());
        expect((seen.last as StreamingFailed).failure.code, 'streaming_engine');
      } finally {
        await subscription.cancel();
        await engine.dispose();
      }
    },
  );

  test(
    'native terminal failure does not duplicate a pending protocol failure',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      port
        ..emit({...text(0), 'unownedField': true})
        ..emit({
          ..._header(owner),
          'sequence': 1,
          'type': 'failure',
          'reason': 'engine',
          'released': true,
        });
      await Future<void>.delayed(Duration.zero);
      try {
        expect(seen.whereType<StreamingFailed>(), hasLength(1));
      } finally {
        ack.complete({..._header(owner), 'ok': true, 'released': true});
        await subscription.cancel();
        expect((await engine.dispose()).isOk, isTrue);
      }
    },
  );

  test(
    'dispose requests every owner close before waiting for any one reply',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closeByMeeting['meeting'] = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      await _open(engine, request);
      await _open(
        engine,
        StreamingStartRequest(
          owner: const StreamingOwner(
            meetingId: 'second',
            runId: 'other',
            epoch: 1,
          ),
          modelId: 'debug-zipformer',
          bundleSha256: 'a' * 64,
          parameterVersion: 1,
        ),
      );
      final disposing = engine.dispose();
      await Future<void>.delayed(Duration.zero);
      try {
        expect(
          port.calls
              .where((call) => call.$1 == 'close')
              .map((call) => call.$2['meetingId']),
          ['meeting', 'second'],
        );
      } finally {
        ack.complete({..._header(owner), 'ok': true, 'released': true});
        expect((await disposing).isOk, isTrue);
      }
    },
  );

  test(
    'open validates before platform acquisition and preserves pinned request',
    () async {
      final port = _Port();
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final bad = StreamingStartRequest(
        owner: owner,
        modelId: '../model',
        bundleSha256: 'a' * 64,
        parameterVersion: 1,
      );
      expect((await engine.open(bad)).isErr, isTrue);
      expect(port.calls, isEmpty);
      final session = await _open(engine, request);
      expect(port.calls.single.$1, 'open');
      expect(port.calls.single.$2, {
        ..._header(owner),
        'modelId': 'debug-zipformer',
        'bundleSha256': 'a' * 64,
        'parameterVersion': 1,
      });
      expect(session.owner, owner);
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      expect((await engine.dispose()).isOk, isTrue);
      expect(port.closed, isTrue);
    },
  );

  test(
    'cancel waits for matching release and drops queued and late events',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add)..pause();
      port.emit(text(0));
      var settled = false;
      final closing = session.close(StreamingCloseReason.cancelled);
      unawaited(
        closing.then((_) {
          settled = true;
        }),
      );
      expect(session.close(StreamingCloseReason.cancelled), same(closing));
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      expect((await engine.open(request)).isErr, isTrue);
      port.emit(text(1));
      ack.complete({..._header(owner), 'ok': true, 'released': true});
      expect((await closing).isOk, isTrue);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await subscription.cancel();
      port.closing = null;
      expect((await engine.open(request)).isErr, isTrue);
      final replacement = await _open(engine, _next(request));
      expect(
        (await replacement.close(StreamingCloseReason.replaced)).isOk,
        isTrue,
      );
      expect((await engine.dispose()).isOk, isTrue);
    },
  );

  test(
    'only matching ordered events revise raw text and stop permits final flush',
    () async {
      final ack = Completer<Object?>();
      final port = _Port()..closing = ack.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add);
      port
        ..emit({...text(3), 'runId': 'old'})
        ..emit(text(1))
        ..emit(text(1))
        ..emit(text(0));
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));
      final closing = session.close(StreamingCloseReason.stopped);
      port.emit({...text(2), 'finalized': true});
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.whereType<StreamingUtterance>().map((event) => event.status),
        [
          StreamingUtteranceStatus.provisional,
          StreamingUtteranceStatus.finalized,
        ],
      );
      ack.complete({..._header(owner), 'ok': true, 'released': true});
      expect((await closing).isOk, isTrue);
      port.emit(text(4));
      await subscription.cancel();
      expect((await engine.dispose()).isOk, isTrue);
    },
  );

  test(
    'wrong release acknowledgement retains ownership until verified retry',
    () async {
      final port = _Port()
        ..closing = Future.value({
          ..._header(owner),
          'epoch': 6,
          'ok': true,
          'released': true,
        });
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isErr,
        isTrue,
      );
      expect((await engine.open(request)).isErr, isTrue);
      port.closing = null;
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      final next = await _open(engine, _next(request));
      expect((await next.close(StreamingCloseReason.cancelled)).isOk, isTrue);
      expect((await engine.dispose()).isOk, isTrue);
    },
  );

  test(
    'terminal failure releases without waiting for a paused Dart subscriber',
    () async {
      final port = _Port();
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final session = await _open(engine, request);
      final seen = <StreamingEvent>[];
      final subscription = session.events.listen(seen.add)..pause();
      port.emit({
        ..._header(owner),
        'sequence': 0,
        'type': 'failure',
        'reason': 'memory',
        'released': true,
      });
      final next = await _open(engine, _next(request));
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.single,
        isA<StreamingFailed>().having(
          (event) => event.failure.code,
          'cause',
          'streaming_memory',
        ),
      );
      expect(
        (await session.close(StreamingCloseReason.cancelled)).isOk,
        isTrue,
      );
      expect((await next.close(StreamingCloseReason.cancelled)).isOk, isTrue);
      await subscription.cancel();
      expect((await engine.dispose()).isOk, isTrue);
    },
  );

  test(
    'dispose cancels even a pending open and fences its late readiness',
    () async {
      final ready = Completer<Object?>();
      final port = _Port()..opening = ready.future;
      final engine = MethodChannelStreamingTranscriptionEngine(port: port);
      final opening = engine.open(request);
      expect((await engine.dispose()).isOk, isTrue);
      ready.complete({..._header(owner), 'ok': true, 'released': false});
      expect((await opening).isErr, isTrue);
      expect(port.calls.map((call) => call.$1), ['open', 'close']);
      expect(port.closed, isTrue);
      expect((await engine.open(request)).isErr, isTrue);
    },
  );
}

Future<StreamingSession> _open(
  MethodChannelStreamingTranscriptionEngine engine,
  StreamingStartRequest request,
) async {
  final result = await engine.open(request);
  expect(result, isA<Ok<StreamingSession, StreamingFailure>>());
  return (result as Ok<StreamingSession, StreamingFailure>).value;
}

Map<String, Object?> _header(StreamingOwner owner) => {
  'v': 1,
  'meetingId': owner.meetingId,
  'runId': owner.runId,
  'epoch': owner.epoch,
};

StreamingStartRequest _next(StreamingStartRequest request) =>
    StreamingStartRequest(
      owner: StreamingOwner(
        meetingId: request.owner.meetingId,
        runId: 'next',
        epoch: 8,
      ),
      modelId: request.modelId,
      bundleSha256: request.bundleSha256,
      parameterVersion: 1,
    );

final class _Port implements StreamingPlatformPort {
  final calls = <(String, Map<String, Object?>)>[];
  Future<Object?>? opening;
  Future<Object?>? closing;
  final closeByMeeting = <String, Future<Object?>>{};
  bool closed = false;
  bool throwOnClose = false;
  void Function(Object?)? receiver;
  void emit(Object? value) => receiver?.call(value);
  @override
  void onEvent(void Function(Object?) receive) {
    receiver = receive;
  }

  @override
  void close() {
    closed = true;
    receiver = null;
  }

  @override
  Future<Object?> request(String method, Map<String, Object?> arguments) {
    calls.add((method, Map.of(arguments)));
    final header = Map.of(arguments)
      ..removeWhere(
        (key, _) => !{'v', 'meetingId', 'runId', 'epoch'}.contains(key),
      );
    if (method == 'open') {
      return opening ??
          Future.value({...header, 'ok': true, 'released': false});
    }
    if (method == 'close') {
      if (throwOnClose) throw StateError('channel closed synchronously');
      return closeByMeeting[arguments['meetingId']] ??
          closing ??
          Future.value({...header, 'ok': true, 'released': true});
    }
    throw StateError('unexpected method');
  }
}
