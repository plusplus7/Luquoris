import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_backup_record_repository.dart';
import 'package:loquiris/features/export_backup/domain/backup_entities.dart';
import 'package:loquiris/services/backup_record_repository_contract.dart';

void main() {
  late db.AppDatabase database;
  late DriftBackupRecordRepository repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftBackupRecordRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
  });

  tearDown(() => database.close());

  test('persists a completed checksummed private backup', () async {
    const pending = BackupRecord(
      id: 'backup-1',
      createdAtUtcMs: 10,
      state: BackupPending(),
    );
    await _ok(repository.createPending(pending));
    final path = _path('backups/loquiris-backup-backup-1.zip');

    await _ok(
      repository.complete(
        'backup-1',
        relativePath: path,
        sha256: _shaA,
        bytes: 2048,
        updatedAtUtcMs: 11,
      ),
    );

    expect(
      (await _ok(repository.read('backup-1'))).state,
      BackupCompleted(
        relativePath: path,
        sha256: _shaA,
        bytes: 2048,
      ),
    );
  });

  test('startup fails interrupted pending backups without a path', () async {
    await _ok(
      repository.createPending(
        const BackupRecord(
          id: 'backup-2',
          createdAtUtcMs: 20,
          state: BackupPending(),
        ),
      ),
    );

    final count = await repository.failInterruptedPending(updatedAtUtcMs: 30);

    expect((count as Ok<int, BackupRecordRepositoryFailure>).value, 1);
    expect(
      (await _ok(repository.read('backup-2'))).state,
      const BackupFailed(failureCode: 'backup_interrupted'),
    );
  });
}

AppRelativePath _path(String value) =>
    (AppRelativePath.tryParse(value)
            as Ok<AppRelativePath, InvalidAppRelativePath>)
        .value;

Future<T> _ok<T>(
  Future<Result<T, BackupRecordRepositoryFailure>> future,
) async => (await future as Ok<T, BackupRecordRepositoryFailure>).value;

const _shaA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
