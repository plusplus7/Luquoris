import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_panel.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';
import '../support/harness.dart';

void main() {
  testWidgets('trash remains readable at 200 percent text on compact height', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(
            FakeAudioCaptureService(),
          ),
          sessionRepositoryProvider.overrideWithValue(
            FakeSessionRepository(),
          ),
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              boldText: true,
              accessibleNavigation: true,
            ),
            child: const LoquirisApp(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Trash'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(
      find.textContaining('Nothing is deleted automatically'),
      findsOneWidget,
    );
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('live draft exposes stable state and fallback as semantics', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            boldText: true,
            accessibleNavigation: true,
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LiveTranscriptPanel(
                  state: LiveTranscriptState(
                    status: LiveTranscriptStatus.degraded,
                    meetingId: 'meeting-live',
                    runId: 'run-live',
                    chunks: const <TranscriptChunk>[
                      TranscriptChunk(
                        segmentId: 'stable',
                        start: Duration.zero,
                        end: Duration(seconds: 1),
                        rawText: 'Final phrase',
                        displayText: 'Final phrase',
                        stability: TranscriptStability.stable,
                      ),
                    ],
                    incomplete: true,
                    degradationReason: 'transcription_live_thermal',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Stable. Final phrase'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('live-transcript-status'))),
      isSemantics(isLiveRegion: true),
    );
  });
}
