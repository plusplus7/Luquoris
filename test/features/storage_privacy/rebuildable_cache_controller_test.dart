import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/presentation/rebuildable_cache_controller.dart';
import 'package:loquiris/services/service_providers.dart';

void main() {
  test('publishes progress and a successful cleanup receipt', () async {
    final service = _FakeRebuildableCacheService();
    final container = ProviderContainer(
      overrides: [
        rebuildableCacheServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final states = <RebuildableCacheState>[];
    container.listen(
      rebuildableCacheControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );

    final operation = container
        .read(rebuildableCacheControllerProvider.notifier)
        .clear();
    expect(
      container.read(rebuildableCacheControllerProvider).isClearing,
      isTrue,
    );
    service.complete(
      const Ok(
        RebuildableCacheCleanupReceipt(filesDeleted: 2, bytesDeleted: 42),
      ),
    );
    await operation;

    expect(states.whereType<RebuildableCacheClearing>(), hasLength(1));
    expect(
      container.read(rebuildableCacheControllerProvider),
      isA<RebuildableCacheCleared>().having(
        (state) => state.receipt.bytesDeleted,
        'bytesDeleted',
        42,
      ),
    );
  });

  test('coalesces repeat taps and retains partial failure counts', () async {
    final service = _FakeRebuildableCacheService();
    final container = ProviderContainer(
      overrides: [
        rebuildableCacheServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      rebuildableCacheControllerProvider.notifier,
    );

    final first = notifier.clear();
    final second = notifier.clear();
    expect(service.calls, 1);
    service.complete(
      const Err(
        RebuildableCacheFailure(
          code: 'rebuildable_cache_cleanup_failed',
          filesDeleted: 1,
          bytesDeleted: 7,
        ),
      ),
    );
    await Future.wait(<Future<void>>[first, second]);

    expect(
      container.read(rebuildableCacheControllerProvider),
      isA<RebuildableCacheClearFailed>()
          .having((state) => state.failure.filesDeleted, 'filesDeleted', 1)
          .having((state) => state.failure.bytesDeleted, 'bytesDeleted', 7),
    );
  });
}

final class _FakeRebuildableCacheService implements RebuildableCacheService {
  final _completer =
      Completer<
        Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>
      >();
  int calls = 0;

  @override
  Future<Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>>
  clear() {
    calls += 1;
    return _completer.future;
  }

  void complete(
    Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure> result,
  ) => _completer.complete(result);
}
