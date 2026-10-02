import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:meta/meta.dart';

/// A durable input assembled from one or more locally stored audio segments.
final class AudioInput {
  /// Creates an audio input for [sessionId].
  AudioInput({required this.sessionId, required List<String> segmentPaths})
    : segmentPaths = List.unmodifiable(segmentPaths);

  /// The owning meeting session.
  final String sessionId;

  /// App-private paths ordered by media time.
  final List<String> segmentPaths;
}

/// Requested parameters for starting capture.
final class AudioCaptureRequest {
  /// Creates a request for [sessionId].
  const AudioCaptureRequest({required this.sessionId});

  /// The durable session that will own captured segments.
  final String sessionId;
}

/// The lifecycle state reported by the native recorder.
enum AudioCaptureState {
  /// No capture session is active.
  idle,

  /// Native capture resources are being prepared.
  preparing,

  /// Audio is being captured and durably written.
  recording,

  /// Capture is intentionally paused by the user.
  pausedByUser,

  /// Capture is paused because the platform interrupted audio input.
  pausedByInterruption,

  /// Durable finalization is in progress.
  stopping,

  /// Capture and its authoritative manifest were finalized.
  finalized,

  /// Committed segments were recovered after abnormal termination.
  recoverable,

  /// Finalization failed but authoritative segments remain recoverable.
  failedFinalization,
}

/// A value-only snapshot of authoritative recorder state.
final class AudioCaptureSnapshot {
  /// Creates a recorder snapshot.
  const AudioCaptureSnapshot({
    required this.state,
    required this.elapsed,
    required this.bytesWritten,
  });

  /// Current lifecycle state.
  final AudioCaptureState state;

  /// Pause-aware captured media duration.
  final Duration elapsed;

  /// Bytes durably written so far.
  final int bytesWritten;
}

/// Recoverable failures produced by [AudioCaptureService].
sealed class AudioCaptureFailure implements Failure {
  const AudioCaptureFailure(this.code);

  @override
  final String code;
}

/// Capture could not perform the requested transition.
final class AudioCaptureUnavailable extends AudioCaptureFailure {
  /// Creates a capture failure with a stable [code].
  const AudioCaptureUnavailable(super.code);
}

/// Boundary for durable native microphone capture.
abstract interface class AudioCaptureService {
  /// Recorder snapshots emitted independently of Flutter screen lifecycle.
  Stream<AudioCaptureSnapshot> get snapshots;

  /// Starts a new recording without replacing an active one.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  );

  /// Pauses the active recording.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> pause();

  /// Resumes the paused recording.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> resume();

  /// Finalizes the active recording and its durable manifest.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> stop();
}

/// A request to transcribe local audio.
final class TranscriptionRequest {
  /// Creates a transcription request.
  const TranscriptionRequest({required this.runId, required this.audio});

  /// Stable identifier shared by progress events and the final output.
  final String runId;

  /// The local audio to analyze.
  final AudioInput audio;
}

/// A timestamped piece of recognized speech.
final class TranscriptChunk {
  /// Creates a transcript chunk.
  const TranscriptChunk({
    required this.segmentId,
    required this.start,
    required this.end,
    required this.rawText,
    required this.displayText,
    required this.stability,
  });

  /// Stable identifier within this transcript run.
  final String segmentId;

  /// Inclusive media-time start.
  final Duration start;

  /// Exclusive media-time end.
  final Duration end;

  /// Raw recognized text without translation or rewriting.
  final String rawText;

  /// Deterministically formatted text shown to the user.
  final String displayText;

  /// Whether an incremental engine may still replace this chunk.
  final TranscriptStability stability;
}

/// Stability of an incremental transcript hypothesis.
enum TranscriptStability {
  /// The engine may replace this draft hypothesis.
  unstable,

  /// The engine has finalized this segment for the current run.
  stable,
}

