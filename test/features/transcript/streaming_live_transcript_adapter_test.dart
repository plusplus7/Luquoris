import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  test(
    'paused UI cannot delay native acknowledgement of graceful finish',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final listener = session.events.listen(seen.add)..pause();
      addTearDown(listener.cancel);
      var acknowledged = false;
      final finishing = session.finish!().then((result) {
        acknowledged = result.isOk;
      });
      h.native.emit(_text(0, 'Final retained while paused', finalText: true));
      h.native.ack.complete(const Ok(null));
      await pumpEventQueue();
      expect(acknowledged, isTrue);
      expect(seen, isEmpty);
      listener.resume();
      await finishing;
      await pumpEventQueue();
      expect(
        seen.whereType<TranscriptionDraftUpdated>().single.chunk.rawText,
        'Final retained while paused',
      );
    },
  );

  test(
    'cancel during graceful finish upgrades close and still waits for real ACK',
    () async {
      final native = _TraceSession();
      final adapter = StreamingLiveTranscriptAdapter(
        _BrokenEventsEngine(native),
      );
      final result = await adapter.open(_request);
      final session =
          (result as Ok<LiveTranscriptionSession, TranscriptionFailure>).value;
      final seen = <TranscriptionEvent>[];
      final listener = session.events.listen(seen.add);
      addTearDown(listener.cancel);
      final finishing = session.finish!();
      var acknowledged = false;
      final cancelling = session.release().then((result) {
        acknowledged = true;
        return result;
      });
      native.source.add(_text(0, 'must not arrive', finalText: true));
      await pumpEventQueue();
      expect(native.reasons, [
        StreamingCloseReason.stopped,
        StreamingCloseReason.cancelled,
      ]);
      expect(acknowledged, isFalse);
      expect(seen, isEmpty);
      native.ack.complete(const Ok(null));
      expect((await cancelling).isOk, isTrue);
      expect((await finishing).isOk, isTrue);
    },
  );

  test(
    'completed graceful finish does not dispatch a later cancellation',
    () async {
      final native = _TraceSession();
      final adapter = StreamingLiveTranscriptAdapter(
        _BrokenEventsEngine(native),
      );
      final result = await adapter.open(_request);
      final session =
          (result as Ok<LiveTranscriptionSession, TranscriptionFailure>).value;
      final finishing = session.finish!();
      native.ack.complete(const Ok(null));
      expect((await finishing).isOk, isTrue);
      expect((await session.release()).isOk, isTrue);
      expect(native.reasons, [StreamingCloseReason.stopped]);
    },
  );

  test(
    'normal finish retains endpoint text until native STOP acknowledgement',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      h.native.emit(_text(0, 'unfinished'));
      await pumpEventQueue();
      var acknowledged = false;
      final finishing = session.finish!().then((result) {
        acknowledged = true;
        return result;
      });
      expect(h.native.closeReasons, [StreamingCloseReason.stopped]);
      h.native.emit(_text(1, 'Endpoint final', finalText: true));
      await pumpEventQueue();
      expect(acknowledged, isFalse);
      expect(
        seen.whereType<TranscriptionDraftUpdated>().last.chunk.rawText,
        'Endpoint final',
      );
      h.native.ack.complete(const Ok(null));
      expect(await finishing, isA<Ok<void, TranscriptionFailure>>());
      await pumpEventQueue();
      expect(seen.whereType<TranscriptionDraftDegraded>(), isEmpty);
    },
  );

  test(
    'a released UI handle with missing ACK is retained before reopening',
    () async {
      final native = _RetryEventsSession();
      addTearDown(native.source.close);
      final engine = _BrokenEventsEngine(native);
      final adapter = StreamingLiveTranscriptAdapter(engine);
      final opened = await adapter.open(_request);
      final session =
          (opened as Ok<LiveTranscriptionSession, TranscriptionFailure>).value;
      final releasing = session.release();
      native.firstAck.complete(
        const Err(StreamingUnavailable(StreamingFailureReason.engine)),
      );
      expect(await releasing, isA<Err<void, TranscriptionFailure>>());
      // The route may now discard its handle. The adapter must still own cleanup.
      final reopening = adapter.open(_request);
      await pumpEventQueue();
      expect(engine.allocations, 1);
      expect(native.closeCalls, 2);
      native.retryAck.complete(const Ok(null));
      final result = await reopening;
      expect(engine.allocations, 2);
      expect(
        (result as Err<LiveTranscriptionSession, TranscriptionFailure>)
            .failure
            .code,
        'transcription_model_unavailable',
      );
    },
  );

  test(
    'failed handoff retains cleanup responsibility until native ACK',
    () async {
      final native = _BrokenEventsSession();
      final engine = _BrokenEventsEngine(native);
      final adapter = StreamingLiveTranscriptAdapter(engine);
      var settled = false;
      final opening = adapter.open(_request).then((result) {
        settled = true;
        return result;
      });
      await pumpEventQueue();
      expect(native.closeCalls, 1);
      expect(settled, isFalse);
      native.firstAck.complete(const Ok(null));
      final result = await opening;
      expect(
        (result as Err<LiveTranscriptionSession, TranscriptionFailure>)
            .failure
            .code,
        'transcription_live_unavailable',
      );
    },
  );

  test(
    'unconfirmed handoff cleanup is retried before any later allocation',
    () async {
      final native = _BrokenEventsSession();
      final engine = _BrokenEventsEngine(native);
      final adapter = StreamingLiveTranscriptAdapter(engine);
      final opening = adapter.open(_request);
      native.firstAck.complete(
        const Err(StreamingUnavailable(StreamingFailureReason.engine)),
      );
      final failed = await opening;
      expect(
        (failed as Err<LiveTranscriptionSession, TranscriptionFailure>)
            .failure
            .code,
        'transcription_live_cleanup_unconfirmed',
      );
      final retried = adapter.open(_request);
      await pumpEventQueue();
      expect(native.closeCalls, 2);
      expect(engine.allocations, 1);
      native.retryAck.complete(const Ok(null));
      final result = await retried;
      expect(
        (result as Err<LiveTranscriptionSession, TranscriptionFailure>)
            .failure
            .code,
        'transcription_model_unavailable',
      );
      expect(engine.allocations, 2);
    },
  );

  test(
    'projects untouched provisional/final text and rejects a sealed rewrite',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      h.native
        ..emit(_text(0, 'hello 中国'))
        ..emit(_text(1, 'Hello 中国', finalText: true))
        ..emit(_text(2, 'WRONG rewritten final', finalText: true));
      await pumpEventQueue();
      final chunks = seen
          .whereType<TranscriptionDraftUpdated>()
          .map((e) => e.chunk)
          .toList();
      expect(chunks.map((c) => c.rawText), ['hello 中国', 'Hello 中国']);
      expect(chunks.map((c) => c.displayText), ['hello 中国', 'Hello 中国']);
      expect(chunks.map((c) => c.stability), [
        TranscriptStability.unstable,
        TranscriptStability.stable,
      ]);
      expect(chunks.first.segmentId, chunks.last.segmentId);
      expect(chunks.last.start, Duration.zero);
      expect(chunks.last.end, const Duration(seconds: 1));
    },
  );

  test(
    'captured-media gap reports incomplete coverage without inventing words',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      h.native
        ..emit(_text(0, 'before', finalText: true))
        ..emit(
          const StreamingGap(
            owner: _owner,
            sequence: 1,
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
            captureEpoch: 1,
            reason: StreamingGapReason.discontinuity,
          ),
        )
        ..emit(
          _text(
            2,
            'after',
            start: const Duration(seconds: 2),
            end: const Duration(seconds: 3),
            id: 'u2',
            captureEpoch: 1,
          ),
        );
      await pumpEventQueue();
      expect(
        seen.whereType<TranscriptionDraftUpdated>().map((e) => e.chunk.rawText),
        ['before', 'after'],
      );
      final gap = seen.whereType<TranscriptionDraftDegraded>().single;
      expect(gap.incomplete, isTrue);
      expect(gap.reason, 'transcription_live_discontinuity');
    },
  );

  test('zero-media pause is a boundary rather than lost coverage', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final session = await h.startView();
    final seen = <TranscriptionEvent>[];
    final subscription = session.events.listen(seen.add);
    addTearDown(subscription.cancel);
    h.native
      ..emit(_text(0, 'before', finalText: true))
      ..emit(
        const StreamingGap(
          owner: _owner,
          sequence: 1,
          start: Duration(seconds: 1),
          end: Duration(seconds: 1),
          captureEpoch: 1,
          reason: StreamingGapReason.pause,
        ),
      )
      ..emit(
        _text(
          2,
          'after',
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 2),
          id: 'u2',
          captureEpoch: 1,
        ),
      );
    await pumpEventQueue();
    expect(seen.whereType<TranscriptionDraftDegraded>(), isEmpty);
    expect(seen.whereType<TranscriptionDraftUpdated>(), hasLength(2));
  });

  test('buffers early events until the UI listener attaches', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final session = await h.startView();
    h.native.emit(_text(0, 'early'));
    await pumpEventQueue();
    final seen = <TranscriptionEvent>[];
    final subscription = session.events.listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(
      seen.whereType<TranscriptionDraftUpdated>().single.chunk.rawText,
      'early',
    );
  });

  test(
    'typed thermal failure preserves prior text and suppresses later callbacks',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      h.native
        ..emit(_text(0, 'retained'))
        ..emit(
          const StreamingFailed(
            owner: _owner,
            sequence: 1,
            failure: StreamingUnavailable(StreamingFailureReason.thermal),
          ),
        )
        ..emit(_text(2, 'late'));
      await pumpEventQueue();
      expect(
        seen.whereType<TranscriptionDraftUpdated>().single.chunk.rawText,
        'retained',
      );
      expect(
        seen.whereType<TranscriptionDraftDegraded>().single.reason,
        'transcription_live_thermal',
      );
    },
  );

  test('open failure retains a model-specific fallback code', () async {
    final h = _Harness()
      ..failure = const StreamingUnavailable(
        StreamingFailureReason.modelUnavailable,
      );
    addTearDown(h.dispose);
    final result = await StreamingLiveTranscriptAdapter(h).open(_request);
    expect(
      (result as Err<LiveTranscriptionSession, TranscriptionFailure>)
          .failure
          .code,
      'transcription_model_unavailable',
    );
  });

  test(
    'cancellation waits for native ACK without waiting for a paused UI',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add)..pause();
      addTearDown(subscription.cancel);
      h.native.emit(_text(0, 'queued'));
      var released = false;
      final closing = session.release().then((r) {
        released = true;
        return r;
      });
      await pumpEventQueue();
      expect(released, isFalse);
      expect(h.native.closeReasons, [StreamingCloseReason.cancelled]);
      h.native.ack.complete(const Ok(null));
      expect((await closing).isOk, isTrue);
      subscription.resume();
      await pumpEventQueue();
      expect(seen, isEmpty);
    },
  );

  test(
    'unobserved prefix is bounded and degrades safely on overflow',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final session = await h.startView();
      for (var i = 0; i < 70; i++) {
        h.native.emit(_text(i, 'revision $i'));
      }
      await pumpEventQueue();
      expect(h.native.closeReasons, [StreamingCloseReason.cancelled]);
      final seen = <TranscriptionEvent>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.length, lessThanOrEqualTo(65));
      expect(
        seen.whereType<TranscriptionDraftDegraded>().single.reason,
        'transcription_live_unavailable',
      );
    },
  );
}

