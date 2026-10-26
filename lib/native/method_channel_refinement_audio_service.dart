import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';

/// Sole Dart owner of the read-only refinement_audio_v1 wire contract.
final class MethodChannelRefinementAudioService
    implements RefinementAudioInventoryService {
  /// Creates the platform adapter or an injected test channel.
  const MethodChannelRefinementAudioService({
    MethodChannel? channel,
    this.timeout = const Duration(minutes: 5),
  }) : _channel =
           channel ?? const MethodChannel('com.loquiris/refinement_audio_v1');

  final MethodChannel _channel;

  /// Maximum platform wait; timing out never authorizes input or creates a job.
  final Duration timeout;

  @override
  Future<Result<RefinementAudioInventory, RefinementAudioFailure>> inspect(
    String meetingId, {
    String? expectedSha256,
  }) async {
    if (!_identifier.hasMatch(meetingId) ||
        (expectedSha256 != null && !_hash.hasMatch(expectedSha256))) {
      return const Err(
        RefinementAudioUnavailable('refinement_audio_request_invalid'),
      );
    }
    try {
      final raw = await _channel
          .invokeMethod<Object?>('inspect', <String, Object?>{
            'v': 1,
            'meetingId': meetingId,
            'expectedSha256': expectedSha256,
          })
          .timeout(timeout);
      return _parse(raw, meetingId, expectedSha256);
    } on TimeoutException {
      return const Err(RefinementAudioUnavailable('refinement_audio_timeout'));
    } on PlatformException {
      return const Err(
        RefinementAudioUnavailable('refinement_audio_unavailable'),
      );
    } on MissingPluginException {
      return const Err(
        RefinementAudioUnavailable('refinement_audio_unavailable'),
      );
    }
  }

  Result<RefinementAudioInventory, RefinementAudioFailure> _parse(
    Object? raw,
    String meetingId,
    String? expectedSha256,
  ) {
    if (raw is! Map<Object?, Object?> ||
        raw['v'] is! int ||
        raw['v'] != 1 ||
        raw['meetingId'] != meetingId ||
        raw['ok'] is! bool) {
      return _invalid();
    }
    if (raw['ok'] == false) return _failure(raw['failure']);
    final inventory = raw['inventory'];
    if (inventory is! Map<Object?, Object?>) return _invalid();
    final hash = inventory['sha256'];
    final samples = inventory['totalSamples'];
    final count = inventory['segmentCount'];
    if (hash is! String ||
        !_hash.hasMatch(hash) ||
        (expectedSha256 != null && hash != expectedSha256) ||
        samples is! int ||
        samples <= 0 ||
        samples % 1_024 != 0 ||
        count is! int ||
        count <= 0 ||
        count > 10_000 ||
        inventory['sampleRateHz'] is! int ||
        inventory['sampleRateHz'] != 16_000 ||
        samples < count * 1_024) {
      return _invalid();
    }
    final segments = _parseSegments(inventory['segments'], count, samples);
    if (segments == null) return _invalid();
    return Ok(
      RefinementAudioInventory(
        sha256: hash,
        totalSamples: samples,
        segments: segments,
      ),
    );
  }

  List<RefinementAudioSegmentInventory>? _parseSegments(
    Object? raw,
    int count,
    int totalSamples,
  ) {
    if (raw is! List<Object?> || raw.length != count) return null;
    var offset = 0;
    final segments = <RefinementAudioSegmentInventory>[];
    for (final (index, value) in raw.indexed) {
      if (value is! Map<Object?, Object?>) return null;
      final start = value['startSample'];
      final samples = value['committedSamples'];
      final bytes = value['committedBytes'];
      final hash = value['sha256'];
      final reference = value['referenceSha256'];
      if (value['index'] is! int ||
          value['index'] != index ||
          start is! int ||
          start != offset ||
          samples is! int ||
          samples <= 0 ||
          samples % 1_024 != 0 ||
          bytes is! int ||
          bytes <= 0 ||
          bytes > 64 * 1_024 * 1_024 ||
          hash is! String ||
          !_hash.hasMatch(hash) ||
          reference is! String ||
          !_hash.hasMatch(reference)) {
        return null;
      }
      offset += samples;
      if (offset > totalSamples) return null;
      segments.add(
        RefinementAudioSegmentInventory(
          index: index,
          startSample: start,
          committedSamples: samples,
          committedBytes: bytes,
          sha256: hash,
          referenceSha256: reference,
        ),
      );
    }
    return offset == totalSamples ? segments : null;
  }

  Result<RefinementAudioInventory, RefinementAudioFailure> _failure(
    Object? raw,
  ) {
    if (raw is! Map<Object?, Object?>) return _invalid();
    final code = raw['code'];
    if (code is! String || !_code.hasMatch(code)) return _invalid();
    return switch (raw['kind']) {
      'deferred' => Err(RefinementAudioDeferred(code)),
      'cancelled' => const Err(RefinementAudioCancelled()),
      'unavailable' => Err(RefinementAudioUnavailable(code)),
      _ => _invalid(),
    };
  }

  Result<RefinementAudioInventory, RefinementAudioFailure> _invalid() =>
      const Err(RefinementAudioUnavailable('refinement_audio_channel_invalid'));
}

final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._\-]{0,127}$');
final _hash = RegExp(r'^[0-9a-f]{64}$');
final _code = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
