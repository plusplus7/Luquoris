import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:meta/meta.dart';

/// Recoverable failures from local analysis persistence.
sealed class AnalysisRepositoryFailure implements Failure {
  const AnalysisRepositoryFailure(this.code);

  @override
  final String code;
}

/// A requested analysis record was not found or did not belong to its owner.
final class AnalysisNotFound extends AnalysisRepositoryFailure {
  /// Creates a not-found failure.
  const AnalysisNotFound() : super('analysis_not_found');
}

/// Immutable provenance or an optimistic correction precondition conflicted.
final class AnalysisConflict extends AnalysisRepositoryFailure {
  /// Creates a conflict failure.
  const AnalysisConflict() : super('analysis_conflict');
}

/// A correction payload did not agree with its typed target.
final class AnalysisInvalidRevision extends AnalysisRepositoryFailure {
  /// Creates an invalid-revision failure.
  const AnalysisInvalidRevision() : super('analysis_invalid_revision');
}

/// Human corrections are unavailable while capture or draft work is active.
final class AnalysisEditingLocked extends AnalysisRepositoryFailure {
  /// Creates an editing-locked failure.
  const AnalysisEditingLocked() : super('analysis_editing_locked');
}

/// The local database could not complete an analysis operation.
final class AnalysisStoreUnavailable extends AnalysisRepositoryFailure {
  /// Creates a store failure with a privacy-safe [code].
  const AnalysisStoreUnavailable(super.code);
}

/// One immutable transcript analysis version and its stable segments.
@immutable
final class TranscriptVersion {
  /// Creates a transcript version projection.
  TranscriptVersion({
    required this.run,
    required List<TranscriptSegment> segments,
    required this.isCurrent,
    Map<String, LanguageDecision> languagesBySegmentId = const {},
    Map<String, Speaker> speakersById = const {},
  }) : segments = List<TranscriptSegment>.unmodifiable(segments),
       languagesBySegmentId = Map.unmodifiable(languagesBySegmentId),
       speakersById = Map.unmodifiable(speakersById);

  /// Versioned inference run and reproducible provenance.
  final TranscriptRun run;

  /// Stable segments owned by [run].
  final List<TranscriptSegment> segments;

  /// Whether the user explicitly selected this version for display/export.
  final bool isCurrent;

  /// Selected language records referenced by this version's segments.
  final Map<String, LanguageDecision> languagesBySegmentId;

  /// Meeting-local speaker records referenced by this version's segments.
  final Map<String, Speaker> speakersById;
}

/// One locally consistent projection for the combined correction surface.
@immutable
final class TranscriptEditorDocument {
  /// Creates an immutable editor projection.
  TranscriptEditorDocument({
    required this.meetingId,
    required this.lifecycle,
    required this.currentVersion,
    required Map<String, LanguageDecision> languagesBySegmentId,
    required Map<String, Speaker> speakersById,
    required List<Revision> revisions,
  }) : languagesBySegmentId = Map.unmodifiable(languagesBySegmentId),
       speakersById = Map.unmodifiable(speakersById),
       revisions = List.unmodifiable(revisions);

  /// Owning meeting identity.
  final String meetingId;

  /// Durable meeting lifecycle used to prevent active-draft editing.
  final MeetingLifecycle lifecycle;

  /// Explicitly selected transcript version, when one exists.
  final TranscriptVersion? currentVersion;

  /// Current selected language decision keyed by stable segment identity.
  final Map<String, LanguageDecision> languagesBySegmentId;

  /// Materialized meeting-local labels referenced by the current transcript.
  final Map<String, Speaker> speakersById;

  /// Immutable human correction history in creation order.
  final List<Revision> revisions;

  /// Whether the selected stable transcript can accept human corrections.
  bool get canEdit =>
      currentVersion?.run.state is AnalysisCompleted &&
      switch (lifecycle) {
        MeetingLifecycle.finalized ||
        MeetingLifecycle.recoverable ||
        MeetingLifecycle.failedFinalization => true,
        MeetingLifecycle.draft ||
        MeetingLifecycle.preparing ||
        MeetingLifecycle.recording ||
        MeetingLifecycle.pausedByUser ||
        MeetingLifecycle.pausedByInterruption ||
        MeetingLifecycle.stopping ||
        MeetingLifecycle.trashed ||
        MeetingLifecycle.deleting => false,
      };
}