const _owner = StreamingOwner(meetingId: 'meeting', runId: 'run', epoch: 1);
const _request = StreamingStartRequest(
  owner: _owner,
  modelId: 'explicit-probe',
  bundleSha256:
      '0000000000000000000000000000000000000000000000000000000000000000',
  parameterVersion: 1,
);

StreamingUtterance _text(
  int seq,
  String text, {
  bool finalText = false,
  Duration start = Duration.zero,
  Duration end = const Duration(seconds: 1),
  String id = 'u1',
  int captureEpoch = 0,
}) => StreamingUtterance(
  owner: _owner,
  sequence: seq,
  utteranceId: id,
  start: start,
  end: end,
  rawText: text,
  captureEpoch: captureEpoch,
  status: finalText
      ? StreamingUtteranceStatus.finalized
      : StreamingUtteranceStatus.provisional,
);

final class _Harness implements StreamingTranscriptionEngine {
  final native = _Native();
  StreamingFailure? failure;
  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async => failure == null ? Ok(native) : Err(failure!);
  Future<LiveTranscriptionSession> startView() async {
    final result = await StreamingLiveTranscriptAdapter(this).open(_request);
    expect(result, isA<Ok<LiveTranscriptionSession, TranscriptionFailure>>());
    return (result as Ok<LiveTranscriptionSession, TranscriptionFailure>).value;
  }

