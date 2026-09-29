import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// Result of loading the local meeting library.
@immutable
sealed class SessionsSnapshot {
  const SessionsSnapshot();
}

/// Successfully loaded local meetings.
final class SessionsLoaded extends SessionsSnapshot {
  /// Creates a successful snapshot.
  const SessionsLoaded(this.collection);

  /// Immutable meeting projections.
  final SessionCollection collection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionsLoaded && collection == other.collection;

  @override
  int get hashCode => collection.hashCode;
}

/// Expected local repository failure.
final class SessionsLoadFailed extends SessionsSnapshot {
  /// Creates a failed snapshot from a typed boundary value.
  const SessionsLoadFailed(this.failure);

  /// Stable, structured failure.
  final SessionRepositoryFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionsLoadFailed &&
          failure.runtimeType == other.failure.runtimeType &&
          failure.code == other.failure.code;

  @override
  int get hashCode => Object.hash(failure.runtimeType, failure.code);
}

/// Loads meeting-list presentation state from the injected repository.
final class SessionsController extends AsyncNotifier<SessionsSnapshot> {
  @override
  Future<SessionsSnapshot> build() async {
    final result = await ref.watch(sessionRepositoryProvider).list();
    return switch (result) {
      Ok(:final value) => SessionsLoaded(value),
      Err(:final failure) => SessionsLoadFailed(failure),
    };
  }

  /// Retries without discarding any screen-local navigation state.
  void retry() => ref.invalidateSelf();
}

/// Screen-lifetime meeting library state.
final AsyncNotifierProvider<SessionsController, SessionsSnapshot>
sessionsControllerProvider =
    AsyncNotifierProvider.autoDispose<SessionsController, SessionsSnapshot>(
      SessionsController.new,
    );
