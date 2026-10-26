import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_transcription_panel.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/sessions/presentation/session_detail_controller.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_status.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_readiness_notice.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Saved meeting detail with validated local playback and durable timelines.
final class SessionDetailScreen extends ConsumerWidget {
  /// Creates detail UI for one locally saved meeting.
  const SessionDetailScreen({
    required this.meetingId,
    this.initialOffset,
    super.key,
  });

  /// Stable meeting identity from the route.
  final String meetingId;

  /// Optional pause-free media time requested by a search or marker link.
  final Duration? initialOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = SessionDetailRequest(
      meetingId: meetingId,
      initialOffset: initialOffset,
    );
    final state = ref.watch(sessionDetailControllerProvider(request));
    final remoteEnabled = ref.watch(remoteTranscriptionEnabledProvider);
    final hasLegacyTranscript =
        state.value?.detail.meeting.currentTranscriptRunId != null;
    return Scaffold(
      key: ValueKey<String>('session-detail:$meetingId'),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).sessionDetailTitle),
        actions: [
          if (!remoteEnabled || hasLegacyTranscript)
            IconButton(
              key: const Key('session-detail-open-export'),
              tooltip: AppLocalizations.of(context).exportTitle,
              onPressed: () => context.push(AppRoutes.export(meetingId)),
              icon: const ExcludeSemantics(
                child: Icon(Icons.ios_share_outlined),
              ),
            ),
          if (!remoteEnabled || hasLegacyTranscript)
            IconButton(
              key: const Key('session-detail-open-editor'),
              tooltip: AppLocalizations.of(context).transcriptEditorTitle,
              onPressed: () => context.push(AppRoutes.editor(meetingId)),
              icon: const Icon(Icons.edit_note_rounded),
            ),
        ],
      ),
      body: switch (state) {
        AsyncData(:final value) => _DetailContent(
          state: value,
          remoteEnabled: remoteEnabled,
          onToggle: () => ref
              .read(sessionDetailControllerProvider(request).notifier)
              .togglePlayback(),
          onSeek: (position) => ref
              .read(sessionDetailControllerProvider(request).notifier)
              .seek(position),
        ),
        AsyncError() => Center(
          child: Text(AppLocalizations.of(context).sessionDetailLoadFailed),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

final class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.state,
    required this.onToggle,
    required this.onSeek,
    required this.remoteEnabled,
  });

  final SessionDetailViewState state;
  final bool remoteEnabled;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail;
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return LoquirisAdaptivePage(
      child: ListView(
        children: [
          Text(
            detail.meeting.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: spacing.related),
          Text(_meetingMetadata(context, detail.meeting)),
          SizedBox(height: spacing.section),
          _PlaybackCard(state: state, onToggle: onToggle, onSeek: onSeek),
          SizedBox(height: spacing.section),
          if (!remoteEnabled)
            MeetingTranscriptionStatus(meetingId: detail.meeting.id),
          RemoteTranscriptionPanel(meetingId: detail.meeting.id),
          if (!remoteEnabled || detail.meeting.currentTranscriptRunId != null)
            TranscriptVersionReadinessNotice(
              meetingId: detail.meeting.id,
              onOpenVersions: () => context.push<void>(
                AppRoutes.transcriptVersions(detail.meeting.id),
              ),
            ),
          _Section(
            title: l10n.sessionDetailMarkersTitle,
            emptyLabel: l10n.sessionDetailNoMarkers,
            children: detail.bookmarks
                .map(
                  (marker) => ListTile(
                    key: Key('session-detail-marker:${marker.id}'),
                    leading: Icon(
                      marker.kind == BookmarkKind.highlight
                          ? Icons.star_outline_rounded
                          : Icons.bookmark_outline_rounded,
                    ),
                    title: Text(
                      marker.kind == BookmarkKind.highlight
                          ? l10n.sessionDetailHighlight
                          : l10n.sessionDetailBookmark,
                    ),
                    subtitle: Text(_formatDuration(marker.mediaOffset)),
                    onTap: state.playback == null
                        ? null
                        : () => onSeek(marker.mediaOffset),
                  ),
                )
                .toList(),
          ),
          _RecordingDiagnostics(detail: detail, collapsed: remoteEnabled),
          if (detail.recoveryDiagnostics.isNotEmpty)
            _Section(
              title: l10n.sessionDetailRecoveryTitle,
              emptyLabel: l10n.sessionDetailNoRecoveryIssues,
              children: detail.recoveryDiagnostics
                  .map(
                    (diagnostic) => ListTile(
                      leading: const Icon(Icons.warning_amber_rounded),
                      title: Text(_recoveryLabel(l10n, diagnostic.code)),
                    ),
                  )
                  .toList(),
            ),
          SizedBox(height: spacing.page),
        ],
      ),
    );
  }
}