/// Output from one transcription engine run.
final class TranscriptionOutput {
  /// Creates transcription output.
  TranscriptionOutput({required List<TranscriptChunk> chunks})
    : chunks = List.unmodifiable(chunks);

  /// Timestamped chunks in media-time order.
  final List<TranscriptChunk> chunks;
}

/// An observable event emitted while a transcription run is active.
sealed class TranscriptionEvent {
  const TranscriptionEvent({required this.runId});

  /// Stable run identifier.
  final String runId;
}

/// An incremental transcript replacement with current processing backlog.
final class TranscriptionDraftUpdated extends TranscriptionEvent {
  /// Creates an incremental draft event.
  const TranscriptionDraftUpdated({
    required super.runId,
    required this.chunk,
    required this.backlog,
  });

  /// Partial or stable timestamped hypothesis.
  final TranscriptChunk chunk;

  /// Audio duration waiting to be processed.
  final Duration backlog;
}

/// Progress for a post-session or live transcription run.
final class TranscriptionProgressUpdated extends TranscriptionEvent {
  /// Creates a progress event.
  const TranscriptionProgressUpdated({
    required super.runId,
    required this.fraction,
    required this.remaining,
  });

  /// Normalized completed fraction from zero to one.
  final double fraction;

  /// Estimated remaining processing time when known.
  final Duration? remaining;
}

/// Recoverable failures produced by [TranscriptionEngine].
sealed class TranscriptionFailure implements Failure {
  const TranscriptionFailure(this.code);

  @override
  final String code;
}

/// Transcription could not run or finish locally.
final class TranscriptionUnavailable extends TranscriptionFailure {
  /// Creates a transcription failure with a stable [code].
  const TranscriptionUnavailable(super.code);
}

/// Replaceable local speech-to-text engine boundary.
abstract interface class TranscriptionEngine {
  /// Observes incremental results and progress for [runId].
  Stream<TranscriptionEvent> eventsFor(String runId);

  /// Transcribes local audio without affecting the source recording.
  @useResult
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  );
}

/// A request to identify the primary language of local audio.
final class LanguageIdentificationRequest {
  /// Creates a language-identification request.
  const LanguageIdentificationRequest({
    required this.segmentId,
    required this.start,
    required this.end,
    required this.audio,
  });

  /// Stable transcript-segment identifier receiving the result.
  final String segmentId;

  /// Inclusive media-time start of the stable segment.
  final Duration start;

  /// Exclusive media-time end of the stable segment.
  final Duration end;

  /// The local audio to analyze.
  final AudioInput audio;
}

/// Supported language labels for a segment.
enum IdentifiedLanguage {
  /// Predominantly Chinese speech.
  chinese,

  /// Predominantly English speech.
  english,

  /// Material Chinese and English speech in one segment.
  mixed,

  /// Confidence is too low to force a language label.
  uncertain,
}

/// Local language-identification output.
final class LanguageIdentification {
  /// Creates a language result with normalized [confidence].
  const LanguageIdentification({
    required this.segmentId,
    required this.language,
    required this.confidence,
  });

  /// Stable transcript-segment identifier this result labels.
  final String segmentId;

  /// The best supported label.
  final IdentifiedLanguage language;

  /// A normalized confidence value from zero to one.
  final double confidence;
}

/// Recoverable failures produced by [LanguageIdentificationEngine].
sealed class LanguageIdentificationFailure implements Failure {
  const LanguageIdentificationFailure(this.code);

  @override
  final String code;
}

/// Language identification could not finish locally.
final class LanguageIdentificationUnavailable
    extends LanguageIdentificationFailure {
  /// Creates a language-identification failure with a stable [code].
  const LanguageIdentificationUnavailable(super.code);
}

/// Replaceable local language-identification boundary.
// The class is intentionally an interface so implementations stay injectable.
// ignore: one_member_abstracts
abstract interface class LanguageIdentificationEngine {
  /// Identifies a segment without translating or rewriting it.
  @useResult
  Future<Result<LanguageIdentification, LanguageIdentificationFailure>>
  identify(
    LanguageIdentificationRequest request,
  );
}

