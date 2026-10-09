import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

void main() {
  late db.AppDatabase database;
  late DriftModelRepository repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftModelRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
  });

  tearDown(() => database.close());

  group('durable transcription jobs', () {
    late DriftTranscriptionJobRepository jobs;

    setUp(() {
      jobs = DriftTranscriptionJobRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
    });

    test('enqueue is idempotent for one deterministic job key', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);

      final first = await _ok(
        jobs.enqueue(job, run, storedAtUtcMs: 2),
      );
      final duplicate = await _ok(
        jobs.enqueue(job, run, storedAtUtcMs: 3),
      );

      expect(first, job);
      expect(duplicate, job);
      expect(await _tableCount(database, 'processing_jobs'), 1);
      expect(await _tableCount(database, 'transcript_runs'), 1);

      final conflict = await jobs.enqueue(
        job.copyWith(targetRunId: 'different-run'),
        run,
        storedAtUtcMs: 4,
      );
      expect(
        (conflict as Err<ProcessingJob, AnalysisRepositoryFailure>).failure,
        isA<AnalysisConflict>(),
      );
    });

    test('meeting watch re-emits committed transcription job states', () async {
      await _seedTranscription(database);
      final iterator = StreamIterator(jobs.watchMeeting('meeting-1'));
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>)
            .value,
        isEmpty,
      );
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);

      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>)
            .value
            .single
            .state,
        const ProcessingQueued(),
      );
      await _ok(jobs.start(job.id, startedAtUtcMs: 3));
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>)
            .value
            .single
            .state,
        const ProcessingRunning(progress: 0),
      );
    });

    test('running progress and checkpoints never regress', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);
      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));

      final started = await _ok(jobs.start(job.id, startedAtUtcMs: 3));
      expect(started.state, const ProcessingRunning(progress: 0));
      const checkpoint = TranscriptionCheckpoint(
        completedMedia: Duration(seconds: 4),
        parameterVersion: 1,
      );
      final progressed = await _ok(
        jobs.saveProgress(
          job.id,
          progress: 0.4,
          checkpoint: checkpoint,
          storedAtUtcMs: 4,
        ),
      );
      expect(progressed.state, const ProcessingRunning(progress: 0.4));
      expect(progressed.transcriptionCheckpoint, checkpoint);

      final regressing = await jobs.saveProgress(
        job.id,
        progress: 0.3,
        checkpoint: const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 3),
          parameterVersion: 1,
        ),
        storedAtUtcMs: 5,
      );
      expect(
        (regressing as Err<ProcessingJob, AnalysisRepositoryFailure>).failure,
        isA<AnalysisConflict>(),
      );
      final incompatible = await jobs.saveProgress(
        job.id,
        progress: 0.5,
        checkpoint: const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 5),
          parameterVersion: 2,
        ),
        storedAtUtcMs: 5,
      );
      expect(
        (incompatible as Err<ProcessingJob, AnalysisRepositoryFailure>).failure,
        isA<AnalysisConflict>(),
      );
      expect((await _ok(jobs.load(job.id))).state, progressed.state);
    });

    test('orphaned running jobs become resumably paused', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);
      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
      await _ok(jobs.start(job.id, startedAtUtcMs: 3));
      await _ok(
        jobs.saveProgress(
          job.id,
          progress: 0.25,
          checkpoint: const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 2),
            parameterVersion: 1,
          ),
          storedAtUtcMs: 4,
        ),
      );

      final recovered = await _ok(
        jobs.recoverOrphanedRunning(recoveredAtUtcMs: 5),
      );

      expect(recovered, hasLength(1));
      expect(
        recovered.single.state,
        const ProcessingPaused(reasonCode: 'process_restarted'),
      );
      expect(
        recovered.single.transcriptionCheckpoint,
        const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 2),
          parameterVersion: 1,
        ),
      );
      final version = (await _ok(
        DriftTranscriptRepository(
          database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).listVersions('meeting-1'),
      )).single;
      expect(version.run.state, const AnalysisQueued());
      expect(await _ok(jobs.listRecoverable()), recovered);
    });

    test(
      'checkpoint storage contains only the typed resume boundary',
      () async {
        await _seedTranscription(database);
        final run = _jobRun('run-1', createdAt: 2);
        final job = _transcriptionJob('job-1', run.id, createdAt: 2);
        await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
        await _ok(jobs.start(job.id, startedAtUtcMs: 3));

        await _ok(
          jobs.saveProgress(
            job.id,
            progress: 0.5,
            checkpoint: const TranscriptionCheckpoint(
              completedMedia: Duration(microseconds: 1234567),
              parameterVersion: 1,
            ),
            storedAtUtcMs: 4,
          ),
        );

        final row = await database
            .customSelect(
              "SELECT checkpoint FROM processing_jobs WHERE id = 'job-1'",
            )
            .getSingle();
        expect(
          row.read<String>('checkpoint'),
          '{"completedMediaUs":1234567,"parameterVersion":1}',
        );
      },
    );

    test('completion atomically stores one stable visible version', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);
      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
      await _ok(jobs.start(job.id, startedAtUtcMs: 3));
      final completedRun = _completedJobRun(
        'run-1',
        createdAt: 2,
        startedAt: 3,
        endedAt: 8,
      );
      final segments = <TranscriptSegment>[
        _timedSegment('segment-1', run.id, 'first', startSeconds: 0),
        _timedSegment('segment-2', run.id, 'second', startSeconds: 1),
      ];

      final completed = await _ok(
        jobs.complete(
          job.id,
          completedRun,
          segments,
          storedAtUtcMs: 8,
        ),
      );

      expect(completed.run, completedRun);
      expect(completed.segments, segments);
      expect(completed.isCurrent, isTrue);
      expect((await _ok(jobs.load(job.id))).state, const ProcessingSucceeded());
      final retained = await _ok(
        DriftTranscriptRepository(
          database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).listVersions('meeting-1'),
      );
      expect(retained, hasLength(1));
      expect(retained.single.run, completed.run);
      expect(retained.single.segments, completed.segments);
      expect(retained.single.isCurrent, isTrue);
    });

    test(
      'completion rejects incompatible provenance and duplicate segments',
      () async {
        await _seedTranscription(database);
        final run = _jobRun('run-1', createdAt: 2);
        final job = _transcriptionJob('job-1', run.id, createdAt: 2);
        await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
        await _ok(jobs.start(job.id, startedAtUtcMs: 3));

        final incompatible = await jobs.complete(
          job.id,
          _completedJobRun(
            run.id,
            createdAt: 2,
            startedAt: 3,
            endedAt: 4,
            engineVersion: 'different',
          ),
          [_timedSegment('segment-1', run.id, 'text', startSeconds: 0)],
          storedAtUtcMs: 4,
        );
        expect(
          (incompatible as Err<TranscriptVersion, AnalysisRepositoryFailure>)
              .failure,
          isA<AnalysisConflict>(),
        );

        final duplicate = await jobs.complete(
          job.id,
          _completedJobRun(
            run.id,
            createdAt: 2,
            startedAt: 3,
            endedAt: 4,
          ),
          [
            _timedSegment('segment-1', run.id, 'text', startSeconds: 0),
            _timedSegment('segment-1', run.id, 'text', startSeconds: 0),
          ],
          storedAtUtcMs: 4,
        );
        expect(
          (duplicate as Err<TranscriptVersion, AnalysisRepositoryFailure>)
              .failure,
          isA<AnalysisConflict>(),
        );
        expect(await _tableCount(database, 'transcript_segments'), 0);
        expect(
          (await _ok(jobs.load(job.id))).state,
          const ProcessingRunning(progress: 0),
        );
      },
    );

    test(
      'completion rolls back run, segments, job, and selection together',
      () async {
        await _seedTranscription(database);
        final run = _jobRun('run-1', createdAt: 2);
        final job = _transcriptionJob('job-1', run.id, createdAt: 2);
        await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
        await _ok(jobs.start(job.id, startedAtUtcMs: 3));
        await database.customStatement('''
        CREATE TRIGGER fail_transcription_segment
        BEFORE INSERT ON transcript_segments
        BEGIN
          SELECT RAISE(ABORT, 'simulated segment failure');
        END
      ''');

        final result = await jobs.complete(
          job.id,
          _completedJobRun(
            run.id,
            createdAt: 2,
            startedAt: 3,
            endedAt: 4,
          ),
          [_timedSegment('segment-1', run.id, 'text', startSeconds: 0)],
          storedAtUtcMs: 4,
        );

        expect(
          (result as Err<TranscriptVersion, AnalysisRepositoryFailure>).failure,
          isA<AnalysisStoreUnavailable>(),
        );
        expect(await _tableCount(database, 'transcript_segments'), 0);
        expect(await _tableCount(database, 'meeting_transcript_selections'), 0);
        expect(
          (await _ok(jobs.load(job.id))).state,
          const ProcessingRunning(progress: 0),
        );
        final version = (await _ok(
          DriftTranscriptRepository(
            database,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ).listVersions('meeting-1'),
        )).single;
        expect(
          version.run.state,
          const AnalysisRunning(startedAtUtcMs: 3, progress: 0),
        );
      },
    );

    test(
      'failure is terminal, privacy-safe, and retry returns to queued',
      () async {
        await _seedTranscription(database);
        final run = _jobRun('run-1', createdAt: 2);
        final job = _transcriptionJob('job-1', run.id, createdAt: 2);
        await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
        await _ok(jobs.start(job.id, startedAtUtcMs: 3));
        await _ok(
          jobs.saveProgress(
            job.id,
            progress: 0.6,
            checkpoint: const TranscriptionCheckpoint(
              completedMedia: Duration(seconds: 6),
              parameterVersion: 1,
            ),
            storedAtUtcMs: 4,
          ),
        );

        final unsafe = await jobs.fail(
          job.id,
          failureCode: 'meeting title leaked',
          failedAtUtcMs: 5,
        );
        expect(
          (unsafe as Err<ProcessingJob, AnalysisRepositoryFailure>).failure,
          isA<AnalysisConflict>(),
        );
        final failed = await _ok(
          jobs.fail(
            job.id,
            failureCode: 'inference_execution_failed',
            failedAtUtcMs: 5,
          ),
        );
        expect(
          failed.state,
          const ProcessingFailed(failureCode: 'inference_execution_failed'),
        );
        final failedRun = (await _ok(
          DriftTranscriptRepository(
            database,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ).listVersions('meeting-1'),
        )).single.run;
        expect(
          failedRun.state,
          const AnalysisFailed(
            startedAtUtcMs: 3,
            endedAtUtcMs: 5,
            progress: 0.6,
            failureCode: 'inference_execution_failed',
          ),
        );

        final retried = await _ok(jobs.retry(job.id, queuedAtUtcMs: 6));
        expect(retried.state, const ProcessingQueued());
        expect(
          retried.transcriptionCheckpoint,
          const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 6),
            parameterVersion: 1,
          ),
        );
        final queuedRun = (await _ok(
          DriftTranscriptRepository(
            database,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ).listVersions('meeting-1'),
        )).single.run;
        expect(queuedRun.state, const AnalysisQueued());
      },
    );

    test('cancellation records a stable terminal failure', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);
      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));
      await _ok(jobs.start(job.id, startedAtUtcMs: 3));

      final cancelled = await _ok(
        jobs.cancel(job.id, cancelledAtUtcMs: 4),
      );

      expect(
        cancelled.state,
        const ProcessingFailed(failureCode: 'transcription_cancelled'),
      );
      expect(await _tableCount(database, 'transcript_segments'), 0);
      final version = (await _ok(
        DriftTranscriptRepository(
          database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).listVersions('meeting-1'),
      )).single;
      expect(
        version.run.state,
        const AnalysisFailed(
          startedAtUtcMs: 3,
          endedAtUtcMs: 4,
          progress: 0,
          failureCode: 'transcription_cancelled',
        ),
      );
    });

    test(
      'only the first completed version is selected automatically',
      () async {
        await _seedTranscription(database);
        for (var index = 1; index <= 2; index += 1) {
          final run = _jobRun('run-$index', createdAt: index + 1);
          final job = _transcriptionJob(
            'job-$index',
            run.id,
            createdAt: index + 1,
          );
          await _ok(jobs.enqueue(job, run, storedAtUtcMs: index + 1));
          await _ok(jobs.start(job.id, startedAtUtcMs: index + 3));
          await _ok(
            jobs.complete(
              job.id,
              _completedJobRun(
                run.id,
                createdAt: index + 1,
                startedAt: index + 3,
                endedAt: index + 4,
              ),
              [
                _timedSegment(
                  'segment-$index',
                  run.id,
                  'text $index',
                  startSeconds: 0,
                ),
              ],
              storedAtUtcMs: index + 4,
            ),
          );
        }

        final versions = await _ok(
          DriftTranscriptRepository(
            database,
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ).listVersions('meeting-1'),
        );
        expect(versions, hasLength(2));
        expect(
          versions.singleWhere((version) => version.isCurrent).run.id,
          'run-1',
        );
      },
    );

    test('illegal state transitions are rejected without mutation', () async {
      await _seedTranscription(database);
      final run = _jobRun('run-1', createdAt: 2);
      final job = _transcriptionJob('job-1', run.id, createdAt: 2);
      await _ok(jobs.enqueue(job, run, storedAtUtcMs: 2));

      expect(
        await jobs.saveProgress(
          job.id,
          progress: 0.1,
          checkpoint: const TranscriptionCheckpoint(
            completedMedia: Duration(seconds: 1),
            parameterVersion: 1,
          ),
          storedAtUtcMs: 3,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect(
        await jobs.fail(
          job.id,
          failureCode: 'inference_execution_failed',
          failedAtUtcMs: 3,
        ),
        isA<Err<ProcessingJob, AnalysisRepositoryFailure>>(),
      );
      expect((await _ok(jobs.load(job.id))).state, const ProcessingQueued());
    });
  });

  test('model manifests are complete, idempotent, and immutable', () async {
    final model = _model();

    expect(
      await repository.registerBundled(model, observedAtUtcMs: 10),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(
      await repository.registerBundled(model, observedAtUtcMs: 11),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(
      await repository.registerBundled(
        model.copyWith(
          capabilities: model.capabilities.reversed.toList(),
          enabledModes: model.enabledModes.reversed.toList(),
        ),
        observedAtUtcMs: 11,
      ),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(await _ok(repository.listInstalled()), [model]);

    final conflict = await repository.registerBundled(
      model.copyWith(sha256: 'different-hash'),
      observedAtUtcMs: 12,
    );
    expect(
      (conflict as Err<InstalledModel, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    expect(await _ok(repository.listInstalled()), [model]);
  });

  test(
    'model child-write failure rolls back the manifest transaction',
    () async {
      await database.customStatement('''
      CREATE TRIGGER fail_model_capability
      BEFORE INSERT ON model_capability_entries
      BEGIN
        SELECT RAISE(ABORT, 'simulated capability failure');
      END
      ''');

      final result = await repository.registerBundled(
        _model(),
        observedAtUtcMs: 1,
      );

      expect(
        (result as Err<InstalledModel, AnalysisRepositoryFailure>).failure,
        isA<AnalysisStoreUnavailable>(),
      );
      expect(await _tableCount(database, 'model_manifests'), 0);
      expect(await _tableCount(database, 'model_capability_entries'), 0);
    },
  );

  test(
    'parallel transcript versions require explicit current selection',
    () async {
      await _insertMeeting(database, 'meeting-1');
      await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      final firstRun = _run('run-1', createdAt: 2);
      final secondRun = _run('run-2', createdAt: 4);

      await _ok(
        transcripts.saveVersion(
          firstRun,
          [_segment('segment-1', 'run-1', 'first')],
          storedAtUtcMs: 2,
        ),
      );
      await _ok(
        transcripts.selectCurrent('meeting-1', 'run-1', selectedAtUtcMs: 3),
      );
      await _ok(
        transcripts.saveVersion(
          secondRun,
          [_segment('segment-2', 'run-2', 'second')],
          storedAtUtcMs: 4,
        ),
      );

      final retained = await _ok(transcripts.listVersions('meeting-1'));
      expect(retained.map((version) => version.run.id), ['run-2', 'run-1']);
      expect(
        retained.singleWhere((version) => version.isCurrent).run.id,
        'run-1',
      );
      expect(retained.last.segments.single.rawModelText, 'first');

      await _ok(
        transcripts.selectCurrent('meeting-1', 'run-2', selectedAtUtcMs: 5),
      );
      final selected = await _ok(transcripts.listVersions('meeting-1'));
      expect(
        selected.singleWhere((version) => version.isCurrent).run.id,
        'run-2',
      );
      expect(selected, hasLength(2));
    },
  );

  test('text and language corrections preserve machine evidence', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    final transcripts = DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _ok(
      transcripts.saveVersion(
        _run('run-1', createdAt: 2),
        [_segment('segment-1', 'run-1', 'machine text')],
        storedAtUtcMs: 2,
      ),
    );
    await _insertAutomaticLanguage(database);

    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-language',
          meetingId: 'meeting-1',
          targetId: 'segment-1',
          change: LanguageLabelChange(
            previous: LanguageTag.chinese,
            revised: LanguageTag.mixed,
          ),
          createdAtUtcMs: 4,
        ),
      ),
    );
    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-text',
          meetingId: 'meeting-1',
          targetId: 'segment-1',
          change: TranscriptTextChange(
            previousText: 'machine text',
            revisedText: 'human text',
          ),
          createdAtUtcMs: 3,
        ),
      ),
    );

    final version = (await _ok(transcripts.listVersions('meeting-1'))).single;
    final corrected = version.segments.single;
    expect(corrected.rawModelText, 'machine text');
    expect(corrected.displayedText, 'human text');
    expect(corrected.revisionState, TranscriptRevisionState.corrected);
    expect(corrected.languageDecisionId, 'revision-language:language');
    expect(await _tableCount(database, 'language_decisions'), 2);
    expect(await _ok(revisions.listMeeting('meeting-1')), hasLength(2));

    await _ok(
      transcripts.saveVersion(
        _run('run-2', createdAt: 5),
        [_segment('segment-2', 'run-2', 'new machine text')],
        storedAtUtcMs: 5,
      ),
    );
    final retained = await _ok(transcripts.listVersions('meeting-1'));
    expect(
      retained
          .singleWhere((version) => version.run.id == 'run-1')
          .segments
          .single
          .displayedText,
      'human text',
    );
  });

  test('speaker corrections project without mutating raw analysis', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    await _insertSpeakerAnalysis(database);
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    const rawSpeaker = Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-1',
      analysisRunId: 'diarization-1',
      label: 'Speaker 1',
    );
    const rawAssignment = SpeakerAssignment(
      id: 'assignment-1',
      analysisRunId: 'diarization-1',
      speakerId: 'speaker-1',
      start: Duration.zero,
      end: Duration(seconds: 1),
      confidence: 0.7,
      isOverlap: false,
      needsConfirmation: false,
    );

    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-speaker-label',
          meetingId: 'meeting-1',
          targetId: 'speaker-1',
          change: SpeakerLabelChange(
            previous: 'Speaker 1',
            revised: 'Alice',
          ),
          createdAtUtcMs: 3,
        ),
      ),
    );
    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-speaker-assignment',
          meetingId: 'meeting-1',
          targetId: 'assignment-1',
          change: SpeakerAssignmentChange(
            start: Duration.zero,
            end: Duration(seconds: 1),
            previousSpeakerId: 'speaker-1',
            revisedSpeakerId: null,
            needsConfirmation: true,
          ),
          createdAtUtcMs: 4,
        ),
      ),
    );

    expect(
      (await _ok(revisions.materializeSpeaker(rawSpeaker))).label,
      'Alice',
    );
    final projected = await _ok(
      revisions.materializeSpeakerAssignment(rawAssignment),
    );
    expect(projected.speakerId, isNull);
    expect(projected.needsConfirmation, isTrue);
    final rawSpeakerRow = await database
        .customSelect("SELECT label FROM speakers WHERE id = 'speaker-1'")
        .getSingle();
    final rawAssignmentRow = await database
        .customSelect(
          "SELECT speaker_id FROM speaker_assignments WHERE id = 'assignment-1'",
        )
        .getSingle();
    expect(rawSpeakerRow.read<String>('label'), 'Speaker 1');
    expect(rawAssignmentRow.read<String>('speaker_id'), 'speaker-1');

    final olderLabel = await revisions.apply(
      const Revision(
        id: 'revision-older-label',
        meetingId: 'meeting-1',
        targetId: 'speaker-1',
        change: SpeakerLabelChange(previous: 'Alice', revised: 'Bob'),
        createdAtUtcMs: 2,
      ),
    );
    expect(
      (olderLabel as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    final sameTimeEarlierLabelId = await revisions.apply(
      const Revision(
        id: 'a-label',
        meetingId: 'meeting-1',
        targetId: 'speaker-1',
        change: SpeakerLabelChange(previous: 'Alice', revised: 'Bob'),
        createdAtUtcMs: 3,
      ),
    );
    expect(
      (sameTimeEarlierLabelId as Err<Revision, AnalysisRepositoryFailure>)
          .failure,
      isA<AnalysisConflict>(),
    );
    final olderAssignment = await revisions.apply(
      const Revision(
        id: 'revision-older-assignment',
        meetingId: 'meeting-1',
        targetId: 'assignment-1',
        change: SpeakerAssignmentChange(
          start: Duration.zero,
          end: Duration(seconds: 1),
          previousSpeakerId: null,
          revisedSpeakerId: 'speaker-1',
          needsConfirmation: false,
        ),
        createdAtUtcMs: 3,
      ),
    );
    expect(
      (olderAssignment as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    final sameTimeEarlierId = await revisions.apply(
      const Revision(
        id: 'a',
        meetingId: 'meeting-1',
        targetId: 'assignment-1',
        change: SpeakerAssignmentChange(
          start: Duration.zero,
          end: Duration(seconds: 1),
          previousSpeakerId: null,
          revisedSpeakerId: 'speaker-1',
          needsConfirmation: false,
        ),
        createdAtUtcMs: 4,
      ),
    );
    expect(
      (sameTimeEarlierId as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    expect(
      (await _ok(revisions.materializeSpeaker(rawSpeaker))).label,
      'Alice',
    );
    expect(
      (await _ok(
        revisions.materializeSpeakerAssignment(rawAssignment),
      )).speakerId,
      isNull,
    );
  });

  test('revision insert failure rolls back the corrected projection', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    final transcripts = DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _ok(
      transcripts.saveVersion(
        _run('run-1', createdAt: 2),
        [_segment('segment-1', 'run-1', 'machine text')],
        storedAtUtcMs: 2,
      ),
    );
    await database.customStatement('''
      CREATE TRIGGER fail_revision_insert
      BEFORE INSERT ON revisions
      BEGIN
        SELECT RAISE(ABORT, 'simulated revision failure');
      END
      ''');

    final result = await revisions.apply(
      const Revision(
        id: 'revision-text',
        meetingId: 'meeting-1',
        targetId: 'segment-1',
        change: TranscriptTextChange(
          previousText: 'machine text',
          revisedText: 'must roll back',
        ),
        createdAtUtcMs: 3,
      ),
    );

    expect(
      (result as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisStoreUnavailable>(),
    );
    final version = (await _ok(transcripts.listVersions('meeting-1'))).single;
    expect(version.segments.single.displayedText, 'machine text');
    expect(
      version.segments.single.revisionState,
      TranscriptRevisionState.machine,
    );
    expect(await _tableCount(database, 'revisions'), 0);
  });
}

InstalledModel _model() => InstalledModel(
  id: 'whisper-base-q5',
  version: '1',
  source: 'bundled-test-fixture',
  sha256: 'verified-hash',
  bytes: 42,
  capabilities: const <ModelCapability>[
    ModelCapability.transcription,
    ModelCapability.languageIdentification,
  ],
  expectedEngineId: 'whisper.cpp',
  licenseId: 'MIT',
  licenseSnapshotPath: _path('licenses/whisper.txt'),
  enabledModes: const <PerformanceMode>[
    PerformanceMode.balanced,
    PerformanceMode.postSession,
  ],
);

AppRelativePath _path(String value) =>
    switch (AppRelativePath.tryParse(value)) {
      Ok(:final value) => value,
      Err() => throw TestFailure('invalid test path'),
    };

TranscriptRun _run(String id, {required int createdAt}) => TranscriptRun(
  id: id,
  meetingId: 'meeting-1',
  provenance: const InferenceProvenance(
    engineId: 'whisper.cpp',
    engineVersion: '1',
    modelId: 'whisper-base-q5',
    modelVersion: '1',
    modelSha256: 'verified-hash',
    parametersJson: '{}',
  ),
  createdAtUtcMs: createdAt,
  state: const AnalysisQueued(),
);

TranscriptRun _jobRun(String id, {required int createdAt}) => TranscriptRun(
  id: id,
  meetingId: 'meeting-1',
  provenance: const InferenceProvenance(
    engineId: 'whisper.cpp',
    engineVersion: '1',
    modelId: 'whisper-base-q5',
    modelVersion: '1',
    modelSha256: 'verified-hash',
    parametersJson: '{"parameterVersion":1}',
  ),
  createdAtUtcMs: createdAt,
  state: const AnalysisQueued(),
);

TranscriptRun _completedJobRun(
  String id, {
  required int createdAt,
  required int startedAt,
  required int endedAt,
  String engineVersion = '1',
}) => TranscriptRun(
  id: id,
  meetingId: 'meeting-1',
  provenance: InferenceProvenance(
    engineId: 'whisper.cpp',
    engineVersion: engineVersion,
    modelId: 'whisper-base-q5',
    modelVersion: '1',
    modelSha256: 'verified-hash',
    parametersJson: '{"parameterVersion":1}',
  ),
  createdAtUtcMs: createdAt,
  state: AnalysisCompleted(
    startedAtUtcMs: startedAt,
    endedAtUtcMs: endedAt,
  ),
);

ProcessingJob _transcriptionJob(
  String id,
  String runId, {
  required int createdAt,
}) => ProcessingJob(
  id: id,
  meetingId: 'meeting-1',
  kind: ProcessingJobKind.transcription,
  createdAtUtcMs: createdAt,
  state: const ProcessingQueued(),
  targetRunId: runId,
  modelId: 'whisper-base-q5',
);

TranscriptSegment _timedSegment(
  String id,
  String runId,
  String text, {
  required int startSeconds,
}) => TranscriptSegment(
  id: id,
  transcriptRunId: runId,
  start: Duration(seconds: startSeconds),
  end: Duration(seconds: startSeconds + 1),
  rawModelText: text,
  displayedText: text,
  revisionState: TranscriptRevisionState.machine,
);

TranscriptSegment _segment(String id, String runId, String text) =>
    TranscriptSegment(
      id: id,
      transcriptRunId: runId,
      start: Duration.zero,
      end: const Duration(seconds: 1),
      rawModelText: text,
      displayedText: text,
      revisionState: TranscriptRevisionState.machine,
    );

Future<void> _insertMeeting(db.AppDatabase database, String id) =>
    database.customStatement(
      '''
      INSERT INTO meetings (
        id, created_at, updated_at, title, media_duration_us,
        lifecycle, language_mode
      ) VALUES (?, 1, 1, ?, 0, 'finalized', 'mixed')
      ''',
      <Object>[id, id],
    );

Future<void> _seedTranscription(db.AppDatabase database) async {
  await _insertMeeting(database, 'meeting-1');
  await _ok(
    DriftModelRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    ).registerBundled(_model(), observedAtUtcMs: 1),
  );
}

Future<void> _insertAutomaticLanguage(db.AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO language_decisions (
      id, created_at, updated_at, transcript_segment_id, tag, source, confidence
    ) VALUES ('language-auto', 2, 2, 'segment-1', 'chinese', 'automatic', 0.9)
    ''');
  await database.customStatement('''
    INSERT INTO transcript_language_selections (
      id, created_at, updated_at, transcript_segment_id, language_decision_id
    ) VALUES ('language-selection', 2, 2, 'segment-1', 'language-auto')
    ''');
}

Future<int> _tableCount(db.AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<void> _insertSpeakerAnalysis(db.AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO diarization_runs (
      id, created_at, updated_at, meeting_id, engine_id, engine_version,
      model_id, model_version, model_sha256, parameters_json, run_state
    ) VALUES (
      'diarization-1', 2, 2, 'meeting-1', 'whisper.cpp', '1',
      'whisper-base-q5', '1', 'verified-hash', '{}', 'queued'
    )
    ''');
  await database.customStatement('''
    INSERT INTO speakers (
      id, created_at, updated_at, meeting_id, analysis_run_id, label
    ) VALUES ('speaker-1', 2, 2, 'meeting-1', 'diarization-1', 'Speaker 1')
    ''');
  await database.customStatement('''
    INSERT INTO speaker_assignments (
      id, created_at, updated_at, meeting_id, analysis_run_id,
      speaker_id, speaker_analysis_run_id, start_us, end_us,
      confidence, is_overlap, needs_confirmation
    ) VALUES (
      'assignment-1', 2, 2, 'meeting-1', 'diarization-1',
      'speaker-1', 'diarization-1', 0, 1000000, 0.7, 0, 0
    )
    ''');
}

Future<T> _ok<T>(Future<Result<T, AnalysisRepositoryFailure>> result) async {
  return switch (await result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('Unexpected ${failure.code}'),
  };
}
