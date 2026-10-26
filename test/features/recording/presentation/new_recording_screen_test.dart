import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';
import '../../../support/harness.dart';
import '../../../support/recording_processing_fixture.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('explicit choices remain usable in $locale at $scale', (
        tester,
      ) async {
        tester.useDevice(TestDevice.compact);
        tester.binding.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        await tester.pumpLoquirisApp(textScaler: TextScaler.linear(scale));
        await tester.tap(find.text(locale == 'zh' ? '录音' : 'Record').last);
        await tester.pumpAndSettle();

        final unavailable = find.byKey(
          const Key('new-recording-mode-two-pass'),
        );
        await tester.ensureVisible(unavailable);
        await tester.pumpAndSettle();
        final disabled = tester.getSemantics(unavailable);
        expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
        expect(
          disabled.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(
          (disabled.sortKey! as OrdinalSortKey).order,
          1,
        );
        final recordOnly = find.byKey(
          const Key('new-recording-mode-recording-only'),
        );
        await tester.ensureVisible(recordOnly);
        await tester.pumpAndSettle();
        expect(tester.getSize(recordOnly).height, greaterThanOrEqualTo(48));
        await tester.tapAt(
          tester.getTopLeft(recordOnly) + const Offset(32, 32),
        );
        await tester.pump();
        expect(
          tester.getSemantics(recordOnly).flagsCollection.isSelected,
          Tristate.isTrue,
        );
        final container = ProviderScope.containerOf(tester.element(recordOnly));
        expect(
          container
              .read(newRecordingControllerProvider)
              .requireValue
              .processingMode,
          MeetingProcessingMode.recordingOnly,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

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
          ...recordingProcessingOverrides(),
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
      find.byKey(const Key('new-recording-mode-recording-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('new-recording-language-english')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-recording-speakers-4')), findsOneWidget);

    final captureOnly = find.byKey(
      const Key('new-recording-mode-recording-only'),
    );
    await tester.ensureVisible(captureOnly);
    await tester.pumpAndSettle();
    await tester.tap(captureOnly);
    final english = find.byKey(const Key('new-recording-language-english'));
    await tester.ensureVisible(english);
    await tester.pumpAndSettle();
    await tester.tap(english);
    final fourSpeakers = find.byKey(const Key('new-recording-speakers-4'));
    await tester.ensureVisible(fourSpeakers);
    await tester.pumpAndSettle();
    await tester.tap(fourSpeakers);
    final start = find.byKey(const Key('new-recording-start'));
    await tester.ensureVisible(start);
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
      const Key('new-recording-mode-two-pass'),
    );
    expect(mode, findsOneWidget);
    expect(
      tester.getSemantics(mode),
      isSemantics(
        label: 'Live draft + refinement',
        hint:
            'Unavailable until a streaming model pair passes the required checks. '
            'Choose post-session transcription or recording only.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: false,
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
          ...recordingProcessingOverrides(),
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
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(
      find.text('100 MB available · 200 MB required'),
      findsOneWidget,
    );
  });
}