final class _RecordingDiagnostics extends StatelessWidget {
  const _RecordingDiagnostics({required this.detail, required this.collapsed});
  final SessionDetail detail;
  final bool collapsed;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otherProcessingJobs = detail.processingJobs
        .where((job) => job.kind != ProcessingJobKind.transcription)
        .toList(growable: false);
    final children = <Widget>[
      _Section(
        title: l10n.sessionDetailSegmentsTitle,
        emptyLabel: l10n.sessionDetailNoSegments,
        children: detail.segments
            .map(
              (segment) => ListTile(
                key: Key('session-detail-segment:${segment.id}'),
                leading: const Icon(Icons.audio_file_outlined),
                title: Text(
                  l10n.sessionDetailSegment(segment.sequence + 1),
                ),
                subtitle: Text(
                  '${_formatDuration(segment.mediaStart)}–'
                  '${_formatDuration(segment.mediaStart + segment.mediaDuration)} · '
                  '${_formatBytes(segment.committedBytes)} · '
                  '${_segmentStateLabel(l10n, segment.state)}',
                ),
              ),
            )
            .toList(),
      ),
      _Section(
        title: l10n.sessionDetailEventsTitle,
        emptyLabel: l10n.sessionDetailNoEvents,
        children: detail.events
            .map(
              (event) => ListTile(
                key: Key('session-detail-event:${event.id}'),
                leading: const Icon(Icons.timeline_rounded),
                title: Text(_eventLabel(l10n, event.type)),
                subtitle: Text(
                  '${DateFormat.yMd(Localizations.localeOf(context).toString()).add_jm().format(DateTime.fromMillisecondsSinceEpoch(event.wallClockUtcMs))} · '
                  '${_formatDuration(event.mediaOffset)}',
                ),
              ),
            )
            .toList(),
      ),
      if (otherProcessingJobs.isNotEmpty)
        _Section(
          title: l10n.sessionDetailProcessingTitle,
          emptyLabel: l10n.sessionDetailNoProcessing,
          children: otherProcessingJobs
              .map(
                (job) => ListTile(
                  leading: const Icon(Icons.memory_rounded),
                  title: Text(_processingKindLabel(l10n, job.kind)),
                  subtitle: Text(_processingLabel(l10n, job.state)),
                ),
              )
              .toList(),
        ),
    ];
    return collapsed
        ? ExpansionTile(
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Text(l10n.remoteRecordingDetails),
            children: children,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
  }
}

