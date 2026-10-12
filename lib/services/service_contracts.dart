import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
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

/// Throttled microphone read-health counters reported by native capture.
@immutable
final class AudioInputHealthSnapshot {
  /// Creates a cumulative input-health snapshot for the active session.
  const AudioInputHealthSnapshot({
    required this.readCalls,
    required this.pcmBytes,
    required this.shortReads,
    required this.zeroReads,
    required this.errorReads,
    required this.maximumReadGap,
    required this.timestampRegressions,
  });

  /// Number of microphone read attempts.
  final int readCalls;

  /// PCM bytes successfully received from Android's audio source.
  final int pcmBytes;

  /// Reads that returned fewer bytes than requested.
  final int shortReads;

  /// Reads that returned no audio data.
  final int zeroReads;

  /// Reads that failed with an error result.
  final int errorReads;

  /// Longest observed interval between consecutive reads.
  final Duration maximumReadGap;

  /// Count of non-monotonic capture timestamps.
  final int timestampRegressions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioInputHealthSnapshot &&
          readCalls == other.readCalls &&
          pcmBytes == other.pcmBytes &&
          shortReads == other.shortReads &&
          zeroReads == other.zeroReads &&
          errorReads == other.errorReads &&
          maximumReadGap == other.maximumReadGap &&
          timestampRegressions == other.timestampRegressions;

  @override
  int get hashCode => Object.hash(
    readCalls,
    pcmBytes,
    shortReads,
    zeroReads,
    errorReads,
    maximumReadGap,
    timestampRegressions,
  );
}

/// A value-only snapshot of authoritative recorder state.
final class AudioCaptureSnapshot {
  /// Creates a recorder snapshot.
  const AudioCaptureSnapshot({
    required this.state,
    required this.elapsed,
    required this.bytesWritten,
    this.sessionId,
    this.revision = 0,
    this.inputHealth,
  });

  /// Stable meeting identifier, or null only when [state] is idle.
  final String? sessionId;

  /// Current lifecycle state.
  final AudioCaptureState state;

  /// Pause-aware captured media duration.
  final Duration elapsed;

  /// Bytes durably written so far.
  final int bytesWritten;

  /// Monotonic native persistence revision used to reject stale observations.
  final int revision;

  /// Live microphone input health, absent before native capture reports it.
  final AudioInputHealthSnapshot? inputHealth;
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

/// Capture was refused because the four-hour storage preflight failed.
final class AudioCaptureInsufficientStorage extends AudioCaptureFailure {
  /// Creates a structured storage failure.
  const AudioCaptureInsufficientStorage({
    required String code,
    required this.availableBytes,
    required this.requiredBytes,
  }) : super(code);

  /// Free app-private filesystem bytes observed by Android.
  final int? availableBytes;

  /// Bytes required by the selected capture safety policy.
  final int requiredBytes;
}

/// Closed state reported by the local meeting playback boundary.
enum SessionPlaybackState {
  /// No validated playback artifact is loaded.
  unavailable,

  /// A validated artifact is loaded and positioned.
  ready,

  /// Audio is currently playing.
  playing,

  /// Playback was explicitly paused.
  paused,

  /// Playback reached the end of the meeting timeline.
  completed,
}

/// Value-only native playback observation that never exposes a file path.
@immutable
final class SessionPlaybackSnapshot {
  /// Creates a playback snapshot.
  const SessionPlaybackSnapshot({
    required this.sessionId,
    required this.state,
    required this.position,
    required this.duration,
  });

  /// Loaded meeting identity.
  final String sessionId;

  /// Current playback lifecycle.
  final SessionPlaybackState state;

  /// Pause-free media position.
  final Duration position;

  /// Validated artifact duration.
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPlaybackSnapshot &&
          sessionId == other.sessionId &&
          state == other.state &&
          position == other.position &&
          duration == other.duration;

  @override
  int get hashCode => Object.hash(sessionId, state, position, duration);
}

/// Typed local playback failure with a stable privacy-safe code.
final class SessionPlaybackFailure implements Failure {
  /// Creates a playback failure.
  const SessionPlaybackFailure(this.code);

