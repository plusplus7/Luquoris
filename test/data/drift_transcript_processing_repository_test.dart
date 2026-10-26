import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_transcript_processing_repository.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/transcript_editor_controller.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_choices_controller.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_readiness_notice.dart';
import 'package:loquiris/features/transcript/presentation/transcript_versions_screen.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

import '../support/harness.dart';
import '../support/model_bundle_fixture.dart';

void main() {
  late db.AppDatabase database;
  late DriftTranscriptProcessingRepository processing;
  late DriftTranscriptionJobRepository jobs;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    processing = DriftTranscriptProcessingRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    jobs = DriftTranscriptionJobRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _seed(database);
  });
  tearDown(() => database.close());

  testWidgets(
    'version readiness notice and real button preserve explicit selection',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      await tester.runAsync(() async {
        _ok(
          await processing.enqueueRefinement(
            _job(),
            _run('refined'),
            _info(refinement: true),
            storedAtUtcMs: 3,
          ),
        );
        _ok(await processing.startRefinement('job', startedAtUtcMs: 4));
        _ok(
          await jobs.complete(
            'job',
            _run('refined').copyWith(
              state: const AnalysisCompleted(
                startedAtUtcMs: 4,
                endedAtUtcMs: 5,
              ),
            ),
            [_segment('refined')],
            storedAtUtcMs: 5,
          ),
        );
      });
      final container = ProviderContainer(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
        ],
      );
      addTearDown(container.dispose);
      var opened = false;
      await tester.pumpLocalizedContent(
        UncontrolledProviderScope(
          container: container,
          child: TranscriptVersionReadinessNotice(
            meetingId: 'meeting',
            onOpenVersions: () => opened = true,
          ),
        ),
      );
      for (
        var index = 0;
        index < 30 &&
            find
                .byKey(const Key('transcript-refinement-ready'))
                .evaluate()
                .isEmpty;
        index++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(
        find.byKey(const Key('transcript-refinement-ready')),
        findsOneWidget,
      );
      await tester.tap(find.text('Transcript versions'));
      expect(opened, isTrue);
      expect(
        await tester.runAsync(
          () => database.select(database.meetingTranscriptSelections).get(),
        ),
        isEmpty,
      );
      await tester.pumpLocalizedContent(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(
            height: 580,
            child: TranscriptVersionsScreen(meetingId: 'meeting'),
          ),
        ),
      );
      for (
        var index = 0;
        index < 30 &&
            find
                .byKey(const Key('use-transcript-version:refined'))
                .evaluate()
                .isEmpty;
        index++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      final button = find.byKey(const Key('use-transcript-version:refined'));
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      for (
        var index = 0;
        index < 30 && find.text('Current version').evaluate().isEmpty;
        index++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(find.text('Current version'), findsOneWidget);
      final selected = await tester.runAsync(
        () => database.select(database.meetingTranscriptSelections).getSingle(),
      );
      expect(selected?.transcriptRunId, 'refined');
      expect(
        find.text(
          'A refined version is available. It will not replace your current transcript automatically.',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'version choices announce refinement readiness without selecting it',
    () async {
      _ok(
        await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true, source: 'draft'),
          storedAtUtcMs: 3,
        ),
      );
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
        ],
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      expect(
        initial.choices
            .singleWhere((choice) => choice.run.id == 'draft')
            .canSelect,
        isTrue,
      );
      expect(
        initial.choices
            .singleWhere((choice) => choice.run.id == 'refined')
            .canSelect,
        isFalse,
      );
      expect(initial.choices.any((choice) => choice.isReady), isFalse);
      _ok(await processing.startRefinement('job', startedAtUtcMs: 4));
      _ok(
        await jobs.complete(
          'job',
          _run('refined').copyWith(
            state: const AnalysisCompleted(startedAtUtcMs: 4, endedAtUtcMs: 5),
          ),
          [_segment('refined')],
          storedAtUtcMs: 5,
        ),
      );
      final ready = await _waitForChoices(
        container,
        (state) => state.choices.any((choice) => choice.isReady),
      );
      final refined = ready.choices.singleWhere(
        (choice) => choice.run.id == 'refined',
      );
      expect(refined.processing?.role, TranscriptProcessingRole.refinement);
      expect(refined.processing?.completeness, TranscriptCompleteness.complete);
      expect(refined.isCurrent, isFalse);
      expect(
        await database.select(database.meetingTranscriptSelections).get(),
        isEmpty,
      );
    },
  );

  test(
    'explicit version switch preserves source corrections and raw results',
    () async {
      _ok(
        await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      _ok(
        await transcripts.selectCurrent('meeting', 'draft', selectedAtUtcMs: 3),
      );
      final revisions = DriftRevisionRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      _ok(
        await revisions.apply(
          const Revision(
            id: 'human-correction',
            meetingId: 'meeting',
            targetId: 'draft-segment',
            change: TranscriptTextChange(
              previousText: '  刘国梁 ONNX\n',
              revisedText: '人工校正 API',
            ),
            createdAtUtcMs: 4,
          ),
        ),
      );
      _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true, source: 'draft'),
          storedAtUtcMs: 4,
        ),
      );
      _ok(await processing.startRefinement('job', startedAtUtcMs: 4));
      _ok(
        await jobs.complete(
          'job',
          _run('refined').copyWith(
            state: const AnalysisCompleted(startedAtUtcMs: 4, endedAtUtcMs: 5),
          ),
          [_segment('refined')],
          storedAtUtcMs: 5,
        ),
      );
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
          clockProvider.overrideWithValue(
            Clock.fixed(DateTime.utc(2026, 10, 15)),
          ),
        ],
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      container.read(provider.notifier).select('refined');
      await _waitForChoices(
        container,
        (state) =>
            state.selectingRunId == null &&
            state.choices.any(
              (choice) => choice.run.id == 'refined' && choice.isCurrent,
            ),
      );
      expect(
        _ok(await transcripts.loadEditor('meeting')).currentVersion?.run.id,
        'refined',
      );
      container.read(provider.notifier).select('draft');
      await _waitForChoices(
        container,
        (state) =>
            state.selectingRunId == null &&
            state.choices.any(
              (choice) => choice.run.id == 'draft' && choice.isCurrent,
            ),
      );
      final restored = _ok(await transcripts.loadEditor('meeting'));
      expect(
        restored.currentVersion?.segments.single.displayedText,
        '人工校正 API',
      );
      expect(
        restored.currentVersion?.segments.single.rawModelText,
        '  刘国梁 ONNX\n',
      );
      expect(restored.revisions.single.id, 'human-correction');
      final all = _ok(await transcripts.listVersions('meeting'));
      expect(
        all
            .singleWhere((version) => version.run.id == 'refined')
            .segments
            .single
            .rawModelText,
        '  刘国梁 ONNX\n',
      );
      expect(
        (await database
                .select(database.meetingTranscriptSelections)
                .getSingle())
            .updatedAt,
        DateTime.utc(2026, 10, 15).millisecondsSinceEpoch,
      );
    },
  );

  test(
    'version selection failure retains the durable current version',
    () async {
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      for (final id in ['draft', 'other']) {
        _ok(
          await processing.saveLiveVersion(
            _run(id, completed: true),
            [_segment(id)],
            _info(),
            storedAtUtcMs: 3,
          ),
        );
      }
      _ok(
        await transcripts.selectCurrent('meeting', 'draft', selectedAtUtcMs: 3),
      );
      await database.customStatement('''
      CREATE TRIGGER reject_selection BEFORE UPDATE ON meeting_transcript_selections
      BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
        ],
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final controller = container.read(provider.notifier)..select('other');
      expect(container.read(provider).value?.selectingRunId, 'other');
      expect(
        container
            .read(provider)
            .value
            ?.choices
            .singleWhere((choice) => choice.isCurrent)
            .run
            .id,
        'draft',
      );
      controller.select('draft');
      final failed = await _waitForChoices(
        container,
        (state) => state.selectionFailed && state.selectingRunId == null,
      );
      expect(
        failed.choices.singleWhere((choice) => choice.isCurrent).run.id,
        'draft',
      );
      expect(
        (await database
                .select(database.meetingTranscriptSelections)
                .getSingle())
            .transcriptRunId,
        'draft',
      );
    },
  );

  test('unclosed and invalid-provenance versions cannot be selected', () async {
    final transcripts = DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    _ok(
      await processing.saveLiveVersion(
        _run('draft', completed: true),
        [_segment('draft')],
        _info(),
        storedAtUtcMs: 3,
      ),
    );
    _ok(
      await processing.enqueueRefinement(
        _job(),
        _run('refined'),
        _info(refinement: true),
        storedAtUtcMs: 3,
      ),
    );
    await database.customStatement(
      '''UPDATE transcript_processing_metadata SET bundle_manifest_json = '{"schemaVersion":2}' WHERE transcript_run_id = 'draft' ''',
    );
    final container = ProviderContainer.test(
      overrides: [
        transcriptRepositoryProvider.overrideWithValue(transcripts),
        transcriptProcessingRepositoryProvider.overrideWithValue(processing),
      ],
    );
    final provider = transcriptVersionChoicesControllerProvider('meeting');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    expect(
      initial.choices
          .singleWhere((choice) => choice.run.id == 'draft')
          .metadataInvalid,
      isTrue,
    );
    expect(initial.choices.every((choice) => !choice.canSelect), isTrue);
    container.read(provider.notifier).select('draft');
    container.read(provider.notifier).select('refined');
    container.read(provider.notifier).select('foreign-run');
    expect(container.read(provider).value?.selectingRunId, isNull);
    expect(
      await database.select(database.meetingTranscriptSelections).get(),
      isEmpty,
    );
  });

  test(
    'legacy and failed live versions retain distinct safe presentation',
    () async {
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      _ok(
        await transcripts.saveVersion(_run('legacy', completed: true), [
          _segment('legacy'),
        ], storedAtUtcMs: 3),
      );
      _ok(
        await processing.saveLiveVersion(
          _run('draft').copyWith(
            state: const AnalysisFailed(
              startedAtUtcMs: 1,
              endedAtUtcMs: 2,
              progress: 0.5,
              failureCode: 'live_failed',
            ),
          ),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
        ],
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final legacy = initial.choices.singleWhere(
        (choice) => choice.run.id == 'legacy',
      );
      expect(legacy.processing, isNull);
      expect(legacy.isReady, isFalse);
      expect(legacy.canSelect, isTrue);
      final draft = initial.choices.singleWhere(
        (choice) => choice.run.id == 'draft',
      );
      expect(draft.processing?.completeness, TranscriptCompleteness.incomplete);
      expect(draft.canSelect, isTrue);
      container.read(provider.notifier).select('draft');
      await _waitForChoices(
        container,
        (state) => state.choices.any(
          (choice) => choice.isCurrent && choice.run.id == 'draft',
        ),
      );
      expect(_ok(await transcripts.loadEditor('meeting')).canEdit, isFalse);
    },
  );

  test(
    'selection completes and refreshes an existing editor after choices close',
    () async {
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      for (final id in ['draft', 'other']) {
        _ok(
          await processing.saveLiveVersion(
            _run(id, completed: true),
            [_segment(id)],
            _info(),
            storedAtUtcMs: 3,
          ),
        );
      }
      _ok(
        await transcripts.selectCurrent('meeting', 'draft', selectedAtUtcMs: 3),
      );
      final gated = _GatedTranscriptRepository(transcripts);
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(gated),
          transcriptProcessingRepositoryProvider.overrideWithValue(processing),
          transcriptionJobRepositoryProvider.overrideWithValue(jobs),
        ],
      );
      final editor = transcriptEditorControllerProvider('meeting');
      final editorSubscription = container.listen(editor, (_, _) {});
      addTearDown(editorSubscription.close);
      expect(
        (await container.read(editor.future)).document.currentVersion?.run.id,
        'draft',
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final choicesSubscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      container.read(provider.notifier).select('other');
      await gated.entered.future;
      choicesSubscription.close();
      await container.pump();
      gated.release.complete();
      await gated.finished.future;
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(
        (await container.read(editor.future)).document.currentVersion?.run.id,
        'other',
      );
      expect(
        (await database
                .select(database.meetingTranscriptSelections)
                .getSingle())
            .transcriptRunId,
        'other',
      );
    },
  );

  for (final mutation in [
    'snapshot',
    'deletedMetadata',
    'missingMetadata',
    'runReset',
    'recording',
  ]) {
    test('selection atomically rejects $mutation after UI validation', () async {
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      for (final id in ['draft', 'other']) {
        _ok(
          await processing.saveLiveVersion(
            _run(id, completed: true),
            [_segment(id)],
            _info(),
            storedAtUtcMs: 3,
          ),
        );
      }
      _ok(
        await transcripts.selectCurrent('meeting', 'draft', selectedAtUtcMs: 3),
      );
      final mutating = _ProcessingReadMutation(processing, () async {
        await database.customStatement(switch (mutation) {
          'snapshot' =>
            '''UPDATE transcript_processing_metadata SET bundle_manifest_json = '{"schemaVersion":2}' WHERE transcript_run_id = 'other' ''',
          'deletedMetadata' =>
            "UPDATE transcript_processing_metadata SET is_deleted=1, deleted_at=4 WHERE transcript_run_id='other'",
          'missingMetadata' =>
            "DELETE FROM transcript_processing_metadata WHERE transcript_run_id='other'",
          'runReset' =>
            "UPDATE transcript_runs SET run_state='queued',started_at_utc_ms=NULL,ended_at_utc_ms=NULL,progress=NULL WHERE id='other'",
          'recording' =>
            "UPDATE meetings SET lifecycle='recording' WHERE id='meeting'",
          _ => throw StateError('invalid test mutation'),
        });
      });
      final container = ProviderContainer.test(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(transcripts),
          transcriptProcessingRepositoryProvider.overrideWithValue(mutating),
        ],
      );
      final provider = transcriptVersionChoicesControllerProvider('meeting');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      mutating.mutateNextLoad = true;
      container.read(provider.notifier).select('other');
      final settled = await _waitForChoices(
        container,
        (state) => state.selectingRunId == null,
      );
      expect(settled.selectionFailed, isTrue);
      expect(
        (await database
                .select(database.meetingTranscriptSelections)
                .getSingle())
            .transcriptRunId,
        'draft',
      );
    });
  }

  test('verified catalog alias retains the original frozen snapshot', () async {
    await database.transaction(() async {
      await database.customStatement('PRAGMA defer_foreign_keys = ON');
      await database.customStatement(
        "UPDATE model_manifests SET id = 'restored-catalog'",
      );
      for (final table in ['model_capability_entries', 'model_mode_entries']) {
        await database.customStatement(
          "UPDATE $table SET model_id = 'restored-catalog'",
        );
      }
    });
    final snapshot = jsonEncode(modelBundleFixture());
    final info = _info(refinement: true, snapshot: snapshot);
    _ok(
      await processing.enqueueRefinement(
        _job(modelId: 'restored-catalog'),
        _run('refined', modelId: 'restored-catalog'),
        info,
        storedAtUtcMs: 3,
      ),
    );
    expect(_ok(await processing.load('refined')), info);
    expect(
      _ok(await jobs.loadRun('refined')).provenance.modelId,
      'restored-catalog',
    );
    _ok(
      await processing.saveLiveVersion(
        _run('draft', completed: true, modelId: 'restored-catalog'),
        [_segment('draft')],
        _info(snapshot: snapshot),
        storedAtUtcMs: 3,
      ),
    );
  });

  test(
    'matching hash does not authorize conflicting catalog metadata',
    () async {
      final changes = <String, Object>{
        'source': 'https://different.test/model',
        'license_id': 'different',
        'license_snapshot_path': 'models/licenses/different.txt',
        'bytes': 999,
      };
      for (final change in changes.entries) {
        final before = await database
            .customSelect(
              'SELECT ${change.key} AS value FROM model_manifests',
            )
            .getSingle();
        await database.customStatement(
          'UPDATE model_manifests SET ${change.key} = ?',
          [change.value],
        );
        expect(
          await processing.enqueueRefinement(
            _job(),
            _run('refined'),
            _info(refinement: true),
            storedAtUtcMs: 3,
          ),
          isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
          reason: change.key,
        );
        expect(await database.select(database.transcriptRuns).get(), isEmpty);
        await database.customStatement(
          'UPDATE model_manifests SET ${change.key} = ?',
          [before.data['value']],
        );
      }
    },
  );

  test(
    'missing catalog capability or mode prevents new paired writes',
    () async {
      for (final table in ['model_capability_entries', 'model_mode_entries']) {
        await database.customStatement(
          'UPDATE $table SET is_deleted = 1, deleted_at = 2',
        );
        expect(
          await processing.saveLiveVersion(
            _run('draft', completed: true),
            [_segment('draft')],
            _info(),
            storedAtUtcMs: 3,
          ),
          isA<Err<TranscriptVersion, AnalysisRepositoryFailure>>(),
          reason: table,
        );
        expect(await database.select(database.transcriptRuns).get(), isEmpty);
        await database.customStatement(
          'UPDATE $table SET is_deleted = 0, deleted_at = NULL',
        );
      }
    },
  );

  test(
    'live version and complete provenance commit together without selecting',
    () async {
      final info = _info();
      final result = await processing.saveLiveVersion(
        _run('draft', completed: true),
        [_segment('draft')],
        info,
        storedAtUtcMs: 3,
      );
      final version = _ok(result);
      expect(version.isCurrent, isFalse);
      expect(version.segments.single.rawModelText, '  刘国梁 ONNX\n');
      expect(_ok(await processing.load('draft')), info);
      expect(
        await database.select(database.meetingTranscriptSelections).get(),
        isEmpty,
      );
      expect(
        await database.select(database.transcriptProcessingMetadata).get(),
        hasLength(1),
      );
      expect(
        await processing.load('legacy-or-missing'),
        isA<Ok<TranscriptProcessingInfo?, AnalysisRepositoryFailure>>(),
      );
      expect(_ok(await processing.load('legacy-or-missing')), isNull);
    },
  );

  test(
    'invalid bundle or mismatching runtime leaves no partial live run',
    () async {
      final snapshots = <String>['not json', '{"schemaVersion":2}'];
      for (final field in ['engineVersion', 'engineId']) {
        final bundle = modelBundleFixture();
        (bundle['runtime']! as Map<String, Object?>)[field] = 'different';
        snapshots.add(jsonEncode(bundle));
      }
      final bundle = modelBundleFixture()..['version'] = 'different-version';
      snapshots.add(jsonEncode(bundle));
      for (final snapshot in snapshots) {
        final result = await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(snapshot: snapshot),
          storedAtUtcMs: 3,
        );
        expect(
          result,
          isA<Err<TranscriptVersion, AnalysisRepositoryFailure>>(),
        );
        expect(await database.select(database.transcriptRuns).get(), isEmpty);
        expect(
          await database.select(database.transcriptSegments).get(),
          isEmpty,
        );
        expect(
          await database.select(database.transcriptProcessingMetadata).get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'overlapping stable live segments are rejected before persistence',
    () async {
      final result = await processing.saveLiveVersion(
        _run('draft', completed: true),
        [
          _segment('draft'),
          const TranscriptSegment(
            id: 'overlap',
            transcriptRunId: 'draft',
            start: Duration.zero,
            end: Duration(seconds: 2),
            rawModelText: 'overlap',
            displayedText: 'overlap',
            revisionState: TranscriptRevisionState.machine,
          ),
        ],
        _info(),
        storedAtUtcMs: 3,
      );
      expect(result, isA<Err<TranscriptVersion, AnalysisRepositoryFailure>>());
      expect(await database.select(database.transcriptRuns).get(), isEmpty);
    },
  );

  test(
    'refinement job records only a same-meeting live source and deduplicates',
    () async {
      _ok(
        await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      final info = _info(refinement: true, source: 'draft');
      final first = _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          info,
          storedAtUtcMs: 4,
        ),
      );
      final repeat = _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          info,
          storedAtUtcMs: 5,
        ),
      );
      expect(first, repeat);
      expect(_ok(await processing.load('refined')), info);
      expect(
        await database.select(database.processingJobs).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.transcriptRuns).get(),
        hasLength(2),
      );
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true, source: 'draft', audioHash: 'b' * 64),
          storedAtUtcMs: 6,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(_ok(await processing.load('refined')), info);
    },
  );

  test(
    'source-less refinement remains representable after live never started',
    () async {
      final info = _info(refinement: true);
      _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          info,
          storedAtUtcMs: 3,
        ),
      );
      expect(_ok(await processing.load('refined'))!.sourceRunId, isNull);
    },
  );

  test(
    'invalid source provenance is rejected before new refinement writes',
    () async {
      _ok(
        await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      await database.customStatement(
        'UPDATE transcript_processing_metadata SET bundle_manifest_json = ? WHERE transcript_run_id = ?',
        ['{"schemaVersion":2}', 'draft'],
      );
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true, source: 'draft'),
          storedAtUtcMs: 4,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(await database.select(database.processingJobs).get(), isEmpty);
    },
  );

  test(
    'draft from another meeting cannot be linked as refinement source',
    () async {
      await database
          .into(database.meetings)
          .insert(
            db.MeetingsCompanion.insert(
              id: 'other',
              createdAt: 1,
              updatedAt: 1,
              title: 'other',
              lifecycle: 'finalized',
              languageMode: 'mixed',
            ),
          );
      _ok(
        await processing.saveLiveVersion(
          _run('foreign-draft', completed: true, meetingId: 'other'),
          [_segment('foreign-draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
      );
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true, source: 'foreign-draft'),
          storedAtUtcMs: 4,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(await database.select(database.processingJobs).get(), isEmpty);
    },
  );

  test(
    'legacy and refinement runs cannot be relabeled as a source draft',
    () async {
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      _ok(
        await transcripts.saveVersion(_run('legacy', completed: true), [
          _segment('legacy'),
        ], storedAtUtcMs: 3),
      );
      _ok(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true),
          storedAtUtcMs: 3,
        ),
      );
      for (final source in ['legacy', 'refined', 'missing']) {
        expect(
          await processing.enqueueRefinement(
            _job(id: 'job-other', runId: 'other'),
            _run('other'),
            _info(refinement: true, source: source),
            storedAtUtcMs: 4,
          ),
          isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
        );
      }
      expect(
        await database.select(database.transcriptRuns).get(),
        hasLength(2),
      );
    },
  );

  test(
    'refinement cannot reinterpret an existing legacy job identity',
    () async {
      _ok(await jobs.enqueue(_job(), _run('refined'), storedAtUtcMs: 2));
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true),
          storedAtUtcMs: 3,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(_ok(await processing.load('refined')), isNull);
    },
  );

  test('nonfinalized or deleted meeting never accepts refinement', () async {
    for (final lifecycle in [
      'recording',
      'pausedByUser',
      'stopping',
      'recoverable',
      'trashed',
      'deleting',
    ]) {
      final trashed = lifecycle == 'trashed' || lifecycle == 'deleting';
      final values = trashed
          ? <Object?>[lifecycle, 2, 'finalized', 1, 2, 'meeting']
          : <Object?>[lifecycle, null, null, 0, null, 'meeting'];
      await database.customStatement('''
        UPDATE meetings SET lifecycle = ?, trashed_at_utc_ms = ?,
        lifecycle_before_trash = ?, is_deleted = ?, deleted_at = ? WHERE id = ?
      ''', values);
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true),
          storedAtUtcMs: 3,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
        reason: lifecycle,
      );
    }
    expect(await database.select(database.transcriptRuns).get(), isEmpty);
  });

  test(
    'metadata publication failure rolls back live text and queued work',
    () async {
      await database.customStatement('''
      CREATE TRIGGER reject_processing BEFORE INSERT ON transcript_processing_metadata
      BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
      expect(
        await processing.saveLiveVersion(
          _run('draft', completed: true),
          [_segment('draft')],
          _info(),
          storedAtUtcMs: 3,
        ),
        isA<Err<TranscriptVersion, AnalysisRepositoryFailure>>(),
      );
      expect(
        await processing.enqueueRefinement(
          _job(),
          _run('refined'),
          _info(refinement: true),
          storedAtUtcMs: 3,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(await database.select(database.transcriptRuns).get(), isEmpty);
      expect(await database.select(database.transcriptSegments).get(), isEmpty);
      expect(await database.select(database.processingJobs).get(), isEmpty);
    },
  );
}

final class _GatedTranscriptRepository implements TranscriptRepository {
  _GatedTranscriptRepository(this.delegate);
  final TranscriptRepository delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  final finished = Completer<void>();

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectReadableVersion(
    TranscriptRun expectedRun,
    TranscriptProcessingInfo? expectedProcessing, {
    required int selectedAtUtcMs,
  }) async {
    entered.complete();
    await release.future;
    try {
      return await delegate.selectReadableVersion(
        expectedRun,
        expectedProcessing,
        selectedAtUtcMs: selectedAtUtcMs,
      );
    } finally {
      finished.complete();
    }
  }

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) => delegate.loadEditor(meetingId);

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) => delegate.listVersions(meetingId);

  @override
  Stream<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  watchVersions(String meetingId) => delegate.watchVersions(meetingId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _ProcessingReadMutation implements TranscriptProcessingRepository {
  _ProcessingReadMutation(this.delegate, this.mutate);
  final TranscriptProcessingRepository delegate;
  final Future<void> Function() mutate;
  bool mutateNextLoad = false;

  @override
  Future<Result<TranscriptProcessingInfo?, AnalysisRepositoryFailure>> load(
    String runId,
  ) async {
    final result = await delegate.load(runId);
    if (mutateNextLoad) {
      mutateNextLoad = false;
      await mutate();
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<TranscriptVersionChoicesState> _waitForChoices(
  ProviderContainer container,
  bool Function(TranscriptVersionChoicesState) predicate,
) async {
  final completer = Completer<TranscriptVersionChoicesState>();
  final subscription = container.listen(
    transcriptVersionChoicesControllerProvider('meeting'),
    (_, next) {
      final value = next.value;
      if (!completer.isCompleted && value != null && predicate(value)) {
        completer.complete(value);
      }
    },
    fireImmediately: true,
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}

T _ok<T>(Result<T, AnalysisRepositoryFailure> result) {
  expect(result, isA<Ok<T, AnalysisRepositoryFailure>>());
  return (result as Ok<T, AnalysisRepositoryFailure>).value;
}

TranscriptProcessingInfo _info({
  bool refinement = false,
  String? source,
  String? snapshot,
  String? audioHash,
}) => TranscriptProcessingInfo(
  role: refinement
      ? TranscriptProcessingRole.refinement
      : TranscriptProcessingRole.liveDraft,
  completeness: TranscriptCompleteness.incomplete,
  sourceRunId: source,
  bundleManifestJson: snapshot ?? jsonEncode(modelBundleFixture()),
  audioInventorySha256: refinement ? audioHash ?? 'a' * 64 : null,
);

TranscriptRun _run(
  String id, {
  bool completed = false,
  String meetingId = 'meeting',
  String modelId = 'test-bundle',
}) => TranscriptRun(
  id: id,
  meetingId: meetingId,
  createdAtUtcMs: 1,
  provenance: InferenceProvenance(
    engineId: 'test-streaming',
    engineVersion: '1.0.0',
    modelId: modelId,
    modelVersion: modelBundleFixture()['version']! as String,
    modelSha256: modelBundleFixture()['sha256']! as String,
    parametersJson: '{"parameterVersion":1}',
  ),
  state: completed
      ? const AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2)
      : const AnalysisQueued(),
);

TranscriptSegment _segment(String runId) => TranscriptSegment(
  id: '$runId-segment',
  transcriptRunId: runId,
  start: Duration.zero,
  end: const Duration(seconds: 1),
  rawModelText: '  刘国梁 ONNX\n',
  displayedText: '  刘国梁 ONNX\n',
  revisionState: TranscriptRevisionState.machine,
);

ProcessingJob _job({
  String id = 'job',
  String runId = 'refined',
  String modelId = 'test-bundle',
}) => ProcessingJob(
  id: id,
  meetingId: 'meeting',
  createdAtUtcMs: 1,
  kind: ProcessingJobKind.transcription,
  state: const ProcessingQueued(),
  targetRunId: runId,
  modelId: modelId,
);

Future<void> _seed(db.AppDatabase database) async {
  final bundle = modelBundleFixture();
  await database
      .into(database.meetings)
      .insert(
        db.MeetingsCompanion.insert(
          id: 'meeting',
          createdAt: 1,
          updatedAt: 1,
          title: 'paired',
          lifecycle: 'finalized',
          languageMode: 'mixed',
        ),
      );
  await database
      .into(database.modelManifests)
      .insert(
        db.ModelManifestsCompanion.insert(
          id: 'test-bundle',
          createdAt: 1,
          updatedAt: 1,
          version: bundle['version']! as String,
          source: bundle['source']! as String,
          sha256: bundle['sha256']! as String,
          bytes: bundle['bytes']! as int,
          expectedEngineId: 'test-streaming',
          licenseId: 'MIT',
          licenseSnapshotPath: 'models/licenses/test-bundle.txt',
        ),
      );
  await database
      .into(database.modelCapabilityEntries)
      .insert(
        db.ModelCapabilityEntriesCompanion.insert(
          id: 'capability',
          createdAt: 1,
          updatedAt: 1,
          modelId: 'test-bundle',
          capability: 'transcription',
        ),
      );
  await database
      .into(database.modelModeEntries)
      .insert(
        db.ModelModeEntriesCompanion.insert(
          id: 'mode',
          createdAt: 1,
          updatedAt: 1,
          modelId: 'test-bundle',
          mode: 'balanced',
        ),
      );
}
