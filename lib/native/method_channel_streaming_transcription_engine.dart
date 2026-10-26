import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/streaming_channel_contract.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Owns streaming platform leases; no production composition root installs it yet.
final class MethodChannelStreamingTranscriptionEngine
    implements StreamingTranscriptionEngine {
  /// Creates a native bridge or a contract-honouring test transport.
  MethodChannelStreamingTranscriptionEngine({StreamingPlatformPort? port})
    : _port = port ?? MethodChannelStreamingPort() {
    _port.onEvent(_receive);
  }

  final StreamingPlatformPort _port;
  final _sessions = <StreamingOwner, _ChannelStreamingSession>{};
  final _retired = <StreamingOwner>{};
  bool _disposed = false;

  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async {
    final owner = request.owner;
    if (_disposed) {
      return const Err(StreamingUnavailable(StreamingFailureReason.closed));
    }
    if (!StreamingChannelContract.validRequest(request)) {
      return const Err(
        StreamingUnavailable(StreamingFailureReason.modelUnavailable),
      );
    }
    if (_sessions.keys.any((active) => active.meetingId == owner.meetingId)) {
      return const Err(
        StreamingUnavailable(StreamingFailureReason.alreadyOwned),
      );
    }
    if (_retired.contains(owner)) {
      return const Err(StreamingUnavailable(StreamingFailureReason.closed));
    }
    final session = _ChannelStreamingSession(owner, _port, () {
      _sessions.remove(owner);
    });
    _sessions[owner] = session;
    _retired.add(
      owner,
    ); // Never let a queued callback revive this same wire identity.
    try {
      final raw = await Future.any<Object?>([
        _port.request('open', StreamingChannelContract.encodeStart(request)),
        session.whenReleased.future,
      ]);
      if (session.released) {
        return const Err(StreamingUnavailable(StreamingFailureReason.closed));
      }
      if (!StreamingChannelContract.isEnvelope(raw, owner) ||
          raw is! Map<Object?, Object?>) {
        unawaited(session.close(StreamingCloseReason.cancelled));
        return const Err(StreamingUnavailable(StreamingFailureReason.engine));
      }
      if (raw['released'] == true) session.release();
      if (raw['ok'] == false) {
        if (!session.released) {
          unawaited(session.close(StreamingCloseReason.cancelled));
        }
        return Err(
          StreamingChannelContract.decodeFailure(raw['reason']) ??
              const StreamingUnavailable(StreamingFailureReason.engine),
        );
      }
      if (_disposed || session.released) {
        return const Err(StreamingUnavailable(StreamingFailureReason.closed));
      }
      return Ok(session);
    } on MissingPluginException {
      session.release(); // No handler adopted the request.
      return const Err(
        StreamingUnavailable(StreamingFailureReason.modelUnavailable),
      );
    } on Object {
      unawaited(session.close(StreamingCloseReason.cancelled));
      return const Err(StreamingUnavailable(StreamingFailureReason.engine));
    }
  }

  void _receive(Object? raw) {
    if (raw is! Map<Object?, Object?>) return;
    for (final session in _sessions.values.toList()) {
      final owner = session.owner;
      if (raw['meetingId'] != owner.meetingId ||
          raw['runId'] != owner.runId ||
          raw['epoch'] is! int ||
          raw['epoch'] != owner.epoch) {
        continue;
      }
      final event = StreamingChannelContract.decodeEvent(raw, owner);
      if (event == null) {
        unawaited(session.failProtocol());
      } else {
        session.deliver(event);
      }
      return;
    }
  }

  /// Requests cancellation of every lease without manufacturing release.
  Future<Result<void, StreamingFailure>> dispose() async {
    _disposed = true;
    // Dispatch every close before waiting: one lost reply must not strand others.
    final results = await Future.wait(
      _sessions.values.toList().map(
        (session) => session.close(StreamingCloseReason.cancelled),
      ),
    );
    for (final result in results) {
      switch (result) {
        case Ok():
          break;
        case Err(:final failure):
          return Err(failure);
      }
    }
    _port.close();
    return const Ok(null);
  }
}