  @override
  final String code;
}

/// Native playback boundary for generation-validated local meeting audio.
abstract interface class SessionPlaybackService {
  /// Loads the current validated playback artifact for [sessionId].
  @useResult
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> load(
    String sessionId, {
    required String ownerId,
  });

  /// Reads current playback state.
  @useResult
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> current({
    required String ownerId,
  });

  /// Starts or resumes playback.
  @useResult
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> play({
    required String ownerId,
  });

  /// Pauses playback.
  @useResult
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> pause({
    required String ownerId,
  });

  /// Seeks to pause-free [position].
  @useResult
  Future<Result<SessionPlaybackSnapshot, SessionPlaybackFailure>> seek(
    Duration position, {
    required String ownerId,
  });

  /// Releases the native player owned by this screen flow.
  Future<void> release({required String ownerId});
}

/// Boundary for durable native microphone capture.
abstract interface class AudioCaptureService {
  /// Recorder snapshots emitted independently of Flutter screen lifecycle.
  Stream<AudioCaptureSnapshot> get snapshots;

  /// Reads the latest authoritative native snapshot for process restoration.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current();

  /// Starts a new recording without replacing an active one.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  );

  /// Finalizes recovered audio without opening the microphone.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovered(
    String sessionId,
  );

  /// Explicitly starts a new segment after a recoverable interruption.
  @useResult
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> continueRecovered(
    String sessionId,
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
  const TranscriptionRequest({
    required this.runId,
    required this.audio,
    this.modelId = 'whisper-base-q5_1',
    this.languageHint = MeetingLanguageMode.mixed,
    this.parameterVersion = 1,
  });

  /// Stable identifier shared by progress events and the final output.
  final String runId;

  /// The local audio to analyze.
  final AudioInput audio;

  /// Stable bundled-model identifier requested for this run.
  final String modelId;

  /// Recognition-language preference selected for the meeting.
  final MeetingLanguageMode languageHint;

  /// Canonical inference-parameter schema used for this run.
  final int parameterVersion;
}

/// A request to start bounded near-real-time draft inference for a meeting.
final class TranscriptionDraftRequest {
  /// Creates a live draft request.
  const TranscriptionDraftRequest({
    required this.runId,
    required this.meetingId,
    this.modelId = 'whisper-base-q5_1',
    this.languageHint = MeetingLanguageMode.mixed,
    this.parameterVersion = 1,
  });

  /// Stable identifier shared by live events and stop requests.
  final String runId;

  /// Active recording whose canonical PCM fan-out supplies inference.
  final String meetingId;

  /// Stable bundled-model identifier requested for this run.
  final String modelId;

  /// Recognition-language preference selected for the meeting.
  final MeetingLanguageMode languageHint;

  /// Canonical inference-parameter schema used for this run.
  final int parameterVersion;
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
  TranscriptionOutput({
    required List<TranscriptChunk> chunks,
    this.engineVersion = 'unknown',
    this.warningCode,
  }) : chunks = List.unmodifiable(chunks);

  /// Timestamped chunks in media-time order.
  final List<TranscriptChunk> chunks;

  /// Exact native inference-engine version that produced [chunks].
  final String engineVersion;

  /// Stable partial-input warning retained with a successful output.
  final String? warningCode;
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

/// Explicit notification that live inference degraded or stopped safely.
final class TranscriptionDraftDegraded extends TranscriptionEvent {
  /// Creates a live degradation event.
  const TranscriptionDraftDegraded({
    required super.runId,
    required this.reason,
    required this.backlog,
    required this.incomplete,
  });

  /// Stable, user-presentable reason code without native diagnostic detail.
  final String reason;

  /// Audio duration waiting when degradation was detected.
  final Duration backlog;

  /// Whether the visible draft may omit audio or unstable text.
  final bool incomplete;
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

  /// Starts bounded live inference without affecting canonical recording.
  @useResult
  Future<Result<void, TranscriptionFailure>> startDraft(
    TranscriptionDraftRequest request,
  );

