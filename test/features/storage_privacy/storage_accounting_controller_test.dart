import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/features/storage_privacy/presentation/storage_accounting_controller.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  test('loads through injected boundaries and retry re-measures', () async {
    final metrics = _StorageMetricsService();
    final container = ProviderContainer(
      overrides: [
        storageMetricsServiceProvider.overrideWithValue(metrics),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        modelRepositoryProvider.overrideWithValue(_EmptyModelRepository()),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(
      storageAccountingControllerProvider.future,
    );
    expect(
      first,
      isA<Ok<StorageAccountingSnapshot, StorageAccountingFailure>>(),
    );
    expect(metrics.calls, 1);

    container.read(storageAccountingControllerProvider.notifier).retry();
    await container.read(storageAccountingControllerProvider.future);

    expect(metrics.calls, 2);
  });
}

final class _StorageMetricsService implements StorageMetricsService {
  int calls = 0;

  @override
  Future<Result<PlatformStorageMetrics, StorageMetricsFailure>>
  measure() async {
    calls += 1;
    return const Ok(
      PlatformStorageMetrics(
        appBytes: 1,
        dataBytes: 2,
        cacheBytes: 0,
        availableBytes: 3,
      ),
    );
  }
}

final class _EmptyModelRepository implements ModelRepository {
  @override
  Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
  listInstalled() async => const Ok(<InstalledModel>[]);

  @override
  Future<Result<InstalledModel, AnalysisRepositoryFailure>> registerBundled(
    InstalledModel model, {
    required int observedAtUtcMs,
  }) async => Ok(model);
}
