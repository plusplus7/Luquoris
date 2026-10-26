import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:meta/meta.dart';

/// Atomic writes for new paired runs without relabeling legacy analyses.
abstract interface class TranscriptProcessingRepository {
  /// Lists recoverable explicit refinements, never legacy or live-only runs.
  @useResult
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  listRecoverableRefinements();

  /// Claims one queued refinement after checking its frozen processing role.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> startRefinement(
    String jobId, {
    required int startedAtUtcMs,
  });

  /// Recovers process-orphaned refinement work without touching legacy jobs.
  @useResult
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  recoverOrphanedRefinements({required int recoveredAtUtcMs});

  /// Durably yields queued/running work while retaining its privacy-safe checkpoint.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> pauseRefinement(
    String jobId, {
    required String reasonCode,
    required int pausedAtUtcMs,
  });

  /// Requeues the same failed refinement identity without changing provenance.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> retryRefinement(
    String jobId, {
    required int queuedAtUtcMs,
  });

  /// Loads validated processing metadata, or null for an unextended legacy run.
  @useResult
  Future<Result<TranscriptProcessingInfo?, AnalysisRepositoryFailure>> load(
    String runId,
  );

  /// Stores closed live evidence and its provenance without selecting it.
  @useResult
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveLiveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments,
    TranscriptProcessingInfo processing, {
    required int storedAtUtcMs,
  });

  /// Queues a distinct complete pass and its exact provenance in one transaction.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> enqueueRefinement(
    ProcessingJob job,
    TranscriptRun run,
    TranscriptProcessingInfo processing, {
    required int storedAtUtcMs,
  });
}

/// Paired provenance and role-scoped durable transitions installed by bootstrap.
final transcriptProcessingRepositoryProvider =
    Provider<TranscriptProcessingRepository>(
      (ref) =>
          throw UnimplementedError('Transcript processing is not installed'),
    );
