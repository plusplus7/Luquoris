import 'package:flutter/material.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Read-only, bounded presentation of one experimental live draft.
final class LiveTranscriptPanel extends StatelessWidget {
  /// Creates the panel from already-reconciled [state].
  const LiveTranscriptPanel({required this.state, super.key});

  /// Current screen-ready draft state.
  final LiveTranscriptState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == LiveTranscriptStatus.inactive) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const Key('live-transcript-panel'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.liveTranscriptTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.liveTranscriptExperimentalLabel,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            if (state.chunks.isEmpty)
              Text(l10n.liveTranscriptWaiting)
            else
              for (final chunk in state.chunks) ...[
                _DraftSegment(chunk: chunk),
                const SizedBox(height: 8),
              ],
            _LiveDraftStatus(state: state),
          ],
        ),
      ),
    );
  }
}

final class _DraftSegment extends StatelessWidget {
  const _DraftSegment({required this.chunk});

  final TranscriptChunk chunk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stable = chunk.stability == TranscriptStability.stable;
    final label = stable
        ? l10n.liveTranscriptStableLabel
        : l10n.liveTranscriptDraftLabel;
    final semanticLabel = stable
        ? l10n.liveTranscriptStableSegment(chunk.displayText)
        : l10n.liveTranscriptDraftSegment(chunk.displayText);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              stable
                  ? Icons.check_circle_outline_rounded
                  : Icons.edit_note_rounded,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(chunk.displayText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LiveDraftStatus extends StatelessWidget {
  const _LiveDraftStatus({required this.state});

  final LiveTranscriptState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = <String>[
      if (state.isBacklogged)
        l10n.liveTranscriptBacklog(_roundedUpSeconds(state.backlog)),
      if (state.incomplete) l10n.liveTranscriptIncomplete,
      if (state.degradationReason != null)
        _degradationMessage(l10n, state.degradationReason!),
      l10n.liveTranscriptPostSessionFallback,
    ];
    return Semantics(
      key: const Key('live-transcript-status'),
      container: true,
      liveRegion: true,
      label: messages.join(' '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          for (final message in messages)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Text(message),
            ),
        ],
      ),
    );
  }
}

int _roundedUpSeconds(Duration duration) =>
    (duration.inMilliseconds / Duration.millisecondsPerSecond).ceil();

String _degradationMessage(AppLocalizations l10n, String reason) {
  if (reason == 'transcription_live_thermal') {
    return l10n.liveTranscriptThermalFallback;
  }
  if (reason.startsWith('transcription_model_')) {
    return l10n.liveTranscriptModelFallback;
  }
  return l10n.liveTranscriptGenericFallback;
}
