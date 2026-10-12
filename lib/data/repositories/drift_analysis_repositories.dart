import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

/// Drift-backed parallel transcript-version repository.
final class DriftTranscriptRepository implements TranscriptRepository {
  /// Creates a transcript repository over the shared local database.
  const DriftTranscriptRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  }) async {
    if (segments.any((segment) => segment.transcriptRunId != run.id)) {
      return const Err(AnalysisConflict());
    }
    try {
      await database.transaction(() async {
        final existing = await (database.select(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).getSingleOrNull();
        if (existing != null) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        final state = _storedAnalysisState(run.state);
        await database
            .into(database.transcriptRuns)
            .insert(
              db.TranscriptRunsCompanion.insert(
                id: run.id,
                createdAt: run.createdAtUtcMs,
                updatedAt: storedAtUtcMs,
                meetingId: run.meetingId,
                engineId: run.provenance.engineId,
                engineVersion: run.provenance.engineVersion,
                modelId: run.provenance.modelId,
                modelVersion: run.provenance.modelVersion,
                modelSha256: run.provenance.modelSha256,
                parametersJson: run.provenance.parametersJson,
                runState: state.name,
                startedAtUtcMs: Value(state.startedAtUtcMs),
                endedAtUtcMs: Value(state.endedAtUtcMs),
                progress: Value(state.progress),
                failureCode: Value(state.failureCode),
              ),
            );
        for (final segment in segments) {
          await database
              .into(database.transcriptSegments)
              .insert(
                db.TranscriptSegmentsCompanion.insert(
                  id: segment.id,
                  createdAt: storedAtUtcMs,
                  updatedAt: storedAtUtcMs,
                  meetingId: run.meetingId,
                  transcriptRunId: run.id,
                  startUs: segment.start.inMicroseconds,
                  endUs: segment.end.inMicroseconds,
                  rawModelText: segment.rawModelText,
                  displayedText: segment.displayedText,
                  revisionState: segment.revisionState.name,
                  speakerId: Value(segment.speakerId),
                  speakerMeetingId: Value(
                    segment.speakerId == null ? null : run.meetingId,
                  ),
                ),
              );
        }
      });
      return Ok(
        TranscriptVersion(run: run, segments: segments, isCurrent: false),
      );
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_version_save_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async {
    try {
      final runRows =
          await (database.select(database.transcriptRuns)
                ..where(
                  (row) =>
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                )
                ..orderBy([
                  (row) => OrderingTerm.desc(row.createdAt),
                  (row) => OrderingTerm.desc(row.id),
                ]))
              .get();
      final selection =
          await (database.select(
                database.meetingTranscriptSelections,
              )..where(
                (row) =>
                    row.meetingId.equals(meetingId) &
                    row.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      final versions = <TranscriptVersion>[];
      for (final runRow in runRows) {
        final segmentRows = await database
            .customSelect(
              '''
              SELECT ts.*, tls.language_decision_id
              FROM transcript_segments AS ts
              LEFT JOIN transcript_language_selections AS tls
                ON tls.transcript_segment_id = ts.id AND tls.is_deleted = 0
              WHERE ts.transcript_run_id = ? AND ts.is_deleted = 0
              ORDER BY ts.start_us, ts.id
              ''',
              variables: <Variable<Object>>[Variable<String>(runRow.id)],
            )
            .get();
        final segments = segmentRows.map(_readTranscriptSegment).toList();
        final associations = await _loadVersionAssociations(
          meetingId,
          segments,
        );
        versions.add(
          TranscriptVersion(
            run: _readTranscriptRun(runRow),
            segments: segments,
            isCurrent: selection?.transcriptRunId == runRow.id,
            languagesBySegmentId: associations.languages,
            speakersById: associations.speakers,
          ),
        );
      }
      return Ok(List<TranscriptVersion>.unmodifiable(versions));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_version_list_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async {
    try {
      final document = await database.transaction(() async {
        final meeting =
            await (database.select(database.meetings)..where(
                  (row) =>
                      row.id.equals(meetingId) & row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (meeting == null) {
          throw const _AnalysisStateError('analysis_not_found');
        }
        final revisionRows =
            await (database.select(database.revisions)
                  ..where(
                    (row) =>
                        row.meetingId.equals(meetingId) &
                        row.isDeleted.equals(false),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.createdAt),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        final revisions = revisionRows.map(_readRevision).toList();
        final selection =
            await (database.select(
                  database.meetingTranscriptSelections,
                )..where(
                  (row) =>
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        TranscriptVersion? currentVersion;
        final languages = <String, LanguageDecision>{};
        final speakers = <String, Speaker>{};
        if (selection != null) {
          final run =
              await (database.select(database.transcriptRuns)..where(
                    (row) =>
                        row.id.equals(selection.transcriptRunId) &
                        row.meetingId.equals(meetingId) &
                        row.isDeleted.equals(false),
                  ))
                  .getSingleOrNull();
          if (run == null) {
            throw const _AnalysisStateError('analysis_not_found');
          }
          final segmentRows = await database
              .customSelect(
                '''
                SELECT ts.*, tls.language_decision_id
                FROM transcript_segments AS ts
                LEFT JOIN transcript_language_selections AS tls
                  ON tls.transcript_segment_id = ts.id AND tls.is_deleted = 0
                WHERE ts.transcript_run_id = ? AND ts.is_deleted = 0
                ORDER BY ts.start_us, ts.id
                ''',
                variables: <Variable<Object>>[
                  Variable<String>(selection.transcriptRunId),
                ],
              )
              .get();
          final segments = segmentRows.map(_readTranscriptSegment).toList();
          for (final segment in segments) {
            if (segment.languageDecisionId case final decisionId?) {
              final decision =
                  await (database.select(database.languageDecisions)..where(
                        (row) =>
                            row.id.equals(decisionId) &
                            row.transcriptSegmentId.equals(segment.id) &
                            row.isDeleted.equals(false),
                      ))
                      .getSingleOrNull();
              if (decision != null) {
                languages[segment.id] = _readLanguageDecision(decision);
              }
            }
            if (segment.speakerId case final speakerId?) {
              if (speakers.containsKey(speakerId)) continue;
              final speakerRow =
                  await (database.select(database.speakers)..where(
                        (row) =>
                            row.id.equals(speakerId) &
                            row.meetingId.equals(meetingId) &
                            row.isDeleted.equals(false),
                      ))
                      .getSingleOrNull();
              if (speakerRow != null) {
                var speaker = _readSpeaker(speakerRow);
                for (final revision in revisions) {
                  if (revision.targetId != speakerId) continue;
                  if (revision.change case final SpeakerLabelChange change) {
                    speaker = speaker.copyWith(label: change.revised);
                  }
                }
                speakers[speakerId] = speaker;
              }
            }
          }
          currentVersion = TranscriptVersion(
            run: _readTranscriptRun(run),
            segments: segments,
            isCurrent: true,
            languagesBySegmentId: languages,
            speakersById: speakers,
          );
        }
        return TranscriptEditorDocument(
          meetingId: meetingId,
          lifecycle: MeetingLifecycle.values.byName(meeting.lifecycle),
          currentVersion: currentVersion,
          languagesBySegmentId: languages,
          speakersById: speakers,
          revisions: revisions,
        );
      });
      return Ok(document);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_editor_load_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  Future<
    ({
      Map<String, LanguageDecision> languages,
      Map<String, Speaker> speakers,
    })
  >
  _loadVersionAssociations(
    String meetingId,
    List<TranscriptSegment> segments,
  ) async {
    final languages = <String, LanguageDecision>{};
    final speakers = <String, Speaker>{};
    for (final segment in segments) {
      if (segment.languageDecisionId case final decisionId?) {
        final decision =
            await (database.select(database.languageDecisions)..where(
                  (row) =>
                      row.id.equals(decisionId) &
                      row.transcriptSegmentId.equals(segment.id) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (decision != null) {
          languages[segment.id] = _readLanguageDecision(decision);
        }
      }
      if (segment.speakerId case final speakerId?) {
        if (speakers.containsKey(speakerId)) continue;
        final speaker =
            await (database.select(database.speakers)..where(
                  (row) =>
                      row.id.equals(speakerId) &
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (speaker != null) speakers[speakerId] = _readSpeaker(speaker);
      }
    }
    return (languages: languages, speakers: speakers);
  }

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  }) async {
    try {
      await database.transaction(() async {
        final run =
            await (database.select(database.transcriptRuns)..where(
                  (row) =>
                      row.id.equals(runId) &
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (run == null) {
          throw const _AnalysisStateError('analysis_not_found');
        }
        final existing = await (database.select(
          database.meetingTranscriptSelections,
        )..where((row) => row.meetingId.equals(meetingId))).getSingleOrNull();
        if (existing == null) {
          await database
              .into(database.meetingTranscriptSelections)
              .insert(
                db.MeetingTranscriptSelectionsCompanion.insert(
                  id: '$meetingId:current-transcript',
                  createdAt: selectedAtUtcMs,
                  updatedAt: selectedAtUtcMs,
                  meetingId: meetingId,
                  transcriptRunId: runId,
                ),
              );
        } else {
          await (database.update(
            database.meetingTranscriptSelections,
          )..where((row) => row.id.equals(existing.id))).write(
            db.MeetingTranscriptSelectionsCompanion(
              updatedAt: Value(selectedAtUtcMs),
              rowRevision: Value(existing.rowRevision + 1),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              transcriptRunId: Value(runId),
            ),
          );
        }
      });
      return const Ok<void, AnalysisRepositoryFailure>(null);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_selection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }
}

/// Drift-backed durable transcription job and run state machine.
final class DriftTranscriptionJobRepository
    implements TranscriptionJobRepository {
  /// Creates a transcription job repository over the shared local database.
  const DriftTranscriptionJobRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  static final RegExp _privacySafeCode = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> enqueue(
    ProcessingJob job,
    TranscriptRun run, {
    required int storedAtUtcMs,
  }) async {
    if (!_validQueuedPair(job, run) || storedAtUtcMs < 0) {
      return const Err(AnalysisConflict());
    }
    try {
      final stored = await database.transaction(() async {
        final existingJob = await _jobRow(job.id);
        final existingRun = await _runRow(run.id);
        if (existingJob != null) {
          if (existingRun == null ||
              !_sameJobIdentity(existingJob, job) ||
              !_sameRunIdentity(existingRun, run)) {
            throw const _AnalysisStateError('analysis_conflict');
          }
          return _readTranscriptionJob(existingJob);
        }
        if (existingRun != null) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        await database
            .into(database.transcriptRuns)
            .insert(
              db.TranscriptRunsCompanion.insert(
                id: run.id,
                createdAt: run.createdAtUtcMs,
                updatedAt: storedAtUtcMs,
                meetingId: run.meetingId,
                engineId: run.provenance.engineId,
                engineVersion: run.provenance.engineVersion,
                modelId: run.provenance.modelId,
                modelVersion: run.provenance.modelVersion,
                modelSha256: run.provenance.modelSha256,
                parametersJson: run.provenance.parametersJson,
                runState: 'queued',
              ),
            );
        await database
            .into(database.processingJobs)
            .insert(
              db.ProcessingJobsCompanion.insert(
                id: job.id,
                createdAt: job.createdAtUtcMs,
                updatedAt: storedAtUtcMs,
                meetingId: job.meetingId,
                jobKind: ProcessingJobKind.transcription.name,
                jobState: 'queued',
                transcriptRunId: Value(run.id),
                modelId: Value(job.modelId),
              ),
            );
        return job;
      });
      return Ok(stored);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_enqueue_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> load(
    String jobId,
  ) async {
    try {
      final row = await _jobRow(jobId);
      if (row == null || row.isDeleted) {
        return const Err(AnalysisNotFound());
      }
      return Ok(_readTranscriptionJob(row));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_load_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<TranscriptRun, AnalysisRepositoryFailure>> loadRun(
    String runId,
  ) async {
    try {
      final row = await _runRow(runId);
      if (row == null || row.isDeleted) {
        return const Err(AnalysisNotFound());
      }
      return Ok(_readTranscriptRun(row));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_run_load_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Stream<Result<List<ProcessingJob>, AnalysisRepositoryFailure>> watchMeeting(
    String meetingId,
  ) async* {
    try {
      final query = database.select(database.processingJobs)
        ..where(
          (row) =>
              row.meetingId.equals(meetingId) &
              row.jobKind.equals(ProcessingJobKind.transcription.name) &
              row.isDeleted.equals(false),
        )
        ..orderBy([
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.id),
        ]);
      await for (final rows in query.watch()) {
        yield Ok(
          List<ProcessingJob>.unmodifiable(rows.map(_readTranscriptionJob)),
        );
      }
    } on SqliteException catch (error, stackTrace) {
      yield Err(
        _storeFailure(
          diagnosticSink,
          'transcription_jobs_watch_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  listRecoverable() async {
    try {
      final rows =
          await (database.select(database.processingJobs)
                ..where(
                  (row) =>
                      row.jobKind.equals(ProcessingJobKind.transcription.name) &
                      row.jobState.isIn(const <String>[
                        'queued',
                        'running',
                        'paused',
                      ]) &
                      row.isDeleted.equals(false),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      return Ok(
        List<ProcessingJob>.unmodifiable(rows.map(_readTranscriptionJob)),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_jobs_list_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> start(
    String jobId, {
    required int startedAtUtcMs,
  }) async {
    if (startedAtUtcMs < 0) return const Err(AnalysisConflict());
    try {
      final job = await database.transaction(() async {
        final current = await _requiredJob(jobId);
        final run = await _requiredOwnedRun(current);
        if ((current.jobState != 'queued' && current.jobState != 'paused') ||
            run.runState != 'queued') {
          throw const _AnalysisStateError('analysis_conflict');
        }
        final progress = current.progress ?? run.progress;
        await (database.update(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).write(
          db.TranscriptRunsCompanion(
            updatedAt: Value(startedAtUtcMs),
            rowRevision: Value(run.rowRevision + 1),
            runState: const Value('running'),
            startedAtUtcMs: Value(startedAtUtcMs),
            endedAtUtcMs: const Value(null),
            progress: Value(progress),
            failureCode: const Value(null),
          ),
        );
        await (database.update(
          database.processingJobs,
        )..where((row) => row.id.equals(current.id))).write(
          db.ProcessingJobsCompanion(
            updatedAt: Value(startedAtUtcMs),
            rowRevision: Value(current.rowRevision + 1),
            jobState: const Value('running'),
            progress: Value(progress),
            reasonCode: const Value(null),
            failureCode: const Value(null),
          ),
        );
        return _readTranscriptionJob((await _jobRow(jobId))!);
      });
      return Ok(job);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_start_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> saveProgress(
    String jobId, {
    required double progress,
    required TranscriptionCheckpoint checkpoint,
    required int storedAtUtcMs,
  }) async {
    if (!progress.isFinite ||
        progress < 0 ||
        progress > 1 ||
        checkpoint.completedMedia.isNegative ||
        checkpoint.parameterVersion <= 0 ||
        storedAtUtcMs < 0) {
      return const Err(AnalysisConflict());
    }
    try {
      final job = await database.transaction(() async {
        final current = await _requiredJob(jobId);
        final run = await _requiredOwnedRun(current);
        final previousCheckpoint = TranscriptionCheckpoint.tryParse(
          current.checkpoint,
        );
        if (current.jobState != 'running' ||
            run.runState != 'running' ||
            progress < (current.progress ?? 0) ||
            progress < run.progress ||
            (current.checkpoint != null && previousCheckpoint == null) ||
            (previousCheckpoint != null &&
                (checkpoint.parameterVersion !=
                        previousCheckpoint.parameterVersion ||
                    checkpoint.completedMedia <
                        previousCheckpoint.completedMedia)) ||
            checkpoint.parameterVersion !=
                _transcriptionParameterVersion(run.parametersJson)) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        await (database.update(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).write(
          db.TranscriptRunsCompanion(
            updatedAt: Value(storedAtUtcMs),
            rowRevision: Value(run.rowRevision + 1),
            progress: Value(progress),
          ),
        );
        await (database.update(
          database.processingJobs,
        )..where((row) => row.id.equals(current.id))).write(
          db.ProcessingJobsCompanion(
            updatedAt: Value(storedAtUtcMs),
            rowRevision: Value(current.rowRevision + 1),
            progress: Value(progress),
            checkpoint: Value(checkpoint.toStorageJson()),
          ),
        );
        return _readTranscriptionJob((await _jobRow(jobId))!);
      });
      return Ok(job);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_progress_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  recoverOrphanedRunning({required int recoveredAtUtcMs}) async {
    if (recoveredAtUtcMs < 0) return const Err(AnalysisConflict());
    try {
      final recovered = await database.transaction(() async {
        final rows =
            await (database.select(database.processingJobs)..where(
                  (row) =>
                      row.jobKind.equals(ProcessingJobKind.transcription.name) &
                      row.jobState.equals('running') &
                      row.isDeleted.equals(false),
                ))
                .get();
        final result = <ProcessingJob>[];
        for (final current in rows) {
          final run = await _requiredOwnedRun(current);
          if (run.runState != 'running') {
            throw const _AnalysisStateError('analysis_conflict');
          }
          await (database.update(
            database.transcriptRuns,
          )..where((row) => row.id.equals(run.id))).write(
            db.TranscriptRunsCompanion(
              updatedAt: Value(recoveredAtUtcMs),
              rowRevision: Value(run.rowRevision + 1),
              runState: const Value('queued'),
              startedAtUtcMs: const Value(null),
              endedAtUtcMs: const Value(null),
              failureCode: const Value(null),
            ),
          );
          await (database.update(
            database.processingJobs,
          )..where((row) => row.id.equals(current.id))).write(
            db.ProcessingJobsCompanion(
              updatedAt: Value(recoveredAtUtcMs),
              rowRevision: Value(current.rowRevision + 1),
              jobState: const Value('paused'),
              reasonCode: const Value('process_restarted'),
              failureCode: const Value(null),
            ),
          );
          result.add(_readTranscriptionJob((await _jobRow(current.id))!));
        }
        return List<ProcessingJob>.unmodifiable(result);
      });
      return Ok(recovered);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_recovery_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> complete(
    String jobId,
    TranscriptRun completedRun,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
    String? warningCode,
  }) async {
    if (completedRun.state is! AnalysisCompleted ||
        !_validStableSegments(completedRun.id, segments) ||
        storedAtUtcMs < 0 ||
        (warningCode != null && !_privacySafeCode.hasMatch(warningCode))) {
      return const Err(AnalysisConflict());
    }
    try {
      final version = await database.transaction(() async {
        final current = await _requiredJob(jobId);
        final run = await _requiredOwnedRun(current);
        final terminal = completedRun.state as AnalysisCompleted;
        if (current.jobState != 'running' ||
            run.runState != 'running' ||
            !_sameRunIdentity(run, completedRun) ||
            terminal.startedAtUtcMs != run.startedAtUtcMs ||
            current.modelId != completedRun.provenance.modelId) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        final existingSegments = await (database.select(
          database.transcriptSegments,
        )..where((row) => row.transcriptRunId.equals(run.id))).get();
        if (existingSegments.isNotEmpty) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        for (final segment in segments) {
          await database
              .into(database.transcriptSegments)
              .insert(
                db.TranscriptSegmentsCompanion.insert(
                  id: segment.id,
                  createdAt: storedAtUtcMs,
                  updatedAt: storedAtUtcMs,
                  meetingId: run.meetingId,
                  transcriptRunId: run.id,
                  startUs: segment.start.inMicroseconds,
                  endUs: segment.end.inMicroseconds,
                  rawModelText: segment.rawModelText,
                  displayedText: segment.displayedText,
                  revisionState: segment.revisionState.name,
                  speakerId: Value(segment.speakerId),
                  speakerMeetingId: Value(
                    segment.speakerId == null ? null : run.meetingId,
                  ),
                ),
              );
        }
        await (database.update(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).write(
          db.TranscriptRunsCompanion(
            updatedAt: Value(storedAtUtcMs),
            rowRevision: Value(run.rowRevision + 1),
            runState: const Value('completed'),
            startedAtUtcMs: Value(terminal.startedAtUtcMs),
            endedAtUtcMs: Value(terminal.endedAtUtcMs),
            progress: const Value(1),
            failureCode: const Value(null),
          ),
        );
        await (database.update(
          database.processingJobs,
        )..where((row) => row.id.equals(current.id))).write(
          db.ProcessingJobsCompanion(
            updatedAt: Value(storedAtUtcMs),
            rowRevision: Value(current.rowRevision + 1),
            jobState: const Value('succeeded'),
            progress: const Value(1),
            reasonCode: const Value(null),
            failureCode: const Value(null),
            checkpoint: Value(
              warningCode == null
                  ? null
                  : TranscriptionCompletionWarning(
                      warningCode: warningCode,
                    ).toStorageJson(),
            ),
          ),
        );
        final selection =
            await (database.select(
                  database.meetingTranscriptSelections,
                )..where((row) => row.meetingId.equals(run.meetingId)))
                .getSingleOrNull();
        final isCurrent = selection == null;
        if (isCurrent) {
          await database
              .into(database.meetingTranscriptSelections)
              .insert(
                db.MeetingTranscriptSelectionsCompanion.insert(
                  id: '${run.meetingId}:current-transcript',
                  createdAt: storedAtUtcMs,
                  updatedAt: storedAtUtcMs,
                  meetingId: run.meetingId,
                  transcriptRunId: run.id,
                ),
              );
        }
        return TranscriptVersion(
          run: completedRun,
          segments: segments,
          isCurrent: isCurrent,
        );
      });
      return Ok(version);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_complete_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> fail(
    String jobId, {
    required String failureCode,
    required int failedAtUtcMs,
  }) => _finishWithFailure(
    jobId,
    failureCode: failureCode,
    failedAtUtcMs: failedAtUtcMs,
  );

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> cancel(
    String jobId, {
    required int cancelledAtUtcMs,
  }) => _finishWithFailure(
    jobId,
    failureCode: 'transcription_cancelled',
    failedAtUtcMs: cancelledAtUtcMs,
  );

  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> _finishWithFailure(
    String jobId, {
    required String failureCode,
    required int failedAtUtcMs,
  }) async {
    if (!_privacySafeCode.hasMatch(failureCode) || failedAtUtcMs < 0) {
      return const Err(AnalysisConflict());
    }
    try {
      final job = await database.transaction(() async {
        final current = await _requiredJob(jobId);
        final run = await _requiredOwnedRun(current);
        if (current.jobState != 'running' ||
            run.runState != 'running' ||
            run.startedAtUtcMs == null ||
            failedAtUtcMs < run.startedAtUtcMs!) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        final progress = current.progress ?? run.progress;
        await (database.update(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).write(
          db.TranscriptRunsCompanion(
            updatedAt: Value(failedAtUtcMs),
            rowRevision: Value(run.rowRevision + 1),
            runState: const Value('failed'),
            endedAtUtcMs: Value(failedAtUtcMs),
            progress: Value(progress),
            failureCode: Value(failureCode),
          ),
        );
        await (database.update(
          database.processingJobs,
        )..where((row) => row.id.equals(current.id))).write(
          db.ProcessingJobsCompanion(
            updatedAt: Value(failedAtUtcMs),
            rowRevision: Value(current.rowRevision + 1),
            jobState: const Value('failed'),
            progress: Value(progress),
            reasonCode: const Value(null),
            failureCode: Value(failureCode),
          ),
        );
        return _readTranscriptionJob((await _jobRow(jobId))!);
      });
      return Ok(job);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_failure_store_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> retry(
    String jobId, {
    required int queuedAtUtcMs,
  }) async {
    if (queuedAtUtcMs < 0) return const Err(AnalysisConflict());
    try {
      final job = await database.transaction(() async {
        final current = await _requiredJob(jobId);
        final run = await _requiredOwnedRun(current);
        if (current.jobState != 'failed' || run.runState != 'failed') {
          throw const _AnalysisStateError('analysis_conflict');
        }
        await (database.update(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).write(
          db.TranscriptRunsCompanion(
            updatedAt: Value(queuedAtUtcMs),
            rowRevision: Value(run.rowRevision + 1),
            runState: const Value('queued'),
            startedAtUtcMs: const Value(null),
            endedAtUtcMs: const Value(null),
            failureCode: const Value(null),
          ),
        );
        await (database.update(
          database.processingJobs,
        )..where((row) => row.id.equals(current.id))).write(
          db.ProcessingJobsCompanion(
            updatedAt: Value(queuedAtUtcMs),
            rowRevision: Value(current.rowRevision + 1),
            jobState: const Value('queued'),
            progress: const Value(null),
            reasonCode: const Value(null),
            failureCode: const Value(null),
          ),
        );
        return _readTranscriptionJob((await _jobRow(jobId))!);
      });
      return Ok(job);
    } on _AnalysisStateError catch (error, _) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcription_job_retry_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  Future<db.ProcessingJob?> _jobRow(String jobId) => (database.select(
    database.processingJobs,
  )..where((row) => row.id.equals(jobId))).getSingleOrNull();

  Future<db.TranscriptRun?> _runRow(String runId) => (database.select(
    database.transcriptRuns,
  )..where((row) => row.id.equals(runId))).getSingleOrNull();

  Future<db.ProcessingJob> _requiredJob(String jobId) async {
    final row = await _jobRow(jobId);
    if (row == null ||
        row.isDeleted ||
        row.jobKind != ProcessingJobKind.transcription.name) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    return row;
  }

  Future<db.TranscriptRun> _requiredOwnedRun(db.ProcessingJob job) async {
    final runId = job.transcriptRunId;
    if (runId == null) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    final run = await _runRow(runId);
    if (run == null || run.isDeleted || run.meetingId != job.meetingId) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    return run;
  }
}

/// Drift-backed immutable revision history and corrected-view repository.
final class DriftRevisionRepository implements RevisionRepository {
  /// Creates a revision repository over the shared local database.
  const DriftRevisionRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(
    Revision revision,
  ) async {
    try {
      await database.transaction(() async {
        final duplicate = await (database.select(
          database.revisions,
        )..where((row) => row.id.equals(revision.id))).getSingleOrNull();
        if (duplicate != null) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        await _ensureMeetingEditable(revision.meetingId);
        await _ensureRevisionOrder(revision);
        switch (revision.change) {
          case final TranscriptTextChange change:
            await _applyText(revision, change);
          case final LanguageLabelChange change:
            await _applyLanguage(revision, change);
          case final SpeakerAssignmentChange change:
            await _applySpeakerAssignment(revision, change);
          case final SpeakerLabelChange change:
            await _applySpeakerLabel(revision, change);
        }
        await _insertRevision(revision);
      });
      return Ok(revision);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_apply_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  Future<void> _ensureMeetingEditable(String meetingId) async {
    final meeting =
        await (database.select(database.meetings)..where(
              (row) => row.id.equals(meetingId) & row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (meeting == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final lifecycle = MeetingLifecycle.values.byName(meeting.lifecycle);
    if (lifecycle != MeetingLifecycle.finalized &&
        lifecycle != MeetingLifecycle.recoverable &&
        lifecycle != MeetingLifecycle.failedFinalization) {
      throw const _AnalysisStateError('analysis_editing_locked');
    }
  }

  @override
  Future<Result<List<Revision>, AnalysisRepositoryFailure>> listMeeting(
    String meetingId,
  ) async {
    try {
      final rows =
          await (database.select(database.revisions)
                ..where(
                  (row) =>
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      return Ok(
        List<Revision>.unmodifiable(rows.map(_readRevision)),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_list_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<SpeakerAssignment, AnalysisRepositoryFailure>>
  materializeSpeakerAssignment(SpeakerAssignment rawAssignment) async {
    try {
      return Ok(await _materializedAssignment(rawAssignment));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_assignment_projection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Speaker, AnalysisRepositoryFailure>> materializeSpeaker(
    Speaker rawSpeaker,
  ) async {
    try {
      return Ok(await _materializedSpeaker(rawSpeaker));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_speaker_projection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  Future<void> _applyText(
    Revision revision,
    TranscriptTextChange change,
  ) async {
    final segment = await _ownedSegment(revision);
    if (segment.displayedText != change.previousText) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    await (database.update(
      database.transcriptSegments,
    )..where((row) => row.id.equals(segment.id))).write(
      db.TranscriptSegmentsCompanion(
        updatedAt: Value(revision.createdAtUtcMs),
        rowRevision: Value(segment.rowRevision + 1),
        displayedText: Value(change.revisedText),
        revisionState: Value(TranscriptRevisionState.corrected.name),
      ),
    );
  }

  Future<void> _ensureRevisionOrder(Revision revision) async {
    if (revision.change is TranscriptTextChange ||
        revision.change is LanguageLabelChange) {
      return;
    }
    final query = database.select(database.revisions)
      ..where(
        switch (revision.change) {
          SpeakerAssignmentChange() =>
            (row) =>
                row.speakerAssignmentId.equals(revision.targetId) &
                row.isDeleted.equals(false),
          SpeakerLabelChange() =>
            (row) =>
                row.speakerId.equals(revision.targetId) &
                row.isDeleted.equals(false),
          TranscriptTextChange() || LanguageLabelChange() => throw StateError(
            'unreachable transcript revision ordering',
          ),
        },
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ])
      ..limit(1);
    final latest = await query.getSingleOrNull();
    if (latest != null &&
        (revision.createdAtUtcMs < latest.createdAt ||
            (revision.createdAtUtcMs == latest.createdAt &&
                revision.id.compareTo(latest.id) <= 0))) {
      throw const _AnalysisStateError('analysis_conflict');
    }
  }

  Future<void> _applyLanguage(
    Revision revision,
    LanguageLabelChange change,
  ) async {
    final segment = await _ownedSegment(revision);
    final selection =
        await (database.select(
              database.transcriptLanguageSelections,
            )..where(
              (row) =>
                  row.transcriptSegmentId.equals(segment.id) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (selection == null) {
      throw const _AnalysisStateError('analysis_invalid_revision');
    }
    final current =
        await (database.select(database.languageDecisions)..where(
              (row) =>
                  row.id.equals(selection.languageDecisionId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (current == null || current.tag != change.previous.name) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    final decisionId = '${revision.id}:language';
    await database
        .into(database.languageDecisions)
        .insert(
          db.LanguageDecisionsCompanion.insert(
            id: decisionId,
            createdAt: revision.createdAtUtcMs,
            updatedAt: revision.createdAtUtcMs,
            transcriptSegmentId: segment.id,
            tag: change.revised.name,
            source: LanguageDecisionSource.manual.name,
            confidence: const Value(null),
          ),
        );
    await (database.update(
      database.transcriptLanguageSelections,
    )..where((row) => row.id.equals(selection.id))).write(
      db.TranscriptLanguageSelectionsCompanion(
        updatedAt: Value(revision.createdAtUtcMs),
        rowRevision: Value(selection.rowRevision + 1),
        languageDecisionId: Value(decisionId),
      ),
    );
  }

  Future<void> _applySpeakerAssignment(
    Revision revision,
    SpeakerAssignmentChange change,
  ) async {
    final row =
        await (database.select(database.speakerAssignments)..where(
              (candidate) =>
                  candidate.id.equals(revision.targetId) &
                  candidate.meetingId.equals(revision.meetingId) &
                  candidate.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final raw = _readSpeakerAssignment(row);
    final current = await _materializedAssignment(raw);
    if (current.speakerId != change.previousSpeakerId ||
        raw.start != change.start ||
        raw.end != change.end) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    if (change.revisedSpeakerId case final speakerId?) {
      final speaker =
          await (database.select(database.speakers)..where(
                (candidate) =>
                    candidate.id.equals(speakerId) &
                    candidate.analysisRunId.equals(row.analysisRunId) &
                    candidate.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (speaker == null) {
        throw const _AnalysisStateError('analysis_invalid_revision');
      }
    }
  }

  Future<void> _applySpeakerLabel(
    Revision revision,
    SpeakerLabelChange change,
  ) async {
    final row =
        await (database.select(database.speakers)..where(
              (candidate) =>
                  candidate.id.equals(revision.targetId) &
                  candidate.meetingId.equals(revision.meetingId) &
                  candidate.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final speaker = await _materializedSpeaker(_readSpeaker(row));
    if (speaker.label != change.previous) {
      throw const _AnalysisStateError('analysis_conflict');
    }
  }

  Future<db.TranscriptSegment> _ownedSegment(Revision revision) async {
    final segment =
        await (database.select(database.transcriptSegments)..where(
              (row) =>
                  row.id.equals(revision.targetId) &
                  row.meetingId.equals(revision.meetingId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (segment == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final selection =
        await (database.select(database.meetingTranscriptSelections)..where(
              (row) =>
                  row.meetingId.equals(revision.meetingId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (selection == null ||
        selection.transcriptRunId != segment.transcriptRunId) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    final run =
        await (database.select(database.transcriptRuns)..where(
              (row) =>
                  row.id.equals(segment.transcriptRunId) &
                  row.meetingId.equals(revision.meetingId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (run == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    if (run.runState != 'completed') {
      throw const _AnalysisStateError('analysis_editing_locked');
    }
    return segment;
  }

  Future<void> _insertRevision(Revision revision) async {
    final encoded = _encodedRevision(revision.change);
    await database
        .into(database.revisions)
        .insert(
          db.RevisionsCompanion.insert(
            id: revision.id,
            createdAt: revision.createdAtUtcMs,
            updatedAt: revision.createdAtUtcMs,
            meetingId: revision.meetingId,
            transcriptSegmentId: Value(
              encoded.kind == 'transcriptText' ||
                      encoded.kind == 'languageLabel'
                  ? revision.targetId
                  : null,
            ),
            speakerAssignmentId: Value(
              encoded.kind == 'speakerAssignment' ? revision.targetId : null,
            ),
            speakerId: Value(
              encoded.kind == 'speakerLabel' ? revision.targetId : null,
            ),
            revisionKind: encoded.kind,
            payloadJson: encoded.payload,
          ),
        );
  }

  Future<SpeakerAssignment> _materializedAssignment(
    SpeakerAssignment raw,
  ) async {
    var projected = raw;
    final rows =
        await (database.select(database.revisions)
              ..where(
                (row) =>
                    row.speakerAssignmentId.equals(raw.id) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in rows) {
      final revision = _readRevision(row);
      if (revision.change case final SpeakerAssignmentChange change) {
        projected = projected.copyWith(
          speakerId: change.revisedSpeakerId,
          needsConfirmation: change.needsConfirmation,
        );
      }
    }
    return projected;
  }

  Future<List<db.Revision>> _revisionRowsForSpeaker(String speakerId) =>
      (database.select(database.revisions)
            ..where(
              (row) =>
                  row.speakerId.equals(speakerId) & row.isDeleted.equals(false),
            )
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();

  Future<Speaker> _materializedSpeaker(Speaker raw) async {
    var projected = raw;
    final rows = await _revisionRowsForSpeaker(raw.id);
    for (final row in rows) {
      final revision = _readRevision(row);
      if (revision.change case final SpeakerLabelChange change) {
        projected = projected.copyWith(label: change.revised);
      }
    }
    return projected;
  }
}

/// Drift-backed immutable bundled-model manifest repository.
final class DriftModelRepository implements ModelRepository {
  /// Creates a model repository over the shared local database.
  const DriftModelRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<InstalledModel, AnalysisRepositoryFailure>> registerBundled(
    InstalledModel model, {
    required int observedAtUtcMs,
  }) async {
    try {
      late InstalledModel stored;
      await database.transaction(() async {
        final existing = await _findModel(model.id);
        if (existing != null) {
          if (!_sameModelManifest(existing, model)) {
            throw const _AnalysisStateError('analysis_conflict');
          }
          stored = existing;
          return;
        }
        await database
            .into(database.modelManifests)
            .insert(
              db.ModelManifestsCompanion.insert(
                id: model.id,
                createdAt: observedAtUtcMs,
                updatedAt: observedAtUtcMs,
                version: model.version,
                source: model.source,
                sha256: model.sha256,
                bytes: model.bytes,
                expectedEngineId: model.expectedEngineId,
                licenseId: model.licenseId,
                licenseSnapshotPath: model.licenseSnapshotPath.value,
              ),
            );
        for (final capability in model.capabilities) {
          await database
              .into(database.modelCapabilityEntries)
              .insert(
                db.ModelCapabilityEntriesCompanion.insert(
                  id: '${model.id}:capability:${capability.name}',
                  createdAt: observedAtUtcMs,
                  updatedAt: observedAtUtcMs,
                  modelId: model.id,
                  capability: capability.name,
                ),
              );
        }
        for (final mode in model.enabledModes) {
          await database
              .into(database.modelModeEntries)
              .insert(
                db.ModelModeEntriesCompanion.insert(
                  id: '${model.id}:mode:${mode.name}',
                  createdAt: observedAtUtcMs,
                  updatedAt: observedAtUtcMs,
                  modelId: model.id,
                  mode: mode.name,
                ),
              );
        }
        stored = model;
      });
      return Ok(stored);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('model_register_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
  listInstalled() async {
    try {
      final rows = await (database.select(
        database.modelManifests,
      )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
      final models = <InstalledModel>[];
      for (final row in rows) {
        models.add((await _findModel(row.id))!);
      }
      return Ok(List<InstalledModel>.unmodifiable(models));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('model_list_failed', error, stackTrace));
    }
  }

  Future<InstalledModel?> _findModel(String modelId) async {
    final row = await (database.select(
      database.modelManifests,
    )..where((candidate) => candidate.id.equals(modelId))).getSingleOrNull();
    if (row == null) return null;
    final capabilityRows = await (database.select(
      database.modelCapabilityEntries,
    )..where((entry) => entry.modelId.equals(modelId))).get();
    final modeRows = await (database.select(
      database.modelModeEntries,
    )..where((entry) => entry.modelId.equals(modelId))).get();
    final licensePath = switch (AppRelativePath.tryParse(
      row.licenseSnapshotPath,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('database path invariant violated'),
    };
    final capabilities =
        capabilityRows
            .map((entry) => ModelCapability.values.byName(entry.capability))
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));
    final modes =
        modeRows
            .map((entry) => PerformanceMode.values.byName(entry.mode))
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));
    return InstalledModel(
      id: row.id,
      version: row.version,
      source: row.source,
      sha256: row.sha256,
      bytes: row.bytes,
      capabilities: capabilities,
      expectedEngineId: row.expectedEngineId,
      licenseId: row.licenseId,
      licenseSnapshotPath: licensePath,
      enabledModes: modes,
    );
  }

  AnalysisStoreUnavailable _storeFailure(
    String code,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.analysisRepositoryOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
    return AnalysisStoreUnavailable(code);
  }
}

final class _AnalysisStateError implements Exception {
  const _AnalysisStateError(this.code);

  final String code;
}

AnalysisRepositoryFailure _stateFailure(_AnalysisStateError error) =>
    switch (error.code) {
      'analysis_not_found' => const AnalysisNotFound(),
      'analysis_conflict' => const AnalysisConflict(),
      'analysis_invalid_revision' => const AnalysisInvalidRevision(),
      'analysis_editing_locked' => const AnalysisEditingLocked(),
      _ => throw StateError('unknown analysis repository state failure'),
    };

({
  String name,
  int? startedAtUtcMs,
  int? endedAtUtcMs,
  double progress,
  String? failureCode,
})
_storedAnalysisState(AnalysisState state) => switch (state) {
  AnalysisQueued() => (
    name: 'queued',
    startedAtUtcMs: null,
    endedAtUtcMs: null,
    progress: 0,
    failureCode: null,
  ),
  AnalysisRunning(:final startedAtUtcMs, :final progress) => (
    name: 'running',
    startedAtUtcMs: startedAtUtcMs,
    endedAtUtcMs: null,
    progress: progress,
    failureCode: null,
  ),
  AnalysisCompleted(:final startedAtUtcMs, :final endedAtUtcMs) => (
    name: 'completed',
    startedAtUtcMs: startedAtUtcMs,
    endedAtUtcMs: endedAtUtcMs,
    progress: 1,
    failureCode: null,
  ),
  AnalysisFailed(
    :final startedAtUtcMs,
    :final endedAtUtcMs,
    :final progress,
    :final failureCode,
  ) =>
    (
      name: 'failed',
      startedAtUtcMs: startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs,
      progress: progress,
      failureCode: failureCode,
    ),
};

bool _validQueuedPair(ProcessingJob job, TranscriptRun run) =>
    job.kind == ProcessingJobKind.transcription &&
    job.state is ProcessingQueued &&
    job.meetingId == run.meetingId &&
    job.targetRunId == run.id &&
    job.modelId == run.provenance.modelId &&
    job.checkpoint == null &&
    run.state is AnalysisQueued &&
    _transcriptionParameterVersion(run.provenance.parametersJson) != null;

bool _sameJobIdentity(db.ProcessingJob stored, ProcessingJob requested) =>
    stored.id == requested.id &&
    stored.createdAt == requested.createdAtUtcMs &&
    stored.meetingId == requested.meetingId &&
    stored.jobKind == requested.kind.name &&
    stored.transcriptRunId == requested.targetRunId &&
    stored.modelId == requested.modelId;

bool _sameRunIdentity(db.TranscriptRun stored, TranscriptRun requested) =>
    stored.id == requested.id &&
    stored.createdAt == requested.createdAtUtcMs &&
    stored.meetingId == requested.meetingId &&
    stored.engineId == requested.provenance.engineId &&
    stored.engineVersion == requested.provenance.engineVersion &&
    stored.modelId == requested.provenance.modelId &&
    stored.modelVersion == requested.provenance.modelVersion &&
    stored.modelSha256 == requested.provenance.modelSha256 &&
    stored.parametersJson == requested.provenance.parametersJson;

ProcessingJob _readTranscriptionJob(db.ProcessingJob row) => ProcessingJob(
  id: row.id,
  meetingId: row.meetingId,
  kind: ProcessingJobKind.values.byName(row.jobKind),
  createdAtUtcMs: row.createdAt,
  state: switch (row.jobState) {
    'queued' => const ProcessingQueued(),
    'running' => ProcessingRunning(progress: row.progress!),
    'paused' => ProcessingPaused(reasonCode: row.reasonCode!),
    'succeeded' =>
      TranscriptionCompletionWarning.tryParse(row.checkpoint) == null
          ? const ProcessingSucceeded()
          : ProcessingSucceededWithWarning(
              warningCode: TranscriptionCompletionWarning.tryParse(
                row.checkpoint,
              )!.warningCode,
            ),
    'failed' => ProcessingFailed(failureCode: row.failureCode!),
    _ => throw StateError('database processing state invariant violated'),
  },
  targetRunId: row.transcriptRunId,
  modelId: row.modelId,
  checkpoint: row.checkpoint,
);

int? _transcriptionParameterVersion(String parametersJson) {
  try {
    final decoded = jsonDecode(parametersJson);
    if (decoded is! Map<String, Object?>) return null;
    final version = decoded['parameterVersion'];
    return version is int && version > 0 ? version : null;
  } on FormatException {
    return null;
  }
}

bool _validStableSegments(
  String runId,
  List<TranscriptSegment> segments,
) {
  final ids = <String>{};
  final ranges = <(int, int)>{};
  var previousEndUs = 0;
  for (final segment in segments) {
    final startUs = segment.start.inMicroseconds;
    final endUs = segment.end.inMicroseconds;
    if (segment.id.isEmpty ||
        segment.transcriptRunId != runId ||
        segment.revisionState != TranscriptRevisionState.machine ||
        startUs < previousEndUs ||
        endUs <= startUs ||
        !ids.add(segment.id) ||
        !ranges.add((startUs, endUs))) {
      return false;
    }
    previousEndUs = endUs;
  }
  return true;
}

TranscriptRun _readTranscriptRun(db.TranscriptRun row) => TranscriptRun(
  id: row.id,
  meetingId: row.meetingId,
  provenance: InferenceProvenance(
    engineId: row.engineId,
    engineVersion: row.engineVersion,
    modelId: row.modelId,
    modelVersion: row.modelVersion,
    modelSha256: row.modelSha256,
    parametersJson: row.parametersJson,
  ),
  createdAtUtcMs: row.createdAt,
  state: switch (row.runState) {
    'queued' => const AnalysisQueued(),
    'running' => AnalysisRunning(
      startedAtUtcMs: row.startedAtUtcMs!,
      progress: row.progress,
    ),
    'completed' => AnalysisCompleted(
      startedAtUtcMs: row.startedAtUtcMs!,
      endedAtUtcMs: row.endedAtUtcMs!,
    ),
    'failed' => AnalysisFailed(
      startedAtUtcMs: row.startedAtUtcMs!,
      endedAtUtcMs: row.endedAtUtcMs!,
      progress: row.progress,
      failureCode: row.failureCode!,
    ),
    _ => throw StateError('database analysis state invariant violated'),
  },
);

TranscriptSegment _readTranscriptSegment(QueryRow row) => TranscriptSegment(
  id: row.read<String>('id'),
  transcriptRunId: row.read<String>('transcript_run_id'),
  start: Duration(microseconds: row.read<int>('start_us')),
  end: Duration(microseconds: row.read<int>('end_us')),
  rawModelText: row.read<String>('raw_model_text'),
  displayedText: row.read<String>('displayed_text'),
  revisionState: TranscriptRevisionState.values.byName(
    row.read<String>('revision_state'),
  ),
  languageDecisionId: row.readNullable<String>('language_decision_id'),
  speakerId: row.readNullable<String>('speaker_id'),
);

LanguageDecision _readLanguageDecision(db.LanguageDecision row) =>
    LanguageDecision(
      id: row.id,
      transcriptSegmentId: row.transcriptSegmentId,
      tag: LanguageTag.values.byName(row.tag),
      source: LanguageDecisionSource.values.byName(row.source),
      confidence: row.confidence,
    );

({String kind, String payload}) _encodedRevision(RevisionChange change) =>
    switch (change) {
      TranscriptTextChange(:final previousText, :final revisedText) => (
        kind: 'transcriptText',
        payload: jsonEncode(<String, Object>{
          'previousText': previousText,
          'revisedText': revisedText,
        }),
      ),
      LanguageLabelChange(:final previous, :final revised) => (
        kind: 'languageLabel',
        payload: jsonEncode(<String, Object>{
          'previous': previous.name,
          'revised': revised.name,
        }),
      ),
      SpeakerAssignmentChange(
        :final start,
        :final end,
        :final previousSpeakerId,
        :final revisedSpeakerId,
        :final needsConfirmation,
      ) =>
        (
          kind: 'speakerAssignment',
          payload: jsonEncode(<String, Object?>{
            'startUs': start.inMicroseconds,
            'endUs': end.inMicroseconds,
            'previousSpeakerId': previousSpeakerId,
            'revisedSpeakerId': revisedSpeakerId,
            'needsConfirmation': needsConfirmation,
          }),
        ),
      SpeakerLabelChange(:final previous, :final revised) => (
        kind: 'speakerLabel',
        payload: jsonEncode(<String, Object>{
          'previous': previous,
          'revised': revised,
        }),
      ),
    };

Revision _readRevision(db.Revision row) {
  final payload = jsonDecode(row.payloadJson) as Map<String, Object?>;
  final targetId = switch (row.revisionKind) {
    'transcriptText' || 'languageLabel' => row.transcriptSegmentId!,
    'speakerAssignment' => row.speakerAssignmentId!,
    'speakerLabel' => row.speakerId!,
    _ => throw StateError('database revision kind invariant violated'),
  };
  final change = switch (row.revisionKind) {
    'transcriptText' => TranscriptTextChange(
      previousText: payload['previousText']! as String,
      revisedText: payload['revisedText']! as String,
    ),
    'languageLabel' => LanguageLabelChange(
      previous: LanguageTag.values.byName(payload['previous']! as String),
      revised: LanguageTag.values.byName(payload['revised']! as String),
    ),
    'speakerAssignment' => SpeakerAssignmentChange(
      start: Duration(microseconds: payload['startUs']! as int),
      end: Duration(microseconds: payload['endUs']! as int),
      previousSpeakerId: payload['previousSpeakerId'] as String?,
      revisedSpeakerId: payload['revisedSpeakerId'] as String?,
      needsConfirmation: payload['needsConfirmation']! as bool,
    ),
    'speakerLabel' => SpeakerLabelChange(
      previous: payload['previous']! as String,
      revised: payload['revised']! as String,
    ),
    _ => throw StateError('database revision kind invariant violated'),
  };
  return Revision(
    id: row.id,
    meetingId: row.meetingId,
    targetId: targetId,
    change: change,
    createdAtUtcMs: row.createdAt,
  );
}

Speaker _readSpeaker(db.Speaker row) => Speaker(
  id: row.id,
  meetingId: row.meetingId,
  analysisRunId: row.analysisRunId,
  label: row.label,
);

SpeakerAssignment _readSpeakerAssignment(db.SpeakerAssignment row) =>
    SpeakerAssignment(
      id: row.id,
      analysisRunId: row.analysisRunId,
      speakerId: row.speakerId,
      start: Duration(microseconds: row.startUs),
      end: Duration(microseconds: row.endUs),
      confidence: row.confidence,
      isOverlap: row.isOverlap,
      needsConfirmation: row.needsConfirmation,
    );

bool _sameModelManifest(InstalledModel left, InstalledModel right) =>
    left.id == right.id &&
    left.version == right.version &&
    left.source == right.source &&
    left.sha256 == right.sha256 &&
    left.bytes == right.bytes &&
    left.expectedEngineId == right.expectedEngineId &&
    left.licenseId == right.licenseId &&
    left.licenseSnapshotPath == right.licenseSnapshotPath &&
    left.capabilities.length == right.capabilities.length &&
    left.capabilities.every(right.capabilities.contains) &&
    left.enabledModes.length == right.enabledModes.length &&
    left.enabledModes.every(right.enabledModes.contains);

AnalysisStoreUnavailable _storeFailure(
  DiagnosticLogSink diagnosticSink,
  String code,
  Object error,
  StackTrace stackTrace,
) {
  diagnosticSink.record(
    DiagnosticEvent(
      code: DiagnosticCode.analysisRepositoryOperationFailed,
      errorType: error.runtimeType,
      stackFingerprint: diagnosticStackFingerprint(stackTrace),
    ),
  );
  return AnalysisStoreUnavailable(code);
}
