import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

import '../support/model_bundle_fixture.dart';

void main() {
  late db.AppDatabase database;
  late DriftTranscriptionJobRepository jobs;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    jobs = DriftTranscriptionJobRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _seed(database, jobs);
  });
  tearDown(() => database.close());

  for (final lifecycle in ['trashed', 'recording', 'pausedByUser', 'draft']) {
    test(
      'refinement completion rejects meeting lifecycle $lifecycle atomically',
      () async {
        if (lifecycle == 'trashed') {
          await database.customStatement(
            "UPDATE meetings SET lifecycle='trashed', is_deleted=1, deleted_at=3, trashed_at_utc_ms=3, lifecycle_before_trash='finalized'",
          );
        } else {
          await database.customStatement('UPDATE meetings SET lifecycle=?', [
            lifecycle,
          ]);
        }
        final result = await jobs.complete(
          'job',
          _run.copyWith(
            state: const AnalysisCompleted(startedAtUtcMs: 2, endedAtUtcMs: 3),
          ),
          const [_segment],
          storedAtUtcMs: 3,
        );
        expect(result.isErr, isTrue);
        expect(
          await database.select(database.transcriptSegments).get(),
          isEmpty,
        );
        expect(
          (await database.select(database.processingJobs).getSingle()).jobState,
          'running',
        );
        expect(
          (await database
                  .select(database.transcriptProcessingMetadata)
                  .getSingle())
              .completeness,
          'incomplete',
        );
      },
    );
  }

  test('first refinement result waits for explicit selection', () async {
    final completed = await jobs.complete(
      'job',
      _run.copyWith(
        state: const AnalysisCompleted(startedAtUtcMs: 2, endedAtUtcMs: 3),
      ),
      const [_segment],
      storedAtUtcMs: 3,
    );
    expect(completed, isA<Ok<TranscriptVersion, AnalysisRepositoryFailure>>());
    final version =
        (completed as Ok<TranscriptVersion, AnalysisRepositoryFailure>).value;
    expect(
      version.isCurrent,
      isFalse,
      reason: 'refinement completion is readiness, not permission to select',
    );
    expect(
      await database.select(database.meetingTranscriptSelections).get(),
      isEmpty,
    );
    final metadata = await database
        .select(database.transcriptProcessingMetadata)
        .getSingle();
    expect(metadata.completeness, 'complete');
    final retained = await DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    ).listVersions('meeting');
    expect(
      (retained as Ok<List<TranscriptVersion>, AnalysisRepositoryFailure>)
          .value
          .single
          .isCurrent,
      isFalse,
    );
  });

  test(
    'completion warning never claims complete refinement coverage',
    () async {
      final completed = await jobs.complete(
        'job',
        _run.copyWith(
          state: const AnalysisCompleted(startedAtUtcMs: 2, endedAtUtcMs: 3),
        ),
        const [_segment],
        storedAtUtcMs: 3,
        warningCode: 'transcription_audio_uncommitted_tail',
      );
      expect(
        completed,
        isA<Ok<TranscriptVersion, AnalysisRepositoryFailure>>(),
      );
      final metadata = await database
          .select(database.transcriptProcessingMetadata)
          .getSingle();
      expect(metadata.completeness, 'incomplete');
      expect(
        await database.select(database.meetingTranscriptSelections).get(),
        isEmpty,
      );
    },
  );
  for (final corruption in ['snapshot', 'runtime', 'source']) {
    test(
      'completion rejects $corruption corruption without partial mutation',
      () async {
        if (corruption == 'source') {
          await database.customStatement('''
          INSERT INTO transcript_runs (id,created_at,updated_at,meeting_id,engine_id,
            engine_version,model_id,model_version,model_sha256,parameters_json,
            run_state,started_at_utc_ms,ended_at_utc_ms,progress)
          SELECT 'legacy',1,1,meeting_id,engine_id,engine_version,model_id,
            model_version,model_sha256,parameters_json,'completed',1,2,1
          FROM transcript_runs WHERE id = 'run'
        ''');
          await database.customStatement(
            "UPDATE transcript_processing_metadata SET source_run_id = 'legacy'",
          );
        } else {
          final bundle = modelBundleFixture();
          (bundle['runtime']! as Map<String, Object?>)['engineVersion'] =
              'different';
          await database.customStatement(
            'UPDATE transcript_processing_metadata SET bundle_manifest_json = ?',
            [
              if (corruption == 'snapshot')
                '{"schemaVersion":2}'
              else
                jsonEncode(bundle),
            ],
          );
        }
        final result = await jobs.complete(
          'job',
          _run.copyWith(
            state: const AnalysisCompleted(startedAtUtcMs: 2, endedAtUtcMs: 3),
          ),
          const [_segment],
          storedAtUtcMs: 3,
        );
        expect(
          result,
          isA<Err<TranscriptVersion, AnalysisRepositoryFailure>>(),
        );
        expect(
          await database.select(database.transcriptSegments).get(),
          isEmpty,
        );
        expect(
          (await database.select(database.processingJobs).getSingle()).jobState,
          'running',
        );
        expect(
          (await (database.select(
            database.transcriptRuns,
          )..where((row) => row.id.equals('run'))).getSingle()).runState,
          'running',
        );
        expect(
          (await database
                  .select(database.transcriptProcessingMetadata)
                  .getSingle())
              .completeness,
          'incomplete',
        );
        expect(
          await database.select(database.meetingTranscriptSelections).get(),
          isEmpty,
        );
      },
    );
  }
}

Future<void> _seed(
  db.AppDatabase database,
  DriftTranscriptionJobRepository jobs,
) async {
  final bundle = modelBundleFixture();
  await database
      .into(database.meetings)
      .insert(
        db.MeetingsCompanion.insert(
          id: 'meeting',
          createdAt: 1,
          updatedAt: 1,
          title: 'meeting',
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
  expect(
    await jobs.enqueue(_job, _run, storedAtUtcMs: 1),
    isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
  );
  expect(
    await jobs.start('job', startedAtUtcMs: 2),
    isA<Ok<ProcessingJob, AnalysisRepositoryFailure>>(),
  );
  await database
      .into(database.transcriptProcessingMetadata)
      .insert(
        db.TranscriptProcessingMetadataCompanion.insert(
          id: 'processing',
          createdAt: 1,
          updatedAt: 1,
          transcriptRunId: 'run',
          meetingId: 'meeting',
          processingRole: 'refinement',
          completeness: 'incomplete',
          bundleManifestJson: jsonEncode(bundle),
          audioInventorySha256: Value('a' * 64),
        ),
      );
}

final _run = TranscriptRun(
  id: 'run',
  meetingId: 'meeting',
  createdAtUtcMs: 1,
  provenance: InferenceProvenance(
    engineId: 'test-streaming',
    engineVersion: '1.0.0',
    modelId: 'test-bundle',
    modelVersion: modelBundleFixture()['version']! as String,
    modelSha256: modelBundleFixture()['sha256']! as String,
    parametersJson: '{"parameterVersion":1}',
  ),
  state: const AnalysisQueued(),
);
const _job = ProcessingJob(
  id: 'job',
  meetingId: 'meeting',
  kind: ProcessingJobKind.transcription,
  createdAtUtcMs: 1,
  state: ProcessingQueued(),
  targetRunId: 'run',
  modelId: 'test-bundle',
);
const _segment = TranscriptSegment(
  id: 'segment',
  transcriptRunId: 'run',
  start: Duration.zero,
  end: Duration(seconds: 1),
  rawModelText: '中英 ONNX',
  displayedText: '中英 ONNX',
  revisionState: TranscriptRevisionState.machine,
);