  Future<void> dispose() async {
    if (!native.ack.isCompleted) native.ack.complete(const Ok(null));
    await native.close(StreamingCloseReason.cancelled);
  }
}

final class _Native implements StreamingSession {
  final source = StreamController<StreamingEvent>.broadcast(sync: true);
  final ack = Completer<Result<void, StreamingFailure>>();
  final closeReasons = <StreamingCloseReason>[];
  Future<Result<void, StreamingFailure>>? _closing;
  @override
  StreamingOwner get owner => _owner;
  @override
  Stream<StreamingEvent> get events => source.stream;
  void emit(StreamingEvent event) => source.add(event);
  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    if (_closing != null) return _closing!;
    closeReasons.add(reason);
    return _closing = ack.future.then((r) {
      unawaited(source.close());
      return r;
    });
  }
}

final class _BrokenEventsEngine implements StreamingTranscriptionEngine {
  _BrokenEventsEngine(this.native);
  final StreamingSession native;
  int allocations = 0;
  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async {
    allocations++;
    return allocations == 1
        ? Ok(native)
        : const Err(
            StreamingUnavailable(StreamingFailureReason.modelUnavailable),
          );
  }
}

final class _RetryEventsSession implements StreamingSession {
  final source = StreamController<StreamingEvent>.broadcast();
  final firstAck = Completer<Result<void, StreamingFailure>>();
  final retryAck = Completer<Result<void, StreamingFailure>>();
  int closeCalls = 0;
  @override
  StreamingOwner get owner => _owner;
  @override
  Stream<StreamingEvent> get events => source.stream;
  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    closeCalls++;
    return closeCalls == 1 ? firstAck.future : retryAck.future;
  }
}

final class _TraceSession implements StreamingSession {
  final source = StreamController<StreamingEvent>.broadcast(sync: true);
  final ack = Completer<Result<void, StreamingFailure>>();
  final reasons = <StreamingCloseReason>[];
  @override
  StreamingOwner get owner => _owner;
  @override
  Stream<StreamingEvent> get events => source.stream;
  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    reasons.add(reason);
    return ack.future.then((result) {
      if (result.isOk) unawaited(source.close());
      return result;
    });
  }
}

final class _BrokenEventsSession implements StreamingSession {
  final firstAck = Completer<Result<void, StreamingFailure>>();
  final retryAck = Completer<Result<void, StreamingFailure>>();
  int closeCalls = 0;
  @override
  StreamingOwner get owner => _owner;
  @override
  Stream<StreamingEvent> get events =>
      throw StateError('synthetic listen construction failure');
  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    closeCalls++;
    return closeCalls == 1 ? firstAck.future : retryAck.future;
  }
}