/// A request to separate speakers in local audio.
final class SpeakerDiarizationRequest {
  /// Creates a diarization request.
  const SpeakerDiarizationRequest({required this.audio, this.expectedSpeakers});

  /// The local audio to analyze.
  final AudioInput audio;

  /// Optional user hint constrained by the feature layer to two through six.
  final int? expectedSpeakers;
}

/// One meeting-local speaker turn.
final class SpeakerTurn {
  /// Creates a speaker turn.
  const SpeakerTurn({
    required this.speakerId,
    required this.start,
    required this.end,
    required this.confidence,
  });

  /// Stable meeting-local speaker identifier.
  final String speakerId;

  /// Inclusive media-time start.
  final Duration start;

  /// Exclusive media-time end.
  final Duration end;

  /// A normalized confidence value from zero to one.
  final double confidence;
}

/// Output from one diarization run.
final class SpeakerDiarizationOutput {
  /// Creates diarization output.
  SpeakerDiarizationOutput({required List<SpeakerTurn> turns})
    : turns = List.unmodifiable(turns);

  /// Speaker turns in media-time order.
  final List<SpeakerTurn> turns;
}

/// Recoverable failures produced by [SpeakerDiarizationEngine].
sealed class SpeakerDiarizationFailure implements Failure {
  const SpeakerDiarizationFailure(this.code);

  @override
  final String code;
}

/// Speaker diarization could not finish locally.
final class SpeakerDiarizationUnavailable extends SpeakerDiarizationFailure {
  /// Creates a speaker-diarization failure with a stable [code].
  const SpeakerDiarizationUnavailable(super.code);
}

/// Replaceable local speaker-diarization boundary.
// The class is intentionally an interface so implementations stay injectable.
// ignore: one_member_abstracts
abstract interface class SpeakerDiarizationEngine {
  /// Analyzes local audio after recording unless explicitly experimental.
  @useResult
  Future<Result<SpeakerDiarizationOutput, SpeakerDiarizationFailure>> analyze(
    SpeakerDiarizationRequest request,
  );
}

/// An installed, integrity-verifiable local model.
final class ModelDescriptor {
  /// Creates a model descriptor.
  const ModelDescriptor({
    required this.id,
    required this.version,
    required this.bytes,
  });

  /// Stable manifest identifier.
  final String id;

  /// Model or weight version.
  final String version;

  /// Installed bytes.
  final int bytes;
}

/// Immutable inventory of bundled models visible to the application.
final class ModelInventory {
  /// Creates an immutable model inventory.
  ModelInventory({required List<ModelDescriptor> models})
    : models = List.unmodifiable(models);

  /// Installed models.
  final List<ModelDescriptor> models;
}

/// Recoverable failures produced by [ModelManager].
sealed class ModelFailure implements Failure {
  const ModelFailure(this.code);

  @override
  final String code;
}

/// Model enumeration or integrity verification failed.
final class ModelUnavailable extends ModelFailure {
  /// Creates a model failure with a stable [code].
  const ModelUnavailable(super.code);
}

/// Boundary for bundled local model inventory and integrity checks.
abstract interface class ModelManager {
  /// Lists models installed with the app.
  @useResult
  Future<Result<ModelInventory, ModelFailure>> listInstalled();

  /// Verifies one installed model against its manifest.
  @useResult
  Future<Result<ModelDescriptor, ModelFailure>> verify(String modelId);
}

/// Coarse thermal state used for explicit product degradation.
enum ThermalState {
  /// No thermal degradation is needed.
  nominal,

  /// The device is warming and should be observed.
  warm,

  /// AI work should be reduced or paused.
  hot,

  /// Only safety-critical recording work should continue.
  critical,

