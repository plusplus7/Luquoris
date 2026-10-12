import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/sessions/presentation/sessions_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Local meeting library with exhaustive async states.
final class SessionLibraryScreen extends ConsumerWidget {
  /// Creates the library screen.
  const SessionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionsControllerProvider);
    final l10n = AppLocalizations.of(context);
    final content = switch (state) {
      AsyncData(:final value) => switch (value) {
        SessionsLoaded() => _SessionsLoadedView(
          snapshot: value,
          onStart: () => context.go(AppRoutes.newRecording),
          onShowActive: () =>
              ref.read(sessionsControllerProvider.notifier).showActive(),
          onShowTrash: () =>
              ref.read(sessionsControllerProvider.notifier).showTrash(),
          onSearch: (query) =>
              ref.read(sessionsControllerProvider.notifier).search(query),
          onOpen: (item) {
            final offset = item.mediaOffset;
            final location = AppRoutes.session(item.meeting.id);
            unawaited(
              context.push(
                offset == null
                    ? location
                    : '$location?atUs=${offset.inMicroseconds}',
              ),
            );
          },
          onRename: (meeting) => _renameMeeting(context, ref, meeting),
          onMoveToTrash: (meetingId) => ref
              .read(sessionsControllerProvider.notifier)
              .moveToTrash(meetingId),
          onRestore: (meetingId) => ref
              .read(sessionsControllerProvider.notifier)
              .restoreFromTrash(meetingId),
          onPermanentDelete: (meeting) =>
              _confirmPermanentDelete(context, ref, meeting),
          onReviewRecovery: (meeting) => _reviewRecovery(
            context,
            ref,
            SessionSummary(
              id: meeting.id,
              title: meeting.title,
              isRecoverable: true,
            ),
          ),
        ),
        SessionsLoadFailed(:final failure) => _SessionsError(
          message: _messageForFailure(l10n, failure),
          onRetry: () => ref.read(sessionsControllerProvider.notifier).retry(),
        ),
      },
      AsyncError() => _SessionsError(
        message: l10n.sessionsLoadError,
        onRetry: () => ref.read(sessionsControllerProvider.notifier).retry(),
      ),
      _ => const _DelayedSessionsSkeleton(),
    };

    return LoquirisAdaptivePage(child: content);
  }
}

Future<void> _confirmPermanentDelete(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.permanentDeleteTitle),
      content: Text(l10n.permanentDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          key: const Key('confirm-permanent-delete'),
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size(48, 48),
          ),
          child: Text(l10n.permanentDeleteMeetingAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  ref.read(sessionsControllerProvider.notifier).permanentlyDelete(meeting.id);
}

Future<void> _renameMeeting(
  BuildContext context,
  WidgetRef ref,
  Meeting meeting,
) async {
  final l10n = AppLocalizations.of(context);
  var editedTitle = meeting.title;
  final title = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.renameMeetingAction),
      content: TextFormField(
        initialValue: meeting.title,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.meetingTitleLabel),
        textInputAction: TextInputAction.done,
        onChanged: (value) => editedTitle = value,
        onFieldSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, editedTitle.trim()),
          child: Text(l10n.saveAction),
        ),
      ],
    ),
  );
  if (title == null || title.isEmpty || !context.mounted) return;
  ref.read(sessionsControllerProvider.notifier).rename(meeting.id, title);
}

Future<void> _reviewRecovery(
  BuildContext context,
  WidgetRef ref,
  SessionSummary session,
) async {
  final l10n = AppLocalizations.of(context);
  final resolution = await showDialog<RecoveryResolution>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.recoveryTitle),
      content: Text(l10n.recoveryBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, RecoveryResolution.save),
          child: Text(l10n.saveRecoveredRecordingAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            RecoveryResolution.continueRecording,
          ),
          child: Text(l10n.continueRecordingAction),
        ),
      ],
    ),
  );
  if (resolution == null || !context.mounted) return;
  final capture = ref.read(audioCaptureServiceProvider);
  final nativeResult = switch (resolution) {
    RecoveryResolution.save => capture.saveRecovered(session.id),
    RecoveryResolution.continueRecording => capture.continueRecovered(
      session.id,
    ),
  };
  final native = await nativeResult;
  if (!context.mounted) return;
  if (native is Err<AudioCaptureSnapshot, AudioCaptureFailure>) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.recoveryActionFailed)),
    );
    return;
  }
  final persisted = await ref
      .read(sessionRepositoryProvider)
      .resolveRecovery(
        session.id,
        resolution,
        atUtcMs: ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch,
      );
  if (!context.mounted) return;
  if (persisted is Err<Meeting, SessionRepositoryFailure>) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.recoveryActionFailed)),
    );
    if (resolution == RecoveryResolution.continueRecording) {
      context.go(AppRoutes.activeRecording(session.id));
    }
    return;
  }
  if (resolution == RecoveryResolution.continueRecording) {
    context.go(AppRoutes.activeRecording(session.id));
  } else {
    ref.invalidate(sessionsControllerProvider);
  }
}

