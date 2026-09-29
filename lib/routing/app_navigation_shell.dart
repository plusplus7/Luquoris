import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';

/// Adaptive navigation chrome that preserves each branch stack.
final class AppNavigationShell extends StatelessWidget {
  /// Creates the application shell.
  const AppNavigationShell({required this.navigationShell, super.key});

  /// Stateful branch navigator supplied by GoRouter.
  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sizeClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);
    final compact = sizeClass == WindowSizeClass.compact;
    final destinations = [
      _Destination(l10n.navMeetings, Icons.library_music_outlined),
      _Destination(l10n.navRecord, Icons.mic_none_rounded),
      _Destination(l10n.navSettings, Icons.tune_rounded),
    ];

    if (compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

final class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}
