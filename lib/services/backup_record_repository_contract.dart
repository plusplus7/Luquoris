import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/domain/backup_entities.dart';
import 'package:meta/meta.dart';

/// Typed failures from durable backup-attempt persistence.
sealed class BackupRecordRepositoryFailure implements Failure {
  const BackupRecordRepositoryFailure(this.code);

  @override
  final String code;
}

/// The requested backup attempt does not exist.
final class BackupRecordNotFound extends BackupRecordRepositoryFailure {
  /// Creates a not-found failure.
  const BackupRecordNotFound() : super('backup_record_not_found');
}

/// A backup attempt conflicts with an existing or terminal record.
final class BackupRecordConflict extends BackupRecordRepositoryFailure {
  /// Creates a conflict failure.
  const BackupRecordConflict() : super('backup_record_conflict');
}

/// Local storage could not persist the backup attempt.
final class BackupRecordStoreUnavailable extends BackupRecordRepositoryFailure {
  /// Creates a storage failure with a privacy-safe [code].
  const BackupRecordStoreUnavailable(super.code);
}

/// Durable privacy-safe state for explicit local backup attempts.
abstract interface class BackupRecordRepository {
  /// Inserts one new pending operation.
  @useResult
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> createPending(
    BackupRecord record,
  );

  /// Atomically completes a pending operation.
  @useResult
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> complete(
    String operationId, {
    required AppRelativePath relativePath,
    required String sha256,
    required int bytes,
    required int updatedAtUtcMs,
  });

  /// Atomically records a stable terminal failure.
  @useResult
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  });

  /// Reads one durable attempt.
  @useResult
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> read(
    String operationId,
  );

  /// Marks operations left pending by process death as failed.
  @useResult
  Future<Result<int, BackupRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  });
}
