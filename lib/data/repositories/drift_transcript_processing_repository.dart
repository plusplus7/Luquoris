import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/transcript_processing_validation.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

/// Transactional paired provenance over the existing run/job state machines.
final class DriftTranscriptProcessingRepository
    implements TranscriptProcessingRepository {
  /// Shares one connection so nested legacy writes stay in the outer transaction.
  DriftTranscriptProcessingRepository(
    this.database, {
    required this.diagnosticSink,
  }) : _transcripts = DriftTranscriptRepository(
         database,
         diagnosticSink: diagnosticSink,
       ),
       _jobs = DriftTranscriptionJobRepository(
         database,
         diagnosticSink: diagnosticSink,
       );

  /// Database containing the owning meeting, run, job, and metadata.
  final db.AppDatabase database;

  /// Diagnostics accept only stable codes/types, never a manifest or text.
  final DiagnosticLogSink diagnosticSink;
  final DriftTranscriptRepository _transcripts;
  final DriftTranscriptionJobRepository _jobs;

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  listRecoverableRefinements() => _jobs.listRecoverableRefinements();

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> startRefinement(
    String jobId, {
    required int startedAtUtcMs,
  }) => _jobs.startRefinement(jobId, startedAtUtcMs: startedAtUtcMs);

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  recoverOrphanedRefinements({required int recoveredAtUtcMs}) =>
      _jobs.recoverOrphanedRefinements(recoveredAtUtcMs: recoveredAtUtcMs);

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> pauseRefinement(
    String jobId, {
    required String reasonCode,
    required int pausedAtUtcMs,
  }) => _jobs.pauseRefinement(
    jobId,
    reasonCode: reasonCode,
    pausedAtUtcMs: pausedAtUtcMs,
  );

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> retryRefinement(
    String jobId, {
    required int queuedAtUtcMs,
  }) => _jobs.retryRefinement(jobId, queuedAtUtcMs: queuedAtUtcMs);

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveLiveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments,
    TranscriptProcessingInfo processing, {
    required int storedAtUtcMs,
  }) => _transaction(() async {
    _require(
      processing.role == TranscriptProcessingRole.liveDraft &&
          (run.state is AnalysisCompleted || run.state is AnalysisFailed) &&
          storedAtUtcMs >= 0 &&
          validMachineTranscriptSegments(run.id, segments) &&
          segments.every(
            (segment) =>
                segment.revisionState == TranscriptRevisionState.machine &&
                segment.rawModelText == segment.displayedText,
          ),
    );
    _require(
      await validProcessingModelBinding(database, run.provenance, processing),
    );
    await _requireMeeting(run.meetingId, finalized: false);
    final version = _value(
      await _transcripts.saveVersion(
        run,
        segments,
        storedAtUtcMs: storedAtUtcMs,
      ),
    );
    await _insert(run, processing, storedAtUtcMs);
    return version;
  });

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> enqueueRefinement(
    ProcessingJob job,
    TranscriptRun run,
    TranscriptProcessingInfo processing, {
    required int storedAtUtcMs,
  }) => _transaction(() async {
    _require(
      processing.role == TranscriptProcessingRole.refinement &&
          processing.completeness == TranscriptCompleteness.incomplete &&
          storedAtUtcMs >= 0,
    );
    _require(
      await validProcessingModelBinding(database, run.provenance, processing),
    );
    await _requireMeeting(run.meetingId, finalized: true);
    await _requireSource(run.id, run.meetingId, processing);
    final existing = await _metadata(run.id);
    final existingRun = await (database.select(
      database.transcriptRuns,
    )..where((row) => row.id.equals(run.id))).getSingleOrNull();
    _require(existingRun == null || existing != null);
    if (existing != null) {
      _require(!existing.isDeleted && _sameFrozen(_read(existing), processing));
    }
    final queued = _value(
      await _jobs.enqueue(job, run, storedAtUtcMs: storedAtUtcMs),
    );
    if (existing == null) await _insert(run, processing, storedAtUtcMs);
    return queued;
  });

  @override
  Future<Result<TranscriptProcessingInfo?, AnalysisRepositoryFailure>> load(
    String runId,
  ) => _transaction(() async {
    final row = await _metadata(runId);
    if (row == null) return null;
    _require(!row.isDeleted);
    final run = _value(await _jobs.loadRun(runId));
    final info = _read(row);
    // Restore may remap a catalog ID while retaining the original snapshot.
    _require(_matchesManifest(run.provenance, info, matchModelId: false));
    await _requireSource(run.id, run.meetingId, info);
    return info;
  });

  Future<void> _requireMeeting(
    String meetingId, {
    required bool finalized,
  }) async {
    final meeting = await (database.select(
      database.meetings,
    )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
    _require(
      meeting != null &&
          !meeting.isDeleted &&
          (!finalized || meeting.lifecycle == 'finalized'),
    );
  }

  Future<void> _requireSource(
    String runId,
    String meetingId,
    TranscriptProcessingInfo info,
  ) async {
    _require(await validProcessingSource(database, runId, meetingId, info));
  }

  Future<db.TranscriptProcessingMetadataData?> _metadata(String runId) =>
      (database.select(
        database.transcriptProcessingMetadata,
      )..where((row) => row.transcriptRunId.equals(runId))).getSingleOrNull();

  Future<void> _insert(
    TranscriptRun run,
    TranscriptProcessingInfo info,
    int storedAtUtcMs,
  ) async {
    await database
        .into(database.transcriptProcessingMetadata)
        .insert(
          db.TranscriptProcessingMetadataCompanion.insert(
            id: run.id,
            createdAt: run.createdAtUtcMs,
            updatedAt: storedAtUtcMs,
            transcriptRunId: run.id,
            meetingId: run.meetingId,
            processingRole: info.role.name,
            completeness: info.completeness.name,
            bundleManifestJson: info.bundleManifestJson,
            sourceRunId: Value(info.sourceRunId),
            audioInventorySha256: Value(info.audioInventorySha256),
          ),
        );
  }

  bool _matchesManifest(
    InferenceProvenance provenance,
    TranscriptProcessingInfo info, {
    bool matchModelId = true,
  }) =>
      matchesProcessingProvenance(provenance, info, matchModelId: matchModelId);

  TranscriptProcessingInfo _read(db.TranscriptProcessingMetadataData row) =>
      processingInfoFromRow(row);

  bool _sameFrozen(
    TranscriptProcessingInfo left,
    TranscriptProcessingInfo right,
  ) =>
      left.role == right.role &&
      left.sourceRunId == right.sourceRunId &&
      left.bundleManifestJson == right.bundleManifestJson &&
      left.audioInventorySha256 == right.audioInventorySha256;

  Future<Result<T, AnalysisRepositoryFailure>> _transaction<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await database.transaction(operation));
    } on _ProcessingAbort catch (abort) {
      return Err(abort.failure);
    } on SqliteException catch (error, stackTrace) {
      diagnosticSink.record(
        DiagnosticEvent(
          code: DiagnosticCode.analysisRepositoryOperationFailed,
          errorType: error.runtimeType,
          stackFingerprint: diagnosticStackFingerprint(stackTrace),
        ),
      );
      return const Err(
        AnalysisStoreUnavailable('transcript_processing_store_failed'),
      );
    }
  }

  void _require(bool condition) {
    if (!condition) throw const _ProcessingAbort(AnalysisConflict());
  }

  T _value<T>(Result<T, AnalysisRepositoryFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw _ProcessingAbort(failure),
  };
}

final class _ProcessingAbort implements Exception {
  const _ProcessingAbort(this.failure);
  final AnalysisRepositoryFailure failure;
}
