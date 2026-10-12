import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/domain/export_entities.dart';
import 'package:meta/meta.dart';

/// Typed failures from durable export-attempt persistence.
sealed class ExportRecordRepositoryFailure implements Failure {
  const ExportRecordRepositoryFailure(this.code);

  @override
  final String code;
}

/// The requested export attempt does not exist.
final class ExportRecordNotFound extends ExportRecordRepositoryFailure {
  /// Creates a not-found failure.
  const ExportRecordNotFound() : super('export_record_not_found');
}

/// An export attempt conflicts with an existing or terminal record.
final class ExportRecordConflict extends ExportRecordRepositoryFailure {
  /// Creates a conflict failure.
  const ExportRecordConflict() : super('export_record_conflict');
}

/// Local storage could not persist the export attempt.
final class ExportRecordStoreUnavailable extends ExportRecordRepositoryFailure {
  /// Creates a storage failure with a privacy-safe [code].
  const ExportRecordStoreUnavailable(super.code);
}

/// Durable privacy-safe state for user-authorized export attempts.
abstract interface class ExportRecordRepository {
  /// Inserts one new pending export operation.
  @useResult
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> createPending(
    ExportRecord record,
  );

  /// Atomically completes a pending operation without storing an external path.
  @useResult
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> complete(
    String operationId, {
    required int bytes,
    required int updatedAtUtcMs,
  });

  /// Atomically records one stable terminal failure for a pending operation.
  @useResult
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  });

  /// Reads one durable attempt by its internal operation identity.
  @useResult
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> read(
    String operationId,
  );

  /// Marks operations left pending by process death as failed and identifiable.
  @useResult
  Future<Result<int, ExportRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  });
}