  /// Stops and releases a live draft run. Repeated calls are successful.
  @useResult
  Future<Result<void, TranscriptionFailure>> stopDraft(String runId);

  /// Requests cooperative cancellation for [runId].
  @useResult
  Future<Result<void, TranscriptionFailure>> cancel(String runId);
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

/// One meeting row projected for the local library.
@immutable
final class SessionLibraryItem {
  /// Creates a library row from a meeting and its derived audio size.
  const SessionLibraryItem({
    required this.meeting,
    required this.committedAudioBytes,
  }) : assert(
         committedAudioBytes >= 0,
         'committedAudioBytes must be non-negative',
       );

  /// Durable meeting value.
  final Meeting meeting;

  /// Sum of journal-authorized segment bytes, derived at query time.
  final int committedAudioBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionLibraryItem &&
          meeting == other.meeting &&
          committedAudioBytes == other.committedAudioBytes;

  @override
  int get hashCode => Object.hash(meeting, committedAudioBytes);
}

/// One immutable page of meeting-library projections.
@immutable
final class SessionLibraryPage {
  /// Creates a page and defensively copies [items].
  SessionLibraryPage({
    required List<SessionLibraryItem> items,
    required this.nextCursor,
  }) : items = List.unmodifiable(items);

  /// Meeting rows in descending creation order.
  final List<SessionLibraryItem> items;

  /// Meetings in descending creation order.
  List<Meeting> get meetings =>
      List<Meeting>.unmodifiable(items.map((item) => item.meeting));

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
    this.committedAudioBytes = 0,
  }) : assert(
         (transcriptSegmentId == null) == (mediaOffset == null),
         'transcript anchor and media offset must appear together',
       ),
       assert(
         committedAudioBytes >= 0,
         'committedAudioBytes must be non-negative',
       );

  /// Meeting containing the match.
  final Meeting meeting;

  /// Matching current-version transcript segment, null for a title match.
  final String? transcriptSegmentId;

  /// Playback position for a transcript match.
  final Duration? mediaOffset;

  /// Sum of journal-authorized segment bytes, derived at query time.
  final int committedAudioBytes;
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

/// One manifest-published segment observed during startup reconciliation.
@immutable
final class SessionRecoverySegmentEvidence {
  /// Creates verified metadata for one authoritative segment file.
  const SessionRecoverySegmentEvidence({
    required this.sequence,
    required this.relativePath,
    required this.mediaStart,
    required this.mediaDuration,
    required this.committedBytes,
    required this.state,
  });

  /// Manifest order within the meeting.
  final int sequence;

  /// Validated path below the app-private storage root.
  final AppRelativePath relativePath;

  /// Start on the pause-free media timeline.
  final Duration mediaStart;

  /// Journal-authorized media duration.
  final Duration mediaDuration;

  /// Journal-authorized byte prefix.
  final int committedBytes;

  /// Reconciled file state.
  final AudioSegmentState state;
}

/// Overall integrity of the journal-authorized recovered timeline.
enum RecoveryIntegrityState {
  /// Every published segment is present and contiguous with no discarded tail.
  complete,

  /// Some recording interval is missing, damaged, or was not durably committed.
  partial,
}

/// Privacy-safe reason why recovered audio is partial.
@immutable
final class SessionRecoveryDiagnostic {
  /// Creates a stable diagnostic optionally scoped to one manifest segment.
  const SessionRecoveryDiagnostic({required this.code, this.segmentSequence});

  /// Stable machine-readable recovery code.
  final String code;

  /// Manifest segment sequence associated with the issue, when applicable.
  final int? segmentSequence;
}

/// Exact journal-authorized prefix eligible for raw-segment export.
@immutable
final class SessionRecoveryRawExportSegment {
  /// Creates one ordered raw-export plan entry.
  const SessionRecoveryRawExportSegment({
    required this.sequence,
    required this.relativePath,
    required this.committedBytes,
  });

