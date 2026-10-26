import 'dart:async';

import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/native/streaming_channel_contract.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Test-only, content-free observations at native wire, projection and view boundaries.
final class StreamingDeliveryTrace {
  StreamingDeliveryTrace(this.owner);

  final StreamingOwner owner;
  int _openRequests = 0;
  int _openAccepted = 0;
  int _openRejected = 0;
  int _openTransportErrors = 0;
  final _openReasons = <String>{};
  int _wireText = 0;
  int _wireFinals = 0;
  int _wireNonemptyFinals = 0;
  int _wireGaps = 0;
  final _wireGapDetails = <Map<String, Object>>[];
  int _wireRejected = 0;
  int _projectedText = 0;
  int _projectedNonemptyFinals = 0;
  int _projectedGapNotices = 0;
  int _viewNonemptyFinals = 0;
  String _viewStatus = 'not_observed';
  bool _viewIncomplete = false;
  final _wireReasons = <String>{};
  final _projectedReasons = <String>{};
  final _viewReasons = <String>{};

  StreamingPlatformPort wrapPort(StreamingPlatformPort port) =>
      _TracedStreamingPort(
        port,
        _recordWire,
        _recordRequest,
        _recordOpenReply,
        () {
          _openTransportErrors++;
        },
      );

  void _recordRequest(String method) {
    if (method == 'open') _openRequests++;
  }

  void _recordOpenReply(Object? raw) {
    if (!StreamingChannelContract.isEnvelope(raw, owner) ||
        raw is! Map<Object?, Object?>) {
      _openRejected++;
      _openReasons.add('malformed');
    } else if (raw['ok'] == true && raw['released'] == false) {
      _openAccepted++;
    } else {
      _openRejected++;
      final failure = StreamingChannelContract.decodeFailure(raw['reason']);
      _openReasons.add(
        failure is StreamingUnavailable ? failure.reason.name : 'closed',
      );
    }
  }

  void _recordWire(Object? raw) {
    final event = StreamingChannelContract.decodeEvent(raw, owner);
    switch (event) {
      case StreamingUtterance():
        _wireText++;
        if (event.status == StreamingUtteranceStatus.finalized) {
          _wireFinals++;
          if (event.rawText.trim().isNotEmpty) _wireNonemptyFinals++;
        }
      case StreamingGap():
        _wireGaps++;
        if (_wireGapDetails.length < 32) {
          _wireGapDetails.add({
            'sequence': event.sequence,
            'startUs': event.start.inMicroseconds,
            'endUs': event.end.inMicroseconds,
            'captureEpoch': event.captureEpoch,
            'reason': event.reason.name,
          });
        }
      case StreamingFailed(failure: StreamingUnavailable(:final reason)):
        _wireReasons.add(reason.name);
      case null:
        _wireRejected++;
    }
  }

  void recordProjection(TranscriptionEvent event) {
    if (event.runId != owner.runId) return;
    switch (event) {
      case TranscriptionDraftUpdated(:final chunk):
        _projectedText++;
        if (chunk.stability == TranscriptStability.stable &&
            chunk.rawText.trim().isNotEmpty) {
          _projectedNonemptyFinals++;
        }
      case TranscriptionDraftDegraded(:final reason):
        _projectedReasons.add(_safeReason(reason));
        if (reason == 'transcription_live_discontinuity') {
          _projectedGapNotices++;
        }
      case TranscriptionProgressUpdated():
        break;
    }
  }

  void recordView(LiveTranscriptState? state) {
    if (state == null ||
        state.meetingId != owner.meetingId ||
        state.runId != owner.runId) {
      return;
    }
    _viewStatus = state.status.name;
    _viewIncomplete = state.incomplete;
    _viewNonemptyFinals = state.chunks
        .where(
          (chunk) =>
              chunk.stability == TranscriptStability.stable &&
              chunk.rawText.trim().isNotEmpty,
        )
        .length;
    final reason = state.degradationReason;
    if (reason != null) _viewReasons.add(_safeReason(reason));
  }

  Map<String, Object> get snapshot => {
    'openRequests': _openRequests,
    'openAccepted': _openAccepted,
    'openRejected': _openRejected,
    'openTransportErrors': _openTransportErrors,
    'openFailureReasons': _openReasons.toList(),
    'wireText': _wireText,
    'wireFinals': _wireFinals,
    'wireNonemptyFinals': _wireNonemptyFinals,
    'wireGaps': _wireGaps,
    'wireGapDetails': [
      for (final gap in _wireGapDetails) Map<String, Object>.of(gap),
    ],
    'wireGapDetailsDropped': _wireGaps - _wireGapDetails.length,
    'wireRejected': _wireRejected,
    'wireFailureReasons': _wireReasons.toList(),
    'projectedText': _projectedText,
    'projectedNonemptyFinals': _projectedNonemptyFinals,
    'projectedGapNotices': _projectedGapNotices,
    'projectedFailureReasons': _projectedReasons.toList(),
    'viewStatus': _viewStatus,
    'viewIncomplete': _viewIncomplete,
    'viewNonemptyFinals': _viewNonemptyFinals,
    'viewFailureReasons': _viewReasons.toList(),
  };
}

String _safeReason(String reason) =>
    _knownReasons.contains(reason) ? reason : 'unrecognized';

const _knownReasons = {
  'transcription_live_cleanup_unconfirmed',
  'transcription_live_unavailable',
  'transcription_live_discontinuity',
  'transcription_model_unavailable',
  'transcription_live_thermal',
  'transcription_live_backlog',
  'transcription_live_memory',
  'transcription_live_already_owned',
  'transcription_live_closed',
};

final class _TracedStreamingPort implements StreamingPlatformPort {
  _TracedStreamingPort(
    this._inner,
    this._observe,
    this._request,
    this._reply,
    this._openError,
  );
  final StreamingPlatformPort _inner;
  final void Function(Object?) _observe;
  final void Function(String) _request;
  final void Function(Object?) _reply;
  final void Function() _openError;
  @override
  Future<Object?> request(String method, Map<String, Object?> arguments) {
    _request(method);
    final Future<Object?> pending;
    try {
      pending = _inner.request(method, arguments);
    } on Object {
      if (method == 'open') _openError();
      rethrow;
    }
    if (method == 'open') {
      unawaited(
        pending.then<void>(
          _reply,
          onError: (Object _, StackTrace _) {
            _openError();
          },
        ),
      );
    }
    return pending;
  }

  @override
  void onEvent(void Function(Object?) receive) {
    _inner.onEvent((raw) {
      _observe(raw);
      receive(raw);
    });
  }

  @override
  void close() => _inner.close();
}