/// Durable local transcript versions and explicit current selection.
abstract interface class TranscriptRepository {
  /// Inserts a new parallel analysis version without replacing older versions.
  @useResult
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  });

  /// Lists every retained version for a meeting, newest first.
  @useResult
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId);

  /// Watches committed versions, corrections, provenance, and current selection.
  Stream<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  watchVersions(String meetingId);

  /// Selects an unchanged closed run after atomically revalidating its provenance.
  @useResult
  Future<Result<void, AnalysisRepositoryFailure>> selectReadableVersion(
    TranscriptRun expectedRun,
    TranscriptProcessingInfo? expectedProcessing, {
    required int selectedAtUtcMs,
  });

  /// Loads the selected stable transcript and its current correction context.
  @useResult
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId);

  /// Explicitly selects one owned version as current.
  @useResult
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  });
}

/// Durable state machine for one post-session transcription job and run.
abstract interface class TranscriptionJobRepository {
  /// Idempotently creates a queued job and its queued transcript run.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> enqueue(
    ProcessingJob job,
    TranscriptRun run, {
    required int storedAtUtcMs,
  });

  /// Loads one job without exposing its Drift row.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> load(String jobId);

  /// Loads the durable run whose provenance owns resumed inference.
  @useResult
  Future<Result<TranscriptRun, AnalysisRepositoryFailure>> loadRun(
    String runId,
  );

  /// Watches committed transcription jobs for one meeting.
  Stream<Result<List<ProcessingJob>, AnalysisRepositoryFailure>> watchMeeting(
    String meetingId,
  );

  /// Lists recoverable legacy work, excluding explicit paired-role metadata.
  @useResult
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  listRecoverable();

  /// Claims legacy work; paired roles require their explicit processing writer.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> start(
    String jobId, {
    required int startedAtUtcMs,
  });

  /// Persists monotonic progress and a privacy-safe resume boundary.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> saveProgress(
    String jobId, {
    required double progress,
    required TranscriptionCheckpoint checkpoint,
    required int storedAtUtcMs,
  });

  /// Recovers orphaned legacy work without mutating any explicit paired role.
  @useResult
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  recoverOrphanedRunning({required int recoveredAtUtcMs});

  /// Atomically completes the run, stable segments, job, and first selection.
  @useResult
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> complete(
    String jobId,
    TranscriptRun completedRun,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
    String? warningCode,
  });

  /// Records one privacy-safe terminal failure on the job and run.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> fail(
    String jobId, {
    required String failureCode,
    required int failedAtUtcMs,
  });

  /// Requeues failed legacy work while retaining its safe checkpoint.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> retry(
    String jobId, {
    required int queuedAtUtcMs,
  });

  /// Records cooperative cancellation as a stable terminal failure.
  @useResult
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> cancel(
    String jobId, {
    required int cancelledAtUtcMs,
  });
}

/// Immutable bundled-model manifest persistence.
abstract interface class ModelRepository {
  /// Registers an exact bundled manifest idempotently.
  @useResult
  Future<Result<InstalledModel, AnalysisRepositoryFailure>> registerBundled(
    InstalledModel model, {
    required int observedAtUtcMs,
  });

  /// Lists complete installed manifests and their checked capabilities.
  @useResult
  Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
  listInstalled();
}

/// Non-destructive human-correction persistence and corrected projections.
abstract interface class RevisionRepository {
  /// Applies one typed correction atomically while preserving machine output.
  @useResult
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(Revision revision);

  /// Lists a meeting's immutable correction history in creation order.
  @useResult
  Future<Result<List<Revision>, AnalysisRepositoryFailure>> listMeeting(
    String meetingId,
  );

  /// Projects assignment corrections without mutating the raw engine row.
  @useResult
  Future<Result<SpeakerAssignment, AnalysisRepositoryFailure>>
  materializeSpeakerAssignment(SpeakerAssignment rawAssignment);

  /// Projects label corrections without mutating the raw cluster row.
  @useResult
  Future<Result<Speaker, AnalysisRepositoryFailure>> materializeSpeaker(
    Speaker rawSpeaker,
  );
}
