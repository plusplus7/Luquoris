import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/new_recording_screen.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';
import '../../../support/harness.dart';

void main() {
  testWidgets('microphone denial explains how to grant access', (tester) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..startResult = const Err(
        AudioCaptureUnavailable('recording_permission_denied'),
      );
    addTearDown(capture.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            FakeSessionRepository(),
          ),
          audioCaptureServiceProvider.overrideWithValue(capture),
          meetingIdFactoryProvider.overrideWithValue(
            () => 'permission-denied',
          ),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Record').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final setupScroll = find.descendant(
      of: find.byType(NewRecordingScreen),
      matching: find.byType(CustomScrollView),
    );
    await tester.drag(setupScroll, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('new-recording-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'Microphone access is required to record. If Android does not show '
        'the permission prompt again, enable Microphone for Loquiris in '
        'Settings.',
      ),
      findsOneWidget,
    );
  });
}
