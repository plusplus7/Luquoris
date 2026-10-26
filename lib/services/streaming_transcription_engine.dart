import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:meta/meta.dart';

/// Identifies the sole native recognizer owner, including replacement epochs.
final class StreamingOwner extends ValueObject {
  /// Creates a recording/run identity with a non-negative owner [epoch].
  const StreamingOwner({
    required this.meetingId,
    required this.runId,
    required this.epoch,
  }) : assert(epoch >= 0, 'owner epoch must be non-negative');

  /// Authoritative recording whose native PCM fan-out supplies recognition.
  final String meetingId;

  /// Independent live draft run, never the complete-pass run identity.
  final String runId;

  /// Monotonic ownership generation; callbacks from older owners are stale.
  final int epoch;

  @override
  List<Object?> get equalityValues => [meetingId, runId, epoch];
}

/// Pins an offline bundle and parameters before acquiring native resources.
final class StreamingStartRequest extends ValueObject {
  /// Creates a request; PCM stays on the native recorder worker boundary.
  const StreamingStartRequest({
    required this.owner,
    required this.modelId,
    required this.bundleSha256,
    required this.parameterVersion,
  });

  /// Recording/run/epoch isolation boundary.
  final StreamingOwner owner;

  /// Locally bundled model identifier.
  final String modelId;

  /// Canonical verified bundle digest, not a single weight-file digest.
  final String bundleSha256;

  /// Version of the pinned chunk and endpoint configuration.
  final int parameterVersion;

  @override
  List<Object?> get equalityValues => [
    owner,
    modelId,
    bundleSha256,
    parameterVersion,
  ];
}

/// Whether an utterance can still be revised within this owner epoch.
enum StreamingUtteranceStatus {
  /// Revisable recognizer hypothesis, read-only to the user.
  provisional,

  /// Immutable endpoint result.
  finalized,
}

/// A callback ordered within one owner; sequence numbers never use wall time.
sealed class StreamingEvent extends ValueObject {
  const StreamingEvent({required this.owner, required this.sequence})
    : assert(sequence >= 0, 'callback sequence must be non-negative');

  /// Identity required before any callback can affect a draft.
  final StreamingOwner owner;

  /// Strictly increasing callback number within this owner epoch.
  final int sequence;
}

/// Original-language recognition anchored to the recorder's media timeline.
final class StreamingUtterance extends StreamingEvent {
  /// Creates a partial/final callback with a stable utterance identifier.
  // Duration comparisons cannot be evaluated by a const constructor.
  // ignore: prefer_const_constructors_in_immutables
  StreamingUtterance({
    required super.owner,
    required super.sequence,
    required this.utteranceId,
    required this.start,
    required this.end,
    required this.rawText,
    required this.status,
    this.captureEpoch = 0,
  }) : assert(start >= Duration.zero, 'capture start must be non-negative'),
       assert(end >= start, 'capture interval must not run backwards');

  /// Stable identity; only provisional hypotheses for this id may change.
  final String utteranceId;

  /// Inclusive captured-media position, never recognition wall time.
  final Duration start;

  /// Exclusive captured-media position.
  final Duration end;

  /// Untouched recognizer output, without translation or human corrections.
  final String rawText;

  /// Provisional or endpoint-final status.
  final StreamingUtteranceStatus status;

  /// Successful recorder pause/resume generation, distinct from owner epoch.
  final int captureEpoch;

  @override
  List<Object?> get equalityValues => [
    owner,
    sequence,
    utteranceId,
    start,
    end,
    rawText,
    status,
    captureEpoch,
  ];
}

/// Why capture continuity was cut; none of these markers represents speech.
enum StreamingGapReason {
  /// User paused capture before resuming.
  pause,

  /// Audio-focus interruption separated captured intervals.
  audioFocus,

  /// Captured PCM positions or capture generation were discontinuous.
  discontinuity,
}

