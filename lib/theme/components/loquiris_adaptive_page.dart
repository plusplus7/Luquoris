import 'package:flutter/material.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Shared Material window size classes based on available logical width.
enum WindowSizeClass {
  /// Width below 600.
  compact,

  /// Width from 600 through 839.
  medium,

  /// Width from 840 through 1199.
  expanded,

  /// Width from 1200 through 1599.
  large,

  /// Width at or above 1600.
  extraLarge,
}

/// Resolves the standard Material window class for [width].
WindowSizeClass windowSizeClassFor(double width) => switch (width) {
  < 600 => WindowSizeClass.compact,
  < 840 => WindowSizeClass.medium,
  < 1200 => WindowSizeClass.expanded,
  < 1600 => WindowSizeClass.large,
  _ => WindowSizeClass.extraLarge,
};

/// Full-bleed page background with safe, centered, readable content.
final class LoquirisAdaptivePage extends StatelessWidget {
  /// Creates an adaptive page around [child].
  const LoquirisAdaptivePage({required this.child, super.key});

  /// Stable test hook for the readable content region.
  static const contentKey = Key('loquiris-adaptive-content');

  /// Page content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = LoquirisSpacing.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            key: contentKey,
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.page),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
