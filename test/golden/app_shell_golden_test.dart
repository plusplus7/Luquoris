@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/routing/app_navigation_shell.dart';

import '../support/harness.dart';

void main() {
  testWidgets('empty meeting library phone portrait light', (tester) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp();
    await tester.pump();

    await expectLater(
      find.byType(AppNavigationShell),
      matchesGoldenFile('goldens/app_shell_empty_light.png'),
    );
  });

  testWidgets('empty meeting library phone portrait dark', (tester) async {
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.view.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp();
    await tester.pump();

    await expectLater(
      find.byType(AppNavigationShell),
      matchesGoldenFile('goldens/app_shell_empty_dark.png'),
    );
  });
}
