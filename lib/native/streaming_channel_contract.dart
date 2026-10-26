import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Sole Dart owner of streaming_v1, mirrored by StreamingChannelContract.kt.
final class StreamingChannelContract {
  const StreamingChannelContract._();

  /// Bidirectional control/event channel; no PCM crosses this boundary.
  static const channelName = 'com.loquiris/streaming_v1';

  /// Whether a locally pinned start request is safe to send across the channel.
  static bool validRequest(StreamingStartRequest request) =>
      _identifier.hasMatch(request.owner.meetingId) &&
      _identifier.hasMatch(request.owner.runId) &&
      request.owner.epoch >= 0 &&
      _identifier.hasMatch(request.modelId) &&
      _hash.hasMatch(request.bundleSha256) &&
      request.parameterVersion == 1;

  /// Encodes an owner-scoped open without transferring PCM through Dart.
  ///
  /// Callers must first check [validRequest]; Android independently validates it.
  static Map<String, Object?> encodeStart(StreamingStartRequest request) => {
    ..._header(request.owner),
    'modelId': request.modelId,
    'bundleSha256': request.bundleSha256,
    'parameterVersion': request.parameterVersion,
  };

  /// Encodes explicit stop-flush versus cancellation with immutable ownership.
  static Map<String, Object?> encodeClose(
    StreamingOwner owner,
    StreamingCloseReason reason,
  ) => {
    ..._header(owner),
    'reason': reason.name,
  };

  /// Parses validated owner events; null means foreign or malformed, never text.
  static StreamingEvent? decodeEvent(Object? raw, StreamingOwner owner) {
    if (raw is! Map<Object?, Object?> || !_owned(raw, owner)) return null;
    final sequence = raw['sequence'];
    if (sequence is! int || sequence < 0 || sequence >= 0x7fffffffffffffff) {
      return null;
    }
    if (raw['type'] == 'failure') return _failureEvent(raw, owner, sequence);
    if (sequence == 0x7fffffffffffffff - 1) return null;
    return _captureEvent(raw, owner, sequence);
  }

  /// Whether an acknowledgement carries the exact owner and release state.
  static bool isEnvelope(Object? raw, StreamingOwner owner) =>
      raw is Map<Object?, Object?> &&
      _owned(raw, owner) &&
      raw['ok'] is bool &&
      raw['released'] is bool &&
      _hasKeys(raw, {
        ..._ownerKeys,
        'ok',
        'released',
        if (raw['ok'] == false) 'reason',
      }) &&
      (raw['ok'] == true || decodeFailure(raw['reason']) != null);

  /// Parses only stable declared reasons, never native paths or exception text.
  static StreamingFailure? decodeFailure(Object? value) {
    for (final reason in StreamingFailureReason.values) {
      if (value == reason.name) return StreamingUnavailable(reason);
    }
    return null;
  }

  static StreamingEvent? _captureEvent(
    Map<Object?, Object?> raw,
    StreamingOwner owner,
    int sequence,
  ) {
    final start = raw['startSample'];
    final end = raw['endSampleExclusive'];
    final epoch = raw['captureEpoch'];
    if (start is! int ||
        end is! int ||
        epoch is! int ||
        epoch < 0 ||
        start < 0 ||
        end < start ||
        end > _maximumSample) {
      return null;
    }
    final common = {
      ..._ownerKeys,
      'type',
      'sequence',
      'startSample',
      'endSampleExclusive',
      'captureEpoch',
    };
    if (raw['type'] == 'gap' && _hasKeys(raw, {...common, 'reason'})) {
      for (final reason in StreamingGapReason.values) {
        if (raw['reason'] == reason.name) {
          return StreamingGap(
            owner: owner,
            sequence: sequence,
            start: _duration(start),
            end: _duration(end),
            captureEpoch: epoch,
            reason: reason,
          );
        }
      }
    }
    final id = raw['utteranceId'];
    final text = raw['rawText'];
    final finalized = raw['finalized'];
    if (raw['type'] != 'text' ||
        !_hasKeys(raw, {...common, 'utteranceId', 'rawText', 'finalized'}) ||
        end == start ||
        id is! String ||
        !_identifier.hasMatch(id) ||
        text is! String ||
        text.length > 16000 ||
        finalized is! bool) {
      return null;
    }
    return StreamingUtterance(
      owner: owner,
      sequence: sequence,
      utteranceId: id,
      start: _duration(start),
      end: _duration(end),
      captureEpoch: epoch,
      rawText: text,
      status: finalized
          ? StreamingUtteranceStatus.finalized
          : StreamingUtteranceStatus.provisional,
    );
  }

  static StreamingEvent? _failureEvent(
    Map<Object?, Object?> raw,
    StreamingOwner owner,
    int sequence,
  ) {
    if (!_hasKeys(raw, {
          ..._ownerKeys,
          'type',
          'sequence',
          'reason',
          'released',
        }) ||
        raw['released'] != true) {
      return null;
    }
    final failure = decodeFailure(raw['reason']);
    return failure == null
        ? null
        : StreamingFailed(owner: owner, sequence: sequence, failure: failure);
  }

  static bool _owned(Map<Object?, Object?> raw, StreamingOwner owner) =>
      raw['v'] is int &&
      raw['v'] == 1 &&
      raw['meetingId'] == owner.meetingId &&
      raw['runId'] == owner.runId &&
      raw['epoch'] is int &&
      raw['epoch'] == owner.epoch;

  static Map<String, Object?> _header(StreamingOwner owner) => {
    'v': 1,
    'meetingId': owner.meetingId,
    'runId': owner.runId,
    'epoch': owner.epoch,
  };

  static bool _hasKeys(Map<Object?, Object?> raw, Set<String> keys) =>
      raw.length == keys.length && raw.keys.every(keys.contains);

  // Canonical 16 kHz samples; floor half-microseconds, divide before multiplying.
  static Duration _duration(int sample) =>
      Duration(microseconds: (sample ~/ 2) * 125 + (sample % 2) * 62);
}

const _ownerKeys = {'v', 'meetingId', 'runId', 'epoch'};
const int _maximumSample = 0x7fffffffffffffff ~/ 125;
final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._\-]{0,127}$');
final _hash = RegExp(r'^[a-f0-9]{64}$');
