import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Android method-channel implementation of generation-validated playback.
final class MethodChannelSessionPlaybackService
    implements SessionPlaybackService {
  /// Creates the service with an injectable [channel].
  const MethodChannelSessionPlaybackService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.loquiris/session_playback_v1';
  static const _version = 1;

  final MethodChannel _channel;

  @override
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> load(
    String sessionId, {
    required String ownerId,
  }) async {
    final result = await _invoke('load', <String, Object?>{
      'sessionId': sessionId,
      'ownerId': ownerId,
    });
    return switch (result) {
      Ok(:final value) when value.sessionId != sessionId => const Err(
        SessionPlaybackFailure('playback_snapshot_session_mismatch'),
      ),
      _ => result,
    };
  }

  @override
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> current({
    required String ownerId,
  }) => _invoke('current', <String, Object?>{'ownerId': ownerId});

  @override
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> play({
    required String ownerId,
  }) => _invoke('play', <String, Object?>{'ownerId': ownerId});

  @override
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> pause({
    required String ownerId,
  }) => _invoke('pause', <String, Object?>{'ownerId': ownerId});

  @override
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> seek(
    Duration position, {
    required String ownerId,
  }) => _invoke('seek', <String, Object?>{
    'positionMilliseconds': position.inMilliseconds,
    'ownerId': ownerId,
  });

  @override
  Future<void> release({required String ownerId}) async {
    try {
      await _channel.invokeMethod<Object?>('release', {
        'v': _version,
        'ownerId': ownerId,
      });
    } on PlatformException {
      // Release is best-effort and never changes authoritative audio.
    } on MissingPluginException {
      // Tests and unsupported platforms have no native player to release.
    }
  }

  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> _invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    try {
      final value = await _channel.invokeMethod<Object?>(method, {
        'v': _version,
        ...arguments,
      });
      if (value is! Map<Object?, Object?> || value['v'] != _version) {
        return const Err(SessionPlaybackFailure('playback_channel_invalid'));
      }
      if (value['ok'] != true) {
        final failure = value['failure'];
        final code = failure is Map<Object?, Object?> ? failure['code'] : null;
        return Err(
          SessionPlaybackFailure(
            code is String && code.isNotEmpty
                ? code
                : 'playback_channel_invalid',
          ),
        );
      }
      return _parseSnapshot(value['snapshot']);
    } on PlatformException {
      return const Err(SessionPlaybackFailure('playback_channel_unavailable'));
    } on MissingPluginException {
      return const Err(SessionPlaybackFailure('playback_channel_unavailable'));
    }
  }

  Result<SessionPlaybackSnapshot, SessionPlaybackFailure> _parseSnapshot(
    Object? value,
  ) {
    if (value is! Map<Object?, Object?>) {
      return const Err(SessionPlaybackFailure('playback_channel_invalid'));
    }
    final sessionId = value['sessionId'];
    final stateName = value['state'];
    final position = value['positionMilliseconds'];
    final duration = value['durationMilliseconds'];
    final state = stateName is String
        ? SessionPlaybackState.values
              .where((candidate) => candidate.name == stateName)
              .firstOrNull
        : null;
    if (sessionId is! String ||
        sessionId.isEmpty ||
        state == null ||
        position is! int ||
        position < 0 ||
        duration is! int ||
        duration < 0 ||
        position > duration) {
      return const Err(SessionPlaybackFailure('playback_channel_invalid'));
    }
    return Ok(
      SessionPlaybackSnapshot(
        sessionId: sessionId,
        state: state,
        position: Duration(milliseconds: position),
        duration: Duration(milliseconds: duration),
      ),
    );
  }
}
