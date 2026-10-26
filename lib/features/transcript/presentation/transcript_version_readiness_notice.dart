import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_choices_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Announces available refinement without changing any current selection.
final class TranscriptVersionReadinessNotice extends ConsumerWidget {
  /// Creates an in-app notice over validated, retained version state.
  const TranscriptVersionReadinessNotice({
    required this.meetingId,
    required this.onOpenVersions,
    super.key,
  });

  /// Stable route-derived owner of the version choices.
  final String meetingId;

  /// Opens the version history; never selects a run implicitly.
  final VoidCallback onOpenVersions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(
      transcriptVersionChoicesControllerProvider(meetingId).select(
        (snapshot) =>
            snapshot.value?.choices.any((choice) => choice.isReady) ?? false,
      ),
    );
    if (!ready) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return Card(
      key: const Key('transcript-refinement-ready'),
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              sortKey: const OrdinalSortKey(0),
              child: Text(l10n.transcriptRefinementReady),
            ),
            SizedBox(height: spacing.related),
            Semantics(
              container: true,
              button: true,
              enabled: true,
              focusable: true,
              label: l10n.transcriptVersionsTitle,
              sortKey: const OrdinalSortKey(1),
              excludeSemantics: true,
              onTap: onOpenVersions,
              child: OutlinedButton(
                onPressed: onOpenVersions,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: spacing.section,
                    vertical: spacing.related,
                  ),
                ),
                child: Text(l10n.transcriptVersionsTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
