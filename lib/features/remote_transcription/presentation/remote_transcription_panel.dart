import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/remote_transcription/application/remote_meeting_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/remote_formatting.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/service_contracts.dart';

const _activeStates = {
  'waitingSetup',
  'waitingAudio',
  'uploading',
  'submitting',
  'waitingNetwork',
  'queued',
  'running',
};

/// Meeting-scoped progress and versions with one appropriate primary action.
final class RemoteTranscriptionPanel extends ConsumerWidget {
  /// Restores progress from the owning meeting identity.
  const RemoteTranscriptionPanel({required this.meetingId, super.key});

  /// Meeting whose original audio is explicitly authorized for remote work.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(remoteTranscriptionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final provider = remoteMeetingControllerProvider(meetingId);
    final state = ref.watch(provider);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: switch (state) {
          AsyncLoading() => const LinearProgressIndicator(),
          AsyncError() => Text(
            l10n.remoteFailure('remote_storage_unavailable'),
          ),
          AsyncData(:final value) => _RemoteMeetingContent(
            state: value,
            onStart: () => unawaited(ref.read(provider.notifier).start()),
            onCancel: (task) =>
                unawaited(ref.read(provider.notifier).cancel(task.id)),
            onEdit: (version, text) =>
                unawaited(ref.read(provider.notifier).edit(version.id, text)),
            onExport: (version, format) =>
                unawaited(ref.read(provider.notifier).export(version, format)),
          ),
        },
      ),
    );
  }
}

final class _RemoteMeetingContent extends StatelessWidget {
  const _RemoteMeetingContent({
    required this.state,
    required this.onStart,
    required this.onCancel,
    required this.onEdit,
    required this.onExport,
  });
  final RemoteMeetingState state;
  final VoidCallback onStart;
  final ValueChanged<RemoteTask> onCancel;
  final void Function(RemoteVersion, String) onEdit;
  final void Function(RemoteVersion, ExportFormat) onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = state.tasks
        .where((task) => _activeStates.contains(task.state))
        .toList();
    final visible = active.isEmpty ? state.tasks.take(1) : active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.remoteTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.remoteExplanation),
        if (state.failureCode != null)
          Semantics(
            liveRegion: true,
            child: Text(l10n.remoteFailure(state.failureCode!)),
          ),
        for (final task in visible)
          RemoteTaskTile(
            task: task,
            onCancel: state.busy ? null : () => onCancel(task),
          ),
        if (state.versions.isEmpty) Text(l10n.remoteEmpty),
        for (var i = 0; i < state.versions.length; i++)
          RemoteVersionCard(
            key: ValueKey(state.versions[i].id),
            version: state.versions[i],
            initiallyExpanded: i == 0,
            versionNumber: state.versions.length - i,
            onSave: (text) => onEdit(state.versions[i], text),
            onExport: (format) => onExport(state.versions[i], format),
          ),
        const SizedBox(height: 12),
        if (active.any((task) => task.state == 'waitingSetup'))
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.modelsPerformance),
            icon: const Icon(Icons.dns_outlined),
            label: Text(l10n.remoteOpenSettings),
          )
        else if (active.isEmpty)
          FilledButton.icon(
            onPressed: state.busy ? null : onStart,
            icon: const Icon(Icons.transcribe_outlined),
            label: Text(
              state.versions.isEmpty ? l10n.remoteStart : l10n.remoteRestart,
            ),
          ),
      ],
    );
  }
}

/// Committed progress with cancellation only while work remains active.
final class RemoteTaskTile extends StatelessWidget {
  /// Does not expose ineffective terminal-task controls.
  const RemoteTaskTile({required this.task, required this.onCancel, super.key});

  /// Durable upload or inference progress.
  final RemoteTask task;

  /// Explicit cancellation intent, disabled during another pending mutation.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      title: Text(l10n.remoteState(task.state)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.totalBytes > 0)
            Text(l10n.remoteTaskProgress(task.confirmedBytes, task.totalBytes)),
          if (task.retentionSeconds != null)
            Text(l10n.remoteRetention(task.retentionSeconds!)),
          if (task.expiresAtUtcMs != null)
            Text(localizedRemoteExpiry(context, task.expiresAtUtcMs!)),
          if (task.failureCode != null)
            Text(l10n.remoteFailure(task.failureCode!)),
        ],
      ),
      trailing: _activeStates.contains(task.state)
          ? IconButton(
              tooltip: l10n.remoteCancel,
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined),
            )
          : null,
    );
  }
}

/// Displays and edits one retained version without changing raw machine evidence.
final class RemoteVersionCard extends StatefulWidget {
  /// Keeps unsaved draft text scoped to this version's widget lifetime.
  const RemoteVersionCard({
    required this.version,
    required this.onSave,
    required this.onExport,
    this.initiallyExpanded = true,
    this.versionNumber = 1,
    super.key,
  });

  /// Local version with verified source metadata.
  final RemoteVersion version;

  /// Persists human corrections through the ViewModel.
  final ValueChanged<String> onSave;

  /// Exports the selected local representation through the system picker.
  final ValueChanged<ExportFormat> onExport;

  /// Opens the newest result while keeping older versions compact.
  final bool initiallyExpanded;

  /// Chronological display number independent of the opaque run identity.
  final int versionNumber;
  @override
  State<RemoteVersionCard> createState() => _RemoteVersionCardState();
}

final class _RemoteVersionCardState extends State<RemoteVersionCard> {
  late final _text = TextEditingController(text: widget.version.displayedText);
  bool _dirty = false;

  @override
  void didUpdateWidget(covariant RemoteVersionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text == widget.version.displayedText) _dirty = false;
    if (!_dirty &&
        oldWidget.version.displayedText != widget.version.displayedText) {
      _text.text = widget.version.displayedText;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasContent =
        widget.version.result.segments.isNotEmpty ||
        widget.version.displayedText.isNotEmpty;
    return ExpansionTile(
      initiallyExpanded: widget.initiallyExpanded,
      title: Text(l10n.remoteVersionNumber(widget.versionNumber)),
      subtitle: Text(
        (widget.version.result.provenance['model'] ?? '').split('/').last,
      ),
      children: [
        if (!hasContent)
          Text(l10n.remoteNoSpeech)
        else ...[
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 12,
            onChanged: (value) =>
                setState(() => _dirty = value != widget.version.displayedText),
            decoration: InputDecoration(labelText: l10n.remoteEdit),
          ),
          Row(
            children: [
              if (_dirty)
                TextButton.icon(
                  onPressed: () => widget.onSave(_text.text),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.remoteSave),
                ),
              const Spacer(),
              PopupMenuButton<ExportFormat>(
                tooltip: l10n.remoteExport,
                icon: const Icon(Icons.ios_share_outlined),
                onSelected: widget.onExport,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ExportFormat.text,
                    child: Text(l10n.remoteExportText),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.json,
                    child: Text(l10n.remoteExportJson),
                  ),
                  PopupMenuItem(
                    value: ExportFormat.subtitles,
                    child: Text(l10n.remoteExportSubtitles),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}
