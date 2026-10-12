import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/presentation/transcript_editor_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Combined basic editor for stable transcript, language, and speaker labels.
final class TranscriptEditorScreen extends ConsumerWidget {
  /// Creates an editor for one route-derived meeting.
  const TranscriptEditorScreen({required this.meetingId, super.key});

  /// Stable meeting identity.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = transcriptEditorControllerProvider(meetingId);
    final snapshot = ref.watch(provider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ValueKey<String>('transcript-editor:$meetingId'),
      appBar: AppBar(title: Text(l10n.transcriptEditorTitle)),
      body: switch (snapshot) {
        AsyncData(:final value) => _EditorContent(
          state: value,
          onSaveText: (segmentId, text) =>
              ref.read(provider.notifier).correctText(segmentId, text),
          onSaveLanguage: (segmentId, language) =>
              ref.read(provider.notifier).correctLanguage(segmentId, language),
          onRenameSpeaker: (speakerId, label) =>
              ref.read(provider.notifier).renameSpeaker(speakerId, label),
        ),
        AsyncError() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.transcriptEditorLoadFailed),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(provider),
                child: Text(l10n.retryAction),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

final class _EditorContent extends StatelessWidget {
  const _EditorContent({
    required this.state,
    required this.onSaveText,
    required this.onSaveLanguage,
    required this.onRenameSpeaker,
  });

  final TranscriptEditorViewState state;
  final void Function(String segmentId, String text) onSaveText;
  final void Function(String segmentId, LanguageTag language) onSaveLanguage;
  final void Function(String speakerId, String label) onRenameSpeaker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final document = state.document;
    final version = document.currentVersion;
    return LoquirisAdaptivePage(
      child: ListView(
        children: [
          if (state.failureCode != null) ...[
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                state.committedButRefreshFailed
                    ? l10n.transcriptEditorRefreshAfterSaveFailed
                    : l10n.transcriptEditorSaveFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            SizedBox(height: spacing.related),
          ],
          if (!document.canEdit && version != null) ...[
            Card(
              key: const Key('transcript-read-only'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_clock_outlined),
                    SizedBox(width: spacing.related),
                    Expanded(child: Text(l10n.transcriptEditorReadOnly)),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.section),
          ],
          Text(
            l10n.transcriptEditorSegmentsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.related),
          if (version == null || version.segments.isEmpty)
            Text(l10n.transcriptEditorNoTranscript)
          else
            ...version.segments.map(
              (segment) => Padding(
                padding: EdgeInsets.only(bottom: spacing.related),
                child: _SegmentCard(
                  segment: segment,
                  language: document.languagesBySegmentId[segment.id],
                  speakerLabel: document.speakersById[segment.speakerId]?.label,
                  canEdit: document.canEdit && !state.isSaving,
                  onSaveText: (text) => onSaveText(segment.id, text),
                  onSaveLanguage: (language) =>
                      onSaveLanguage(segment.id, language),
                ),
              ),
            ),
          SizedBox(height: spacing.section),
          Text(
            l10n.transcriptEditorSpeakersTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.related),
          if (document.speakersById.isEmpty)
            Text(l10n.transcriptEditorNoSpeaker)
          else
            ...document.speakersById.values.map(
              (speaker) => ListTile(
                key: Key('speaker-label:${speaker.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(speaker.label),
                trailing: IconButton(
                  tooltip: l10n.transcriptEditorRenameSpeaker,
                  onPressed: document.canEdit && !state.isSaving
                      ? () => _showSpeakerRename(
                          context,
                          initialLabel: speaker.label,
                          onSave: (label) => onRenameSpeaker(speaker.id, label),
                        )
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
          SizedBox(height: spacing.section),
          Text(
            l10n.transcriptEditorHistoryTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.related),
          if (document.revisions.isEmpty)
            Text(l10n.transcriptEditorNoHistory)
          else
            Column(
              key: const Key('revision-history-item'),
              children: document.revisions
                  .map(
                    (revision) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(_revisionLabel(l10n, revision.change)),
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

final class _SegmentCard extends StatefulWidget {
  const _SegmentCard({
    required this.segment,
    required this.language,
    required this.speakerLabel,
    required this.canEdit,
    required this.onSaveText,
    required this.onSaveLanguage,
  });

  final TranscriptSegment segment;
  final LanguageDecision? language;
  final String? speakerLabel;
  final bool canEdit;
  final ValueChanged<String> onSaveText;
  final ValueChanged<LanguageTag> onSaveLanguage;

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

final class _SegmentCardState extends State<_SegmentCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.segment.displayedText,
  );

  @override
  void didUpdateWidget(covariant _SegmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.displayedText != widget.segment.displayedText) {
      _controller.text = widget.segment.displayedText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segment = widget.segment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.transcriptEditorSegmentTime(
                _formatDuration(segment.start),
                _formatDuration(segment.end),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.canEdit) ...[
              TextFormField(
                key: Key('transcript-text:${segment.id}'),
                controller: _controller,
                decoration: InputDecoration(
                  labelText: l10n.transcriptEditorTextLabel,
                ),
                minLines: 2,
                maxLines: 5,
                onFieldSubmitted: widget.onSaveText,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonalIcon(
                  key: Key('transcript-save:${segment.id}'),
                  onPressed: () => widget.onSaveText(_controller.text),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.transcriptEditorSaveText),
                ),
              ),
            ] else
              Text(segment.displayedText),
            const SizedBox(height: 12),
            DropdownButtonFormField<LanguageTag>(
              key: Key('transcript-language:${segment.id}'),
              initialValue: widget.language?.tag,
              decoration: InputDecoration(
                labelText: l10n.transcriptEditorLanguageLabel,
              ),
              items: LanguageTag.values
                  .map(
                    (tag) => DropdownMenuItem(
                      value: tag,
                      child: Text(_languageLabel(l10n, tag)),
                    ),
                  )
                  .toList(),
              onChanged: widget.canEdit && widget.language != null
                  ? (value) {
                      if (value != null) widget.onSaveLanguage(value);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.speakerLabel ?? l10n.transcriptEditorNoSpeaker,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSpeakerRename(
  BuildContext context, {
  required String initialLabel,
  required ValueChanged<String> onSave,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => _SpeakerRenameDialog(initialLabel: initialLabel),
  );
  if (result != null) onSave(result);
}

final class _SpeakerRenameDialog extends StatefulWidget {
  const _SpeakerRenameDialog({required this.initialLabel});

  final String initialLabel;

  @override
  State<_SpeakerRenameDialog> createState() => _SpeakerRenameDialogState();
}

final class _SpeakerRenameDialogState extends State<_SpeakerRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialLabel,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.transcriptEditorRenameSpeaker),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.transcriptEditorSpeakerName,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

String _languageLabel(AppLocalizations l10n, LanguageTag tag) => switch (tag) {
  LanguageTag.chinese => l10n.languageChinese,
  LanguageTag.english => l10n.languageEnglish,
  LanguageTag.mixed => l10n.languageMixed,
  LanguageTag.uncertain => l10n.languageUncertain,
};

String _revisionLabel(AppLocalizations l10n, RevisionChange change) =>
    switch (change) {
      TranscriptTextChange() => l10n.transcriptEditorRevisionText,
      LanguageLabelChange() => l10n.transcriptEditorRevisionLanguage,
      SpeakerAssignmentChange() ||
      SpeakerLabelChange() => l10n.transcriptEditorRevisionSpeaker,
    };

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
