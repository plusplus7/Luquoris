import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/active_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_panel.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Active native recording controls and pause-aware recording information.
final class ActiveRecordingScreen extends ConsumerWidget {
  /// Creates the screen for [meetingId].
  const ActiveRecordingScreen({required this.meetingId, super.key});

  /// Meeting identity reconstructed from the URL.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(recordingControllerProvider, (previous, next) {
      final prior = previous?.value?.snapshot;
      final current = next.value?.snapshot;
      if (current?.sessionId == meetingId &&
          current?.state == AudioCaptureState.finalized &&
          (prior?.sessionId != meetingId ||
              prior?.state != AudioCaptureState.finalized) &&
          context.mounted) {
        context.go(AppRoutes.session(meetingId));
      }
    });
    final recording = ref.watch(recordingControllerProvider);
    return LoquirisAdaptivePage(
      key: ValueKey<String>('active-recording:$meetingId'),
      child: switch (recording) {
        AsyncData(:final value) => _ActiveRecordingContent(
          meetingId: meetingId,
          state: value,
          onPause: () => ref.read(recordingControllerProvider.notifier).pause(),
          onResume: () =>
              ref.read(recordingControllerProvider.notifier).resume(),
          onStop: () => ref.read(recordingControllerProvider.notifier).stop(),
          onMarker: (kind) => ref
              .read(activeRecordingActionsProvider(meetingId))
              .addMarker(kind),
        ),
        AsyncError() => const _RecordingUnavailable(),
        _ => const _RecordingLoading(),
      },
    );
  }
}

final class _ActiveRecordingContent extends StatelessWidget {
  const _ActiveRecordingContent({
    required this.meetingId,
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onMarker,
  });