  /// The platform could not provide a thermal state.
  unknown,
}

/// A privacy-safe device performance sample.
final class DevicePerformanceSnapshot {
  /// Creates a performance sample.
  DevicePerformanceSnapshot({
    required this.observedAtMonotonic,
    required this.processCpuTime,
    required this.processPssBytes,
    required this.thermalState,
    required this.isCharging,
    this.remainingDeviceEnergyNanowattHours,
  }) : assert(
         !observedAtMonotonic.isNegative,
         'observedAtMonotonic must be non-negative',
       ),
       assert(
         !processCpuTime.isNegative,
         'processCpuTime must be non-negative',
       ),
       assert(processPssBytes >= 0, 'processPssBytes must be non-negative'),
       assert(
         processPssBytes <= 9223372036854775807,
         'processPssBytes must fit signed 64-bit',
       ),
       assert(
         remainingDeviceEnergyNanowattHours == null ||
             remainingDeviceEnergyNanowattHours >= 0,
         'remainingDeviceEnergyNanowattHours must be non-negative',
       ),
       assert(
         remainingDeviceEnergyNanowattHours == null ||
             remainingDeviceEnergyNanowattHours <= 9223372036854775807,
         'remainingDeviceEnergyNanowattHours must fit signed 64-bit',
       );

  /// Monotonic time at which the platform observed this sample.
  final Duration observedAtMonotonic;

  /// Cumulative CPU time consumed by this process.
  final Duration processCpuTime;

  /// Current process proportional-set-size sample in bytes.
  final int processPssBytes;

  /// Current coarse thermal state.
  final ThermalState thermalState;

  /// Remaining device energy in nanowatt-hours when the platform supports it.
  final int? remainingDeviceEnergyNanowattHours;

  /// Whether the device was charging when the sample was observed.
  final bool isCharging;
}

/// Recoverable failures produced by [ThermalAndPerformanceMonitor].
sealed class PerformanceFailure implements Failure {
  const PerformanceFailure(this.code);

  @override
  final String code;
}

/// Device performance metrics were unavailable.
final class PerformanceUnavailable extends PerformanceFailure {
  /// Creates a performance failure with a stable [code].
  const PerformanceUnavailable(super.code);
}

/// Boundary for thermal and resource observations.
// The interface keeps the platform read injectable and independently fakeable.
// ignore: one_member_abstracts
abstract interface class ThermalAndPerformanceMonitor {
  /// Reads one current privacy-safe device performance sample.
  @useResult
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>> current();
}

/// Minimal session projection used before the full domain model is introduced.
@immutable
final class SessionSummary {
  /// Creates a session projection.
  const SessionSummary({
    required this.id,
    required this.title,
    this.isRecoverable = false,
  });

  /// Stable local session identifier.
  final String id;

  /// User-visible local title.
  final String title;

  /// Whether committed audio needs explicit user-led recovery.
  final bool isRecoverable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSummary &&
          id == other.id &&
          title == other.title &&
          isRecoverable == other.isRecoverable;

  @override
  int get hashCode => Object.hash(id, title, isRecoverable);
}

/// Immutable collection of current session projections.
@immutable
final class SessionCollection {
  /// Creates an immutable session collection.
  SessionCollection({required List<SessionSummary> sessions})
    : sessions = List.unmodifiable(sessions);

