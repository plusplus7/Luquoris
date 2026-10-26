import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_choices_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Retained transcript history with deliberate, non-destructive selection.
final class TranscriptVersionsScreen extends ConsumerWidget {
  /// Reconstructs the version surface from its route identity.
  const TranscriptVersionsScreen({required this.meetingId, super.key});

  /// Stable owning meeting identity, never transported through route extras.
  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = transcriptVersionChoicesControllerProvider(meetingId);
    final snapshot = ref.watch(provider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ValueKey('transcript-versions:$meetingId'),
      appBar: AppBar(title: Text(l10n.transcriptVersionsTitle)),
      body: LoquirisAdaptivePage(
        child: switch (snapshot) {
          AsyncData(:final value) => TranscriptVersionsContent(
            state: value,
            onSelect: (runId) => ref.read(provider.notifier).select(runId),
          ),
          AsyncError() => _VersionsFailure(
            onRetry: () => ref.invalidate(provider),
          ),
          AsyncLoading() => Center(
            child: Semantics(
              liveRegion: true,
              child: Text(l10n.transcriptVersionsLoading),
            ),
          ),
        },
      ),
    );
  }
}

/// Lazy version history that renders only committed selection markers.
final class TranscriptVersionsContent extends StatelessWidget {
  /// Creates a history surface without owning repository state.
  const TranscriptVersionsContent({
    required this.state,
    required this.onSelect,
    super.key,
  });

  /// Immutable choices and one pending user action.
  final TranscriptVersionChoicesState state;

  /// Resolves a stable run ID at activation time.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: state.choices.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _VersionSummary(state: state);
      final choice = state.choices[index - 1];
      return Semantics(
        key: ValueKey(choice.run.id),
        container: true,
        explicitChildNodes: true,
        sortKey: OrdinalSortKey(index.toDouble()),
        child: TranscriptVersionCard(
          choice: choice,
          isSelecting: state.selectingRunId == choice.run.id,
          selectionBlocked: state.selectingRunId != null,
          onSelect: () => onSelect(choice.run.id),
        ),
      );
    },
  );
}

final class _VersionSummary extends StatelessWidget {
  const _VersionSummary({required this.state});
  final TranscriptVersionChoicesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return Semantics(
      sortKey: const OrdinalSortKey(0),
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: spacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.transcriptVersionsHelp),
            if (state.selectionFailed) ...[
              SizedBox(height: spacing.related),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.transcriptVersionSelectionFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (state.choices.isEmpty) ...[
              SizedBox(height: spacing.section),
              Text(l10n.transcriptVersionsEmpty),
            ],
          ],
        ),
      ),
    );
  }
}

/// A readable version identity, source, coverage, and explicit selection action.
final class TranscriptVersionCard extends StatelessWidget {
  /// Creates a card whose current marker comes only from persisted state.
  const TranscriptVersionCard({
    required this.choice,
    required this.isSelecting,
    required this.selectionBlocked,
    required this.onSelect,
    super.key,
  });

  /// Validated role and immutable run provenance.
  final TranscriptVersionChoice choice;

  /// Whether this card's explicit selection awaits commit.
  final bool isSelecting;

  /// Whether another selection already owns the action.
  final bool selectionBlocked;

  /// Invokes the controller, never a repository directly.
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final role = l10n.transcriptVersionRole(
      choice.metadataInvalid
          ? 'unverified'
          : choice.processing?.role.name ?? 'legacy',
    );
    final title = l10n.transcriptVersionIdentity(
      role,
      choice.createdAt,
      choice.createdAt,
    );
    final provenance = choice.run.provenance;
    final enabled = choice.canSelect && !choice.isCurrent && !selectionBlocked;
    final action = isSelecting
        ? l10n.transcriptVersionSelecting
        : choice.isCurrent
        ? l10n.transcriptVersionCurrent
        : l10n.transcriptVersionUse;
    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              sortKey: const OrdinalSortKey(0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(height: spacing.related),
            _VersionDetails(choice: choice),
            SizedBox(height: spacing.related),
            Semantics(
              sortKey: const OrdinalSortKey(2),
              child: Text(
                l10n.transcriptVersionProvenance(
                  provenance.modelId,
                  provenance.modelVersion,
                  provenance.engineId,
                  provenance.engineVersion,
                  provenance.modelSha256,
                ),
              ),
            ),
            SizedBox(height: spacing.section),
            Semantics(
              container: true,
              button: true,
              enabled: enabled,
              selected: choice.isCurrent,
              focusable: true,
              label: enabled
                  ? l10n.transcriptVersionUseSemantic(title)
                  : action,
              sortKey: const OrdinalSortKey(3),
              excludeSemantics: true,
              onTap: enabled ? onSelect : null,
              child: FilledButton(
                key: Key('use-transcript-version:${choice.run.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: spacing.section,
                    vertical: spacing.related,
                  ),
                ),
                onPressed: enabled ? onSelect : null,
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _VersionDetails extends StatelessWidget {
  const _VersionDetails({required this.choice});
  final TranscriptVersionChoice choice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return Semantics(
      sortKey: const OrdinalSortKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.transcriptVersionCoverage(
              choice.processing?.completeness.name ?? 'unknown',
            ),
          ),
          if (choice.isReady) ...[
            SizedBox(height: spacing.related),
            Semantics(
              liveRegion: true,
              child: Text(l10n.transcriptRefinementReady),
            ),
          ],
          if (choice.metadataInvalid || !choice.canSelect) ...[
            SizedBox(height: spacing.related),
            Text(
              choice.metadataInvalid
                  ? l10n.transcriptVersionUnverified
                  : l10n.transcriptVersionNotReady,
            ),
          ],
        ],
      ),
    );
  }
}

final class _VersionsFailure extends StatelessWidget {
  const _VersionsFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(l10n.transcriptVersionsLoadFailed),
        ),
        SizedBox(height: LoquirisSpacing.of(context).related),
        Semantics(
          button: true,
          label: l10n.retryAction,
          sortKey: const OrdinalSortKey(1),
          child: FilledButton(
            onPressed: onRetry,
            child: Text(l10n.retryAction),
          ),
        ),
      ],
    );
  }
}
