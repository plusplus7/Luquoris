import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/domain/streaming_draft.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Projects an explicitly selected streaming owner onto the read-only live UI.
final class StreamingLiveTranscriptAdapter {
  /// Uses the injected engine; construction never allocates native resources.
  StreamingLiveTranscriptAdapter(this._engine);

  final StreamingTranscriptionEngine _engine;
  final _quarantined = <StreamingSession>{};

  /// Opens only the explicit request, without selecting a model or starting capture.
  Future<Result<LiveTranscriptionSession, TranscriptionFailure>> open(
    StreamingStartRequest request,
  ) async {
    if (!await _clearQuarantine()) {
      return const Err(
        TranscriptionUnavailable('transcription_live_cleanup_unconfirmed'),
      );
    }
    StreamingSession? acquired;
    try {
      final result = await _engine.open(request);
      if (result case Err(:final failure)) return Err(_failure(failure));
      acquired = (result as Ok<StreamingSession, StreamingFailure>).value;
      final projected = _StreamingProjection(acquired, _quarantined).session;
      acquired =
          null; // Ownership transfers only after the complete UI handle exists.
      return Ok(projected);
    } on Object {
      if (acquired != null) {
        _quarantined.add(acquired);
        if (!await _clearQuarantine()) {
          return const Err(
            TranscriptionUnavailable('transcription_live_cleanup_unconfirmed'),
          );
        }
      }
      return const Err(
        TranscriptionUnavailable('transcription_live_unavailable'),
      );
    }
  }

  Future<bool> _clearQuarantine() async {
    final released = await Future.wait(
      _quarantined.toList().map((session) async {
        try {
          final result = await session.close(StreamingCloseReason.cancelled);
          if (result.isOk) _quarantined.remove(session);
          return result.isOk;
        } on Object {
          return false; // Retain this owner; no new allocation until a real ACK.
        }
      }),
    );
    return released.every((confirmed) => confirmed);
  }
}

final class _StreamingProjection {
  _StreamingProjection(this._native, this._quarantined)
    : _draft = StreamingDraft.empty(_native.owner) {
    _subscription = _native.events.listen(
      _receive,
      onError: _streamError,
      onDone: _streamDone,
    );
    if (_closed) unawaited(_subscription?.cancel());
  }

  final StreamingSession _native;
  final Set<StreamingSession> _quarantined;
  StreamingDraft _draft;
  StreamSubscription<StreamingEvent>? _subscription;
  late final _events = StreamController<TranscriptionEvent>(
    onListen: () {
      _listened = true;
    },
  );
  late final Stream<TranscriptionEvent> _broadcast = _events.stream
      .asBroadcastStream();
  bool _listened = false;
  int _prefixCount = 0;
  bool _closed = false;
  bool _finishing = false;
  final _nativeDone = Completer<void>();
  bool _discardPending = false;
  Future<Result<void, TranscriptionFailure>>? _closing;

  LiveTranscriptionSession get session => LiveTranscriptionSession(
    meetingId: _native.owner.meetingId,
    runId: _native.owner.runId,
    events: _broadcast.where((_) => !_discardPending),
    finish: _finish,
    release: () {
      _discardPending = true;
      return _close();
    },
  );

  void _receive(StreamingEvent event) {
    if (_closed) return;
    final next = _draft.accept(event);
    if (identical(next, _draft)) return;
    _draft = next;
    switch (event) {
      case StreamingUtterance():
        _emit(
          TranscriptionDraftUpdated(
            runId: _native.owner.runId,
            chunk: TranscriptChunk(
              segmentId: event.utteranceId,
              start: event.start,
              end: event.end,
              rawText: event.rawText,
              displayText: event.rawText,
              stability: event.status == StreamingUtteranceStatus.finalized
                  ? TranscriptStability.stable
                  : TranscriptStability.unstable,
            ),
            backlog: Duration.zero,
          ),
        );
      case StreamingGap():
        if (event.end > event.start) {
          _emit(
            TranscriptionDraftDegraded(
              runId: _native.owner.runId,
              reason: 'transcription_live_discontinuity',
              backlog: Duration.zero,
              incomplete: true,
            ),
          );
        }
      case StreamingFailed(:final failure):
        _degrade(_failure(failure).code);
    }
  }