  /// Manifest order within the meeting.
  final int sequence;

  /// Validated app-private relative path.
  final AppRelativePath relativePath;

  /// Exact byte prefix authorized by the commit journal.
  final int committedBytes;
}

/// Durable recovery explanation and raw-segment export plan for one meeting.
@immutable
final class SessionRecoveryDetails {
  /// Creates immutable recovery details.
  SessionRecoveryDetails({
    required this.integrityState,
    required List<SessionRecoveryDiagnostic> diagnostics,
    required List<SessionRecoveryRawExportSegment> rawExportSegments,
  }) : diagnostics = List.unmodifiable(diagnostics),
       rawExportSegments = List.unmodifiable(rawExportSegments);

  /// Whether all journal-authorized recording intervals remain available.
  final RecoveryIntegrityState integrityState;

  /// Stable privacy-safe findings retained after startup reconciliation.
  final List<SessionRecoveryDiagnostic> diagnostics;

  /// Ordered committed prefixes eligible for explicit raw-segment export.
  final List<SessionRecoveryRawExportSegment> rawExportSegments;
}

/// Transactionally consistent local projection for one session detail view.
@immutable
final class SessionDetail {
  /// Creates an immutable meeting-local detail projection.
  SessionDetail({
    required this.meeting,
    required List<AudioSegment> segments,
    required List<SessionEvent> events,
    required List<Bookmark> bookmarks,
    required List<ProcessingJob> processingJobs,
    required List<SessionRecoveryDiagnostic> recoveryDiagnostics,
  }) : segments = List.unmodifiable(segments),
       events = List.unmodifiable(events),
       bookmarks = List.unmodifiable(bookmarks),
       processingJobs = List.unmodifiable(processingJobs),
       recoveryDiagnostics = List.unmodifiable(recoveryDiagnostics);

  /// Durable meeting aggregate.
  final Meeting meeting;

  /// Authoritative audio metadata ordered by manifest sequence.
  final List<AudioSegment> segments;

  /// Wall-clock capture events ordered by session sequence.
  final List<SessionEvent> events;

  /// User markers ordered by media time and stable identity.
  final List<Bookmark> bookmarks;

  /// Latest-first local processing records.
  final List<ProcessingJob> processingJobs;

  /// Privacy-safe recovery findings ordered by segment and identity.
  final List<SessionRecoveryDiagnostic> recoveryDiagnostics;
}

/// Filesystem/native evidence supplied to startup reconciliation.
@immutable
final class SessionRecoveryEvidence {
  /// Creates evidence from one valid authoritative manifest.
  SessionRecoveryEvidence({
    required this.meetingId,
    required this.storageKey,
    required List<SessionRecoverySegmentEvidence> segments,
    this.integrityState = RecoveryIntegrityState.complete,
    List<SessionRecoveryDiagnostic> diagnostics = const [],
    List<SessionRecoveryRawExportSegment>? rawExportSegments,
  }) : segments = List.unmodifiable(segments),
       diagnostics = List.unmodifiable(diagnostics),
       rawExportSegments = List.unmodifiable(
         rawExportSegments ??
             segments
                 .where(
                   (segment) =>
                       segment.state == AudioSegmentState.committed &&
                       segment.committedBytes > 0,
                 )
                 .map(
                   (segment) => SessionRecoveryRawExportSegment(
                     sequence: segment.sequence,
                     relativePath: segment.relativePath,
                     committedBytes: segment.committedBytes,
                   ),
                 ),
       );

  /// Meeting observed in the authoritative manifest.
  final String meetingId;

  /// Opaque app-private recording directory key containing the manifest.
  final String storageKey;

  /// Manifest-published segments in media order.
  final List<SessionRecoverySegmentEvidence> segments;

  /// Whether the recovered media timeline is complete or only partially usable.
  final RecoveryIntegrityState integrityState;

  /// Stable privacy-safe reasons for a partial classification.
  final List<SessionRecoveryDiagnostic> diagnostics;

