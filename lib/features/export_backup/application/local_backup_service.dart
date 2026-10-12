import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/domain/backup_entities.dart';
import 'package:loquiris/services/backup_record_repository_contract.dart';
import 'package:meta/meta.dart';

/// Stable request for one user-confirmed local backup.
@immutable
final class BackupRequest extends ValueObject {
  /// Creates a request.
  const BackupRequest({required this.id, required this.createdAtUtcMs})
    : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable operation identifier.
  final String id;

  /// Injected UTC creation instant.
  final int createdAtUtcMs;

  @override
  List<Object?> get equalityValues => <Object?>[id, createdAtUtcMs];
}

/// Complete app-private backup artifact.
@immutable
final class BackupReceipt extends ValueObject {
  /// Creates a receipt.
  const BackupReceipt({
    required this.relativePath,
    required this.sha256,
    required this.bytes,
  });

  /// App-private archive path.
  final AppRelativePath relativePath;

  /// SHA-256 over the complete archive.
  final String sha256;

  /// Archive byte length.
  final int bytes;

  @override
  List<Object?> get equalityValues => <Object?>[relativePath, sha256, bytes];
}

/// Stable typed backup failure.
sealed class BackupFailure implements Failure {
  const BackupFailure(this.code);

  @override
  final String code;
}

/// Backup creation could not complete locally.
final class BackupUnavailable extends BackupFailure {
  /// Creates a failure with a privacy-safe [code].
  const BackupUnavailable(super.code);
}

/// One database-authorized recording prefix.
@immutable
final class BackupAudioPlanEntry extends ValueObject {
  /// Creates a plan entry.
  const BackupAudioPlanEntry({
    required this.relativePath,
    required this.committedBytes,
  });

  /// Validated path beneath app-private files.
  final String relativePath;

  /// Exact journal-authorized byte prefix.
  final int committedBytes;

  @override
  List<Object?> get equalityValues => <Object?>[relativePath, committedBytes];
}

/// WAL-safe SQLite snapshot and explicitly eligible audio prefixes.
@immutable
final class BackupSnapshotPlan extends ValueObject {
  /// Creates an immutable plan.
  BackupSnapshotPlan({
    required this.snapshotRelativePath,
    required List<BackupAudioPlanEntry> audioPlan,
  }) : audioPlan = List.unmodifiable(audioPlan);

  /// App-private snapshot path beneath the files root.
  final String snapshotRelativePath;

  /// Explicit recording prefixes, never a filesystem walk.
  final List<BackupAudioPlanEntry> audioPlan;

  @override
  List<Object?> get equalityValues => <Object?>[
    snapshotRelativePath,
    audioPlan,
  ];
}

/// Creates and cleans WAL-safe database snapshots.
abstract interface class BackupSnapshotPlanner {
  /// Creates the snapshot and authoritative audio plan.
  Future<Result<BackupSnapshotPlan, BackupFailure>> create(String operationId);

  /// Best-effort cleanup after native packaging or a failed invocation.
  Future<void> deleteSnapshot(String relativePath);
}

/// Value-only request passed to the native streaming ZIP writer.
@immutable
final class BackupNativeRequest extends ValueObject {
  /// Creates a native request.
  BackupNativeRequest({
    required this.operationId,
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.snapshotRelativePath,
    required List<BackupAudioPlanEntry> audioPlan,
  }) : audioPlan = List.unmodifiable(audioPlan);

  /// Stable operation identity.
  final String operationId;

  /// Database schema embedded independently in the manifest.
  final int schemaVersion;

  /// Injected canonical UTC instant.
  final String exportedAtUtc;

  /// App-private SQLite snapshot.
  final String snapshotRelativePath;

  /// Database-authorized audio prefixes.
  final List<BackupAudioPlanEntry> audioPlan;

  @override
  List<Object?> get equalityValues => <Object?>[
    operationId,
    schemaVersion,
    exportedAtUtc,
    snapshotRelativePath,
    audioPlan,
  ];
}

/// Native result before durable database completion.
@immutable
final class BackupNativeReceipt extends ValueObject {
  /// Creates a native receipt.
  const BackupNativeReceipt({
    required this.relativePath,
    required this.sha256,
    required this.bytes,
  });

  /// Complete app-private archive path.
  final AppRelativePath relativePath;

  /// Complete archive SHA-256.
  final String sha256;

  /// Complete archive byte length.
  final int bytes;

