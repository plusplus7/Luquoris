import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/export_backup/domain/backup_entities.dart';
import 'package:loquiris/services/backup_record_repository_contract.dart';

/// Drift-backed durable backup-attempt repository.
final class DriftBackupRecordRepository implements BackupRecordRepository {
  /// Creates a repository over the shared local database.
  const DriftBackupRecordRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe diagnostic sink.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> createPending(
    BackupRecord record,
  ) async {
    if (record.state is! BackupPending) {
      return const Err(BackupRecordConflict());
    }
    try {
      await database
          .into(database.backupRecords)
          .insert(
            db.BackupRecordsCompanion.insert(
              id: record.id,
              createdAt: record.createdAtUtcMs,
              updatedAt: record.createdAtUtcMs,
              backupState: 'pending',
            ),
          );
      return Ok(record);
    } on SqliteException catch (error, stackTrace) {
      if (error.extendedResultCode == 1555 ||
          error.extendedResultCode == 2067) {
        return const Err(BackupRecordConflict());
      }
      return Err(
        _storeFailure('backup_record_create_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> complete(
    String operationId, {
    required AppRelativePath relativePath,
    required String sha256,
    required int bytes,
    required int updatedAtUtcMs,
  }) {
    if (!_safeSha256(sha256) || bytes < 0) {
      return Future.value(const Err(BackupRecordConflict()));
    }
    return _transition(
      operationId,
      updatedAtUtcMs: updatedAtUtcMs,
      companion: db.BackupRecordsCompanion(
        updatedAt: Value(updatedAtUtcMs),
        backupState: const Value('completed'),
        relativePath: Value(relativePath.value),
        sha256: Value(sha256),
        bytes: Value(bytes),
        failureCode: const Value(null),
      ),
    );
  }

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  }) {
    if (!_safeCode(code)) {
      return Future.value(const Err(BackupRecordConflict()));
    }
    return _transition(
      operationId,
      updatedAtUtcMs: updatedAtUtcMs,
      companion: db.BackupRecordsCompanion(
        updatedAt: Value(updatedAtUtcMs),
        backupState: const Value('failed'),
        relativePath: const Value(null),
        sha256: const Value(null),
        bytes: const Value(null),
        failureCode: Value(code),
      ),
    );
  }

  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> _transition(
    String operationId, {
    required int updatedAtUtcMs,
    required db.BackupRecordsCompanion companion,
  }) async {
    if (updatedAtUtcMs < 0) return const Err(BackupRecordConflict());
    try {
      final changed =
          await (database.update(database.backupRecords)..where(
                (row) =>
                    row.id.equals(operationId) &
                    row.backupState.equals('pending'),
              ))
              .write(companion);
      if (changed != 1) {
        final exists = await (database.select(
          database.backupRecords,
        )..where((row) => row.id.equals(operationId))).getSingleOrNull();
        return Err(
          exists == null
              ? const BackupRecordNotFound()
              : const BackupRecordConflict(),
        );
      }
      return read(operationId);
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('backup_record_transition_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> read(
    String operationId,
  ) async {
    try {
      final row = await (database.select(
        database.backupRecords,
      )..where((value) => value.id.equals(operationId))).getSingleOrNull();
      return row == null ? const Err(BackupRecordNotFound()) : Ok(_read(row));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('backup_record_read_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<int, BackupRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  }) async {
    if (updatedAtUtcMs < 0) return const Err(BackupRecordConflict());
    try {
      final changed = await database.customUpdate(
        '''
        UPDATE backup_records
        SET updated_at = CASE WHEN created_at > ? THEN created_at ELSE ? END,
            row_revision = row_revision + 1,
            backup_state = 'failed',
            relative_path = NULL,
            sha256 = NULL,
            bytes = NULL,
            failure_code = 'backup_interrupted'
        WHERE backup_state = 'pending' AND is_deleted = 0
        ''',
        variables: <Variable<Object>>[
          Variable<int>(updatedAtUtcMs),
          Variable<int>(updatedAtUtcMs),
        ],
        updates: {database.backupRecords},
      );
      return Ok(changed);
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          'backup_record_interrupted_recovery_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  BackupRecord _read(db.BackupRecord row) => BackupRecord(
    id: row.id,
    createdAtUtcMs: row.createdAt,
    state: switch (row.backupState) {
      'pending' => const BackupPending(),
      'completed' => BackupCompleted(
        relativePath: switch (AppRelativePath.tryParse(row.relativePath!)) {
          Ok(:final value) => value,
          Err() => throw StateError('invalid persisted backup path'),
        },
        sha256: row.sha256!,
        bytes: row.bytes!,
      ),
      'failed' => BackupFailed(failureCode: row.failureCode!),
      _ => throw StateError('invalid persisted backup state'),
    },
  );

  BackupRecordStoreUnavailable _storeFailure(
    String code,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.exportOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
    return BackupRecordStoreUnavailable(code);
  }

  static bool _safeCode(String value) =>
      RegExp(r'^[a-z0-9_]{1,128}$').hasMatch(value);

  static bool _safeSha256(String value) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
}