  /// Current sessions in repository order.
  final List<SessionSummary> sessions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionCollection ||
        sessions.length != other.sessions.length) {
      return false;
    }
    for (var index = 0; index < sessions.length; index += 1) {
      if (sessions[index] != other.sessions[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(sessions);
}

/// Library partition selected by a session query.
enum SessionLibraryKind {
  /// Meetings visible in the normal library.
  active,

  /// Meetings retained in the seven-day local trash.
  trash,
}

/// Stable seek cursor for descending meeting creation order.
@immutable
final class SessionLibraryCursor {
  /// Creates a cursor immediately before [createdAtUtcMs] and [id].
  const SessionLibraryCursor({required this.createdAtUtcMs, required this.id});

  /// Creation instant of the last item in the previous page.
  final int createdAtUtcMs;

  /// Stable tie-breaker of the last item in the previous page.
  final String id;
}

/// Scoped, keyset-paged meeting-library query.
@immutable
final class SessionLibraryQuery {
  /// Creates a library query.
  const SessionLibraryQuery({
    required this.kind,
    required this.limit,
    this.before,
  }) : assert(limit > 0 && limit <= 100, 'limit must be between 1 and 100');

  /// Active library or local trash.
  final SessionLibraryKind kind;

  /// Maximum number of meetings returned.
  final int limit;

  /// Optional seek cursor; offset pagination is deliberately unsupported.
  final SessionLibraryCursor? before;
}

/// One immutable page of full meeting values.
@immutable
final class SessionLibraryPage {
  /// Creates a page and defensively copies [meetings].
  SessionLibraryPage({
    required List<Meeting> meetings,
    required this.nextCursor,
  }) : meetings = List.unmodifiable(meetings);

  /// Meetings in descending creation order.
  final List<Meeting> meetings;

  /// Cursor for the next page, or null when the page is exhausted.
  final SessionLibraryCursor? nextCursor;
}

/// Deterministic title or transcript search result.
@immutable
final class SessionSearchHit {
  /// Creates a search hit, optionally anchored to a transcript segment.
  const SessionSearchHit({
    required this.meeting,
    this.transcriptSegmentId,
    this.mediaOffset,
  }) : assert(
         (transcriptSegmentId == null) == (mediaOffset == null),
         'transcript anchor and media offset must appear together',
       );

  /// Meeting containing the match.
  final Meeting meeting;

  /// Matching current-version transcript segment, null for a title match.
  final String? transcriptSegmentId;

  /// Playback position for a transcript match.
  final Duration? mediaOffset;
}

/// Authoritative audio bytes grouped by meeting lifecycle.
@immutable
final class SessionStorageAccounting {
  /// Creates storage accounting from canonical byte counts.
  const SessionStorageAccounting({
    required this.activeMeetingBytes,
    required this.trashBytes,
  });

  /// Authoritative audio bytes owned by non-trashed meetings.
  final int activeMeetingBytes;

  /// Authoritative audio bytes retained in local trash.
  final int trashBytes;

  /// Total authoritative meeting audio represented in the database.
  int get totalMeetingBytes => activeMeetingBytes + trashBytes;
}

/// Filesystem/native evidence supplied to startup reconciliation.
@immutable
final class SessionRecoveryEvidence {
  /// Creates evidence without exposing file paths through the repository API.
  const SessionRecoveryEvidence({
    required this.meetingId,
    required this.hasCommittedAudio,
  });

  /// Meeting observed in the authoritative manifest.
  final String meetingId;

  /// Whether at least one committed audio segment remains usable.
  final bool hasCommittedAudio;
}

/// Result of one atomic startup reconciliation pass.
@immutable
final class SessionRecoveryReport {
  /// Creates an immutable reconciliation report.
  SessionRecoveryReport({
    required List<String> markedRecoverableIds,
    required List<String> unchangedIds,
  }) : markedRecoverableIds = List.unmodifiable(markedRecoverableIds),
       unchangedIds = List.unmodifiable(unchangedIds);

  /// Meetings newly marked recoverable.
  final List<String> markedRecoverableIds;

  /// Meetings deliberately left unchanged.
  final List<String> unchangedIds;
}

/// Recoverable failures produced by [SessionRepository].
sealed class SessionRepositoryFailure implements Failure {
  const SessionRepositoryFailure(this.code);

  @override
  final String code;
}

/// Requested meeting does not exist locally.
final class SessionNotFound extends SessionRepositoryFailure {
  /// Creates a not-found failure.
  const SessionNotFound() : super('session_not_found');
}

/// Requested lifecycle transition is invalid for the current meeting state.
final class SessionInvalidLifecycle extends SessionRepositoryFailure {
  /// Creates an invalid-lifecycle failure.
  const SessionInvalidLifecycle() : super('session_invalid_lifecycle');
}

/// Local database or private filesystem was temporarily unavailable.
sealed class SessionStoreUnavailable extends SessionRepositoryFailure {
  const SessionStoreUnavailable(super.code);
}

/// Session persistence could not complete locally.
final class SessionRepositoryUnavailable extends SessionStoreUnavailable {
  /// Creates a repository failure with a stable [code].
  const SessionRepositoryUnavailable(super.code);
}

/// Boundary for durable local session persistence.
abstract interface class SessionRepository {
  /// Lists current session projections.
  @useResult
  Future<Result<SessionCollection, SessionRepositoryFailure>> list();

  /// Persists a session projection before acknowledging success.
  @useResult
  Future<Result<SessionSummary, SessionRepositoryFailure>> save(
    SessionSummary session,
  );

  /// Watches a scoped, seek-paged library projection after durable commits.
  Stream<Result<SessionLibraryPage, SessionRepositoryFailure>> watchLibrary(
    SessionLibraryQuery query,
  );

  /// Reads a scoped, seek-paged library projection.
  @useResult
  Future<Result<SessionLibraryPage, SessionRepositoryFailure>> queryLibrary(
    SessionLibraryQuery query,
  );

  /// Persists meeting metadata; analysis-version selection has its own writer.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  );

  /// Searches local titles and the selected transcript version.
  @useResult
  Future<Result<List<SessionSearchHit>, SessionRepositoryFailure>> search(
    String query,
  );

  /// Moves a meeting to local trash without deleting owned records.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> moveToTrash(
    String meetingId, {
    required int atUtcMs,
  });

  /// Restores the durable lifecycle saved when a meeting entered trash.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> restoreFromTrash(
    String meetingId, {
    required int atUtcMs,
  });

  /// Permanently deletes a meeting already in trash and its owned records.
  @useResult
  Future<Result<void, SessionRepositoryFailure>> permanentlyDelete(
    String meetingId,
  );

  /// Computes authoritative meeting audio bytes by lifecycle partition.
  @useResult
  Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
  accountStorage();

  /// Reconciles persisted lifecycle against externally verified audio evidence.
  @useResult
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
  });
}

