import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

/// Android implementation without any network I/O on Flutter's isolate.
final class MethodChannelRemoteTranscriptionService
    implements RemoteTranscriptionService {
  /// Allows tests to observe protocol calls through an injected channel.
  const MethodChannelRemoteTranscriptionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.loquiris/remote_v1');
  final MethodChannel _channel;

  Future<Result<T, RemoteTranscriptionFailure>> _call<T>(
    String name, [
    Map<String, Object?>? data,
  ]) async {
    try {
      final value = await _channel.invokeMethod<Object?>(name, data);
      if (value is! Map<Object?, Object?> || value['ok'] != true) {
        return const Err(
          RemoteTranscriptionFailure('remote_platform_unavailable'),
        );
      }
      if (T == String && value['value'] is! String) {
        return const Err(RemoteTranscriptionFailure('remote_platform_invalid'));
      }
      return Ok(value['value'] as T);
    } on PlatformException {
      return const Err(
        RemoteTranscriptionFailure('remote_platform_unavailable'),
      );
    } on MissingPluginException {
      return const Err(
        RemoteTranscriptionFailure('remote_platform_unavailable'),
      );
    }
  }

  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  ) => _call<String>('saveConnection', {'endpoint': endpoint, 'token': token});

  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async {
    final loaded = await _call<Object?>('loadConnection');
    if (loaded case Err(:final failure)) return Err(failure);
    final value = (loaded as Ok<Object?, RemoteTranscriptionFailure>).value;
    if (value == null) return const Ok(null);
    if (value is! Map<Object?, Object?> ||
        value['endpoint'] is! String ||
        value['credentialRef'] is! String) {
      return const Err(RemoteTranscriptionFailure('remote_platform_invalid'));
    }
    return Ok(
      RemoteSavedConnection(
        value['endpoint']! as String,
        value['credentialRef']! as String,
      ),
    );
  }

  @override
  Future<Result<void, RemoteTranscriptionFailure>> prepareDatabase() =>
      _call<void>('prepare');
  @override
  Future<Result<void, RemoteTranscriptionFailure>> resume(
    String databasePath,
  ) => _call<void>('resume', {'databasePath': databasePath});
  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() =>
      _call<void>('wake');
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveCredential(
    String endpoint,
    String token,
  ) => _call<String>('saveCredential', {'endpoint': endpoint, 'token': token});
}
