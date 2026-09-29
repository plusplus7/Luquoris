import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('large bold text keeps the primary action operable', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp(
      textScaler: const TextScaler.linear(2),
      boldText: true,
    );
    await tester.pump();

    final action = find.bySemanticsLabel('Start a recording');
    expect(action, findsOneWidget);
    final size = tester.getSize(action);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TalkBack sees a labelled enabled recording action', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp(accessibleNavigation: true);
    await tester.pump();

    final action = find.bySemanticsLabel('Start a recording');
    final node = tester.getSemantics(action);
    expect(
      node,
      isSemantics(
        label: 'Start a recording',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('primary navigation activates the recording branch', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp();
    await tester.pump();

    await tester.tap(find.text('Record'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('new-recording')),
      findsOneWidget,
    );
  });

  testWidgets('medium width exposes the same destinations in a rail', (
    tester,
  ) async {
    tester.useDevice(TestDevice.medium);
    await tester.pumpLoquirisApp();
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in const ['Meetings', 'Record', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('landscape large text remains scrollable and operable', (
    tester,
  ) async {
    tester.useDevice(TestDevice.smallLandscape);
    await tester.pumpLoquirisApp(textScaler: const TextScaler.linear(2));
    await tester.pump();

    final action = find.bySemanticsLabel('Start a recording');
    await tester.ensureVisible(action);
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('constrained width keeps the primary action reachable', (
    tester,
  ) async {
    tester.useDevice(TestDevice.constrained);
    await tester.pumpLoquirisApp(textScaler: const TextScaler.linear(2));
    await tester.pump();

    final action = find.bySemanticsLabel('Start a recording');
    await tester.ensureVisible(action);
    expect(action, findsOneWidget);
    expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
