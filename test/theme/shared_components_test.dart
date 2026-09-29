import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/theme/app_theme.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/components/loquiris_critical_action.dart';

void main() {
  test('window size classes use the shared Material breakpoints', () {
    expect(windowSizeClassFor(599), WindowSizeClass.compact);
    expect(windowSizeClassFor(600), WindowSizeClass.medium);
    expect(windowSizeClassFor(839), WindowSizeClass.medium);
    expect(windowSizeClassFor(840), WindowSizeClass.expanded);
    expect(windowSizeClassFor(1200), WindowSizeClass.large);
    expect(windowSizeClassFor(1600), WindowSizeClass.extraLarge);
  });

  testWidgets('critical action has a labelled 48dp minimum target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLoquirisTheme(Brightness.light),
        home: Scaffold(
          body: LoquirisCriticalAction(
            label: 'Stop recording',
            icon: Icons.stop_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(LoquirisCriticalAction));
    final semantics = tester.getSemantics(find.byType(LoquirisCriticalAction));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(semantics.label, 'Stop recording');
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('adaptive page caps readable content on a large window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLoquirisTheme(Brightness.light),
        home: const LoquirisAdaptivePage(
          child: ColoredBox(color: Colors.transparent),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(LoquirisAdaptivePage.contentKey)).width,
      lessThanOrEqualTo(720),
    );
    expect(tester.takeException(), isNull);
  });
}
