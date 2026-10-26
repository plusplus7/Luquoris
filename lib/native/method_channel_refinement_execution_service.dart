import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Sole Dart owner of refinement_execution_v1; mirrored by the native contract.
final class MethodChannelRefinementExecutionService
    implements RefinementExecutionService {
  /// Creates the platform adapter or an injected contract-canary channel.
  const MethodChannelRefinementExecutionService({
    MethodChannel? channel,
    this.timeout = const Duration(hours: 6),
    this.cancelTimeout = const Duration(seconds: 5),
  }) : _channel =
           channel ??
           const MethodChannel('com.loquiris/refinement_execution_v1');

  final MethodChannel _channel;

  /// Upper bound on a complete pass; timeout requests cancellation, not success.
  final Duration timeout;

  /// Separate bounded wait for the out-of-band cancellation acknowledgement.
  final Duration cancelTimeout;

  @override
  Future<Result<TranscriptionOutput, RefinementExecutionFailure>> transcribe(
    RefinementExecutionInput input,
  ) async {
    if (!_validOwner(input.meetingId, input.runId) ||
        !_hash.hasMatch(input.audioInventorySha256) ||
        input.totalSamples <= 0 ||
        input.totalSamples > _maximumDurationSamples ||
        input.totalSamples % 1024 != 0) {
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_request_invalid'),
      );
    }
    final nativeCompletion = _channel.invokeMethod<Object?>('transcribe', {
      ..._owner(input.meetingId, input.runId),
      'audioInventorySha256': input.audioInventorySha256,
      'engineVersion': input.profile.engineVersion,
      'manifest': jsonDecode(input.profile.bundleManifestJson),
      'parameters': jsonDecode(input.profile.parametersJson),
    });
    try {
      final raw = await nativeCompletion.timeout(timeout);
      final envelope = _envelope(raw, input.meetingId, input.runId);
      if (envelope == null) return const Err(RefinementExecutionUnsettled());
      if (envelope['ok'] == false) return Err(_failure(envelope['failure']));
      if (envelope['engineVersion'] != input.profile.engineVersion) {
        return _invalid();
      }
      final rawSegments = envelope['segments'];
      if (rawSegments is! List<Object?>) return _invalid();
      final chunks = <TranscriptChunk>[];
      final ids = <String>{};
      var previousEnd = 0;
      for (final rawSegment in rawSegments) {
        if (rawSegment is! Map<Object?, Object?>) return _invalid();
        final id = rawSegment['id'];
        final start = rawSegment['startMs'];
        final end = rawSegment['endMs'];
        final text = rawSegment['rawText'];
        if (id is! String ||
            id.isEmpty ||
            !ids.add(id) ||
            start is! int ||
            end is! int ||
            start < previousEnd ||
            end <= start ||
            end > input.totalSamples ~/ 16 ||
            text is! String ||
            rawSegment['displayText'] != text) {
          return _invalid();
        }
        previousEnd = end;
        chunks.add(
          TranscriptChunk(
            segmentId: id,
            start: Duration(milliseconds: start),
            end: Duration(milliseconds: end),
            rawText: text,
            displayText: text,
            stability: TranscriptStability.stable,
          ),
        );
      }
      return Ok(
        TranscriptionOutput(
          chunks: chunks,
          engineVersion: input.profile.engineVersion,
        ),
      );
    } on TimeoutException {
      // A cancel acknowledgement only latches cancellation. Do not return an
      // ordinary terminal failure until the original call has settled cleanup.
      final cancellation = await cancel(
        meetingId: input.meetingId,
        runId: input.runId,
      );
      switch (cancellation) {
        case Ok():
        case Err():
          break;
      }
      try {
        final terminal = await nativeCompletion;
        if (_envelope(terminal, input.meetingId, input.runId) == null) {
          return const Err(RefinementExecutionUnsettled());
        }
      } on Object {
        return const Err(RefinementExecutionUnsettled());
      }
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_timeout'),
      );
    } on PlatformException {
      return const Err(RefinementExecutionUnsettled());
    } on MissingPluginException {
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_unavailable'),
      );
    }
  }

  @override
  Future<Result<void, RefinementExecutionFailure>> cancel({
    required String meetingId,
    required String runId,
  }) async {
    if (!_validOwner(meetingId, runId)) {
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_request_invalid'),
      );
    }
    try {
      final raw = await _channel
          .invokeMethod<Object?>('cancel', _owner(meetingId, runId))
          .timeout(cancelTimeout);
      final envelope = _envelope(raw, meetingId, runId);
      if (envelope == null) return _invalid();
      return envelope['ok'] == true
          ? const Ok(null)
          : Err(_failure(envelope['failure']));
    } on TimeoutException {
      return const Err(
        RefinementExecutionUnavailable('refinement_cancellation_timeout'),
      );
    } on PlatformException {
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_unavailable'),
      );
    } on MissingPluginException {
      return const Err(
        RefinementExecutionUnavailable('refinement_execution_unavailable'),
      );
    }
  }

  Map<Object?, Object?>? _envelope(Object? raw, String meeting, String run) {
    if (raw is! Map<Object?, Object?> ||
        raw['v'] is! int ||
        raw['v'] != 1 ||
        raw['ok'] is! bool ||
        raw['meetingId'] != meeting ||
        raw['runId'] != run) {
      return null;
    }
    return raw;
  }

  RefinementExecutionFailure _failure(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return const RefinementExecutionUnavailable(
        'refinement_execution_channel_invalid',
      );
    }
    final code = raw['code'];
    if (code is! String || !_code.hasMatch(code)) {
      return const RefinementExecutionUnavailable(
        'refinement_execution_channel_invalid',
      );
    }
    return switch (raw['kind']) {
      'unavailable' => RefinementExecutionUnavailable(code),
      'deferred' => RefinementExecutionDeferred(code),
      'cancelled' => const RefinementExecutionCancelled(),
      _ => const RefinementExecutionUnavailable(
        'refinement_execution_channel_invalid',
      ),
    };
  }

  Err<T, RefinementExecutionFailure> _invalid<T>() => const Err(
    RefinementExecutionUnavailable('refinement_execution_channel_invalid'),
  );
  bool _validOwner(String meeting, String run) =>
      _identifier.hasMatch(meeting) && _identifier.hasMatch(run);
  Map<String, Object?> _owner(String meeting, String run) => {
    'v': 1,
    'meetingId': meeting,
    'runId': run,
  };
}

final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._\-]{0,127}$');
// One AAC frame is 1024 samples / 64000 microseconds. Divide before multiplying.
const int _maximumDurationSamples = (0x7fffffffffffffff ~/ 64000) * 1024;
final _hash = RegExp(r'^[0-9a-f]{64}$');
final _code = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
