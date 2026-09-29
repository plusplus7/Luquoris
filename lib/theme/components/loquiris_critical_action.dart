import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A labelled, single-tap critical action with an explicit semantic order.
final class LoquirisCriticalAction extends StatelessWidget {
  /// Creates a critical action.
  const LoquirisCriticalAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticOrder = 0,
    super.key,
  });

  /// Localized visible and semantic label.
  final String label;

  /// Redundant non-color glyph.
  final IconData icon;

  /// Single-tap callback.
  final VoidCallback? onPressed;

  /// Authored assistive-technology traversal priority.
  final double semanticOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      sortKey: OrdinalSortKey(semanticOrder),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: ExcludeSemantics(
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