  final String meetingId;
  final RecordingViewState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final Future<Result<Bookmark, SessionRepositoryFailure>> Function(
    BookmarkKind kind,
  )
  onMarker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final snapshot = state.snapshot;
    if (snapshot == null || snapshot.sessionId != meetingId) {
      return const _RecordingUnavailable();
    }
    final canPause = snapshot.state == AudioCaptureState.recording;
    final canResume =
        snapshot.state == AudioCaptureState.pausedByUser ||
        snapshot.state == AudioCaptureState.pausedByInterruption;
    final canStop = switch (snapshot.state) {
      AudioCaptureState.recording ||
      AudioCaptureState.pausedByUser ||
      AudioCaptureState.pausedByInterruption => true,
      _ => false,
    };
    final canMark = switch (snapshot.state) {
      AudioCaptureState.recording ||
      AudioCaptureState.pausedByUser ||
      AudioCaptureState.pausedByInterruption => true,
      _ => false,
    };
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.activeRecordingTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: spacing.section),
              _RecordingStatus(snapshot: snapshot),
              SizedBox(height: spacing.section),
              Semantics(
                label: l10n.recordingTimerSemantic(
                  _formatDuration(snapshot.elapsed),
                ),
                excludeSemantics: true,
                child: Text(
                  _formatDuration(snapshot.elapsed),
                  key: const Key('active-recording-timer'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(height: spacing.related),
              Text(
                l10n.recordingSizeLabel(_formatBytes(snapshot.bytesWritten)),
                key: const Key('active-recording-size'),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.section),
              _InputActivity(snapshot: snapshot),
              _LiveTranscriptSection(meetingId: meetingId),
              if (state.failure != null ||
                  state.persistenceFailure != null) ...[
                SizedBox(height: spacing.related),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.persistenceFailure != null
                        ? l10n.recordingMetadataSaveWarning
                        : l10n.recordingControlFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              SizedBox(height: spacing.section),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing.related,
                runSpacing: spacing.related,
                children: [
                  if (canResume)
                    _ControlButton(
                      key: const Key('active-recording-pause'),
                      icon: Icons.mic_rounded,
                      label: l10n.resumeRecordingAction,
                      onPressed: onResume,
                    )
                  else
                    _ControlButton(
                      key: const Key('active-recording-pause'),
                      icon: Icons.pause_rounded,
                      label: l10n.pauseRecordingAction,
                      onPressed: canPause ? onPause : null,
                    ),
                  _ControlButton(
                    key: const Key('active-recording-stop'),
                    icon: Icons.stop_rounded,
                    label: l10n.stopRecordingAction,
                    onPressed: canStop
                        ? () => _confirmStop(context, onStop)
                        : null,
                    destructive: true,
                  ),
                ],
              ),
              SizedBox(height: spacing.section),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing.related,
                runSpacing: spacing.related,
                children: [
                  _ControlButton(
                    key: const Key('active-recording-bookmark'),
                    icon: Icons.bookmark_add_outlined,
                    label: l10n.addBookmarkAction,
                    onPressed: canMark
                        ? () => _addMarker(context, BookmarkKind.bookmark)
                        : null,
                  ),
                  _ControlButton(
                    key: const Key('active-recording-highlight'),
                    icon: Icons.star_outline_rounded,
                    label: l10n.addHighlightAction,
                    onPressed: canMark
                        ? () => _addMarker(context, BookmarkKind.highlight)
                        : null,
                  ),
                ],
              ),
              SizedBox(height: spacing.page),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addMarker(BuildContext context, BookmarkKind kind) async {
    final result = await onMarker(kind);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (result) {
      Ok() when kind == BookmarkKind.bookmark => l10n.bookmarkAddedMessage,
      Ok() => l10n.highlightAddedMessage,
      Err() => l10n.markerAddFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _LiveTranscriptSection extends ConsumerWidget {
  const _LiveTranscriptSection({required this.meetingId});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(liveTranscriptControllerProvider(meetingId));
    return switch (draft) {
      AsyncData(:final value)
          when value.status != LiveTranscriptStatus.inactive =>
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: LoquirisSpacing.of(context).section,
          ),
          child: LiveTranscriptPanel(state: value),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

final class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.snapshot});

  final AudioCaptureSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoquirisColors.of(context);
    final (label, color) = switch (snapshot.state) {
      AudioCaptureState.recording => (
        l10n.recordingStatusActive,
        colors.recording,
      ),
      AudioCaptureState.pausedByUser => (
        l10n.recordingStatusPaused,
        colors.paused,
      ),
      AudioCaptureState.pausedByInterruption => (
        l10n.recordingStatusInterrupted,
        colors.warning,
      ),
      AudioCaptureState.preparing => (
        l10n.recordingStatusPreparing,
        colors.processing,
      ),
      AudioCaptureState.stopping => (
        l10n.recordingStatusSaving,
        colors.processing,
      ),
      AudioCaptureState.finalized => (
        l10n.recordingStatusSaved,
        colors.success,
      ),
      AudioCaptureState.recoverable || AudioCaptureState.failedFinalization => (
        l10n.recordingStatusNeedsReview,
        colors.warning,
      ),
      AudioCaptureState.idle => (
        l10n.recordingStatusUnavailable,
        colors.onSurfaceMuted,
      ),
    };
    return Semantics(
      key: const Key('active-recording-status'),
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.circle, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

final class _InputActivity extends StatelessWidget {
  const _InputActivity({required this.snapshot});

  final AudioCaptureSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoquirisColors.of(context);
    final health = snapshot.inputHealth;
    final (label, icon, color) = switch (snapshot.state) {
      AudioCaptureState.recording
          when health == null || health.readCalls == 0 =>
        (
          l10n.recordingInputChecking,
          Icons.mic_none_rounded,
          colors.processing,
        ),
      AudioCaptureState.recording when (health?.errorReads ?? 0) > 0 => (
        l10n.recordingInputNeedsAttention,
        Icons.mic_off_outlined,
        colors.warning,
      ),
      AudioCaptureState.recording when (health?.pcmBytes ?? 0) > 0 => (
        l10n.recordingInputReceived,
        Icons.graphic_eq_rounded,
        colors.success,
      ),
      AudioCaptureState.pausedByUser ||
      AudioCaptureState.pausedByInterruption => (
        l10n.recordingInputPaused,
        Icons.mic_off_outlined,
        colors.onSurfaceMuted,
      ),
      _ => (
        l10n.recordingInputUnavailable,
        Icons.mic_none_rounded,
        colors.onSurfaceMuted,
      ),
    };
    return Semantics(
      key: const Key('active-recording-input-activity'),
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

final class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = LoquirisColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: destructive
              ? OutlinedButton.styleFrom(foregroundColor: colors.danger)
              : null,
          icon: ExcludeSemantics(child: Icon(icon)),
          label: Text(label),
        ),
      ),
    );
  }
}

Future<void> _confirmStop(BuildContext context, VoidCallback onStop) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.confirmStopRecordingTitle),
      content: Text(l10n.confirmStopRecordingBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          key: const Key('confirm-stop-recording'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.confirmStopRecordingAction),
        ),
      ],
    ),
  );
  if (confirmed == true) onStop();
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatBytes(int bytes) {
  const bytesPerKilobyte = 1024;
  const bytesPerMegabyte = bytesPerKilobyte * 1024;
  if (bytes < bytesPerKilobyte) return '$bytes B';
  if (bytes < bytesPerMegabyte) {
    return '${(bytes / bytesPerKilobyte).toStringAsFixed(1)} KB';
  }
  return '${(bytes / bytesPerMegabyte).toStringAsFixed(1)} MB';
}

final class _RecordingLoading extends StatelessWidget {
  const _RecordingLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: AppLocalizations.of(context).recordingStateLoading,
      child: const CircularProgressIndicator(),
    ),
  );
}

final class _RecordingUnavailable extends StatelessWidget {
  const _RecordingUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      AppLocalizations.of(context).recordingStateUnavailable,
      textAlign: TextAlign.center,
    ),
  );
}
