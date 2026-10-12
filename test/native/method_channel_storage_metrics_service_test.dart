import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/native/method_channel_storage_metrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/storage_metrics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('decodes a strict versioned storage observation', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'measure');
      expect(call.arguments, <String, Object?>{'v': 1});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'metrics': <String, Object?>{
          'appBytes': 100,
          'dataBytes': 200,
          'cacheBytes': 50,
          'availableBytes': 1000,
        },
      };
    });

    final result = await const MethodChannelStorageMetricsService(
      channel: channel,
    ).measure();

    final metrics =
        (result as Ok<PlatformStorageMetrics, StorageMetricsFailure>).value;
    expect(metrics.appBytes, 100);
    expect(metrics.dataBytes, 200);
    expect(metrics.cacheBytes, 50);
    expect(metrics.availableBytes, 1000);
  });

  test('rejects negative, missing, and wrong-version fields', () async {
    for (final response in <Object?>[
      <String, Object?>{'v': 2, 'ok': true, 'metrics': <String, Object?>{}},
      <String, Object?>{
        'v': 1,
        'ok': true,
        'metrics': <String, Object?>{
          'appBytes': 1,
          'dataBytes': 2,
          'cacheBytes': -1,
          'availableBytes': 3,
        },
      },
      <String, Object?>{'v': 1, 'ok': true},
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => response);

      final result = await const MethodChannelStorageMetricsService(
        channel: channel,
      ).measure();

      expect(_failureCode(result), 'storage_metrics_channel_invalid');
    }
  });

  test('maps native and timeout failures to stable codes', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'storage_stats_unavailable'),
    );
    final nativeResult = await const MethodChannelStorageMetricsService(
      channel: channel,
    ).measure();
    expect(_failureCode(nativeResult), 'storage_stats_unavailable');

    messenger.setMockMethodCallHandler(
      channel,
      (_) => Future<Object?>.delayed(const Duration(seconds: 1)),
    );
    final timeoutResult = await const MethodChannelStorageMetricsService(
      channel: channel,
      timeout: Duration(milliseconds: 1),
    ).measure();
    expect(_failureCode(timeoutResult), 'storage_metrics_timeout');
  });

  test('decodes rebuildable cache cleanup without receiving paths', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'clearRebuildableCache');
      expect(call.arguments, <String, Object?>{'v': 1});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'receipt': <String, Object?>{
          'filesDeleted': 3,
          'bytesDeleted': 42,
        },
      };
    });

    final result = await const MethodChannelStorageMetricsService(
      channel: channel,
    ).clear();

    final receipt =
        (result as Ok<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>)
            .value;
    expect(receipt.filesDeleted, 3);
    expect(receipt.bytesDeleted, 42);
  });

  test('preserves partial cleanup counts in a typed failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': false,
        'failure': <String, Object?>{
          'code': 'rebuildable_cache_cleanup_failed',
          'filesDeleted': 1,
          'bytesDeleted': 7,
        },
      },
    );

    final result = await const MethodChannelStorageMetricsService(
      channel: channel,
    ).clear();

    final failure =
        (result as Err<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>)
            .failure;
    expect(failure.code, 'rebuildable_cache_cleanup_failed');
    expect(failure.filesDeleted, 1);
    expect(failure.bytesDeleted, 7);
  });

  test('rejects malformed cache cleanup receipts', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': true,
        'receipt': <String, Object?>{
          'filesDeleted': 1,
          'bytesDeleted': -1,
        },
      },
    );

    final result = await const MethodChannelStorageMetricsService(
      channel: channel,
    ).clear();

    expect(
      (result as Err<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>)
          .failure
          .code,
      'rebuildable_cache_channel_invalid',
    );
  });
}

String _failureCode(
  Result<PlatformStorageMetrics, StorageMetricsFailure> result,
) => switch (result) {
  Ok() => fail('expected failure'),
  Err(:final failure) => failure.code,
};
