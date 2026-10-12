import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';

/// Strict Dart owner of the Android application-storage wire contract.
final class MethodChannelStorageMetricsService
    implements StorageMetricsService, RebuildableCacheService {
  /// Creates the production service or an injected test adapter.
  const MethodChannelStorageMetricsService({
    MethodChannel? channel,
    this.timeout = const Duration(seconds: 10),
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.loquiris/storage_metrics_v1';
  static const _contractVersion = 1;

  final MethodChannel _channel;

  /// Maximum wait for Android's potentially slow storage-statistics query.
  final Duration timeout;

  @override
  Future<Result<PlatformStorageMetrics, StorageMetricsFailure>>
  measure() async {
    try {
      final response = await _channel
          .invokeMethod<Object?>(
            'measure',
            <String, Object?>{'v': _contractVersion},
          )
          .timeout(timeout);
      if (response is! Map<Object?, Object?> ||
          response['v'] != _contractVersion ||
          response['ok'] is! bool) {
        return _invalid();
      }
      if (response['ok'] == false) {
        final failure = response['failure'];
        if (failure is! Map<Object?, Object?> ||
            failure['code'] is! String ||
            (failure['code']! as String).isEmpty) {
          return _invalid();
        }
        return Err(StorageMetricsUnavailable(failure['code']! as String));
      }
      final metrics = response['metrics'];
      if (metrics is! Map<Object?, Object?>) return _invalid();
      final appBytes = metrics['appBytes'];
      final dataBytes = metrics['dataBytes'];
      final cacheBytes = metrics['cacheBytes'];
      final availableBytes = metrics['availableBytes'];
      if (<Object?>[
        appBytes,
        dataBytes,
        cacheBytes,
        availableBytes,
      ].any((value) => value is! int || value < 0)) {
        return _invalid();
      }
      return Ok(
        PlatformStorageMetrics(
          appBytes: appBytes! as int,
          dataBytes: dataBytes! as int,
          cacheBytes: cacheBytes! as int,
          availableBytes: availableBytes! as int,
        ),
      );
    } on TimeoutException {
      return const Err(StorageMetricsUnavailable('storage_metrics_timeout'));
    } on PlatformException catch (error) {
      return Err(
        StorageMetricsUnavailable(
          error.code.isEmpty ? 'storage_metrics_unavailable' : error.code,
        ),
      );
    } on MissingPluginException {
      return const Err(
        StorageMetricsUnavailable('storage_metrics_unavailable'),
      );
    }
  }

  @override
  Future<Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>>
  clear() async {
    try {
      final response = await _channel
          .invokeMethod<Object?>(
            'clearRebuildableCache',
            <String, Object?>{'v': _contractVersion},
          )
          .timeout(timeout);
      if (response is! Map<Object?, Object?> ||
          response['v'] != _contractVersion ||
          response['ok'] is! bool) {
        return _cleanupInvalid();
      }
      if (response['ok'] == false) {
        final failure = response['failure'];
        if (failure is! Map<Object?, Object?> ||
            failure['code'] is! String ||
            (failure['code']! as String).isEmpty ||
            !_validCount(failure['filesDeleted']) ||
            !_validCount(failure['bytesDeleted'])) {
          return _cleanupInvalid();
        }
        return Err(
          RebuildableCacheFailure(
            code: failure['code']! as String,
            filesDeleted: failure['filesDeleted']! as int,
            bytesDeleted: failure['bytesDeleted']! as int,
          ),
        );
      }
      final receipt = response['receipt'];
      if (receipt is! Map<Object?, Object?> ||
          !_validCount(receipt['filesDeleted']) ||
          !_validCount(receipt['bytesDeleted'])) {
        return _cleanupInvalid();
      }
      return Ok(
        RebuildableCacheCleanupReceipt(
          filesDeleted: receipt['filesDeleted']! as int,
          bytesDeleted: receipt['bytesDeleted']! as int,
        ),
      );
    } on TimeoutException {
      return const Err(
        RebuildableCacheFailure(
          code: 'rebuildable_cache_cleanup_timeout',
          filesDeleted: 0,
          bytesDeleted: 0,
        ),
      );
    } on PlatformException catch (error) {
      return Err(
        RebuildableCacheFailure(
          code: error.code.isEmpty
              ? 'rebuildable_cache_cleanup_unavailable'
              : error.code,
          filesDeleted: 0,
          bytesDeleted: 0,
        ),
      );
    } on MissingPluginException {
      return const Err(
        RebuildableCacheFailure(
          code: 'rebuildable_cache_cleanup_unavailable',
          filesDeleted: 0,
          bytesDeleted: 0,
        ),
      );
    }
  }

  Result<PlatformStorageMetrics, StorageMetricsFailure> _invalid() => const Err(
    StorageMetricsUnavailable('storage_metrics_channel_invalid'),
  );

  bool _validCount(Object? value) => value is int && value >= 0;

  Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>
  _cleanupInvalid() => const Err(
    RebuildableCacheFailure(
      code: 'rebuildable_cache_channel_invalid',
      filesDeleted: 0,
      bytesDeleted: 0,
    ),
  );
}
