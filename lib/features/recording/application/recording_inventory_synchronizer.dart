import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/recording_recovery_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Reconciles authoritative native recording manifests into local storage.
// This interface keeps native scanning replaceable in controller tests.
// ignore: one_member_abstracts
abstract interface class RecordingInventorySynchronizer {
  /// Scans native authority and persists its complete audio inventory.
  Future<Result<void, SessionRepositoryFailure>> synchronize();
}

/// Production inventory reconciliation shared by finalization and backup.
final class NativeRecordingInventorySynchronizer
    implements RecordingInventorySynchronizer {
  /// Creates a synchronizer at the native/persistence boundary.
  const NativeRecordingInventorySynchronizer({
    required this._recoveryGateway,
    required this._sessionRepository,
    required this._nowUtcMs,
  });

  final RecordingRecoveryGateway _recoveryGateway;
  final SessionRepository _sessionRepository;
  final int Function() _nowUtcMs;

  @override
  Future<Result<void, SessionRepositoryFailure>> synchronize() async {
    final inventory = await _recoveryGateway.scan();
    switch (inventory) {
      case Err(:final failure):
        return Err(SessionRepositoryUnavailable(failure.code));
      case Ok(:final value):
        final reconciliation = await _sessionRepository.reconcileRecovery(
          value.sessions,
          observedAtUtcMs: _nowUtcMs(),
          liveMeetingIds: value.liveMeetingIds,
          invalidStorageKeys: value.invalidStorageKeys,
        );
        return switch (reconciliation) {
          Ok() => const Ok<void, SessionRepositoryFailure>(null),
          Err(:final failure) => Err(failure),
        };
    }
  }
}

final class _NoopRecordingInventorySynchronizer
    implements RecordingInventorySynchronizer {
  const _NoopRecordingInventorySynchronizer();

  @override
  Future<Result<void, SessionRepositoryFailure>> synchronize() async =>
      const Ok(null);
}

/// App-scoped native inventory synchronization boundary.
final recordingInventorySynchronizerProvider =
    Provider<RecordingInventorySynchronizer>(
      (ref) => const _NoopRecordingInventorySynchronizer(),
    );
