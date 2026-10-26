import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/features/transcript/presentation/refinement_paused_status.dart';
import 'package:loquiris/l10n/app_localizations.dart';

/// Durable, localized post-session transcription status for one meeting.
final class MeetingTranscriptionStatus extends ConsumerWidget {
  /// Creates a status surface keyed by [meetingId].
  const MeetingTranscriptionStatus({required this.meetingId, super.key});

  /// Meeting whose database-backed transcription state is shown.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = meetingTranscriptionControllerProvider(meetingId);
    final snapshot = ref.watch(provider);
    return switch (snapshot) {
      AsyncData(:final value)
          when value.latestJob != null || value.document != null =>
        _StatusCard(
          state: value,
          onRetry: (jobId) => ref.read(provider.notifier).retry(jobId),
          onResume: (jobId) => ref.read(provider.notifier).resume(jobId),
        ),
      AsyncData() => const SizedBox.shrink(),
      AsyncError() || AsyncLoading() => const SizedBox.shrink(),
    };
  }
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.onRetry,
    required this.onResume,
  });

  final MeetingTranscriptionState state;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final job = state.latestJob;
    final version = state.document?.currentVersion;
    return Card(
      key: const Key('meeting-transcription-status'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sessionJobTranscription,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (state.failure != null)
              _LiveMessage(
                message: l10n.transcriptionFailureStorage,
                isError: true,
              )
            else if (job != null)
              _JobStatus(
                job: job,
                isRetrying: state.retryingJobIds.contains(job.id),
                onRetry: onRetry,
                canResume: state.resumableJobIds.contains(job.id),
                onResume: onResume,
              ),
            if (state.retryFailed) ...[
              const SizedBox(height: 8),
              _LiveMessage(
                message: l10n.transcriptionRetryFailed,
                isError: true,
              ),
            ],
            if (version != null &&
                (version.run.state is AnalysisCompleted ||
                    version.run.state is AnalysisFailed)) ...[
              const SizedBox(height: 16),
              if (version.run.state is AnalysisFailed) ...[
                _LiveMessage(
                  message: l10n.transcriptVersionCoverage('incomplete'),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.transcriptPreviewTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (version.segments.isEmpty)
                Text(l10n.transcriptPreviewEmpty)
              else
                ...version.segments
                    .take(3)
                    .map(
                      (segment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(segment.displayedText),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _JobStatus extends StatelessWidget {
  const _JobStatus({
    required this.job,
    required this.isRetrying,
    required this.onRetry,
    required this.canResume,
    required this.onResume,
  });

  final ProcessingJob job;
  final bool isRetrying;
  final ValueChanged<String> onRetry;
  final bool canResume;
  final ValueChanged<String> onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (job.state) {
      ProcessingQueued() => Text(l10n.transcriptionPreparingModel),
      ProcessingRunning(:final progress) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.transcriptionDecodingAudio),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.transcriptionProgress((progress * 100).round()),
            value: '${(progress * 100).round()}%',
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: 6),
          Text(l10n.transcriptionProgress((progress * 100).round())),
        ],
      ),
      ProcessingPaused(:final reasonCode) when canResume =>
        RefinementPausedStatus(
          reasonCode: reasonCode,
          isResuming: isRetrying,
          onResume: () => onResume(job.id),
        ),
      ProcessingPaused() => _LiveMessage(message: l10n.transcriptionDelayed),
      ProcessingSucceeded() => Text(l10n.transcriptionCompleted),
      ProcessingSucceededWithWarning() => _LiveMessage(
        message: l10n.transcriptionIncomplete,
      ),
      ProcessingFailed(:final failureCode) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LiveMessage(
            message: _failureMessage(l10n, failureCode),
            isError: true,
          ),
          const SizedBox(height: 12),
          if (isRetrying)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.transcriptionRetrying)),
              ],
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                key: const Key('transcription-retry'),
                onPressed: () => onRetry(job.id),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.transcriptionRetryAction),
              ),
            ),
        ],
      ),
    };
  }
}

final class _LiveMessage extends StatelessWidget {
  const _LiveMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Text(
      message,
      style: isError
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    ),
  );
}

String _failureMessage(AppLocalizations l10n, String code) {
  if (code == 'transcription_cancelled') {
    return l10n.transcriptionCancelled;
  }
  if (code == 'transcription_output_invalid' ||
      code == 'transcription_engine_version_mismatch') {
    return l10n.transcriptionIncomplete;
  }
  if (code.startsWith('model_') || code.contains('model')) {
    return l10n.transcriptionFailureModel;
  }
  if (code.contains('store') ||
      code.contains('database') ||
      code.contains('persist')) {
    return l10n.transcriptionFailureStorage;
  }
  if (code.startsWith('transcription_') || code.contains('engine')) {
    return l10n.transcriptionFailureEngine;
  }
  return l10n.transcriptionFailureUnknown;
}
