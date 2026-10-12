import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/domain/backup_entities.dart';
import 'package:loquiris/services/backup_record_repository_contract.dart';

void main() {
  test('orchestrates snapshot native package and durable completion', () async {
    final records = _FakeBackupRecords();
    final planner = _FakeSnapshotPlanner();
    final gateway = _FakeBackupGateway();
    final service = LocalBackupService(
      snapshotPlanner: planner,
      gateway: gateway,
      recordRepository: records,
      artifactCleaner: const _NoopArtifactCleaner(),
      schemaVersion: 4,
      nowUtcMs: () => 101,
    );

    final result = await service.create(
      const BackupRequest(id: 'backup_1', createdAtUtcMs: 100),
    );

    expect(result, isA<Ok<BackupReceipt, BackupFailure>>());
    expect(records.current?.state, isA<BackupCompleted>());
    expect(planner.cleaned, ['backup_staging/backup_1.sqlite']);
  });

  test('records native failure and cleans snapshot', () async {
    final records = _FakeBackupRecords();
    final planner = _FakeSnapshotPlanner();
    final service = LocalBackupService(
      snapshotPlanner: planner,
      gateway: _FakeBackupGateway(failureCode: 'backup_publish_failed'),
      recordRepository: records,
      artifactCleaner: const _NoopArtifactCleaner(),
      schemaVersion: 4,
      nowUtcMs: () => 101,
    );

    final result = await service.create(
      const BackupRequest(id: 'backup_2', createdAtUtcMs: 100),
    );

    expect(
      (result as Err<BackupReceipt, BackupFailure>).failure.code,
      'backup_publish_failed',
    );
    expect(
      records.current?.state,
      const BackupFailed(failureCode: 'backup_publish_failed'),
    );
    expect(planner.cleaned, ['backup_staging/backup_2.sqlite']);
  });
}

class _FakeSnapshotPlanner implements BackupSnapshotPlanner {
  final cleaned = <String>[];

  @override
  Future<Result<BackupSnapshotPlan, BackupFailure>> create(
    String operationId,
  ) async => Ok(
    BackupSnapshotPlan(
      snapshotRelativePath: 'backup_staging/$operationId.sqlite',
      audioPlan: const [],
    ),
  );

  @override
  Future<void> deleteSnapshot(String relativePath) async {
    cleaned.add(relativePath);
  }
}

class _FakeBackupGateway implements BackupGateway {
  _FakeBackupGateway({this.failureCode});
  final String? failureCode;

  @override
  Future<Result<BackupNativeReceipt, BackupFailure>> create(
    BackupNativeRequest request,
  ) async {
    final code = failureCode;
    if (code != null) return Err(BackupUnavailable(code));
    return Ok(
      BackupNativeReceipt(
        relativePath: _path(
          'backups/loquiris-backup-${request.operationId}.zip',
        ),
        sha256: _shaC,
        bytes: 512,
      ),
    );
  }
}

class _FakeBackupRecords implements BackupRecordRepository {
  BackupRecord? current;

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> createPending(
    BackupRecord record,
  ) async {
    current = record;
    return Ok(record);
  }

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> complete(
    String operationId, {
    required AppRelativePath relativePath,
    required String sha256,
    required int bytes,
    required int updatedAtUtcMs,
  }) async {
    current = current!.copyWith(
      state: BackupCompleted(
        relativePath: relativePath,
        sha256: sha256,
        bytes: bytes,
      ),
    );
    return Ok(current!);
  }

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  }) async {
    current = current!.copyWith(state: BackupFailed(failureCode: code));
    return Ok(current!);
  }

  @override
  Future<Result<int, BackupRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  }) async => const Ok(0);

  @override
  Future<Result<BackupRecord, BackupRecordRepositoryFailure>> read(
    String operationId,
  ) async => Ok(current!);
}

AppRelativePath _path(String value) =>
    (AppRelativePath.tryParse(value)
            as Ok<AppRelativePath, InvalidAppRelativePath>)
        .value;

class _NoopArtifactCleaner implements BackupArtifactCleaner {
  const _NoopArtifactCleaner();

  @override
  Future<void> delete(AppRelativePath relativePath) async {}
}

const _shaC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
