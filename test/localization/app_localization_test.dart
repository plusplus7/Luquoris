import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/locale_controller.dart';

void main() {
  test('generated catalog supports English and simplified Chinese', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const [Locale('en'), Locale('zh')]),
    );
  });

  testWidgets('null override follows the platform locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: LoquirisApp()));
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull);
    expect(find.text('会议'), findsWidgets);
  });

  testWidgets('an in-app override replaces the platform locale', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoquirisApp(),
      ),
    );
    container.read(localeControllerProvider.notifier).useEnglish();
    await tester.pump();

    expect(find.text('Meetings'), findsWidgets);
    container.read(localeControllerProvider.notifier).useSystemLocale();
    await tester.pump();
    expect(find.text('会议'), findsWidgets);
  });
}
