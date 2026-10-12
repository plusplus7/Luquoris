import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/locale_controller.dart';
import 'package:loquiris/l10n/meeting_formatting.dart';

void main() {
  test('generated catalog supports English and simplified Chinese', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const [Locale('en'), Locale('zh')]),
    );
  });

  test('restored-copy title marker is localized', () {
    expect(
      lookupAppLocalizations(const Locale('en')).restoredCopyTitle('Review'),
      'Review — Restored copy',
    );
    expect(
      lookupAppLocalizations(const Locale('zh')).restoredCopyTitle('复盘'),
      '复盘 — 恢复的副本',
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

  testWidgets('meeting default title uses the active locale date and time', (
    tester,
  ) async {
    late String title;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            title = localizedMeetingDefaultTitle(
              context,
              DateTime(2026, 10, 1, 9, 5),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(title, 'Meeting Thursday, October 1, 2026 9:05 AM');
  });
}
