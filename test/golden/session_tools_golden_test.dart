@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/routing/app_navigation_shell.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';
import '../support/harness.dart';

void main() {
  testWidgets('populated meeting library phone portrait light', (tester) async {
    tester.useDevice(TestDevice.compact);
    await _pumpApp(tester, _repository());
    await tester.pump();

    await expectLater(
      find.byType(AppNavigationShell),
      matchesGoldenFile('goldens/session_library_populated_light.png'),
    );
  });

  testWidgets('populated meeting library phone portrait dark', (tester) async {
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.view.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    tester.useDevice(TestDevice.compact);
    await _pumpApp(tester, _repository());
    await tester.pump();

    await expectLater(
      find.byType(AppNavigationShell),
      matchesGoldenFile('goldens/session_library_populated_dark.png'),
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  FakeSessionRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioCaptureServiceProvider.overrideWithValue(
          FakeAudioCaptureService(),
        ),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const LoquirisApp(),
    ),
  );
  await tester.pump();
}

FakeSessionRepository _repository() => FakeSessionRepository()
  ..activeLibraryPage = SessionLibraryPage(
    items: [
      SessionLibraryItem(
        meeting: Meeting(
          id: 'meeting-1',
          title: 'Bilingual planning',
          createdAtUtcMs: DateTime.utc(2026, 10, 1, 12).millisecondsSinceEpoch,
          mediaDuration: const Duration(minutes: 42, seconds: 18),
          lifecycle: MeetingLifecycle.finalized,
          languageMode: MeetingLanguageMode.mixed,
        ),
        committedAudioBytes: 20 * 1024 * 1024,
      ),
      SessionLibraryItem(
        meeting: Meeting(
          id: 'meeting-2',
          title: 'Interrupted interview',
          createdAtUtcMs: DateTime.utc(2026, 10, 1, 13).millisecondsSinceEpoch,
          mediaDuration: const Duration(minutes: 8, seconds: 5),
          lifecycle: MeetingLifecycle.recoverable,
          languageMode: MeetingLanguageMode.english,
        ),
        committedAudioBytes: 4 * 1024 * 1024,
      ),
    ],
    nextCursor: null,
  );