/// Supported explicit local export formats.
enum ExportFormat {
  /// Finalized audio or recoverable segments.
  audio,

  /// Plain transcript text.
  text,

  /// Timestamped subtitle text.
  subtitles,

  /// Structured session data.
  json,

  /// A checksummed multi-file archive.
  archive,
}

/// A user-authorized export request.
final class ExportRequest {
  /// Creates an export request.
  const ExportRequest({required this.sessionId, required this.format});

  /// Session to export.
  final String sessionId;

  /// Requested output format.
  final ExportFormat format;
}

/// Receipt for a completed local export.
final class ExportReceipt {
  /// Creates an export receipt.
  const ExportReceipt({required this.outputPath});

  /// User-selected output path.
  final String outputPath;
}

/// Recoverable failures produced by [ExportService].
sealed class ExportFailure implements Failure {
  const ExportFailure(this.code);

  @override
  final String code;
}

/// A local export could not finish.
final class ExportUnavailable extends ExportFailure {
  /// Creates an export failure with a stable [code].
  const ExportUnavailable(super.code);
}

/// Boundary for explicit user-authorized local exports.
// The class is intentionally an interface so implementations stay injectable.
// ignore: one_member_abstracts
abstract interface class ExportService {
  /// Writes selected session data to the user-selected destination.
  @useResult
  Future<Result<ExportReceipt, ExportFailure>> export(ExportRequest request);
}
