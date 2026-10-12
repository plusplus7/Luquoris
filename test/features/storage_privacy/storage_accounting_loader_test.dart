import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/storage_privacy/application/storage_accounting_loader.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  test(
    'reconciles private totals without double-counting model manifests',
    () async {
      final loader = StorageAccountingLoader(
        readPlatformMetrics: () async => const Ok(
          PlatformStorageMetrics(
            appBytes: 1000,
            dataBytes: 900,
            cacheBytes: 200,
            availableBytes: 5000,
          ),
        ),
        readSessionStorage: () async => const Ok(
          SessionStorageAccounting(activeMeetingBytes: 300, trashBytes: 100),
        ),
        readInstalledModels: () async => Ok(<InstalledModel>[
          _model(id: 'speech', bytes: 150),
          _model(id: 'speaker', bytes: 100),
        ]),
      );

      final result = await loader.load();

      final snapshot = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail(failure.code),
      };
      expect(snapshot.applicationAndModelsBytes, 1300);
      expect(snapshot.bundledModelBytes, 250);
      expect(snapshot.activeMeetingBytes, 300);
      expect(snapshot.rebuildableCacheBytes, 200);
      expect(snapshot.trashBytes, 100);
      expect(snapshot.availableDeviceBytes, 5000);
    },
  );

  test(
    'clamps unexplained private data when platform totals lag records',
    () async {
      final loader = StorageAccountingLoader(
        readPlatformMetrics: () async => const Ok(
          PlatformStorageMetrics(
            appBytes: 1000,
            dataBytes: 100,
            cacheBytes: 80,
            availableBytes: 5000,
          ),
        ),
        readSessionStorage: () async => const Ok(
          SessionStorageAccounting(activeMeetingBytes: 300, trashBytes: 100),
        ),
        readInstalledModels: () async => const Ok(<InstalledModel>[]),
      );

      final result = await loader.load();

      expect(
        switch (result) {
          Ok(:final value) => value.applicationAndModelsBytes,
          Err(:final failure) => fail(failure.code),
        },
        1000,
      );
    },
  );

  test('maps each dependency failure to a stable accounting failure', () async {
    final metricsFailure = StorageAccountingLoader(
      readPlatformMetrics: () async =>
          const Err(StorageMetricsUnavailable('native_unavailable')),
      readSessionStorage: _emptySessions,
      readInstalledModels: _emptyModels,
    );
    final sessionsFailure = StorageAccountingLoader(
      readPlatformMetrics: _emptyMetrics,
      readSessionStorage: () async =>
          const Err(SessionRepositoryUnavailable('database_unavailable')),
      readInstalledModels: _emptyModels,
    );
    final modelsFailure = StorageAccountingLoader(
      readPlatformMetrics: _emptyMetrics,
      readSessionStorage: _emptySessions,
      readInstalledModels: () async =>
          const Err(AnalysisStoreUnavailable('models_unavailable')),
    );

    expect(_failureCode(await metricsFailure.load()), 'native_unavailable');
    expect(_failureCode(await sessionsFailure.load()), 'database_unavailable');
    expect(_failureCode(await modelsFailure.load()), 'models_unavailable');
  });
}

Future<Result<PlatformStorageMetrics, StorageMetricsFailure>>
_emptyMetrics() async => const Ok(
  PlatformStorageMetrics(
    appBytes: 0,
    dataBytes: 0,
    cacheBytes: 0,
    availableBytes: 0,
  ),
);

Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
_emptySessions() async => const Ok(
  SessionStorageAccounting(activeMeetingBytes: 0, trashBytes: 0),
);

Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
_emptyModels() async => const Ok(<InstalledModel>[]);

String _failureCode(
  Result<StorageAccountingSnapshot, StorageAccountingFailure> value,
) => switch (value) {
  Ok() => fail('expected a typed failure'),
  Err(:final failure) => failure.code,
};

InstalledModel _model({required String id, required int bytes}) =>
    InstalledModel(
      id: id,
      version: '1',
      source: 'test',
      sha256: 'hash-$id',
      bytes: bytes,
      capabilities: const <ModelCapability>[],
      expectedEngineId: 'test-engine',
      licenseId: 'MIT',
      licenseSnapshotPath: switch (AppRelativePath.tryParse(
        'licenses/$id.txt',
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.code),
      },
      enabledModes: const <PerformanceMode>[],
    );