/// Missing media or a zero-duration capture boundary, never synthesized text.
final class StreamingGap extends StreamingEvent {
  /// Creates an owner-scoped half-open gap in captured-media coordinates.
  const StreamingGap({
    required super.owner,
    required super.sequence,
    required this.start,
    required this.end,
    required this.captureEpoch,
    required this.reason,
  });

  /// Inclusive media start; equals [end] for a pure capture-generation boundary.
  final Duration start;

  /// Exclusive media end; no recognized words are implied inside this interval.
  final Duration end;

  /// Recorder generation which begins after this boundary.
  final int captureEpoch;

  /// Stable cause for coverage presentation, not localized copy.
  final StreamingGapReason reason;

  @override
  List<Object?> get equalityValues => [
    owner,
    sequence,
    start,
    end,
    captureEpoch,
    reason,
  ];
}

/// Causes that leave authoritative capture intact but live coverage incomplete.
enum StreamingFailureReason {
  /// Another recognizer already owns this recording.
  alreadyOwned,

  /// A required local bundle is absent or corrupt.
  modelUnavailable,

  /// Native recognizer creation or execution failed.
  engine,

  /// Unique-audio queue exceeded the sustained backlog policy.
  backlog,

  /// Platform reports severe thermal pressure.
  thermal,

  /// Unrecoverable native memory pressure prevents recognition.
  memory,

  /// Requested owner has already closed.
  closed,
}

/// Typed offline streaming failures; presentation supplies localized copy.
sealed class StreamingFailure implements Failure {
  const StreamingFailure();
}

/// Live recognition is unavailable for a stable typed reason.
final class StreamingUnavailable extends StreamingFailure {
  /// Creates a failure without paths, raw exceptions, or localized strings.
  const StreamingUnavailable(this.reason);

  /// Recoverable reason; recording and complete-pass input remain intact.
  final StreamingFailureReason reason;

  @override
  String get code => 'streaming_${reason.name}';
}

/// A terminal worker failure preserving the last recognized draft.
///
/// Delivery releases native ownership and ends the event stream; a subsequent
/// explicit close remains idempotent. Capture continues independently.
final class StreamingFailed extends StreamingEvent {
  /// Creates an owner-scoped typed degradation callback.
  const StreamingFailed({
    required super.owner,
    required super.sequence,
    required this.failure,
  });

  /// Failure to display without changing recorder state.
  final StreamingFailure failure;

  @override
  List<Object?> get equalityValues => [owner, sequence, failure];
}

/// Why ownership must finish; all cases release native streams and recognizers.
enum StreamingCloseReason {
  /// Capture stopped; flush an endpoint if possible before closing events.
  stopped,

  /// Caller cancelled; do not manufacture a final hypothesis.
  cancelled,

  /// A newer owner replaced this run.
  replaced,
}

/// Owns one native recognizer and its PCM subscription until acknowledged close.
abstract interface class StreamingSession {
  /// Immutable recording/run identity assigned when opened.
  StreamingOwner get owner;

  /// Broadcast ordered callbacks; closed only after native resource release.
  /// A terminal [StreamingFailed] closes ownership without a caller round-trip.
  Stream<StreamingEvent> get events;

  /// Idempotently detaches PCM, joins worker work, and frees every native handle.
  ///
  /// Cancel/replacement discards pending events. A paused subscriber cannot
  /// delay the resource-release acknowledgement. An acknowledged close means
  /// no new callbacks and no allocated recognizer, even if called repeatedly.
  @useResult
  Future<Result<void, StreamingFailure>> close(StreamingCloseReason reason);
}

/// Session-scoped offline streaming seam; implementations never block capture.
// A native resource acquisition boundary must remain injectable as an object.
// ignore: one_member_abstracts
abstract interface class StreamingTranscriptionEngine {
  /// Acquires one recognizer for the recording on a native inference worker.
  ///
  /// Model verification, decoding, and PCM buffering must not run on microphone
  /// callbacks or the Flutter isolate. Opening an already owned meeting fails.
  @useResult
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  );
}
