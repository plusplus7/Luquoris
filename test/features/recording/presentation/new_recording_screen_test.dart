import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/new_recording_screen.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';
import '../../../support/harness.dart';

void main() {
  testWidgets('selects setup and starts immediately after native preflight', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final repository = FakeSessionRepository();
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          audioCaptureServiceProvider.overrideWithValue(capture),
          clockProvider.overrideWithValue(
            Clock.fixed(DateTime.utc(2026, 10, 1, 2, 3)),
          ),
          meetingIdFactoryProvider.overrideWithValue(() => 'meeting-fixed'),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Record').last);
    await tester.pumpAndSettle();

    expect(find.text('New recording'), findsWidgets);
    expect(
      find.byKey(const Key('new-recording-mode-near-real-time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('new-recording-language-english')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-recording-speakers-4')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('new-recording-mode-near-real-time')),
    );
    final setupScroll = find.descendant(
      of: find.byType(NewRecordingScreen),
      matching: find.byType(CustomScrollView),
    );
    final english = find.byKey(const Key('new-recording-language-english'));
    await tester.drag(setupScroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(english);
    final fourSpeakers = find.byKey(const Key('new-recording-speakers-4'));
    await tester.drag(setupScroll, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(fourSpeakers);
    final start = find.byKey(const Key('new-recording-start'));
    await tester.drag(setupScroll, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('active-recording:meeting-fixed')),
      findsOneWidget,
    );
    expect(
      repository.recordingDefaults,
      const RecordingDefaults(
        transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        languageMode: MeetingLanguageMode.english,
        expectedSpeakerCount: 4,
      ),
    );
    expect(capture.startRequests.single.sessionId, 'meeting-fixed');
  });

  testWidgets('setup remains usable at two hundred percent text scale', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp(textScaler: const TextScaler.linear(2));
    await tester.tap(find.text('Record').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('new-recording-start')), findsOneWidget);
  });

  testWidgets('TalkBack choices expose selection and tap actions', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLoquirisApp(accessibleNavigation: true);
    await tester.tap(find.text('Record').last);
    await tester.pump();
    await tester.pump();

    final mode = find.byKey(
      const Key('new-recording-mode-near-real-time'),
    );
    expect(mode, findsOneWidget);
    expect(
      tester.getSemantics(mode),
      isSemantics(
        label:
            'Near-real-time draft. Experimental. It may pause or fall back '
            'to post-session processing to protect the recording.',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('storage preflight failure shows measured and required space', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final capture = FakeAudioCaptureService()
      ..startResult = const Err(
        AudioCaptureInsufficientStorage(
          code: 'recording_storage_preflight_insufficient',
          availableBytes: 100 * 1024 * 1024,
          requiredBytes: 200 * 1024 * 1024,
        ),
      );
    addTearDown(capture.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            FakeSessionRepository(),
          ),
          audioCaptureServiceProvider.overrideWithValue(capture),
          meetingIdFactoryProvider.overrideWithValue(() => 'low-storage'),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Record').last);
    await tester.pumpAndSettle();

    final start = find.byKey(const Key('new-recording-start'));
    final setupScroll = find.descendant(
      of: find.byType(NewRecordingScreen),
      matching: find.byType(CustomScrollView),
    );
    await tester.drag(setupScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(
      find.text('100 MB available · 200 MB required'),
      findsOneWidget,
    );
  });
}
