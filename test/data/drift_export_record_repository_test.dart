import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_export_record_repository.dart';
import 'package:loquiris/features/export_backup/domain/export_entities.dart';
import 'package:loquiris/services/export_record_repository_contract.dart';

void main() {
  late db.AppDatabase database;
  late DriftExportRecordRepository repository;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftExportRecordRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await database
        .into(database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: 'meeting-1',
            createdAt: 1,
            updatedAt: 1,
            title: 'Private title',
            lifecycle: 'finalized',
            languageMode: 'mixed',
          ),
        );
  });

  tearDown(() => database.close());

  test('direct SAF completion is durable without an external path', () async {
    const pending = ExportRecord(
      id: 'export-1',
      meetingId: 'meeting-1',
      format: LocalExportFormat.archive,
      createdAtUtcMs: 10,
      state: ExportPending(),
    );

    expect(
      await repository.createPending(pending),
      isA<Ok<ExportRecord, ExportRecordRepositoryFailure>>(),
    );
    expect(
      await repository.complete('export-1', bytes: 4096, updatedAtUtcMs: 11),
      isA<Ok<ExportRecord, ExportRecordRepositoryFailure>>(),
    );

    final stored = await _ok(repository.read('export-1'));
    expect(stored.state, const ExportCompleted(bytes: 4096));
    final row = await database.select(database.exportRecords).getSingle();
    expect(row.relativePath, isNull);
    expect(row.bytes, 4096);
    expect(row.failureCode, isNull);
  });

  test(
    'stable terminal failure is durable and cannot be overwritten',
    () async {
      const pending = ExportRecord(
        id: 'export-2',
        meetingId: 'meeting-1',
        format: LocalExportFormat.audioSegments,
        createdAtUtcMs: 20,
        state: ExportPending(),
      );
      await _ok(repository.createPending(pending));

      final failed = await repository.fail(
        'export-2',
        code: 'export_incomplete_output_cleanup_failed',
        updatedAtUtcMs: 21,
      );
      expect(failed, isA<Ok<ExportRecord, ExportRecordRepositoryFailure>>());
      final conflicting = await repository.complete(
        'export-2',
        bytes: 9,
        updatedAtUtcMs: 22,
      );

      expect(
        (conflicting as Err<ExportRecord, ExportRecordRepositoryFailure>)
            .failure,
        isA<ExportRecordConflict>(),
      );
      expect(
        (await _ok(repository.read('export-2'))).state,
        const ExportFailed(
          failureCode: 'export_incomplete_output_cleanup_failed',
        ),
      );
    },
  );

  test(
    'startup reconciles interrupted pending exports to a durable warning',
    () async {
      const pending = ExportRecord(
        id: 'export-interrupted',
        meetingId: 'meeting-1',
        format: LocalExportFormat.archive,
        createdAtUtcMs: 30,
        state: ExportPending(),
      );
      await _ok(repository.createPending(pending));

      final recovered = await repository.failInterruptedPending(
        updatedAtUtcMs: 40,
      );

      expect(
        (recovered as Ok<int, ExportRecordRepositoryFailure>).value,
        1,
      );
      expect(
        (await _ok(repository.read('export-interrupted'))).state,
        const ExportFailed(
          failureCode: 'export_interrupted_incomplete_output_may_remain',
        ),
      );
      final latest = await _ok(repository.latestFailedForMeeting('meeting-1'));
      expect(latest?.id, 'export-interrupted');
    },
  );
}

Future<T> _ok<T>(
  Future<Result<T, ExportRecordRepositoryFailure>> future,
) async => (await future as Ok<T, ExportRecordRepositoryFailure>).value;
