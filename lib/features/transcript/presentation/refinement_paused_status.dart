import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Explains an explicit refinement pause without exposing internal failure data.
final class RefinementPausedStatus extends StatelessWidget {
  /// Creates a recovery surface after the controller validates the run's role.
  const RefinementPausedStatus({
    required this.reasonCode,
    required this.isResuming,
    required this.onResume,
    super.key,
  });

  /// Stable reason mapped to safe localized copy, never directly displayed.
  final String reasonCode;

  /// Whether one recovery request already owns the action.
  final bool isResuming;

  /// Invokes the controller, never the engine directly.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final message = l10n.refinementPausedMessage(reasonCode);
    final action = isResuming
        ? l10n.refinementResuming
        : l10n.refinementResumeAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          sortKey: const OrdinalSortKey(0),
          label: message,
          excludeSemantics: true,
          child: Text(message),
        ),
        SizedBox(height: spacing.related),
        Semantics(
          container: true,
          button: true,
          enabled: !isResuming,
          focusable: true,
          label: action,
          sortKey: const OrdinalSortKey(1),
          excludeSemantics: true,
          onTap: isResuming ? null : onResume,
          child: FilledButton(
            key: const Key('refinement-resume'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: spacing.section,
                vertical: spacing.related,
              ),
            ),
            onPressed: isResuming ? null : onResume,
            child: Text(action),
          ),
        ),
      ],
    );
  }
}
