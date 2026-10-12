import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/export_backup/domain/export_entities.dart';
import 'package:loquiris/services/export_record_repository_contract.dart';

/// Drift-backed durable export-attempt repository.
final class DriftExportRecordRepository implements ExportRecordRepository {
  /// Creates a repository over the shared local database.
  const DriftExportRecordRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> createPending(
    ExportRecord record,
  ) async {
    if (record.state is! ExportPending) {
      return const Err(ExportRecordConflict());
    }
    try {
      await database
          .into(database.exportRecords)
          .insert(
            db.ExportRecordsCompanion.insert(
              id: record.id,
              createdAt: record.createdAtUtcMs,
              updatedAt: record.createdAtUtcMs,
              meetingId: record.meetingId,
              format: record.format.name,
              exportState: 'pending',
            ),
          );
      return Ok(record);
    } on SqliteException catch (error, stackTrace) {
      if (error.extendedResultCode == 1555 ||
          error.extendedResultCode == 2067) {
        return const Err(ExportRecordConflict());
      }
      return Err(
        _storeFailure('export_record_create_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> complete(
    String operationId, {
    required int bytes,
    required int updatedAtUtcMs,
  }) => _transition(
    operationId,
    updatedAtUtcMs: updatedAtUtcMs,
    companion: db.ExportRecordsCompanion(
      updatedAt: Value(updatedAtUtcMs),
      exportState: const Value('completed'),
      bytes: Value(bytes),
      relativePath: const Value(null),
      failureCode: const Value(null),
    ),
  );

  @override
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  }) {
    if (!_safeCode(code)) {
      return Future.value(const Err(ExportRecordConflict()));
    }
    return _transition(
      operationId,
      updatedAtUtcMs: updatedAtUtcMs,
      companion: db.ExportRecordsCompanion(
        updatedAt: Value(updatedAtUtcMs),
        exportState: const Value('failed'),
        relativePath: const Value(null),
        bytes: const Value(null),
        failureCode: Value(code),
      ),
    );
  }

  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> _transition(
    String operationId, {
    required int updatedAtUtcMs,
    required db.ExportRecordsCompanion companion,
  }) async {
    if (updatedAtUtcMs < 0) return const Err(ExportRecordConflict());
    try {
      final changed =
          await (database.update(database.exportRecords)..where(
                (row) =>
                    row.id.equals(operationId) &
                    row.exportState.equals('pending'),
              ))
              .write(companion);
      if (changed != 1) {
        final exists =
            await (database.select(database.exportRecords)..where(
                  (row) => row.id.equals(operationId),
                ))
                .getSingleOrNull();
        return Err(
          exists == null
              ? const ExportRecordNotFound()
              : const ExportRecordConflict(),
        );
      }
      return read(operationId);
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('export_record_transition_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<ExportRecord, ExportRecordRepositoryFailure>> read(
    String operationId,
  ) async {
    try {
      final row =
          await (database.select(database.exportRecords)..where(
                (value) => value.id.equals(operationId),
              ))
              .getSingleOrNull();
      return row == null ? const Err(ExportRecordNotFound()) : Ok(_read(row));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('export_record_read_failed', error, stackTrace));
    }
  }

  /// Reads the newest privacy-safe failed export for one meeting.
  Future<Result<ExportRecord?, ExportRecordRepositoryFailure>>
  latestFailedForMeeting(String meetingId) async {
    try {
      final query = database.select(database.exportRecords)
        ..where(
          (row) =>
              row.meetingId.equals(meetingId) &
              row.exportState.equals('failed') &
              row.isDeleted.equals(false),
        )
        ..orderBy([
          (row) => OrderingTerm.desc(row.updatedAt),
          (row) => OrderingTerm.desc(row.id),
        ])
        ..limit(1);
      final row = await query.getSingleOrNull();
      return Ok(row == null ? null : _read(row));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure('export_record_history_read_failed', error, stackTrace),
      );
    }
  }

  @override
  Future<Result<int, ExportRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  }) async {
    if (updatedAtUtcMs < 0) return const Err(ExportRecordConflict());
    try {
      final changed = await database.customUpdate(
        '''
        UPDATE export_records
        SET updated_at = CASE WHEN created_at > ? THEN created_at ELSE ? END,
            row_revision = row_revision + 1,
            export_state = 'failed',
            relative_path = NULL,
            bytes = NULL,
            failure_code = 'export_interrupted_incomplete_output_may_remain'
        WHERE export_state = 'pending' AND is_deleted = 0
        ''',
        variables: <Variable<Object>>[
          Variable<int>(updatedAtUtcMs),
          Variable<int>(updatedAtUtcMs),
        ],
        updates: {database.exportRecords},
      );
      return Ok(changed);
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          'export_record_interrupted_recovery_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  ExportRecord _read(db.ExportRecord row) => ExportRecord(
    id: row.id,
    meetingId: row.meetingId,
    format: LocalExportFormat.values.byName(row.format),
    createdAtUtcMs: row.createdAt,
    state: switch (row.exportState) {
      'pending' => const ExportPending(),
      'completed' => ExportCompleted(
        relativePath: switch (row.relativePath) {
          final path? => switch (AppRelativePath.tryParse(path)) {
            Ok(:final value) => value,
            Err() => throw StateError('invalid persisted export path'),
          },
          null => null,
        },
        bytes: row.bytes!,
      ),
      'failed' => ExportFailed(failureCode: row.failureCode!),
      _ => throw StateError('invalid persisted export state'),
    },
  );

  ExportRecordStoreUnavailable _storeFailure(
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
    return ExportRecordStoreUnavailable(code);
  }

  static bool _safeCode(String value) =>
      RegExp(r'^[a-z0-9_]{1,128}$').hasMatch(value);
}
