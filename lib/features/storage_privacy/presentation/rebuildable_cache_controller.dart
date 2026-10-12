import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/presentation/storage_accounting_controller.dart';
import 'package:loquiris/services/service_providers.dart';

/// User-visible lifecycle of one explicit rebuildable-cache cleanup.
sealed class RebuildableCacheState {
  const RebuildableCacheState();

  /// Whether a native cleanup is currently active.
  bool get isClearing => false;
}

/// No cleanup has completed during this screen lifetime.
final class RebuildableCacheIdle extends RebuildableCacheState {
  /// Creates the idle state.
  const RebuildableCacheIdle();
}

/// Native allowlisted cleanup is active.
final class RebuildableCacheClearing extends RebuildableCacheState {
  /// Creates the active state.
  const RebuildableCacheClearing();

  @override
  bool get isClearing => true;
}

/// Allowlisted cleanup completed successfully.
final class RebuildableCacheCleared extends RebuildableCacheState {
  /// Creates a successful state with its native [receipt].
  const RebuildableCacheCleared(this.receipt);

  /// Counts of derived cache removed.
  final RebuildableCacheCleanupReceipt receipt;
}

/// Cleanup stopped with a retryable typed failure.
final class RebuildableCacheClearFailed extends RebuildableCacheState {
  /// Creates a failed state, preserving partial cleanup counts.
  const RebuildableCacheClearFailed(this.failure);

  /// Native failure and work completed before it stopped.
  final RebuildableCacheFailure failure;
}

/// Owns an explicit cache-cleanup action and coalesces repeat taps.
final class RebuildableCacheController extends Notifier<RebuildableCacheState> {
  @override
  RebuildableCacheState build() => const RebuildableCacheIdle();

  /// Clears only native allowlisted derived cache directories.
  Future<void> clear() async {
    if (state.isClearing) return;
    state = const RebuildableCacheClearing();
    final result = await ref.read(rebuildableCacheServiceProvider).clear();
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => RebuildableCacheCleared(value),
      Err(:final failure) => RebuildableCacheClearFailed(failure),
    };
    ref.invalidate(storageAccountingControllerProvider);
  }
}

/// Screen-scoped rebuildable-cache cleanup action.
final NotifierProvider<RebuildableCacheController, RebuildableCacheState>
rebuildableCacheControllerProvider =
    NotifierProvider.autoDispose<
      RebuildableCacheController,
      RebuildableCacheState
    >(RebuildableCacheController.new);