  void _emit(TranscriptionEvent event) {
    if (_closed) return;
    if (!_listened && _prefixCount >= 64) {
      _degrade('transcription_live_unavailable');
      return;
    }
    if (!_listened) _prefixCount++;
    _events.add(event);
  }

  void _degrade(String code) {
    if (_closed) return;
    _events.add(
      TranscriptionDraftDegraded(
        runId: _native.owner.runId,
        reason: code,
        backlog: Duration.zero,
        incomplete: true,
      ),
    );
    unawaited(_close());
  }

  void _streamError(Object _, StackTrace _) =>
      _degrade('transcription_live_unavailable');
  void _streamDone() {
    if (!_nativeDone.isCompleted) _nativeDone.complete();
    if (_finishing) return;
    if (!_closed) _degrade('transcription_live_unavailable');
  }

  Future<Result<void, TranscriptionFailure>> _finish() {
    final existing = _closing;
    if (existing != null) return existing;
    if (_closed) return _close();
    _finishing = true;
    final pending = _finishNative();
    _closing = pending;
    unawaited(
      pending.then((result) {
        if (result is Err<void, TranscriptionFailure> &&
            identical(_closing, pending)) {
          _closing = null;
        }
      }),
    );
    return pending;
  }

  Future<Result<void, TranscriptionFailure>> _finishNative() async {
    _quarantined.add(_native);
    try {
      final result = await _native.close(StreamingCloseReason.stopped);
      if (result case Err(:final failure)) return Err(_failure(failure));
      _quarantined.remove(_native);
      await _nativeDone.future;
      _finishing = false;
      _closed = true;
      _draft = _draft.close();
      unawaited(_events.close());
      return const Ok(null);
    } on Object {
      return const Err(
        TranscriptionUnavailable('transcription_live_unavailable'),
      );
    }
  }

  Future<Result<void, TranscriptionFailure>> _close() {
    _closed = true;
    _draft = _draft.close();
    final existing = _closing;
    if (existing != null) {
      if (_finishing) {
        _finishing = false;
        unawaited(_release());
        if (!_nativeDone.isCompleted) _nativeDone.complete();
      }
      return existing;
    }
    final pending = _release();
    _closing = pending;
    unawaited(
      pending.then((result) {
        if (result is Err<void, TranscriptionFailure> &&
            identical(_closing, pending)) {
          _closing = null;
        }
      }),
    );
    return pending;
  }

  Future<Result<void, TranscriptionFailure>> _release() async {
    _quarantined.add(_native);
    try {
      final pending = _native.close(StreamingCloseReason.cancelled);
      final detached = _subscription?.cancel();
      final result = await pending;
      if (result.isOk) _quarantined.remove(_native);
      await detached;
      if (result.isOk) unawaited(_events.close());
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(_failure(failure)),
      };
    } on Object {
      return const Err(
        TranscriptionUnavailable('transcription_live_unavailable'),
      );
    }
  }
}

TranscriptionFailure _failure(StreamingFailure failure) => switch (failure) {
  StreamingUnavailable(:final reason) => TranscriptionUnavailable(
    switch (reason) {
      StreamingFailureReason.modelUnavailable =>
        'transcription_model_unavailable',
      StreamingFailureReason.thermal => 'transcription_live_thermal',
      StreamingFailureReason.backlog => 'transcription_live_backlog',
      StreamingFailureReason.memory => 'transcription_live_memory',
      StreamingFailureReason.alreadyOwned => 'transcription_live_already_owned',
      StreamingFailureReason.closed => 'transcription_live_closed',
      StreamingFailureReason.engine => 'transcription_live_unavailable',
    },
  ),
};