  /// Ordered journal-authorized prefixes available to explicit export.
  final List<SessionRecoveryRawExportSegment> rawExportSegments;

  /// Whether users must be warned that some audio is unavailable.
  bool get isPartial => integrityState == RecoveryIntegrityState.partial;

  /// Whether at least one journal-authorized segment remains usable.
  bool get hasCommittedAudio => segments.any(
    (segment) =>
        segment.state == AudioSegmentState.committed &&
        segment.committedBytes > 0,
  );
}

/// Result of one atomic startup reconciliation pass.
@immutable
final class SessionRecoveryReport {
  /// Creates an immutable reconciliation report.
  SessionRecoveryReport({
    required List<String> markedRecoverableIds,
    required List<String> unchangedIds,
    List<String> createdRecoverableIds = const <String>[],
    List<String> partialMeetingIds = const <String>[],
    this.reconciledSegmentCount = 0,
  }) : markedRecoverableIds = List.unmodifiable(markedRecoverableIds),
       createdRecoverableIds = List.unmodifiable(createdRecoverableIds),
       partialMeetingIds = List.unmodifiable(partialMeetingIds),
       unchangedIds = List.unmodifiable(unchangedIds);

  /// Meetings newly marked recoverable.
  final List<String> markedRecoverableIds;

  /// Meetings reconstructed from committed audio with no database row.
  final List<String> createdRecoverableIds;

  /// Meetings whose native recovery evidence is only partially usable.
  final List<String> partialMeetingIds;

  /// Meetings deliberately left unchanged.
  final List<String> unchangedIds;

  /// Authoritative segment rows mirrored from valid manifests.
  final int reconciledSegmentCount;
}

/// Recoverable failures produced by [SessionRepository].
sealed class SessionRepositoryFailure implements Failure {
  const SessionRepositoryFailure(this.code);

  @override
  final String code;
}

/// Explicit user decision for an abnormally interrupted meeting.
enum RecoveryResolution {
  /// Keep existing audio and close the meeting without microphone capture.
  save,

  /// Start a new continuation segment after native safety checks.
  continueRecording,
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

/// Defaults remembered locally for the next recording setup.
@immutable
final class RecordingDefaults extends ValueObject {
  /// Creates recording setup defaults.
  const RecordingDefaults({
    this.transcriptionMode = MeetingTranscriptionMode.postSession,
    this.languageMode = MeetingLanguageMode.mixed,
    this.expectedSpeakerCount,
  }) : assert(
         expectedSpeakerCount == null ||
             (expectedSpeakerCount >= 2 && expectedSpeakerCount <= 6),
         'expectedSpeakerCount must be null or between two and six',
       );

  /// Whether draft transcription is requested during or after capture.
  final MeetingTranscriptionMode transcriptionMode;

  /// Recognition language hint for the next meeting.
  final MeetingLanguageMode languageMode;

  /// Optional two-to-six-speaker guidance; null means automatic.
  final int? expectedSpeakerCount;

  @override
  List<Object?> get equalityValues => <Object?>[
    transcriptionMode,
    languageMode,
    expectedSpeakerCount,
  ];
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

  /// Reads one transactionally consistent meeting-detail projection.
  @useResult
  Future<Result<SessionDetail, SessionRepositoryFailure>> loadDetail(
    String meetingId,
  );

  /// Persists meeting metadata; analysis-version selection has its own writer.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  );

  /// Durably stores a user marker independently of transcript availability.
  @useResult
  Future<Result<Bookmark, SessionRepositoryFailure>> saveBookmark(
    Bookmark bookmark,
  );

  /// Reads local defaults for the next recording setup.
  @useResult
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  loadRecordingDefaults();

  /// Replaces local defaults for the next recording setup.
  @useResult
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  saveRecordingDefaults(RecordingDefaults defaults, {required int atUtcMs});

  /// Applies authoritative native recording state without replacing setup data.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>>
  synchronizeRecordingProgress(
    String meetingId, {
    required MeetingLifecycle lifecycle,
    required Duration mediaDuration,
    required int atUtcMs,
  });