final class _ChannelStreamingSession implements StreamingSession {
  _ChannelStreamingSession(this.owner, this._port, this._onRelease);
  @override
  final StreamingOwner owner;
  final StreamingPlatformPort _port;
  final void Function() _onRelease;
  // Buffer before the first listener, including events received before open ACK.
  late final _events = StreamController<StreamingEvent>(
    onListen: () {
      _listened = true;
    },
  );
  bool _listened = false;
  int _beforeListenerCount = 0;
  late final Stream<StreamingEvent> _broadcast = _events.stream
      .asBroadcastStream();
  final whenReleased = Completer<Object?>();
  Future<Result<void, StreamingFailure>>? _closing;
  Completer<Result<void, StreamingFailure>>? _closeCompletion;
  StreamingCloseReason? _closingReason;
  bool released = false;
  bool _discardPending = false;
  bool _acceptText = true;
  int _lastSequence = -1;
  StreamingFailure? _protocolFailure;

  @override
  Stream<StreamingEvent> get events =>
      _broadcast.where((_) => !_discardPending);

  void deliver(StreamingEvent event) {
    if (released || event.sequence <= _lastSequence) return;
    switch (event) {
      case StreamingFailed():
        _lastSequence = event.sequence;
        _protocolFailure =
            null; // The native terminal event is the one failure.
        _events.add(event);
        release();
      case StreamingUtterance():
      case StreamingGap():
        if (_acceptText) {
          _lastSequence = event.sequence;
          _publish(event);
        }
    }
  }

  void _publish(StreamingEvent event) {
    if (!_listened) {
      if (_beforeListenerCount >= 64) {
        unawaited(failProtocol());
        return;
      }
      _beforeListenerCount++;
    }
    _events.add(event);
  }

  Future<Result<void, StreamingFailure>> failProtocol() {
    _acceptText = false;
    _protocolFailure ??= const StreamingUnavailable(
      StreamingFailureReason.engine,
    );
    return _beginClose(StreamingCloseReason.cancelled);
  }

  @override
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason) {
    if (reason != StreamingCloseReason.stopped) {
      _discardPending = true;
      _acceptText = false;
    }
    return _beginClose(reason);
  }

  Future<Result<void, StreamingFailure>> _beginClose(
    StreamingCloseReason reason,
  ) {
    if (released) return Future.value(const Ok(null));
    final pending = _closing;
    if (pending != null) {
      if (_closingReason == StreamingCloseReason.stopped &&
          reason != StreamingCloseReason.stopped) {
        _closingReason = reason;
        unawaited(_requestClose(reason, _closeCompletion!, auxiliary: true));
      }
      return pending;
    }
    final completion = Completer<Result<void, StreamingFailure>>();
    _closeCompletion = completion;
    _closing = completion.future;
    _closingReason = reason;
    // Reserve before dispatch: synchronous transport throws must be retryable.
    unawaited(_requestClose(reason, completion));
    return completion.future;
  }

  Future<void> _requestClose(
    StreamingCloseReason reason,
    Completer<Result<void, StreamingFailure>> completion, {
    bool auxiliary = false,
  }) async {
    Result<void, StreamingFailure> result;
    try {
      final raw = await _port.request(
        'close',
        StreamingChannelContract.encodeClose(owner, reason),
      );
      if (!StreamingChannelContract.isEnvelope(raw, owner) ||
          raw is! Map<Object?, Object?> ||
          raw['released'] != true) {
        result = const Err(StreamingUnavailable(StreamingFailureReason.engine));
      } else {
        result = raw['ok'] == true
            ? const Ok(null)
            : Err(
                StreamingChannelContract.decodeFailure(raw['reason']) ??
                    const StreamingUnavailable(StreamingFailureReason.engine),
              );
        release(result);
        return;
      }
    } on Object {
      result = const Err(StreamingUnavailable(StreamingFailureReason.engine));
    }
    if (auxiliary) {
      return; // A failed upgrade is not failure of the original pending ACK.
    }
    if (!completion.isCompleted) completion.complete(result);
    if (!released && identical(_closeCompletion, completion)) {
      _closeCompletion = null;
      _closing = null; // A failed ACK is retryable, not proof of release.
      _closingReason = null;
    }
  }

  void release([Result<void, StreamingFailure> outcome = const Ok(null)]) {
    if (released) return;
    released = true;
    whenReleased.complete(null);
    final failure = _protocolFailure;
    if (failure != null && !_discardPending) {
      _events.add(
        StreamingFailed(
          owner: owner,
          sequence: _lastSequence + 1,
          failure: failure,
        ),
      );
    }
    _onRelease();
    // Paused subscribers may drain later; they cannot retain native ownership.
    unawaited(_events.close());
    final completion = _closeCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete(outcome);
    }
  }
}
