import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/transcript/presentation/refinement_paused_status.dart';

import '../../support/harness.dart';

void main() {
  const reasons = {
    'refinement_thermal_severe':
        'Refinement is paused while this device cools down. Your recording is safe.',
    'refinement_battery_low':
        'Refinement is paused because the battery is low. Charge this device before resuming.',
    'refinement_memory_pressure':
        'Refinement is paused because memory is low. Close other apps before resuming.',
    'refinement_power_save':
        'Refinement is paused while battery saver is on. Turn it off before resuming.',
    'refinement_recording_active':
        'Refinement is paused to prioritize recording. Resume after recording stops.',
    'refinement_resources_unavailable':
        'Refinement is paused because device resources could not be checked. Try resuming later.',
    'SECRET /private/path':
        'Refinement is paused. Your recording is safe. You can try resuming later.',
  };
  for (final entry in reasons.entries) {
    testWidgets('safe pause explanation for ${entry.key}', (tester) async {
      await tester.pumpLocalizedContent(
        RefinementPausedStatus(
          reasonCode: entry.key,
          isResuming: false,
          onResume: () {},
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(
        tester.getSemantics(find.text(entry.value)),
        isSemantics(
          label: entry.value,
          isLiveRegion: true,
        ),
      );
    });
  }
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('resume remains labelled and fits 320dp at scale $scale', (
      tester,
    ) async {
      tester.useDevice(TestDevice.compact);
      var resumed = false;
      await tester.pumpLocalizedContent(
        RefinementPausedStatus(
          reasonCode: 'refinement_battery_low',
          isResuming: false,
          onResume: () => resumed = true,
        ),
        textScaler: TextScaler.linear(scale),
      );
      final button = find.bySemanticsLabel('Resume refinement');
      expect(
        tester.getSemantics(button),
        isSemantics(
          label: 'Resume refinement',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      final target = tester.getRect(button);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.right, lessThanOrEqualTo(320));
      final label = tester.getRect(find.text('Resume refinement'));
      expect(target.contains(label.topLeft), isTrue);
      expect(target.contains(label.bottomRight), isTrue);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      expect(resumed, isTrue);
    });
  }
  testWidgets('pending recovery disables repeated activation in Chinese', (
    tester,
  ) async {
    var resumed = false;
    await tester.pumpLocalizedContent(
      RefinementPausedStatus(
        reasonCode: 'refinement_battery_low',
        isResuming: true,
        onResume: () => resumed = true,
      ),
      locale: const Locale('zh'),
    );
    expect(find.text('电量过低，精修已暂停。请充电后再恢复。'), findsOneWidget);
    final button = find.bySemanticsLabel('正在恢复精修…');
    expect(
      tester.getSemantics(button),
      isSemantics(
        label: '正在恢复精修…',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        isFocusable: true,
      ),
    );
    await tester.tap(button);
    expect(resumed, isFalse);
  });
}
