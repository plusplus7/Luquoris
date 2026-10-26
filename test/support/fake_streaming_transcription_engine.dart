import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Deterministic contract fake; owns no microphone, model, or platform handle.
final class FakeStreamingTranscriptionEngine
    implements StreamingTranscriptionEngine {
  final Map<StreamingOwner, FakeStreamingSession> _sessions = {};
  StreamingFailure? nextOpenFailure;
  int releaseCount = 0;

  Set<StreamingOwner> get activeOwners => _sessions.keys.toSet();

  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async {
    if (_sessions.keys.any(
      (owner) => owner.meetingId == request.owner.meetingId,
    )) {
      return const Err(
        StreamingUnavailable(StreamingFailureReason.alreadyOwned),
      );
    }
    final failure = nextOpenFailure;
    if (failure != null) return Err(failure);
    final session = FakeStreamingSession(request.owner, () {
      _sessions.remove(request.owner);
      releaseCount += 1;
    });
    _sessions[request.owner] = session;
    return Ok(session);
  }
}

final class FakeStreamingSession implements StreamingSession {
  FakeStreamingSession(this.owner, this._release);

  @override
  final StreamingOwner owner;
  final _events = StreamController<StreamingEvent>.broadcast(sync: true);
  final void Function() _release;
  Future<Result<void, StreamingFailure>>? _closing;
  int _lastSequence = -1;
  bool _discardPending = false;

  @override
  Stream<StreamingEvent> get events => _events.stream.where(
    (event) =>
        _closing == null || (event is StreamingFailed && !_discardPending),
  );

  bool deliver(StreamingEvent event) {
    if (_closing != null ||
        event.owner != owner ||
        event.sequence <= _lastSequence) {
      return false;
    }
    _lastSequence = event.sequence;
    _events.add(event);
    if (event is StreamingFailed) {
      unawaited(_closing ??= _close());
    }
    return true;
  }

  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    _discardPending = true;
    return _closing ??= _close();
  }

  Future<Result<void, StreamingFailure>> _close() async {
    _release();
    // Leave synchronous listener dispatch before closing the controller.
    await Future<void>.value();
    // A paused consumer must not retain native ownership or delay its ack.
    unawaited(_events.close());
    return const Ok(null);
  }
}
