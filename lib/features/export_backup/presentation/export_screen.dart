import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/export_backup/presentation/export_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Explicit local export surface for one saved meeting.
final class ExportScreen extends ConsumerWidget {
  /// Creates the route-scoped export screen.
  const ExportScreen({required this.meetingId, super.key});

  /// Meeting selected by the route.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = exportControllerProvider(meetingId);
    final state = ref.watch(provider);
    final progressLabel = switch (state.progress?.phase) {
      null || ExportProgressPhase.selectingDestination =>
        l10n.exportSelectingDestinationLabel,
      ExportProgressPhase.preparing ||
      ExportProgressPhase.writing => l10n.exportWritingLabel,
      ExportProgressPhase.finalizing => l10n.exportFinalizingLabel,
    };
    return Scaffold(
      key: ValueKey<String>('export:$meetingId'),
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.privacy_tip_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.exportPrivacyWarning)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.exportChooseFormat,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < ExportFormat.values.length; index += 1)
              _ExportChoice(
                format: ExportFormat.values[index],
                selected: state.selectedFormat == ExportFormat.values[index],
                enabled: !state.isExporting,
                sortOrder: index.toDouble() + 1,
                onSelect: () => ref
                    .read(provider.notifier)
                    .select(ExportFormat.values[index]),
              ),
            const SizedBox(height: 16),
            if (state.isExporting)
              Semantics(
                liveRegion: true,
                label: progressLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      key: const Key('export-progress'),
                      value: switch (state.progress?.totalBytes) {
                        final total? when total > 0 =>
                          (state.progress!.bytesProcessed / total).clamp(0, 1),
                        _ => null,
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(progressLabel),
                    if (state.progress?.cancellable == true) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('export-cancel'),
                        onPressed: state.isCancelling
                            ? null
                            : () => unawaited(
                                ref.read(provider.notifier).cancel(),
                              ),
                        icon: const ExcludeSemantics(child: Icon(Icons.close)),
                        label: Text(
                          state.isCancelling
                              ? l10n.exportCancellingLabel
                              : l10n.exportCancelAction,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (state.receipt case final receipt?) ...[
              Semantics(
                liveRegion: true,
                child: Text(l10n.exportSucceeded(receipt.fileName)),
              ),
              if (receipt.usedSegmentFallback)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.exportSegmentsFallbackWarning,
                    key: const Key('export-fallback-warning'),
                  ),
                ),
              if (receipt.warningCodes.contains('export_audio_partial'))
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.exportPartialAudioWarning,
                    key: const Key('export-partial-warning'),
                  ),
                ),
            ],
            if (state.failureCode case final code?)
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (code) {
                    'export_cancelled' => l10n.exportCancelled,
                    'export_incomplete_output_cleanup_failed' =>
                      l10n.exportIncompleteOutputWarning,
                    'export_interrupted_incomplete_output_may_remain' =>
                      l10n.exportInterruptedOutputWarning,
                    'export_completion_persistence_failed' ||
                    'export_failure_persistence_failed' =>
                      l10n.exportPersistenceWarning,
                    _ => l10n.exportFailed,
                  },
                ),
              ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: l10n.exportConfirm,
              sortKey: const OrdinalSortKey(20),
              child: FilledButton.icon(
                key: const Key('export-confirm'),
                onPressed: state.isExporting
                    ? null
                    : () => unawaited(
                        ref.read(provider.notifier).exportSelected(),
                      ),
                icon: const ExcludeSemantics(
                  child: Icon(Icons.save_alt_outlined),
                ),
                label: Text(l10n.exportConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ExportChoice extends StatelessWidget {
  const _ExportChoice({
    required this.format,
    required this.selected,
    required this.enabled,
    required this.sortOrder,
    required this.onSelect,
  });

  final ExportFormat format;
  final bool selected;
  final bool enabled;
  final double sortOrder;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, description) = switch (format) {
      ExportFormat.audioM4a => (
        l10n.exportAudioM4a,
        l10n.exportAudioM4aDescription,
      ),
      ExportFormat.audioSegments => (
        l10n.exportAudioSegments,
        l10n.exportAudioSegmentsDescription,
      ),
      ExportFormat.text => (
        l10n.exportPlainText,
        l10n.exportPlainTextDescription,
      ),
      ExportFormat.subtitles => (l10n.exportSrt, l10n.exportSrtDescription),
      ExportFormat.json => (l10n.exportJson, l10n.exportJsonDescription),
      ExportFormat.archive => (
        l10n.exportArchive,
        l10n.exportArchiveDescription,
      ),
    };
    return Semantics(
      key: Key('export-format-${format.name}'),
      button: true,
      selected: selected,
      enabled: enabled,
      label: title,
      hint: description,
      onTap: enabled ? onSelect : null,
      sortKey: OrdinalSortKey(sortOrder),
      child: ExcludeSemantics(
        child: Card(
          child: InkWell(
            onTap: enabled ? onSelect : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