  @override
  List<Object?> get equalityValues => <Object?>[relativePath, sha256, bytes];
}

/// Native deterministic archive boundary.
// The interface is an injectable platform seam despite having one operation.
// ignore: one_member_abstracts
abstract interface class BackupGateway {
  /// Publishes one complete archive atomically.
  Future<Result<BackupNativeReceipt, BackupFailure>> create(
    BackupNativeRequest request,
  );
}

/// Deletes an app-private backup artifact when durable completion fails.
// The interface constrains private-file deletion in tests and production.
// ignore: one_member_abstracts
abstract interface class BackupArtifactCleaner {
  /// Best-effort deletion constrained to the backup directory.
  Future<void> delete(AppRelativePath relativePath);
}

/// User-confirmed local backup application boundary.
// This interface keeps presentation independent from the concrete orchestrator.
// ignore: one_member_abstracts
abstract interface class BackupService {
  /// Creates one complete checksummed local backup.
  Future<Result<BackupReceipt, BackupFailure>> create(BackupRequest request);
}

/// Orchestrates durable backup state, SQLite snapshotting, and native ZIP I/O.
final class LocalBackupService implements BackupService {
  /// Creates the backup service from injectable boundaries.
  const LocalBackupService({
    required this.snapshotPlanner,
    required this.gateway,
    required this.recordRepository,
    required this.artifactCleaner,
    required this.schemaVersion,
    required this.nowUtcMs,
  });

  /// Snapshot and audio-plan boundary.
  final BackupSnapshotPlanner snapshotPlanner;

  /// Native archive boundary.
  final BackupGateway gateway;

  /// Durable attempt persistence.
  final BackupRecordRepository recordRepository;

  /// Cleanup boundary for an archive that cannot be durably recorded.
  final BackupArtifactCleaner artifactCleaner;

  /// Current Drift schema version.
  final int schemaVersion;

  /// Injected UTC clock.
  final int Function() nowUtcMs;

  /// Creates one checksummed local backup after caller confirmation.
  @override
  Future<Result<BackupReceipt, BackupFailure>> create(
    BackupRequest request,
  ) async {
    final pending = await recordRepository.createPending(
      BackupRecord(
        id: request.id,
        createdAtUtcMs: request.createdAtUtcMs,
        state: const BackupPending(),
      ),
    );
    if (pending is Err<BackupRecord, BackupRecordRepositoryFailure>) {
      return const Err(BackupUnavailable('backup_record_unavailable'));
    }
    final planned = await snapshotPlanner.create(request.id);
    if (planned case Err(:final failure)) {
      return _recordFailure(request.id, failure);
    }
    final plan = (planned as Ok<BackupSnapshotPlan, BackupFailure>).value;
    try {
      final native = await gateway.create(
        BackupNativeRequest(
          operationId: request.id,
          schemaVersion: schemaVersion,
          exportedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            request.createdAtUtcMs,
            isUtc: true,
          ).toIso8601String(),
          snapshotRelativePath: plan.snapshotRelativePath,
          audioPlan: plan.audioPlan,
        ),
      );
      switch (native) {
        case Err(:final failure):
          return _recordFailure(request.id, failure);
        case Ok(:final value):
          final completed = await recordRepository.complete(
            request.id,
            relativePath: value.relativePath,
            sha256: value.sha256,
            bytes: value.bytes,
            updatedAtUtcMs: nowUtcMs(),
          );
          if (completed is Err<BackupRecord, BackupRecordRepositoryFailure>) {
            await artifactCleaner.delete(value.relativePath);
            return const Err(BackupUnavailable('backup_record_unavailable'));
          }
          return Ok(
            BackupReceipt(
              relativePath: value.relativePath,
              sha256: value.sha256,
              bytes: value.bytes,
            ),
          );
      }
    } finally {
      await snapshotPlanner.deleteSnapshot(plan.snapshotRelativePath);
    }
  }

  Future<Result<BackupReceipt, BackupFailure>> _recordFailure(
    String operationId,
    BackupFailure failure,
  ) async {
    final transition = await recordRepository.fail(
      operationId,
      code: failure.code,
      updatedAtUtcMs: nowUtcMs(),
    );
    if (transition is Err<BackupRecord, BackupRecordRepositoryFailure>) {
      return const Err(BackupUnavailable('backup_record_unavailable'));
    }
    return Err(failure);
  }
}
