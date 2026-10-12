import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/presentation/rebuildable_cache_controller.dart';
import 'package:loquiris/features/storage_privacy/presentation/storage_accounting_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';

/// Explains how Loquiris accounts for private on-device storage.
final class StoragePrivacyScreen extends ConsumerWidget {
  /// Creates the storage and privacy screen.
  const StoragePrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(storageAccountingControllerProvider);
    final cleanupState = ref.watch(rebuildableCacheControllerProvider);
    final snapshot = switch (state) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    final failure = switch (state) {
      AsyncError() || AsyncData(value: Err()) => true,
      _ => false,
    };
    final categories = <(IconData, String, String, int?)>[
      (
        Icons.apps_outlined,
        l10n.storageApplicationAndModels,
        l10n.storageApplicationModelsDetail(
          _formatStorageBytes(snapshot?.bundledModelBytes),
        ),
        snapshot?.applicationAndModelsBytes,
      ),
      (
        Icons.mic_none_outlined,
        l10n.storageActiveMeetings,
        l10n.storageActiveMeetingsDetail,
        snapshot?.activeMeetingBytes,
      ),
      (
        Icons.cached_outlined,
        l10n.storageRebuildableCache,
        l10n.storageRebuildableCacheDetail,
        snapshot?.rebuildableCacheBytes,
      ),
      (
        Icons.delete_outline,
        l10n.storageTrash,
        l10n.storageTrashDetail,
        snapshot?.trashBytes,
      ),
      (
        Icons.sd_storage_outlined,
        l10n.storageAvailableDeviceSpace,
        l10n.storageAvailableDeviceSpaceDetail,
        snapshot?.availableDeviceBytes,
      ),
    ];
    return Scaffold(
      key: const ValueKey<String>('storage-privacy'),
      appBar: AppBar(title: Text(l10n.storagePrivacyTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.storageAccountingIntro),
              const SizedBox(height: 12),
              if (state is AsyncLoading)
                Semantics(
                  label: l10n.storageLoadingLabel,
                  liveRegion: true,
                  child: const LinearProgressIndicator(
                    key: Key('storage-loading'),
                  ),
                ),
              if (failure)
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.storageLoadError),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('storage-retry'),
                          onPressed: () => ref
                              .read(
                                storageAccountingControllerProvider.notifier,
                              )
                              .retry(),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retryAction),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              for (final (icon, label, detail, bytes) in categories) ...[
                Card(
                  child: ListTile(
                    leading: ExcludeSemantics(child: Icon(icon)),
                    title: Text(label),
                    subtitle: Text(detail),
                    trailing: Text(
                      _formatStorageBytes(bytes),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Text(
                l10n.clearRebuildableCacheAction,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(l10n.clearRebuildableCacheDescription),
              const SizedBox(height: 12),
              if (cleanupState case RebuildableCacheCleared(:final receipt))
                Semantics(
                  liveRegion: true,
                  child: Text(
                    receipt.filesDeleted == 0
                        ? l10n.rebuildableCacheNothingCleared
                        : l10n.rebuildableCacheCleared(
                            _formatStorageBytes(receipt.bytesDeleted),
                            receipt.filesDeleted,
                          ),
                  ),
                ),
              if (cleanupState case RebuildableCacheClearFailed(:final failure))
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failure.bytesDeleted == 0
                        ? l10n.rebuildableCacheCleanupFailed
                        : l10n.rebuildableCacheCleanupPartiallyFailed(
                            _formatStorageBytes(failure.bytesDeleted),
                          ),
                  ),
                ),
              if (cleanupState is RebuildableCacheClearing) ...[
                Semantics(
                  liveRegion: true,
                  label: l10n.clearingRebuildableCacheLabel,
                  child: const LinearProgressIndicator(
                    key: Key('cache-cleanup-progress'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                key: const Key('clear-rebuildable-cache'),
                onPressed: cleanupState.isClearing
                    ? null
                    : () => unawaited(
                        ref
                            .read(rebuildableCacheControllerProvider.notifier)
                            .clear(),
                      ),
                icon: const ExcludeSemantics(
                  child: Icon(Icons.cleaning_services_outlined),
                ),
                label: Text(
                  cleanupState.isClearing
                      ? l10n.clearingRebuildableCacheLabel
                      : l10n.clearRebuildableCacheAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatStorageBytes(int? bytes) {
  if (bytes == null) return '—';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final displayed = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$displayed ${units[unit]}';
}
