import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/locale_controller.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/theme/app_theme.dart';

/// Root application widget, independent of concrete infrastructure.
final class LoquirisApp extends ConsumerStatefulWidget {
  /// Creates the application widget.
  const LoquirisApp({super.key});

  @override
  ConsumerState<LoquirisApp> createState() => _LoquirisAppState();
}

final class _LoquirisAppState extends ConsumerState<LoquirisApp>
    with RootLifecycleObserver<LoquirisApp> {
  @override
  void initState() {
    super.initState();
    registerRootLifecycleObserver();
  }

  @override
  void dispose() {
    unregisterRootLifecycleObserver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      theme: buildLoquirisTheme(Brightness.light),
      darkTheme: buildLoquirisTheme(Brightness.dark),
      themeAnimationStyle: AnimationStyle.noAnimation,
    );
  }
}