  /// Deletes an unstarted draft only when no audio row can be lost.
  @useResult
  Future<Result<void, SessionRepositoryFailure>> discardUnstartedMeeting(
    String meetingId,
  );

  /// Atomically changes only a meeting title, preserving concurrent state.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> renameMeeting(
    String meetingId,
    String title, {
    required int atUtcMs,
  });

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

  /// Reads retained recovery findings and the raw-segment fallback plan.
  @useResult
  Future<Result<SessionRecoveryDetails, SessionRepositoryFailure>>
  recoveryDetails(String meetingId);

  /// Applies an explicit, idempotent recovery lifecycle decision.
  @useResult
  Future<Result<Meeting, SessionRepositoryFailure>> resolveRecovery(
    String meetingId,
    RecoveryResolution resolution, {
    required int atUtcMs,
  });

  /// Reconciles persisted lifecycle against externally verified audio evidence.
  @useResult
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
    Set<String> liveMeetingIds = const <String>{},
    Set<String> invalidStorageKeys = const <String>{},
  });
}

/// Supported explicit local export formats.
enum ExportFormat {
  /// Finalized or locally rebuilt continuous audio.
  audioM4a,

  /// Recoverable journal-authorized audio segments in a ZIP container.
  audioSegments,

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
  const ExportRequest({
    required this.operationId,
    required this.createdAtUtcMs,
    required this.sessionId,
    required this.format,
  });

  /// Internal identity shared by persistence, progress, and cancellation.
  final String operationId;

  /// UTC instant at which the user started this export attempt.
  final int createdAtUtcMs;

  /// Session to export.
  final String sessionId;

  /// Requested output format.
  final ExportFormat format;
}

/// Native export phase visible while a destination is being produced.
enum ExportProgressPhase {
  /// Android's destination picker is awaiting an explicit user choice.
  selectingDestination,

  /// Local sources are being resolved and validated.
  preparing,

  /// Bytes are being copied into the selected destination.
  writing,

  /// The destination stream is closing and publishing its final state.
  finalizing,
}

/// Privacy-safe live progress for one local export operation.
@immutable
final class ExportProgress {
  /// Creates an immutable progress snapshot.
  const ExportProgress({
    required this.operationId,
    required this.phase,
    required this.bytesProcessed,
    required this.cancellable,
    this.totalBytes,
  }) : assert(bytesProcessed >= 0, 'bytesProcessed must be non-negative'),
       assert(
         totalBytes == null || totalBytes >= 0,
         'totalBytes must be valid',
       );

  /// Internal operation identity.
  final String operationId;

  /// Current native destination phase.
  final ExportProgressPhase phase;

  /// Bytes processed so far; for compressed archives this is output progress.
  final int bytesProcessed;

  /// Known expected byte count when the output size is deterministic.
  final int? totalBytes;

  /// Whether cooperative cancellation is currently safe.
  final bool cancellable;
}

/// Receipt for a completed local export.
final class ExportReceipt {
  /// Creates an export receipt.
  ExportReceipt({
    required this.fileName,
    required this.bytesWritten,
    this.usedSegmentFallback = false,
    List<String> warningCodes = const <String>[],
  }) : warningCodes = List.unmodifiable(warningCodes);

  /// Display name returned by the user-selected destination.
  final String fileName;

  /// Bytes durably written before the platform destination was finalized.
  final int bytesWritten;

  /// Whether continuous audio was unavailable and committed segments were used.
  final bool usedSegmentFallback;

  /// Stable disclosure codes that contain no user content.
  final List<String> warningCodes;
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
abstract interface class ExportService {
  /// Writes selected session data to the user-selected destination.
  @useResult
  Future<Result<ExportReceipt, ExportFailure>> export(ExportRequest request);

  /// Reads the latest native progress for one active operation.
  @useResult
  Future<Result<ExportProgress, ExportFailure>> status(String operationId);

  /// Requests cooperative cancellation when the current phase permits it.
  @useResult
  Future<Result<void, ExportFailure>> cancel(String operationId);
}
