import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_export_record_repository.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/data/repositories/drift_transcript_processing_repository.dart';
import 'package:loquiris/features/export_backup/application/drift_backup_snapshot_planner.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/presentation/sessions_controller.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_status.dart';
import 'package:loquiris/features/transcript/presentation/transcript_version_choices_controller.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

import '../support/harness.dart';
import '../support/model_bundle_fixture.dart';

void main() {
  late _Fixture fixture;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  setUp(() async => fixture = await _Fixture.create());
  tearDown(() => fixture.close());

  for (final state in ['none', 'queued', 'paused', 'failed']) {
    test(
      'selected closed live text is readable while refinement is $state',
      () async {
        final isolated = await _Fixture.create(refinementState: state);
        try {
          final provider = meetingTranscriptionControllerProvider('meeting');
          final subscription = isolated.container.listen(provider, (_, _) {});
          final status = await isolated.container.read(provider.future);
          expect(status.document?.currentVersion?.run.id, 'draft');
          expect(
            status.document?.currentVersion?.segments.first.displayedText,
            '人工校正 API',
          );
          expect(
            status.jobs.any((job) => job.state is ProcessingSucceeded),
            isFalse,
          );
          subscription.close();
        } finally {
          await isolated.close();
        }
      },
    );
  }

  testWidgets(
    'selected failed live evidence remains a visibly incomplete preview',
    (tester) async {
      final isolated = await tester.runAsync(
        () => _Fixture.create(refinementState: 'none', failedLive: true),
      );
      try {
        await tester.pumpLocalizedContent(
          UncontrolledProviderScope(
            container: isolated!.container,
            child: const MeetingTranscriptionStatus(meetingId: 'meeting'),
          ),
        );
        for (
          var index = 0;
          index < 30 && find.text('  刘国梁 ONNX\n').evaluate().isEmpty;
          index++
        ) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(find.text('  刘国梁 ONNX\n'), findsOneWidget);
        expect(find.text('Incomplete coverage'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.runAsync(() => isolated!.close());
      }
    },
  );

  test(
    'selected-version search and playback text preserve media bookmarks',
    () async {
      final status = meetingTranscriptionControllerProvider('meeting');
      final subscription = fixture.container.listen(status, (_, _) {});
      addTearDown(subscription.close);
      final initial = await fixture.container.read(status.future);
      expect(
        initial.document?.currentVersion?.segments.first.displayedText,
        '人工校正 API',
      );
      final draftHits = _value(await fixture.sessions.search('人工校正'));
      expect(draftHits.single.transcriptSegmentId, 'draft-first');
      expect(draftHits.single.mediaOffset, Duration.zero);
      expect(_value(await fixture.sessions.search('refined-only')), isEmpty);
      await fixture.select('refined');
      final refined = await fixture.container.read(status.future);
      expect(refined.document?.currentVersion?.run.id, 'refined');
      expect(
        refined.document?.currentVersion?.segments.single.displayedText,
        'refined-only Zoom API',
      );
      expect(_value(await fixture.sessions.search('人工校正')), isEmpty);
      final refinedHits = _value(await fixture.sessions.search('refined-only'));
      expect(refinedHits.single.transcriptSegmentId, 'refined-whole');
      expect(refinedHits.single.mediaOffset, Duration.zero);
      for (final version in ['refined', 'draft']) {
        await fixture.select(version);
        final detail = _value(await fixture.sessions.loadDetail('meeting'));
        expect(detail.meeting.currentTranscriptRunId, version);
        expect(detail.bookmarks.single.id, 'recording-anchor');
        expect(
          detail.bookmarks.single.mediaOffset,
          const Duration(milliseconds: 2500),
        );
      }
      final restored = _value(await fixture.transcripts.loadEditor('meeting'));
      expect(restored.currentVersion?.segments, hasLength(2));
      expect(restored.currentVersion?.segments.first.displayedText, '人工校正 API');
      expect(
        restored.currentVersion?.segments.first.rawModelText,
        '  刘国梁 ONNX\n',
      );
      expect(restored.revisions.single.targetId, 'draft-first');
    },
  );

  test(
    'an already-open search removes hits after explicit version selection',
    () async {
      final subscription = fixture.container.listen(
        sessionsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(sessionsControllerProvider.future);
      fixture.container
          .read(sessionsControllerProvider.notifier)
          .search('人工校正');
      await fixture.container.pump();
      final initial =
          await fixture.container.read(sessionsControllerProvider.future)
              as SessionsLoaded;
      expect(initial.items.single.transcriptSegmentId, 'draft-first');
      await fixture.select('refined');
      await fixture.container.pump();
      final updated =
          await fixture.container.read(sessionsControllerProvider.future)
              as SessionsLoaded;
      expect(updated.query, '人工校正');
      expect(updated.items, isEmpty);
    },
  );

  test(
    'search observation follows source corrections without a job transition',
    () async {
      final iterator = StreamIterator(fixture.sessions.watchSearch('人工校正'));
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(
        _value(iterator.current).single.transcriptSegmentId,
        'draft-first',
      );
      _value(
        await DriftRevisionRepository(
          fixture.database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).apply(
          const Revision(
            id: 'second-human',
            meetingId: 'meeting',
            targetId: 'draft-first',
            change: TranscriptTextChange(
              previousText: '人工校正 API',
              revisedText: '新的人工文本',
            ),
            createdAtUtcMs: 8,
          ),
        ),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(_value(iterator.current), isEmpty);
      final retained = _value(
        await fixture.transcripts.listVersions('meeting'),
      );
      final draft = retained.singleWhere(
        (version) => version.run.id == 'draft',
      );
      expect(draft.segments.first.rawModelText, '  刘国梁 ONNX\n');
      expect(draft.segments.first.displayedText, '新的人工文本');
    },
  );

  test(
    'backup snapshots restore selection, both segmentations and source corrections',
    () async {
      for (final selectedVersion in ['refined', 'draft']) {
        await fixture.select(selectedVersion);
        final planner = DriftBackupSnapshotPlanner(
          fixture.database,
          () async => fixture.directory,
        );
        final plan = _value(await planner.create('versions-$selectedVersion'));
        final snapshot = db.AppDatabase(
          NativeDatabase(
            File('${fixture.directory.path}/${plan.snapshotRelativePath}'),
          ),
        );
        final target = db.AppDatabase(NativeDatabase.memory());
        try {
          final receipt = _value(
            await DriftRestoreImporter(
              liveDatabase: target,
              restoredCopyTitle: (title) => '$title restored',
            ).import(
              snapshot,
              sourceAudioFingerprints: {'meeting': 'a' * 64},
              liveAudioFingerprint: (_) async => null,
            ),
          );
          expect(receipt.importedCount, 1);
          final transcripts = DriftTranscriptRepository(
            target,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          );
          final processing = DriftTranscriptProcessingRepository(
            target,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          );
          final versions = _value(await transcripts.listVersions('meeting'));
          expect(versions, hasLength(2));
          expect(
            versions.singleWhere((version) => version.isCurrent).run.id,
            selectedVersion,
          );
          final draft = versions.singleWhere(
            (version) => version.run.id == 'draft',
          );
          final refined = versions.singleWhere(
            (version) => version.run.id == 'refined',
          );
          expect(draft.segments, hasLength(2));
          expect(refined.segments, hasLength(1));
          expect(draft.segments.first.rawModelText, '  刘国梁 ONNX\n');
          expect(draft.segments.first.displayedText, '人工校正 API');
          expect(refined.segments.single.rawModelText, 'refined-only Zoom API');
          final refinedProcessing = _value(await processing.load('refined'))!;
          expect(refinedProcessing.sourceRunId, 'draft');
          expect(
            refinedProcessing.bundleManifestJson,
            jsonEncode(modelBundleFixture()),
          );
          expect(
            refinedProcessing.completeness,
            TranscriptCompleteness.complete,
          );
          expect(
            _value(
              await transcripts.loadEditor('meeting'),
            ).revisions.single.targetId,
            'draft-first',
          );
          final sessions = DriftSessionRepository(
            target,
            audioStore: _NoAudioDeletion(),
            diagnosticSink: const DisabledDiagnosticLogSink(),
          );
          final detail = _value(await sessions.loadDetail('meeting'));
          expect(
            detail.bookmarks.single.mediaOffset,
            const Duration(milliseconds: 2500),
          );
          _value(
            await transcripts.selectReadableVersion(
              draft.run,
              _value(await processing.load('draft')),
              selectedAtUtcMs: 30,
            ),
          );
          expect(
            _value(
              await transcripts.loadEditor('meeting'),
            ).currentVersion?.segments.first.displayedText,
            '人工校正 API',
          );
        } finally {
          await snapshot.close();
          await target.close();
          await planner.deleteSnapshot(plan.snapshotRelativePath);
        }
      }
    },
  );

  test(
    'an unselected archive omits empty text files but retains version history',
    () async {
      await fixture.database
          .delete(fixture.database.meetingTranscriptSelections)
          .go();
      final destination = _Destination();
      final service = LocalExportService(
        sessionRepository: fixture.sessions,
        transcriptRepository: fixture.transcripts,
        destinationGateway: destination,
        exportRecordRepository: DriftExportRecordRepository(
          fixture.database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ),
        nowUtcMs: () => 20,
      );
      _value(
        await service.export(
          const ExportRequest(
            operationId: 'unselected-archive',
            createdAtUtcMs: 10,
            sessionId: 'meeting',
            format: ExportFormat.archive,
          ),
        ),
      );
      final documents = destination.payloads.single.documents;
      expect(documents.keys, ['meeting.json']);
      final json =
          jsonDecode(documents['meeting.json']!) as Map<String, Object?>;
      expect(json['currentTranscriptRunId'], isNull);
      expect(json['transcriptVersions'], hasLength(2));
    },
  );

  test(
    'text and subtitle export require an explicit current selection',
    () async {
      await fixture.database
          .delete(fixture.database.meetingTranscriptSelections)
          .go();
      final destination = _Destination();
      final service = LocalExportService(
        sessionRepository: fixture.sessions,
        transcriptRepository: fixture.transcripts,
        destinationGateway: destination,
        exportRecordRepository: DriftExportRecordRepository(
          fixture.database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ),
        nowUtcMs: () => 20,
      );
      for (final format in [ExportFormat.text, ExportFormat.subtitles]) {
        final result = await service.export(
          ExportRequest(
            operationId: 'unselected-${format.name}',
            createdAtUtcMs: 10,
            sessionId: 'meeting',
            format: format,
          ),
        );
        expect(result, isA<Err<ExportReceipt, ExportFailure>>());
      }
      expect(destination.payloads, isEmpty);
    },
  );

  for (final boundary in ['editor', 'versions', 'correction']) {
    test(
      'JSON export rejects a version change at the $boundary read boundary',
      () async {
        final destination = _Destination();
        final repository = _ExportReadBoundaryRepository(
          fixture.transcripts,
          beforeEditor: boundary == 'editor'
              ? () => fixture.select('refined')
              : null,
          beforeVersions: boundary == 'versions'
              ? () => fixture.select('refined')
              : boundary == 'correction'
              ? () async {
                  _value(
                    await DriftRevisionRepository(
                      fixture.database,
                      diagnosticSink: const DisabledDiagnosticLogSink(),
                    ).apply(
                      const Revision(
                        id: 'racing-human',
                        meetingId: 'meeting',
                        targetId: 'draft-first',
                        change: TranscriptTextChange(
                          previousText: '人工校正 API',
                          revisedText: '并发校正',
                        ),
                        createdAtUtcMs: 9,
                      ),
                    ),
                  );
                }
              : null,
        );
        final service = LocalExportService(
          sessionRepository: fixture.sessions,
          transcriptRepository: repository,
          destinationGateway: destination,
          exportRecordRepository: DriftExportRecordRepository(
            fixture.database,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ),
          nowUtcMs: () => 20,
        );
        final result = await service.export(
          const ExportRequest(
            operationId: 'selection-race',
            createdAtUtcMs: 10,
            sessionId: 'meeting',
            format: ExportFormat.json,
          ),
        );
        expect(
          result,
          isA<Err<ExportReceipt, ExportFailure>>().having(
            (result) => result.failure.code,
            'code',
            'export_transcript_changed',
          ),
        );
        expect(destination.payloads, isEmpty);
        expect(
          (await fixture.database
                  .select(fixture.database.exportRecords)
                  .getSingle())
              .failureCode,
          'export_transcript_changed',
        );
      },
    );
  }

  test(
    'local text subtitle and JSON exports follow selection while retaining history',
    () async {
      final destination = _Destination();
      final service = LocalExportService(
        sessionRepository: fixture.sessions,
        transcriptRepository: fixture.transcripts,
        destinationGateway: destination,
        exportRecordRepository: DriftExportRecordRepository(
          fixture.database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ),
        nowUtcMs: () => 20,
      );
      for (final version in ['draft', 'refined', 'draft']) {
        await fixture.select(version);
        for (final format in [
          ExportFormat.text,
          ExportFormat.subtitles,
          ExportFormat.json,
        ]) {
          final operation = 'export-${destination.payloads.length}';
          _value(
            await service.export(
              ExportRequest(
                operationId: operation,
                createdAtUtcMs: 10,
                sessionId: 'meeting',
                format: format,
              ),
            ),
          );
          final documents = destination.payloads.last.documents;
          if (format == ExportFormat.json) {
            final json =
                jsonDecode(documents['meeting.json']!) as Map<String, Object?>;
            expect(json['currentTranscriptRunId'], version);
            expect(json['transcriptRunId'], version);
            final segments = (json['segments']! as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(
              segments.first['displayedText'],
              version == 'draft' ? '人工校正 API' : 'refined-only Zoom API',
            );
            final retained = (json['transcriptVersions']! as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(retained, hasLength(2));
            final draft = retained.singleWhere(
              (entry) => entry['runId'] == 'draft',
            );
            final draftSegments = (draft['segments']! as List<Object?>)
                .cast<Map<String, Object?>>();
            expect(draftSegments.first['rawModelText'], '  刘国梁 ONNX\n');
            expect(draftSegments.first['displayedText'], '人工校正 API');
            final bookmark =
                (json['bookmarks']! as List<Object?>).single!
                    as Map<String, Object?>;
            expect(bookmark['mediaOffsetMilliseconds'], 2500);
          } else {
            final document = documents.values.single;
            expect(
              document,
              contains(
                version == 'draft' ? '人工校正 API' : 'refined-only Zoom API',
              ),
            );
            expect(
              document,
              isNot(contains(version == 'draft' ? 'refined-only' : '人工校正')),
            );
            if (format == ExportFormat.subtitles) {
              expect(
                document,
                contains(
                  version == 'draft'
                      ? '00:00:00,000 --> 00:00:01,000'
                      : '00:00:00,000 --> 00:00:03,000',
                ),
              );
            }
          }
        }
      }
      expect(
        await fixture.database.select(fixture.database.revisions).get(),
        hasLength(1),
      );
    },
  );
}

final class _Fixture {
  _Fixture(this.database, this.directory);
  final db.AppDatabase database;
  final Directory directory;
  late final transcripts = DriftTranscriptRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final processing = DriftTranscriptProcessingRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final jobs = DriftTranscriptionJobRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final sessions = DriftSessionRepository(
    database,
    audioStore: _NoAudioDeletion(),
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final container = ProviderContainer(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(sessions),
      transcriptRepositoryProvider.overrideWithValue(transcripts),
      transcriptProcessingRepositoryProvider.overrideWithValue(processing),
      transcriptionJobRepositoryProvider.overrideWithValue(jobs),
    ],
  );

  static Future<_Fixture> create({
    String refinementState = 'completed',
    bool failedLive = false,
  }) async {
    final fixture = _Fixture(
      db.AppDatabase(NativeDatabase.memory()),
      await Directory.systemTemp.createTemp('loquiris-paired-consumers-'),
    );
    final database = fixture.database;
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
    await database.customStatement(
      "UPDATE meetings SET media_duration_us=3000000 WHERE id='meeting'",
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
    final live = TranscriptProcessingInfo(
      role: TranscriptProcessingRole.liveDraft,
      completeness: TranscriptCompleteness.incomplete,
      bundleManifestJson: jsonEncode(bundle),
    );
    _value(
      await fixture.processing.saveLiveVersion(
        failedLive
            ? _run('draft').copyWith(
                state: const AnalysisFailed(
                  startedAtUtcMs: 1,
                  endedAtUtcMs: 2,
                  progress: 0.5,
                  failureCode: 'live_failed',
                ),
              )
            : _run('draft', completed: true),
        [
          _span('draft-first', 'draft', 0, 1, '  刘国梁 ONNX\n'),
          _span('draft-tail', 'draft', 1, 3, '初稿 tail'),
        ],
        live,
        storedAtUtcMs: 3,
      ),
    );
    _value(
      await fixture.transcripts.selectCurrent(
        'meeting',
        'draft',
        selectedAtUtcMs: 3,
      ),
    );
    if (!failedLive) {
      _value(
        await DriftRevisionRepository(
          database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).apply(
          const Revision(
            id: 'human',
            meetingId: 'meeting',
            targetId: 'draft-first',
            change: TranscriptTextChange(
              previousText: '  刘国梁 ONNX\n',
              revisedText: '人工校正 API',
            ),
            createdAtUtcMs: 4,
          ),
        ),
      );
    }
    await database
        .into(database.bookmarks)
        .insert(
          db.BookmarksCompanion.insert(
            id: 'recording-anchor',
            createdAt: 2,
            updatedAt: 2,
            meetingId: 'meeting',
            mediaOffsetUs: 2500000,
            kind: 'highlight',
          ),
        );
    if (refinementState == 'none') return fixture;
    _value(
      await fixture.processing.enqueueRefinement(
        const ProcessingJob(
          id: 'job',
          meetingId: 'meeting',
          createdAtUtcMs: 4,
          kind: ProcessingJobKind.transcription,
          state: ProcessingQueued(),
          targetRunId: 'refined',
          modelId: 'test-bundle',
        ),
        _run('refined'),
        TranscriptProcessingInfo(
          role: TranscriptProcessingRole.refinement,
          completeness: TranscriptCompleteness.incomplete,
          bundleManifestJson: jsonEncode(bundle),
          sourceRunId: 'draft',
          audioInventorySha256: 'a' * 64,
        ),
        storedAtUtcMs: 4,
      ),
    );
    if (refinementState == 'queued') return fixture;
    if (refinementState == 'paused') {
      _value(
        await fixture.processing.pauseRefinement(
          'job',
          reasonCode: 'refinement_battery_low',
          pausedAtUtcMs: 5,
        ),
      );
      return fixture;
    }
    _value(await fixture.processing.startRefinement('job', startedAtUtcMs: 4));
    if (refinementState == 'failed') {
      _value(
        await fixture.jobs.fail(
          'job',
          failureCode: 'refinement_failed',
          failedAtUtcMs: 5,
        ),
      );
      return fixture;
    }
    _value(
      await fixture.jobs.complete(
        'job',
        _run('refined').copyWith(
          state: const AnalysisCompleted(startedAtUtcMs: 4, endedAtUtcMs: 5),
        ),
        [_span('refined-whole', 'refined', 0, 3, 'refined-only Zoom API')],
        storedAtUtcMs: 5,
      ),
    );
    return fixture;
  }

  Future<void> select(String runId) async {
    final provider = transcriptVersionChoicesControllerProvider('meeting');
    final subscription = container.listen(provider, (_, _) {});
    try {
      await container.read(provider.future);
      container.read(provider.notifier).select(runId);
      await _waitForCurrent(container, runId);
    } finally {
      subscription.close();
    }
  }

  Future<void> close() async {
    container.dispose();
    await database.close();
    await directory.delete(recursive: true);
  }
}

Future<void> _waitForCurrent(ProviderContainer container, String runId) async {
  final completer = Completer<void>();
  final subscription = container.listen(
    transcriptVersionChoicesControllerProvider('meeting'),
    (_, next) {
      final value = next.value;
      if (!completer.isCompleted &&
          value?.selectingRunId == null &&
          (value?.choices.any(
                (choice) => choice.run.id == runId && choice.isCurrent,
              ) ??
              false)) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );
  try {
    await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}

TranscriptRun _run(String id, {bool completed = false}) => TranscriptRun(
  id: id,
  meetingId: 'meeting',
  createdAtUtcMs: id == 'draft' ? 1 : 4,
  provenance: InferenceProvenance(
    engineId: 'test-streaming',
    engineVersion: '1.0.0',
    modelId: 'test-bundle',
    modelVersion: modelBundleFixture()['version']! as String,
    modelSha256: modelBundleFixture()['sha256']! as String,
    parametersJson: '{"parameterVersion":1}',
  ),
  state: completed
      ? const AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2)
      : const AnalysisQueued(),
);

TranscriptSegment _span(
  String id,
  String runId,
  int start,
  int end,
  String text,
) => TranscriptSegment(
  id: id,
  transcriptRunId: runId,
  start: Duration(seconds: start),
  end: Duration(seconds: end),
  rawModelText: text,
  displayedText: text,
  revisionState: TranscriptRevisionState.machine,
);

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected ${failure.code}'),
};

final class _NoAudioDeletion implements MeetingAudioStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No audio deletion is allowed in this fixture');
}

final class _ExportReadBoundaryRepository implements TranscriptRepository {
  _ExportReadBoundaryRepository(
    this.delegate, {
    this.beforeEditor,
    this.beforeVersions,
  });
  final TranscriptRepository delegate;
  final Future<void> Function()? beforeEditor;
  final Future<void> Function()? beforeVersions;

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async {
    await beforeEditor?.call();
    return delegate.loadEditor(meetingId);
  }

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async {
    await beforeVersions?.call();
    return delegate.listVersions(meetingId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _Destination implements ExportDestinationGateway {
  final payloads = <ExportDestinationPayload>[];
  @override
  Future<Result<ExportReceipt, ExportFailure>> save(
    ExportDestinationPayload payload,
  ) async {
    payloads.add(payload);
    return Ok(
      ExportReceipt(
        fileName: payload.suggestedFileName,
        bytesWritten: utf8.encode(payload.documents.values.join()).length,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
