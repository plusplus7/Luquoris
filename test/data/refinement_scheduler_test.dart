import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_meeting_processing_selection_repository.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/data/repositories/drift_transcript_processing_repository.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/refinement_scheduler.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';

import '../support/model_bundle_fixture.dart';

void main() {
  late _SchedulerFixture fixture;
  setUp(() async {
    fixture = await _SchedulerFixture.create();
  });
  tearDown(() => fixture.database.close());

  test(
    'legacy absence and explicit recording-only never create optional work',
    () async {
      expect(_ok(await fixture.scheduler().schedule('meeting')), isNull);
      _ok(
        await fixture.selections.save(
          'meeting',
          const MeetingProcessingSelection.recordingOnly(),
          storedAtUtcMs: 2,
        ),
      );
      await fixture.finalize();
      fixture.audio.outcome = const Err(
        RefinementAudioUnavailable('transcription_audio_missing'),
      );
      expect(_ok(await fixture.scheduler().schedule('meeting')), isNull);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.modelManifests).get(),
        isEmpty,
      );
    },
  );

  test(
    'finalization and durable complete inventory are required before queueing',
    () async {
      await fixture.choose();
      expect(
        await fixture.scheduler().schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      await fixture.finalize(withAudio: false);
      expect(
        await fixture.scheduler().schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
      await fixture.insertAudio();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(job.state, const ProcessingQueued());
      final info = _ok(await fixture.processing.load(job.targetRunId!))!;
      expect(info.role, TranscriptProcessingRole.refinement);
      expect(info.audioInventorySha256, 'a' * 64);
      expect(info.bundleManifestJson, _profile().bundleManifestJson);
      expect(
        await fixture.database
            .select(fixture.database.meetingTranscriptSelections)
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'concurrent repeated notifications and a new coordinator reuse one durable job',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final scheduler = fixture.scheduler();
      final results = await Future.wait([
        scheduler.schedule('meeting'),
        scheduler.schedule('meeting'),
        fixture.scheduler().schedule('meeting'),
      ]);
      final jobs = results.map(_ok).toList();
      expect(jobs.map((job) => job!.id).toSet(), hasLength(1));
      expect(_ok(await fixture.scheduler().schedule('meeting')), jobs.first);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(1),
      );
      expect(
        await fixture.database.select(fixture.database.transcriptRuns).get(),
        hasLength(1),
      );
    },
  );

  test(
    'missing corrupt or recording-deferred input does not publish jobs or models',
    () async {
      await fixture.choose();
      await fixture.finalize();
      for (final failure in <RefinementAudioFailure>[
        const RefinementAudioUnavailable('transcription_audio_missing'),
        const RefinementAudioUnavailable('transcription_audio_segment_corrupt'),
        const RefinementAudioDeferred('refinement_recording_active'),
        const RefinementAudioCancelled(),
      ]) {
        fixture.audio.outcome = Err(failure);
        expect(
          await fixture.scheduler().schedule('meeting'),
          isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
        );
        expect(
          await fixture.database.select(fixture.database.processingJobs).get(),
          isEmpty,
        );
        expect(
          await fixture.database.select(fixture.database.modelManifests).get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'restored job run and catalog IDs are matched semantically not rederived',
    () async {
      await fixture.choose();
      await fixture.finalize();
      _ok(await fixture.scheduler().schedule('meeting'));
      await fixture.database.transaction(() async {
        await fixture.database.customStatement(
          'PRAGMA defer_foreign_keys = ON',
        );
        await fixture.database.customStatement(
          "UPDATE model_manifests SET id='restored-model'",
        );
        for (final table in [
          'model_capability_entries',
          'model_mode_entries',
          'transcript_runs',
          'processing_jobs',
        ]) {
          await fixture.database.customStatement(
            "UPDATE $table SET model_id='restored-model'",
          );
        }
        await fixture.database.customStatement(
          "UPDATE transcript_runs SET id='restored-run'",
        );
        await fixture.database.customStatement(
          "UPDATE transcript_processing_metadata SET id='restored-metadata', transcript_run_id='restored-run'",
        );
        await fixture.database.customStatement(
          "UPDATE processing_jobs SET id='restored-job', transcript_run_id='restored-run'",
        );
      });
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(job.id, 'restored-job');
      expect(job.targetRunId, 'restored-run');
      expect(job.modelId, 'restored-model');
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(1),
      );
    },
  );

  test(
    'retained live draft is linked without becoming current or being overwritten',
    () async {
      final profile = _profile();
      await fixture.choose(twoPass: true);
      _ok(
        await fixture.models.registerBundled(
          profile.manifest.toInstalledModel(),
          observedAtUtcMs: 2,
        ),
      );
      _ok(
        await fixture.processing.saveLiveVersion(
          TranscriptRun(
            id: 'live',
            meetingId: 'meeting',
            provenance: profile.provenance,
            createdAtUtcMs: 1,
            state: const AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2),
          ),
          const [
            TranscriptSegment(
              id: 'live-segment',
              transcriptRunId: 'live',
              start: Duration.zero,
              end: Duration(milliseconds: 64),
              rawModelText: 'draft ONNX',
              displayedText: 'draft ONNX',
              revisionState: TranscriptRevisionState.machine,
            ),
          ],
          TranscriptProcessingInfo(
            role: TranscriptProcessingRole.liveDraft,
            completeness: TranscriptCompleteness.incomplete,
            bundleManifestJson: profile.bundleManifestJson,
          ),
          storedAtUtcMs: 2,
        ),
      );
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      final info = _ok(await fixture.processing.load(job.targetRunId!))!;
      expect(info.sourceRunId, 'live');
      final versions = _ok(await fixture.transcripts.listVersions('meeting'));
      expect(versions, hasLength(2));
      expect(versions.every((version) => !version.isCurrent), isTrue);
      expect(
        versions
            .singleWhere((version) => version.run.id == 'live')
            .segments
            .single
            .rawModelText,
        'draft ONNX',
      );
    },
  );

  test(
    'a compatible existing catalog alias backs a newly queued run',
    () async {
      final profile = _profile();
      await fixture.choose();
      _ok(
        await fixture.models.registerBundled(
          profile.manifest.toInstalledModel(),
          observedAtUtcMs: 2,
        ),
      );
      await fixture.database.transaction(() async {
        await fixture.database.customStatement(
          'PRAGMA defer_foreign_keys = ON',
        );
        await fixture.database.customStatement(
          "UPDATE model_manifests SET id='existing-alias'",
        );
        for (final table in [
          'model_capability_entries',
          'model_mode_entries',
        ]) {
          await fixture.database.customStatement(
            "UPDATE $table SET model_id='existing-alias'",
          );
        }
      });
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(job.modelId, 'existing-alias');
      expect(
        _ok(await fixture.jobs.loadRun(job.targetRunId!)).provenance.modelId,
        'existing-alias',
      );
      expect(
        _ok(
          await fixture.processing.load(job.targetRunId!),
        )!.bundleManifestJson,
        profile.bundleManifestJson,
      );
      expect(
        await fixture.database.select(fixture.database.modelManifests).get(),
        hasLength(1),
      );
    },
  );

  test(
    'same hash with conflicting catalog source never silently substitutes',
    () async {
      await fixture.choose();
      final incompatible = _profile().manifest.toInstalledModel().copyWith(
        source: 'https://different.test/model',
      );
      _ok(
        await fixture.models.registerBundled(incompatible, observedAtUtcMs: 2),
      );
      await fixture.finalize();
      expect(
        await fixture.scheduler().schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
      expect(
        _ok(await fixture.models.listInstalled()).single.source,
        incompatible.source,
      );
    },
  );

  test(
    'failed atomic publication can retry without an orphan run or duplicate job',
    () async {
      await fixture.choose();
      await fixture.finalize();
      await fixture.database.customStatement('''
      CREATE TRIGGER reject_scheduled_metadata BEFORE INSERT ON transcript_processing_metadata
      BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
      final scheduler = fixture.scheduler();
      expect(
        await scheduler.schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.transcriptRuns).get(),
        isEmpty,
      );
      await fixture.database.customStatement(
        'DROP TRIGGER reject_scheduled_metadata',
      );
      expect(_ok(await scheduler.schedule('meeting')), isNotNull);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(1),
      );
      expect(
        await fixture.database.select(fixture.database.transcriptRuns).get(),
        hasLength(1),
      );
    },
  );

  test(
    'database and native inventory disagreement is rejected instead of filtering input',
    () async {
      await fixture.choose();
      await fixture.finalize();
      fixture.audio.outcome = Ok(
        RefinementAudioInventory(
          sha256: 'a' * 64,
          totalSamples: 2_048,
          segments: [_nativeSegment(), _nativeSegment(index: 1, start: 1_024)],
        ),
      );
      expect(
        await fixture.scheduler().schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
    },
  );

  test(
    'same aggregate duration cannot prove per-segment timeline agreement',
    () async {
      await fixture.choose();
      await fixture.finalize();
      await fixture.database
          .into(fixture.database.audioSegments)
          .insert(
            db.AudioSegmentsCompanion.insert(
              id: 'audio-2',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'meeting',
              sequence: 1,
              relativePath: 'recordings/key/second.adts',
              mediaStartUs: 64_000,
              mediaDurationUs: 128_000,
              committedBytes: 22,
              state: 'committed',
            ),
          );
      await fixture.database.customStatement(
        'UPDATE meetings SET media_duration_us=192000',
      );
      fixture.audio.outcome = Ok(
        RefinementAudioInventory(
          sha256: 'a' * 64,
          totalSamples: 3_072,
          segments: [
            _nativeSegment(samples: 2_048, bytes: 22),
            _nativeSegment(index: 1, start: 2_048),
          ],
        ),
      );
      expect(
        await fixture.scheduler().schedule('meeting'),
        isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
    },
  );

  test(
    'same local duration cannot hide byte or file-reference mismatch',
    () async {
      await fixture.choose();
      await fixture.finalize();
      for (final segment in [
        _nativeSegment(bytes: 12),
        _nativeSegment(reference: '0' * 64),
      ]) {
        fixture.audio.outcome = Ok(
          RefinementAudioInventory(
            sha256: 'a' * 64,
            totalSamples: 1_024,
            segments: [segment],
          ),
        );
        expect(
          await fixture.scheduler().schedule('meeting'),
          isA<Err<ProcessingJob?, RefinementScheduleFailure>>(),
        );
        expect(
          await fixture.database.select(fixture.database.processingJobs).get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'different prior decoding settings do not block a distinct requested run',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final prior = _ok(
        ProcessingModelProfile.tryCreate(
          bundleManifestJson: _profile().bundleManifestJson,
          engineVersion: '1.0.0',
          parametersJson: '{"parameterVersion":2}',
        ),
      );
      _ok(
        await fixture.models.registerBundled(
          prior.manifest.toInstalledModel(),
          observedAtUtcMs: 2,
        ),
      );
      _ok(
        await fixture.processing.enqueueRefinement(
          const ProcessingJob(
            id: 'prior-job',
            meetingId: 'meeting',
            kind: ProcessingJobKind.transcription,
            createdAtUtcMs: 1,
            state: ProcessingQueued(),
            targetRunId: 'prior-run',
            modelId: 'test-bundle',
          ),
          TranscriptRun(
            id: 'prior-run',
            meetingId: 'meeting',
            provenance: prior.provenance,
            createdAtUtcMs: 1,
            state: const AnalysisQueued(),
          ),
          TranscriptProcessingInfo(
            role: TranscriptProcessingRole.refinement,
            completeness: TranscriptCompleteness.incomplete,
            bundleManifestJson: prior.bundleManifestJson,
            audioInventorySha256: 'a' * 64,
          ),
          storedAtUtcMs: 3,
        ),
      );
      final requested = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(requested.id, isNot('prior-job'));
      expect(_ok(await fixture.scheduler().schedule('meeting')), requested);
      expect(
        _ok(await fixture.jobs.loadRun('prior-run')).provenance.parametersJson,
        '{"parameterVersion":2}',
      );
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(2),
      );
    },
  );

  test(
    'legacy startup recovery does not hand paired work to the old engine',
    () async {
      await fixture.choose();
      await fixture.finalize();
      _ok(await fixture.scheduler().schedule('meeting'));
      expect(_ok(await fixture.jobs.listRecoverable()), isEmpty);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(1),
      );
    },
  );

  test('legacy orphan recovery never rewrites running paired state', () async {
    await fixture.choose();
    await fixture.finalize();
    final job = _ok(await fixture.scheduler().schedule('meeting'))!;
    await fixture.database.customStatement(
      "UPDATE transcript_runs SET run_state='running', started_at_utc_ms=10",
    );
    await fixture.database.customStatement(
      "UPDATE processing_jobs SET job_state='running', progress=0",
    );
    expect(
      _ok(await fixture.jobs.recoverOrphanedRunning(recoveredAtUtcMs: 12)),
      isEmpty,
    );
    expect(
      _ok(await fixture.jobs.load(job.id)).state,
      const ProcessingRunning(progress: 0),
    );
    expect(
      (_ok(await fixture.jobs.loadRun(job.targetRunId!)).state
              as AnalysisRunning)
          .startedAtUtcMs,
      10,
    );
  });

  test(
    'explicit refinement claim and resource pause retain checkpoint and identity',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(
        _ok(await fixture.processing.listRecoverableRefinements()).single.id,
        job.id,
      );
      expect(
        _ok(
          await fixture.processing.startRefinement(job.id, startedAtUtcMs: 11),
        ).state,
        const ProcessingRunning(progress: 0),
      );
      const checkpoint = TranscriptionCheckpoint(
        completedMedia: Duration(milliseconds: 32),
        parameterVersion: 1,
      );
      _ok(
        await fixture.jobs.saveProgress(
          job.id,
          progress: .5,
          checkpoint: checkpoint,
          storedAtUtcMs: 12,
        ),
      );
      final paused = _ok(
        await fixture.processing.pauseRefinement(
          job.id,
          reasonCode: 'refinement_recording_active',
          pausedAtUtcMs: 13,
        ),
      );
      expect(
        paused.state,
        const ProcessingPaused(reasonCode: 'refinement_recording_active'),
      );
      expect(paused.transcriptionCheckpoint, checkpoint);
      final revision =
          (await fixture.database
                  .select(fixture.database.processingJobs)
                  .getSingle())
              .rowRevision;
      _ok(
        await fixture.processing.pauseRefinement(
          job.id,
          reasonCode: 'refinement_recording_active',
          pausedAtUtcMs: 14,
        ),
      );
      expect(
        (await fixture.database
                .select(fixture.database.processingJobs)
                .getSingle())
            .rowRevision,
        revision,
      );
      final resumed = _ok(
        await fixture.processing.startRefinement(job.id, startedAtUtcMs: 15),
      );
      expect(resumed.state, const ProcessingRunning(progress: .5));
      expect(resumed.targetRunId, job.targetRunId);
      expect(resumed.transcriptionCheckpoint, checkpoint);
      expect(
        _ok(await fixture.processing.load(job.targetRunId!))!.completeness,
        TranscriptCompleteness.incomplete,
      );
    },
  );

  test('failed pause publication rolls back both job and run state', () async {
    await fixture.choose();
    await fixture.finalize();
    final job = _ok(await fixture.scheduler().schedule('meeting'))!;
    _ok(await fixture.processing.startRefinement(job.id, startedAtUtcMs: 11));
    await fixture.database.customStatement('''
      CREATE TRIGGER reject_refinement_pause BEFORE UPDATE ON processing_jobs
      WHEN NEW.job_state='paused' BEGIN SELECT RAISE(ABORT, 'injected'); END
    ''');
    expect(
      (await fixture.processing.pauseRefinement(
        job.id,
        reasonCode: 'refinement_recording_active',
        pausedAtUtcMs: 12,
      )).isErr,
      isTrue,
    );
    expect(
      _ok(await fixture.jobs.load(job.id)).state,
      const ProcessingRunning(progress: 0),
    );
    expect(
      (_ok(await fixture.jobs.loadRun(job.targetRunId!)).state
              as AnalysisRunning)
          .startedAtUtcMs,
      11,
    );
  });

  for (final retry in [false, true]) {
    test(
      'trashed meeting rejects refinement ${retry ? 'retry' : 'claim'} without writes',
      () async {
        await fixture.choose();
        await fixture.finalize();
        final job = _ok(await fixture.scheduler().schedule('meeting'))!;
        if (retry) {
          _ok(
            await fixture.processing.startRefinement(
              job.id,
              startedAtUtcMs: 11,
            ),
          );
          _ok(
            await fixture.jobs.fail(
              job.id,
              failureCode: 'injected_failure',
              failedAtUtcMs: 12,
            ),
          );
        }
        _ok(
          await fixture.scheduler().sessions.moveToTrash(
            'meeting',
            atUtcMs: 13,
          ),
        );
        final beforeJob = _ok(await fixture.jobs.load(job.id));
        final beforeRun = _ok(await fixture.jobs.loadRun(job.targetRunId!));
        final result = retry
            ? await fixture.processing.retryRefinement(
                job.id,
                queuedAtUtcMs: 14,
              )
            : await fixture.processing.startRefinement(
                job.id,
                startedAtUtcMs: 14,
              );
        expect(result.isErr, isTrue);
        expect(_ok(await fixture.jobs.load(job.id)), beforeJob);
        expect(_ok(await fixture.jobs.loadRun(job.targetRunId!)), beforeRun);
      },
    );
  }

  test(
    'explicit retry preserves the same failed refinement provenance',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      final frozen = _ok(await fixture.processing.load(job.targetRunId!));
      _ok(await fixture.processing.startRefinement(job.id, startedAtUtcMs: 11));
      _ok(
        await fixture.jobs.fail(
          job.id,
          failureCode: 'injected_failure',
          failedAtUtcMs: 12,
        ),
      );
      final retried = _ok(
        await fixture.processing.retryRefinement(job.id, queuedAtUtcMs: 13),
      );
      expect(retried.state, const ProcessingQueued());
      expect(retried.targetRunId, job.targetRunId);
      expect(_ok(await fixture.processing.load(job.targetRunId!)), frozen);
      expect(
        _ok(
          await fixture.processing.startRefinement(job.id, startedAtUtcMs: 14),
        ).state,
        const ProcessingRunning(progress: 0),
      );
    },
  );

  test(
    'paired orphan recovery is separate from legacy recovery and claim',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      final profile = _profile();
      _ok(
        await fixture.jobs.enqueue(
          const ProcessingJob(
            id: 'legacy-job',
            meetingId: 'meeting',
            kind: ProcessingJobKind.transcription,
            createdAtUtcMs: 1,
            state: ProcessingQueued(),
            targetRunId: 'legacy-run',
            modelId: 'test-bundle',
          ),
          TranscriptRun(
            id: 'legacy-run',
            meetingId: 'meeting',
            provenance: profile.provenance,
            createdAtUtcMs: 1,
            state: const AnalysisQueued(),
          ),
          storedAtUtcMs: 2,
        ),
      );
      expect(
        (await fixture.processing.startRefinement(
          'legacy-job',
          startedAtUtcMs: 11,
        )).isErr,
        isTrue,
      );
      _ok(await fixture.jobs.start('legacy-job', startedAtUtcMs: 11));
      _ok(await fixture.processing.startRefinement(job.id, startedAtUtcMs: 11));
      final recovered = _ok(
        await fixture.processing.recoverOrphanedRefinements(
          recoveredAtUtcMs: 12,
        ),
      );
      expect(recovered.map((value) => value.id), [job.id]);
      expect(
        recovered.single.state,
        const ProcessingPaused(reasonCode: 'process_restarted'),
      );
      expect(
        _ok(await fixture.jobs.load('legacy-job')).state,
        const ProcessingRunning(progress: 0),
      );
      expect(
        _ok(
          await fixture.processing.listRecoverableRefinements(),
        ).map((value) => value.id),
        [job.id],
      );
      expect(
        _ok(
          await fixture.jobs.recoverOrphanedRunning(recoveredAtUtcMs: 13),
        ).single.id,
        'legacy-job',
      );
    },
  );

  test(
    'queued resource pause and invalid reason never fabricate execution',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      expect(
        (await fixture.processing.pauseRefinement(
          job.id,
          reasonCode: 'private/path',
          pausedAtUtcMs: 11,
        )).isErr,
        isTrue,
      );
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        const ProcessingQueued(),
      );
      final paused = _ok(
        await fixture.processing.pauseRefinement(
          job.id,
          reasonCode: 'refinement_thermal_high',
          pausedAtUtcMs: 12,
        ),
      );
      expect(
        paused.state,
        const ProcessingPaused(reasonCode: 'refinement_thermal_high'),
      );
      expect(
        _ok(await fixture.jobs.loadRun(job.targetRunId!)).state,
        const AnalysisQueued(),
      );
    },
  );

  test(
    'corrupt or deleted processing metadata cannot authorize refinement claim',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      await fixture.database.customStatement(
        "UPDATE transcript_processing_metadata SET bundle_manifest_json='{\"schemaVersion\":2}'",
      );
      expect(
        (await fixture.processing.startRefinement(
          job.id,
          startedAtUtcMs: 11,
        )).isErr,
        isTrue,
      );
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        const ProcessingQueued(),
      );
      await fixture.database.customStatement(
        'UPDATE transcript_processing_metadata SET bundle_manifest_json=?, is_deleted=1, deleted_at=12',
        [_profile().bundleManifestJson],
      );
      expect(
        (await fixture.processing.startRefinement(
          job.id,
          startedAtUtcMs: 13,
        )).isErr,
        isTrue,
      );
      expect(
        _ok(await fixture.processing.listRecoverableRefinements()),
        isEmpty,
      );
      expect(_ok(await fixture.jobs.listRecoverable()), isEmpty);
      expect(
        (await fixture.jobs.start(job.id, startedAtUtcMs: 13)).isErr,
        isTrue,
      );
    },
  );

  test('legacy start cannot claim a paired refinement job', () async {
    await fixture.choose();
    await fixture.finalize();
    final job = _ok(await fixture.scheduler().schedule('meeting'))!;
    expect(
      (await fixture.jobs.start(job.id, startedAtUtcMs: 11)).isErr,
      isTrue,
    );
    expect(
      _ok(await fixture.jobs.load(job.id)).state,
      const ProcessingQueued(),
    );
  });

  test(
    'legacy retry cannot reset failed paired work under the old runtime',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler().schedule('meeting'))!;
      await fixture.database.customStatement("""
      UPDATE transcript_runs SET run_state='failed', started_at_utc_ms=10,
        ended_at_utc_ms=11, progress=0, failure_code='injected_failure'
    """);
      await fixture.database.customStatement("""
      UPDATE processing_jobs SET job_state='failed', progress=0,
        failure_code='injected_failure'
    """);
      expect(
        (await fixture.jobs.retry(job.id, queuedAtUtcMs: 12)).isErr,
        isTrue,
      );
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        const ProcessingFailed(failureCode: 'injected_failure'),
      );
    },
  );

  test(
    'a file reopen recovers explicit selection and reuses queued work',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'loquiris-refinement-schedule-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await fixture.database.close();
      final file = File('${directory.path}/database.sqlite');
      fixture = await _SchedulerFixture.create(file: file);
      await fixture.choose();
      await fixture.finalize();
      final original = _ok(await fixture.scheduler().schedule('meeting'))!;
      await fixture.database.close();
      fixture = await _SchedulerFixture.create(file: file, seed: false);
      expect(_ok(await fixture.selections.listFinalized()), ['meeting']);
      expect(_ok(await fixture.scheduler().schedule('meeting')), original);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        hasLength(1),
      );
    },
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

ProcessingModelProfile _profile() => _ok(
  ProcessingModelProfile.tryCreate(
    bundleManifestJson: jsonEncode(modelBundleFixture()),
    engineVersion: '1.0.0',
    parametersJson: '{"parameterVersion":1}',
  ),
);

final class _SchedulerFixture {
  _SchedulerFixture(this.database);
  final db.AppDatabase database;
  final audio = _FakeInventoryService();
  late final selections = DriftMeetingProcessingSelectionRepository(
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
  late final models = DriftModelRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final transcripts = DriftTranscriptRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );

  static Future<_SchedulerFixture> create({
    File? file,
    bool seed = true,
  }) async {
    final fixture = _SchedulerFixture(
      db.AppDatabase(
        file == null ? NativeDatabase.memory() : NativeDatabase(file),
      ),
    );
    if (seed) {
      await fixture.database
          .into(fixture.database.meetings)
          .insert(
            db.MeetingsCompanion.insert(
              id: 'meeting',
              createdAt: 1,
              updatedAt: 1,
              title: 'meeting',
              lifecycle: 'draft',
              languageMode: 'mixed',
            ),
          );
    }
    return fixture;
  }

  RefinementScheduler scheduler() => RefinementScheduler(
    sessions: DriftSessionRepository(
      database,
      audioStore: _NoDeleteAudioStore(),
      diagnosticSink: const DisabledDiagnosticLogSink(),
    ),
    selections: selections,
    processing: processing,
    jobs: jobs,
    models: models,
    transcripts: transcripts,
    audio: audio,
    clock: Clock.fixed(DateTime.fromMillisecondsSinceEpoch(10, isUtc: true)),
  );

  Future<void> choose({bool twoPass = false}) async {
    final profile = _profile();
    _ok(
      await selections.save(
        'meeting',
        twoPass
            ? MeetingProcessingSelection.twoPass(
                live: profile,
                refinement: profile,
              )
            : MeetingProcessingSelection.postSession(refinement: profile),
        storedAtUtcMs: 2,
      ),
    );
  }

  Future<void> finalize({bool withAudio = true}) async {
    await database.customStatement(
      "UPDATE meetings SET lifecycle='finalized', media_duration_us=64000",
    );
    if (withAudio) await insertAudio();
  }

  Future<void> insertAudio() async {
    await database
        .into(database.audioSegments)
        .insert(
          db.AudioSegmentsCompanion.insert(
            id: 'audio',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'meeting',
            sequence: 0,
            relativePath: 'recordings/key/original.adts',
            mediaStartUs: 0,
            mediaDurationUs: 64_000,
            committedBytes: 11,
            state: 'committed',
          ),
        );
  }
}

final class _FakeInventoryService implements RefinementAudioInventoryService {
  Result<RefinementAudioInventory, RefinementAudioFailure> outcome = Ok(
    RefinementAudioInventory(
      sha256: 'a' * 64,
      totalSamples: 1_024,
      segments: [_nativeSegment()],
    ),
  );
  @override
  Future<Result<RefinementAudioInventory, RefinementAudioFailure>> inspect(
    String meetingId, {
    String? expectedSha256,
  }) async => outcome;
}

RefinementAudioSegmentInventory _nativeSegment({
  int index = 0,
  int start = 0,
  int samples = 1_024,
  int bytes = 11,
  String reference =
      '6ee5f51e2361291caf2b24775f631cdea3d8da46ae89559a5a2153df6f4d1b8d',
}) => RefinementAudioSegmentInventory(
  index: index,
  startSample: start,
  committedSamples: samples,
  committedBytes: bytes,
  sha256: 'b' * 64,
  referenceSha256: reference,
);

final class _NoDeleteAudioStore implements MeetingAudioStore {
  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> paths,
  ) async => throw StateError('scheduler must never delete audio');
}
