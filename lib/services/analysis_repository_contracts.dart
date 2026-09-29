import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
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
  }) : segments = List<TranscriptSegment>.unmodifiable(segments);

  /// Versioned inference run and reproducible provenance.
  final TranscriptRun run;

  /// Stable segments owned by [run].
  final List<TranscriptSegment> segments;

  /// Whether the user explicitly selected this version for display/export.
  final bool isCurrent;
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

  /// Explicitly selects one owned version as current.
  @useResult
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
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
