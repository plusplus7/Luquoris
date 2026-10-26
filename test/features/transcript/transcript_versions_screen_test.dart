import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_choices_controller.dart';
import 'package:loquiris/features/transcript/presentation/transcript_versions_screen.dart';

import '../../support/harness.dart';

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('ready refinement is explicit, accessible and wraps at $scale', (
      tester,
    ) async {
      tester.useDevice(TestDevice.compact);
      var selected = false;
      await tester.pumpLocalizedContent(
        TranscriptVersionCard(
          choice: _choice(),
          isSelecting: false,
          selectionBlocked: false,
          onSelect: () => selected = true,
        ),
        textScaler: TextScaler.linear(scale),
      );
      expect(find.textContaining('Refined transcript'), findsWidgets);
      expect(
        find.text(
          'A refined version is available. It will not replace your current transcript automatically.',
        ),
        findsOneWidget,
      );
      expect(find.text('Complete coverage'), findsOneWidget);
      expect(find.textContaining('private-diagnostic'), findsNothing);
      final button = find.byKey(const Key('use-transcript-version:refined'));
      await tester.ensureVisible(button);
      await tester.pump();
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(button);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(button);
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Chinese pending selection stays disabled without claiming current',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      var selected = false;
      await tester.pumpLocalizedContent(
        TranscriptVersionCard(
          choice: _choice(),
          isSelecting: true,
          selectionBlocked: true,
          onSelect: () => selected = true,
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('正在切换…'), findsOneWidget);
      expect(find.text('当前版本'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('use-transcript-version:refined')),
      );
      expect(button.onPressed, isNull);
      expect(selected, isFalse);
    },
  );

  testWidgets('incomplete live coverage and invalid metadata are explicit', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpLocalizedContent(
      TranscriptVersionCard(
        choice: _choice(
          role: TranscriptProcessingRole.liveDraft,
          completeness: TranscriptCompleteness.incomplete,
        ),
        isSelecting: false,
        selectionBlocked: false,
        onSelect: () {},
      ),
    );
    expect(find.textContaining('Live draft'), findsWidgets);
    expect(find.text('Incomplete coverage'), findsOneWidget);
    await tester.pumpLocalizedContent(
      TranscriptVersionCard(
        choice: _choice(invalid: true),
        isSelecting: false,
        selectionBlocked: false,
        onSelect: () {},
      ),
    );
    expect(
      find.text(
        'Version provenance could not be verified. Selection is unavailable.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('use-transcript-version:refined')),
    );
    expect(button.onPressed, isNull);
  });
}

TranscriptVersionChoice _choice({
  TranscriptProcessingRole role = TranscriptProcessingRole.refinement,
  TranscriptCompleteness completeness = TranscriptCompleteness.complete,
  bool invalid = false,
}) => TranscriptVersionChoice(
  run: const TranscriptRun(
    id: 'refined',
    meetingId: 'meeting',
    createdAtUtcMs: 1792022400000,
    provenance: InferenceProvenance(
      engineId: 'local-engine',
      engineVersion: '1.0',
      modelId: 'local-model',
      modelVersion: 'frozen-version',
      modelSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      parametersJson: '{}',
    ),
    state: AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2),
  ),
  isCurrent: false,
  metadataInvalid: invalid,
  processing: TranscriptProcessingInfo(
    role: role,
    completeness: completeness,
    bundleManifestJson: 'private-diagnostic',
  ),
);