String _messageForFailure(
  AppLocalizations l10n,
  SessionRepositoryFailure failure,
) => l10n.sessionsLoadError;

final class _SessionsLoadedView extends StatefulWidget {
  const _SessionsLoadedView({
    required this.snapshot,
    required this.onStart,
    required this.onShowActive,
    required this.onShowTrash,
    required this.onSearch,
    required this.onOpen,
    required this.onRename,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.onReviewRecovery,
  });

  final SessionsLoaded snapshot;
  final VoidCallback onStart;
  final VoidCallback onShowActive;
  final VoidCallback onShowTrash;
  final ValueChanged<String> onSearch;
  final ValueChanged<SessionSearchHit> onOpen;
  final ValueChanged<Meeting> onRename;
  final ValueChanged<String> onMoveToTrash;
  final ValueChanged<String> onRestore;
  final ValueChanged<Meeting> onPermanentDelete;
  final ValueChanged<Meeting> onReviewRecovery;

  @override
  State<_SessionsLoadedView> createState() => _SessionsLoadedViewState();
}

final class _SessionsLoadedViewState extends State<_SessionsLoadedView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.snapshot.query);
  }

  @override
  void didUpdateWidget(covariant _SessionsLoadedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.snapshot.query) {
      _searchController.value = TextEditingValue(
        text: widget.snapshot.query,
        selection: TextSelection.collapsed(
          offset: widget.snapshot.query.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SearchBar(
            key: const ValueKey<String>('sessions-search'),
            controller: _searchController,
            hintText: l10n.sessionsSearchHint,
            leading: const Icon(Icons.search_rounded),
            onChanged: widget.onSearch,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.related)),
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<SessionLibraryKind>(
              segments: [
                ButtonSegment(
                  value: SessionLibraryKind.active,
                  label: Text(l10n.meetingsLibraryTab),
                  icon: const Icon(Icons.library_music_outlined),
                ),
                ButtonSegment(
                  value: SessionLibraryKind.trash,
                  label: Text(l10n.trashTab),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
              selected: {widget.snapshot.kind},
              onSelectionChanged: (selection) {
                if (selection.single == SessionLibraryKind.active) {
                  widget.onShowActive();
                } else {
                  widget.onShowTrash();
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.section)),
        if (widget.snapshot.kind == SessionLibraryKind.trash) ...[
          SliverToBoxAdapter(
            child: Semantics(
              container: true,
              child: Text(l10n.trashRetentionNotice),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.related)),
        ],
        if (widget.snapshot.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _SessionsEmpty(
              kind: widget.snapshot.kind,
              isSearching: widget.snapshot.query.isNotEmpty,
              onStart: widget.onStart,
            ),
          )
        else
          _SessionsContent(
            items: widget.snapshot.items,
            kind: widget.snapshot.kind,
            onOpen: widget.onOpen,
            onRename: widget.onRename,
            onMoveToTrash: widget.onMoveToTrash,
            onRestore: widget.onRestore,
            onPermanentDelete: widget.onPermanentDelete,
            pendingPermanentDeletionIds:
                widget.snapshot.pendingPermanentDeletionIds,
            failedPermanentDeletionIds:
                widget.snapshot.failedPermanentDeletionIds,
            onReviewRecovery: widget.onReviewRecovery,
          ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.page)),
      ],
    );
  }
}

final class _SessionsEmpty extends StatelessWidget {
  const _SessionsEmpty({
    required this.kind,
    required this.isSearching,
    required this.onStart,
  });

