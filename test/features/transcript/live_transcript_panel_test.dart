import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_panel.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('renders stable and unstable hypotheses as read-only states', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await _pumpPanel(
      tester,
      _state(
        chunks: <TranscriptChunk>[
          _chunk('stable', 'Final phrase', TranscriptStability.stable),
          _chunk('draft', 'Changing phrase', TranscriptStability.unstable),
        ],
      ),
    );

    expect(find.text('Final phrase'), findsOneWidget);
    expect(find.text('Changing phrase'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Stable. Final phrase'), findsOneWidget);
    expect(find.bySemanticsLabel('Draft. Changing phrase'), findsOneWidget);
  });

  testWidgets('announces backlog, degradation, and complete-pass fallback', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await _pumpPanel(
      tester,
      _state(
        status: LiveTranscriptStatus.degraded,
        backlog: const Duration(seconds: 7),
        incomplete: true,
        degradationReason: 'transcription_live_thermal',
      ),
    );

    expect(find.textContaining('7 seconds behind'), findsOneWidget);
    expect(find.textContaining('device is too warm'), findsOneWidget);
    expect(
      find.textContaining('complete transcript will run after recording'),
      findsWidgets,
    );
    final semantics = tester.getSemantics(
      find.byKey(const Key('live-transcript-status')),
    );
    expect(semantics, isSemantics(isLiveRegion: true));
  });

  testWidgets('fits 320 logical pixels at two hundred percent text', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await _pumpPanel(
      tester,
      _state(
        backlog: const Duration(seconds: 12),
        chunks: <TranscriptChunk>[
          _chunk(
            'stable',
            'A longer stable sentence that wraps without hiding any words.',
            TranscriptStability.stable,
          ),
          _chunk(
            'draft',
            'An unfinished sentence remains visibly marked as a draft.',
            TranscriptStability.unstable,
          ),
        ],
      ),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('live-transcript-panel'))).width,
      lessThanOrEqualTo(320),
    );
    expect(
      find.textContaining('without hiding any words'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  LiveTranscriptState state, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiveTranscriptPanel(state: state),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

LiveTranscriptState _state({
  LiveTranscriptStatus status = LiveTranscriptStatus.running,
  List<TranscriptChunk> chunks = const <TranscriptChunk>[],
  Duration backlog = Duration.zero,
  bool incomplete = false,
  String? degradationReason,
}) => LiveTranscriptState(
  status: status,
  meetingId: 'meeting-live',
  runId: 'run-live',
  chunks: chunks,
  backlog: backlog,
  incomplete: incomplete,
  degradationReason: degradationReason,
);

TranscriptChunk _chunk(
  String id,
  String text,
  TranscriptStability stability,
) => TranscriptChunk(
  segmentId: id,
  start: id == 'stable' ? Duration.zero : const Duration(seconds: 2),
  end: id == 'stable' ? const Duration(seconds: 1) : const Duration(seconds: 3),
  rawText: text,
  displayText: text,
  stability: stability,
);
