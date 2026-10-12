import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/application/storage_accounting_loader.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/services/service_providers.dart';

/// Owns one refreshable storage-accounting observation for the screen.
final class StorageAccountingController
    extends
        AsyncNotifier<
          Result<StorageAccountingSnapshot, StorageAccountingFailure>
        > {
  @override
  Future<Result<StorageAccountingSnapshot, StorageAccountingFailure>> build() =>
      StorageAccountingLoader(
        readPlatformMetrics: ref.watch(storageMetricsServiceProvider).measure,
        readSessionStorage: ref.watch(sessionRepositoryProvider).accountStorage,
        readInstalledModels: ref.watch(modelRepositoryProvider).listInstalled,
      ).load();

  /// Re-runs every accounting boundary without retaining stale totals.
  void retry() => ref.invalidateSelf();
}

/// Refreshable storage-accounting state scoped to the storage screen.
final AsyncNotifierProvider<
  StorageAccountingController,
  Result<StorageAccountingSnapshot, StorageAccountingFailure>
>
storageAccountingControllerProvider =
    AsyncNotifierProvider.autoDispose<
      StorageAccountingController,
      Result<StorageAccountingSnapshot, StorageAccountingFailure>
    >(StorageAccountingController.new);