  final SessionLibraryKind kind;
  final bool isSearching;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = isSearching
        ? l10n.searchEmptyTitle
        : kind == SessionLibraryKind.trash
        ? l10n.trashEmptyTitle
        : l10n.sessionsEmptyTitle;
    final body = isSearching
        ? l10n.searchEmptyBody
        : kind == SessionLibraryKind.trash
        ? l10n.trashEmptyBody
        : l10n.sessionsEmptyBody;
    return Semantics(
      key: const ValueKey<String>('sessions-empty'),
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none_rounded,
              color: LoquirisColors.of(context).accent,
            ),
            Text(title),
            Text(body, textAlign: TextAlign.center),
            if (!isSearching && kind == SessionLibraryKind.active)
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.mic_rounded),
                label: Text(l10n.startRecordingAction),
              ),
          ],
        ),
      ),
    );
  }
}

final class _SessionsError extends StatelessWidget {
  const _SessionsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey<String>('sessions-error'),
      liveRegion: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded),
          Text(message, textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.retryAction),
          ),
        ],
      ),
    );
  }
}

final class _SessionsContent extends StatelessWidget {
  const _SessionsContent({
    required this.items,
    required this.kind,
    required this.onOpen,
    required this.onRename,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.pendingPermanentDeletionIds,
    required this.failedPermanentDeletionIds,
    required this.onReviewRecovery,
  });

  final List<SessionSearchHit> items;
  final SessionLibraryKind kind;
  final ValueChanged<SessionSearchHit> onOpen;
  final ValueChanged<Meeting> onRename;
  final ValueChanged<String> onMoveToTrash;
  final ValueChanged<String> onRestore;
  final ValueChanged<Meeting> onPermanentDelete;
  final Set<String> pendingPermanentDeletionIds;
  final Set<String> failedPermanentDeletionIds;
  final ValueChanged<Meeting> onReviewRecovery;

  @override
  Widget build(BuildContext context) {
    final hasRecovery = items.any(
      (item) => item.meeting.lifecycle == MeetingLifecycle.recoverable,
    );
    return SliverList.builder(
      key: ValueKey<String>(
        hasRecovery ? 'sessions-recovery' : 'sessions-content',
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final meeting = item.meeting;
        final deletionPending = pendingPermanentDeletionIds.contains(
          meeting.id,
        );
        if (meeting.lifecycle == MeetingLifecycle.recoverable &&
            kind == SessionLibraryKind.active) {
          return _RecoveryCard(
            item: item,
            onReview: () => onReviewRecovery(meeting),
            onRename: () => onRename(meeting),
            onMoveToTrash: () => onMoveToTrash(meeting.id),
          );
        }
        return _MeetingCard(
          item: item,
          inTrash: kind == SessionLibraryKind.trash,
          onOpen:
              meeting.lifecycle == MeetingLifecycle.deleting || deletionPending
              ? null
              : () => onOpen(item),
          onRename: () => onRename(meeting),
          onMoveToTrash: () => onMoveToTrash(meeting.id),
          onRestore: () => onRestore(meeting.id),
          onPermanentDelete: () => onPermanentDelete(meeting),
          deletionPending: deletionPending,
          deletionFailed: failedPermanentDeletionIds.contains(meeting.id),
        );
      },
    );
  }
}

final class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.item,
    required this.onReview,
    required this.onRename,
    required this.onMoveToTrash,
  });

  final SessionSearchHit item;
  final VoidCallback onReview;
  final VoidCallback onRename;
  final VoidCallback onMoveToTrash;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = _SessionLibraryFormatter(context);
    return Card(
      key: ValueKey<String>('recovery-card:${item.meeting.id}'),
      child: ListTile(
        leading: const Icon(Icons.restore_rounded),
        title: Text(item.meeting.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatter.metadata(item)),
            _MeetingStatusChip(
              meetingId: item.meeting.id,
              lifecycle: item.meeting.lifecycle,
              formatter: formatter,
            ),
            Text(l10n.recoveryBody),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onReview,
                child: Text(l10n.reviewRecordingAction),
              ),
            ),
          ],
        ),
        trailing: _MeetingActions(
          inTrash: false,
          lifecycle: item.meeting.lifecycle,
          onRename: onRename,
          onMoveToTrash: onMoveToTrash,
          onRestore: null,
          onPermanentDelete: null,
        ),
      ),
    );
  }
}