final class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.state,
    required this.onToggle,
    required this.onSeek,
  });

  final SessionDetailViewState state;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playback = state.playback;
    return Card(
      key: const Key('session-detail-playback'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (playback == null)
              Text(
                _playbackFailureLabel(l10n, state.playbackFailure?.code),
                textAlign: TextAlign.center,
              )
            else ...[
              Slider(
                value: playback.position.inMilliseconds
                    .clamp(0, playback.duration.inMilliseconds)
                    .toDouble(),
                max: playback.duration.inMilliseconds
                    .clamp(1, 1 << 31)
                    .toDouble(),
                semanticFormatterCallback: (_) =>
                    l10n.sessionDetailPlaybackPosition(
                      _formatDuration(playback.position),
                      _formatDuration(playback.duration),
                    ),
                onChanged: (value) => onSeek(
                  Duration(milliseconds: value.round()),
                ),
              ),
              Text(
                '${_formatDuration(playback.position)} / '
                '${_formatDuration(playback.duration)}',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('session-detail-play'),
                onPressed: onToggle,
                icon: Icon(
                  playback.state == SessionPlaybackState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  playback.state == SessionPlaybackState.playing
                      ? l10n.sessionDetailPause
                      : l10n.sessionDetailPlay,
                ),
              ),
              if (state.playbackFailure != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    _playbackFailureLabel(
                      l10n,
                      state.playbackFailure?.code,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(emptyLabel),
        )
      else
        ...children,
      const SizedBox(height: 24),
    ],
  );
}

String _meetingMetadata(BuildContext context, Meeting meeting) =>
    '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(DateTime.fromMillisecondsSinceEpoch(meeting.createdAtUtcMs))} · '
    '${_formatDuration(meeting.mediaDuration)}';

String _eventLabel(AppLocalizations l10n, SessionEventType type) =>
    switch (type) {
      SessionEventType.started => l10n.sessionEventStarted,
      SessionEventType.pausedByUser => l10n.sessionEventPaused,
      SessionEventType.resumedByUser => l10n.sessionEventResumed,
      SessionEventType.interrupted => l10n.sessionEventInterrupted,
      SessionEventType.stopped => l10n.sessionEventStopped,
      SessionEventType.recovered => l10n.sessionEventRecovered,
    };

String _processingLabel(AppLocalizations l10n, ProcessingState state) =>
    switch (state) {
      ProcessingQueued() => l10n.sessionProcessingQueued,
      ProcessingRunning(:final progress) => l10n.sessionProcessingRunning(
        (progress * 100).round(),
      ),
      ProcessingPaused() => l10n.sessionProcessingPaused,
      ProcessingSucceeded() => l10n.sessionProcessingSucceeded,
      ProcessingSucceededWithWarning() => l10n.sessionProcessingSucceeded,
      ProcessingFailed(:final failureCode)
          when failureCode == 'recording_m4a_mux_failed' =>
        l10n.sessionAudioPreparationFailed,
      ProcessingFailed() => l10n.sessionProcessingFailed,
    };

String _processingKindLabel(AppLocalizations l10n, ProcessingJobKind kind) =>
    switch (kind) {
      ProcessingJobKind.transcription => l10n.sessionJobTranscription,
      ProcessingJobKind.languageIdentification =>
        l10n.sessionJobLanguageIdentification,
      ProcessingJobKind.speakerDiarization => l10n.sessionJobSpeakerDiarization,
      ProcessingJobKind.audioMerge => l10n.sessionJobAudioMerge,
      ProcessingJobKind.waveform => l10n.sessionJobWaveform,
    };

String _segmentStateLabel(AppLocalizations l10n, AudioSegmentState state) =>
    switch (state) {
      AudioSegmentState.open => l10n.sessionSegmentOpen,
      AudioSegmentState.committed => l10n.sessionSegmentCommitted,
      AudioSegmentState.corrupt => l10n.sessionSegmentCorrupt,
      AudioSegmentState.missing => l10n.sessionSegmentMissing,
    };

String _recoveryLabel(AppLocalizations l10n, String code) => switch (code) {
  'recording_recovery_tail_discarded' => l10n.sessionRecoveryTailDiscarded,
  'recording_recovery_timeline_gap' => l10n.sessionRecoveryTimelineGap,
  'recording_recovery_segment_missing' => l10n.sessionRecoverySegmentMissing,
  'recording_recovery_segment_corrupt' => l10n.sessionRecoverySegmentCorrupt,
  _ => l10n.sessionRecoveryUnknown,
};

String _playbackFailureLabel(AppLocalizations l10n, String? code) =>
    switch (code) {
      'recording_m4a_artifact_not_ready' ||
      'recording_m4a_status_missing' ||
      'recording_m4a_status_corrupt' => l10n.sessionPlaybackPreparing,
      _ => l10n.sessionPlaybackUnavailable,
    };

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
