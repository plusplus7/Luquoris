import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_endpoint.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

/// Bridges a typed load failure into AsyncNotifier's exception-based loading API.
final class RemoteSettingsLoadException implements Exception {
  /// Preserves the stable failure code without exposing credentials.
  const RemoteSettingsLoadException(this.failure);

  /// Recoverable boundary failure rendered by the settings form.
  final RemoteTranscriptionFailure failure;
}

/// Owns the default connection without creating a meeting or transcription run.
final class RemoteSettingsController extends AsyncNotifier<RemoteDestination?> {
  @override
  Future<RemoteDestination?> build() async {
    final result = await ref
        .read(remoteTranscriptionRepositoryProvider)
        .latestDestination();
    if (result case Ok(value: final destination?)) {
      final rebound = await ref
          .read(remoteTranscriptionRepositoryProvider)
          .configurePending(destination);
      if (rebound case Err(:final failure)) {
        throw RemoteSettingsLoadException(failure);
      }
    }
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw RemoteSettingsLoadException(failure),
    };
  }

  /// Saves private native credentials and binds only already authorized intents.
  Future<void> save(String endpoint, String token) async {
    if (state.isLoading) return;
    if (!isRemoteEndpoint(endpoint) ||
        token.length < 32 ||
        token.length > 4096 ||
        token.contains(RegExp(r'[\r\n]'))) {
      state = AsyncError(
        const RemoteTranscriptionFailure('remote_invalid_connection'),
        StackTrace.current,
      );
      return;
    }
    final keepAlive = ref.keepAlive();
    try {
      state = const AsyncLoading();
      final result = await ref
          .read(remoteTranscriptionServiceProvider)
          .saveConnection(endpoint, token);
      if (!ref.mounted) return;
      if (result case Err(:final failure)) {
        state = AsyncError(failure, StackTrace.current);
        return;
      }
      final reference =
          (result as Ok<String, RemoteTranscriptionFailure>).value;
      final destination = RemoteDestination(
        endpoint.replaceFirst(RegExp(r'/$'), ''),
        reference,
        'qwen-1.7b',
      );
      final configured = await ref
          .read(remoteTranscriptionRepositoryProvider)
          .configurePending(destination);
      if (!ref.mounted) return;
      state = switch (configured) {
        Ok() => AsyncData(destination),
        Err(:final failure) => AsyncError(failure, StackTrace.current),
      };
    } finally {
      keepAlive.close();
    }
  }
}

/// Reconstructs connection settings from native no-backup storage.
final AsyncNotifierProvider<RemoteSettingsController, RemoteDestination?>
remoteSettingsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      RemoteSettingsController,
      RemoteDestination?
    >(RemoteSettingsController.new);