final class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.item,
    required this.inTrash,
    required this.onOpen,
    required this.onRename,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.deletionPending,
    required this.deletionFailed,
  });

  final SessionSearchHit item;
  final bool inTrash;
  final VoidCallback? onOpen;
  final VoidCallback onRename;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;
  final bool deletionPending;
  final bool deletionFailed;

  @override
  Widget build(BuildContext context) {
    final formatter = _SessionLibraryFormatter(context);
    final transcriptOffset = item.mediaOffset;
    final rowIdentity = item.transcriptSegmentId == null
        ? item.meeting.id
        : '${item.meeting.id}:${item.transcriptSegmentId}:'
              '${transcriptOffset!.inMicroseconds}';
    return Card(
      key: ValueKey<String>('meeting-card:$rowIdentity'),
      child: ListTile(
        leading: const Icon(Icons.graphic_eq_rounded),
        title: Text(item.meeting.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatter.metadata(item)),
            _MeetingStatusChip(
              meetingId: item.meeting.id,
              lifecycle: item.meeting.lifecycle,
              formatter: formatter,
            ),
            if (transcriptOffset != null)
              Text(formatter.transcriptMatch(transcriptOffset)),
            if (deletionPending)
              Semantics(
                key: ValueKey<String>(
                  'permanent-delete-pending:${item.meeting.id}',
                ),
                liveRegion: true,
                child: Text(
                  AppLocalizations.of(context).permanentDeletePending,
                ),
              ),
            if (deletionFailed)
              Semantics(
                key: ValueKey<String>(
                  'permanent-delete-failed:${item.meeting.id}',
                ),
                liveRegion: true,
                child: Text(
                  AppLocalizations.of(context).permanentDeleteFailed,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        trailing: deletionPending
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _MeetingActions(
                inTrash: inTrash,
                lifecycle: item.meeting.lifecycle,
                onRename: onRename,
                onMoveToTrash: onMoveToTrash,
                onRestore: onRestore,
                onPermanentDelete: onPermanentDelete,
              ),
        onTap: onOpen,
      ),
    );
  }
}

final class _MeetingStatusChip extends StatelessWidget {
  const _MeetingStatusChip({
    required this.meetingId,
    required this.lifecycle,
    required this.formatter,
  });

  final String meetingId;
  final MeetingLifecycle lifecycle;
  final _SessionLibraryFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final colors = LoquirisColors.of(context);
    final status = formatter.appearance(lifecycle);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Chip(
        key: ValueKey<String>('meeting-status:$meetingId'),
        avatar: Icon(
          formatter.statusIcon(lifecycle),
          color: status.color(colors),
        ),
        label: Text(formatter.status(lifecycle)),
        backgroundColor: colors.surfaceRaised,
        side: BorderSide(color: status.color(colors)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

enum _MeetingAction { rename, moveToTrash, restore, permanentlyDelete }

final class _MeetingActions extends StatelessWidget {
  const _MeetingActions({
    required this.inTrash,
    required this.lifecycle,
    required this.onRename,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final bool inTrash;
  final MeetingLifecycle lifecycle;
  final VoidCallback onRename;
  final VoidCallback onMoveToTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MeetingAction>(
      tooltip: l10n.meetingActionsTooltip,
      onSelected: (action) => switch (action) {
        _MeetingAction.rename => onRename(),
        _MeetingAction.moveToTrash => onMoveToTrash(),
        _MeetingAction.restore => onRestore?.call(),
        _MeetingAction.permanentlyDelete => onPermanentDelete?.call(),
      },
      itemBuilder: (context) => [
        if (!inTrash)
          PopupMenuItem(
            value: _MeetingAction.rename,
            child: Text(l10n.renameMeetingAction),
          ),
        if (!inTrash && _canMoveToTrash(lifecycle))
          PopupMenuItem(
            value: _MeetingAction.moveToTrash,
            child: Text(l10n.moveToTrashAction),
          ),
        if (inTrash && lifecycle == MeetingLifecycle.trashed)
          PopupMenuItem(
            value: _MeetingAction.restore,
            child: Text(l10n.restoreMeetingAction),
          ),
        if (inTrash)
          PopupMenuItem(
            value: _MeetingAction.permanentlyDelete,
            child: Text(
              lifecycle == MeetingLifecycle.deleting
                  ? l10n.retryPermanentDeleteAction
                  : l10n.permanentDeleteMeetingAction,
            ),
          ),
      ],
    );
  }
}

bool _canMoveToTrash(MeetingLifecycle lifecycle) => switch (lifecycle) {
  MeetingLifecycle.draft ||
  MeetingLifecycle.finalized ||
  MeetingLifecycle.recoverable ||
  MeetingLifecycle.failedFinalization => true,
  MeetingLifecycle.preparing ||
  MeetingLifecycle.recording ||
  MeetingLifecycle.pausedByUser ||
  MeetingLifecycle.pausedByInterruption ||
  MeetingLifecycle.stopping ||
  MeetingLifecycle.trashed ||
  MeetingLifecycle.deleting => false,
};

final class _SessionLibraryFormatter {
  _SessionLibraryFormatter(BuildContext context)
    : l10n = AppLocalizations.of(context),
      material = MaterialLocalizations.of(context);

  final AppLocalizations l10n;
  final MaterialLocalizations material;

  String metadata(SessionSearchHit item) => l10n.meetingMetadata(
    material.formatCompactDate(
      DateTime.fromMillisecondsSinceEpoch(
        item.meeting.createdAtUtcMs,
        isUtc: true,
      ).toLocal(),
    ),
    _duration(item.meeting.mediaDuration),
    _bytes(item.committedAudioBytes),
  );

  String transcriptMatch(Duration offset) =>
      l10n.transcriptMatchAt(_duration(offset));

  String status(MeetingLifecycle lifecycle) => switch (lifecycle) {
    MeetingLifecycle.draft => l10n.meetingStatusDraft,
    MeetingLifecycle.preparing => l10n.meetingStatusPreparing,
    MeetingLifecycle.recording => l10n.meetingStatusRecording,
    MeetingLifecycle.pausedByUser ||
    MeetingLifecycle.pausedByInterruption => l10n.meetingStatusPaused,
    MeetingLifecycle.stopping => l10n.meetingStatusStopping,
    MeetingLifecycle.finalized => l10n.meetingStatusFinished,
    MeetingLifecycle.recoverable => l10n.meetingStatusRecoverable,
    MeetingLifecycle.failedFinalization => l10n.meetingStatusFailed,
    MeetingLifecycle.trashed => l10n.meetingStatusTrashed,
    MeetingLifecycle.deleting => l10n.meetingStatusDeleting,
  };

  LoquirisStatus appearance(MeetingLifecycle lifecycle) => switch (lifecycle) {
    MeetingLifecycle.recording => LoquirisStatus.recording,
    MeetingLifecycle.pausedByUser ||
    MeetingLifecycle.pausedByInterruption => LoquirisStatus.paused,
    MeetingLifecycle.preparing ||
    MeetingLifecycle.stopping => LoquirisStatus.processing,
    MeetingLifecycle.finalized => LoquirisStatus.completed,
    MeetingLifecycle.draft ||
    MeetingLifecycle.recoverable ||
    MeetingLifecycle.trashed => LoquirisStatus.warning,
    MeetingLifecycle.failedFinalization ||
    MeetingLifecycle.deleting => LoquirisStatus.failed,
  };

  IconData statusIcon(MeetingLifecycle lifecycle) => switch (lifecycle) {
    MeetingLifecycle.recording => Icons.mic_rounded,
    MeetingLifecycle.pausedByUser ||
    MeetingLifecycle.pausedByInterruption => Icons.pause_rounded,
    MeetingLifecycle.preparing ||
    MeetingLifecycle.stopping => Icons.sync_rounded,
    MeetingLifecycle.finalized => Icons.check_circle_outline_rounded,
    MeetingLifecycle.draft => Icons.edit_note_rounded,
    MeetingLifecycle.recoverable => Icons.restore_rounded,
    MeetingLifecycle.failedFinalization => Icons.error_outline_rounded,
    MeetingLifecycle.trashed => Icons.delete_outline_rounded,
    MeetingLifecycle.deleting => Icons.delete_forever_outlined,
  };

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours == 0
        ? '${value.inMinutes}:$seconds'
        : '$hours:$minutes:$seconds';
  }

  String _bytes(int value) {
    if (value < 1000) return '$value B';
    if (value < 1000000) return '${_decimal(value / 1000)} kB';
    return '${_decimal(value / 1000000)} MB';
  }

  String _decimal(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

final class _DelayedSessionsSkeleton extends StatefulWidget {
  const _DelayedSessionsSkeleton();

  @override
  State<_DelayedSessionsSkeleton> createState() =>
      _DelayedSessionsSkeletonState();
}

final class _DelayedSessionsSkeletonState
    extends State<_DelayedSessionsSkeleton> {
  Timer? _timer;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(LoquirisMotion.of(context).medium, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final colors = LoquirisColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey<String>('sessions-loading'),
      container: true,
      liveRegion: true,
      label: l10n.sessionsLoadingLabel,
      child: ExcludeSemantics(
        child: Column(
          children: List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: LoquirisSpacing.of(context).related,
              ),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadiusDirectional.circular(
                    LoquirisShapes.of(context).controlRadius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
