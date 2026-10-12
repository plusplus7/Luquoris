import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:meta/meta.dart';

/// Durable meeting lifecycle persisted independently of Flutter UI state.
enum MeetingLifecycle {
  /// Created before capture starts.
  draft,

  /// Microphone capture is active.
  recording,

  /// Native recorder is acquiring resources before capture.
  preparing,

  /// Capture is intentionally paused by the user.
  pausedByUser,

  /// Capture is paused because of a platform interruption.
  pausedByInterruption,

  /// Recorder is flushing its final durable segment.
  stopping,

  /// Capture finalized normally.
  finalized,

  /// Committed audio needs user-led recovery.
  recoverable,

  /// Audio survived but finalization did not complete.
  failedFinalization,

  /// Soft-deleted within the retention period.
  trashed,

  /// Permanent deletion was confirmed and cleanup must not be reversed.
  deleting,
}

/// User-selected recognition language hint.
enum MeetingLanguageMode {
  /// Prefer Chinese recognition.
  chinese,

  /// Prefer English recognition.
  english,

  /// Preserve Chinese-English code switching.
  mixed,
}

/// User-selected transcription timing for one meeting.
enum MeetingTranscriptionMode {
  /// Produce an experimental draft while recording when resources allow.
  nearRealTime,

  /// Preserve capture resources and transcribe only after recording.
  postSession,
}

/// Immutable meeting aggregate root.
@immutable
final class Meeting extends ValueObject {
  /// Creates a durable meeting value.
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAtUtcMs,
    required this.mediaDuration,
    required this.lifecycle,
    required this.languageMode,
    this.transcriptionMode = MeetingTranscriptionMode.postSession,
    this.expectedSpeakerCount,
    this.currentTranscriptRunId,
    this.lifecycleBeforeTrash,
    this.trashedAtUtcMs,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative'),
       assert(
         expectedSpeakerCount == null ||
             (expectedSpeakerCount >= 2 && expectedSpeakerCount <= 6),
         'expectedSpeakerCount must be null or between two and six',
       ),
       assert(
         (lifecycle == MeetingLifecycle.trashed ||
                 lifecycle == MeetingLifecycle.deleting) ==
             (trashedAtUtcMs != null),
         'deleted lifecycle and trash timestamp must agree',
       ),
       assert(
         (lifecycle == MeetingLifecycle.trashed ||
                 lifecycle == MeetingLifecycle.deleting) ==
             (lifecycleBeforeTrash != null),
         'deleted lifecycle and previous lifecycle must agree',
       ),
       assert(
         lifecycleBeforeTrash != MeetingLifecycle.trashed &&
             lifecycleBeforeTrash != MeetingLifecycle.deleting,
         'the lifecycle before trash cannot be a deleted lifecycle',
       );

  static const _unset = Object();

  /// Stable meeting identifier.
  final String id;

  /// User-visible meeting title.
  final String title;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Media time with paused intervals excluded.
  final Duration mediaDuration;

  /// Durable capture lifecycle.
  final MeetingLifecycle lifecycle;

  /// Recognition language hint.
  final MeetingLanguageMode languageMode;

  /// Selected live-draft or post-session transcription timing.
  final MeetingTranscriptionMode transcriptionMode;

  /// Optional speaker-count guidance; null requests automatic estimation.
  final int? expectedSpeakerCount;

  /// Explicitly selected current transcript version.
  final String? currentTranscriptRunId;

  /// Durable lifecycle restored when this meeting leaves trash.
  final MeetingLifecycle? lifecycleBeforeTrash;

  /// UTC trash instant used to calculate the seven-day retention window.
  final int? trashedAtUtcMs;

  /// Returns a copy while preserving stable identity and creation time.
  Meeting copyWith({
    String? title,
    Duration? mediaDuration,
    MeetingLifecycle? lifecycle,
    MeetingLanguageMode? languageMode,
    MeetingTranscriptionMode? transcriptionMode,
    Object? expectedSpeakerCount = _unset,
    Object? currentTranscriptRunId = _unset,
    Object? lifecycleBeforeTrash = _unset,
    Object? trashedAtUtcMs = _unset,
  }) => Meeting(
    id: id,
    title: title ?? this.title,
    createdAtUtcMs: createdAtUtcMs,
    mediaDuration: mediaDuration ?? this.mediaDuration,
    lifecycle: lifecycle ?? this.lifecycle,
    languageMode: languageMode ?? this.languageMode,
    transcriptionMode: transcriptionMode ?? this.transcriptionMode,
    expectedSpeakerCount: identical(expectedSpeakerCount, _unset)
        ? this.expectedSpeakerCount
        : expectedSpeakerCount as int?,
    currentTranscriptRunId: identical(currentTranscriptRunId, _unset)
        ? this.currentTranscriptRunId
        : currentTranscriptRunId as String?,
    lifecycleBeforeTrash: identical(lifecycleBeforeTrash, _unset)
        ? this.lifecycleBeforeTrash
        : lifecycleBeforeTrash as MeetingLifecycle?,
    trashedAtUtcMs: identical(trashedAtUtcMs, _unset)
        ? this.trashedAtUtcMs
        : trashedAtUtcMs as int?,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    title,
    createdAtUtcMs,
    mediaDuration,
    lifecycle,
    languageMode,
    transcriptionMode,
    expectedSpeakerCount,
    currentTranscriptRunId,
    lifecycleBeforeTrash,
    trashedAtUtcMs,
  ];
}

/// Durable state of one authoritative audio segment.
enum AudioSegmentState {
  /// Segment is currently being appended.
  open,

  /// Segment was durably committed.
  committed,

  /// Segment exists but failed integrity checks.
  corrupt,

  /// Manifest references a missing file.
  missing,
}

/// Metadata for authoritative audio stored outside SQLite.
@immutable
final class AudioSegment extends ValueObject {
  /// Creates audio-segment metadata.
  const AudioSegment({
    required this.id,
    required this.meetingId,
    required this.sequence,
    required this.relativePath,
    required this.mediaStart,
    required this.mediaDuration,
    required this.committedBytes,
    required this.state,
  }) : assert(sequence >= 0, 'sequence must be non-negative'),
       assert(committedBytes >= 0, 'committedBytes must be non-negative');

  /// Stable segment identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Monotonic ordering within the meeting.
  final int sequence;

  /// Path relative to the private media base directory.
  final AppRelativePath relativePath;

  /// Start on the pause-free media timeline.
  final Duration mediaStart;

  /// Committed media duration.
  final Duration mediaDuration;

  /// Bytes known to be durably committed.
  final int committedBytes;

  /// Current integrity/lifecycle state.
  final AudioSegmentState state;

  /// Returns a copy with updated commit metadata.
  AudioSegment copyWith({
    Duration? mediaDuration,
    int? committedBytes,
    AudioSegmentState? state,
  }) => AudioSegment(
    id: id,
    meetingId: meetingId,
    sequence: sequence,
    relativePath: relativePath,
    mediaStart: mediaStart,
    mediaDuration: mediaDuration ?? this.mediaDuration,
    committedBytes: committedBytes ?? this.committedBytes,
    state: state ?? this.state,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    sequence,
    relativePath,
    mediaStart,
    mediaDuration,
    committedBytes,
    state,
  ];
}

/// Persisted capture or interruption event.
enum SessionEventType {
  /// Capture session began.
  started,

  /// User explicitly paused capture.
  pausedByUser,

  /// User explicitly resumed capture.
  resumedByUser,

  /// Platform interruption changed capture state.
  interrupted,

  /// User stopped capture.
  stopped,

  /// Startup reconciliation recovered committed material.
  recovered,
}

/// Event retaining both wall-clock and media timeline information.
@immutable
final class SessionEvent extends ValueObject {
  /// Creates a session event.
  const SessionEvent({
    required this.id,
    required this.meetingId,
    required this.sequence,
    required this.type,
    required this.wallClockUtcMs,
    required this.monotonicElapsed,
    required this.mediaOffset,
  }) : assert(sequence >= 0, 'sequence must be non-negative'),
       assert(wallClockUtcMs >= 0, 'wallClockUtcMs must be non-negative');

  /// Stable event identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Monotonic ordering within the meeting.
  final int sequence;

  /// Event classification.
  final SessionEventType type;

  /// Real UTC wall-clock time in epoch milliseconds.
  final int wallClockUtcMs;

  /// Monotonic elapsed process/session time.
  final Duration monotonicElapsed;

  /// Pause-free media position at the event.
  final Duration mediaOffset;

  /// Returns a copy with updated event timing or classification.
  SessionEvent copyWith({
    SessionEventType? type,
    int? wallClockUtcMs,
    Duration? monotonicElapsed,
    Duration? mediaOffset,
  }) => SessionEvent(
    id: id,
    meetingId: meetingId,
    sequence: sequence,
    type: type ?? this.type,
    wallClockUtcMs: wallClockUtcMs ?? this.wallClockUtcMs,
    monotonicElapsed: monotonicElapsed ?? this.monotonicElapsed,
    mediaOffset: mediaOffset ?? this.mediaOffset,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    sequence,
    type,
    wallClockUtcMs,
    monotonicElapsed,
    mediaOffset,
  ];
}

/// User-authored marker independent of transcription.
enum BookmarkKind {
  /// Ordinary playback bookmark.
  bookmark,

  /// User-marked important moment.
  highlight,
}

/// Durable meeting-local marker on the media timeline.
@immutable
final class Bookmark extends ValueObject {
  /// Creates a bookmark or highlight.
  const Bookmark({
    required this.id,
    required this.meetingId,
    required this.mediaOffset,
    required this.kind,
    required this.createdAtUtcMs,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable marker identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Pause-free media position.
  final Duration mediaOffset;

  /// Marker classification.
  final BookmarkKind kind;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Returns a copy with updated user-editable marker fields.
  Bookmark copyWith({Duration? mediaOffset, BookmarkKind? kind}) => Bookmark(
    id: id,
    meetingId: meetingId,
    mediaOffset: mediaOffset ?? this.mediaOffset,
    kind: kind ?? this.kind,
    createdAtUtcMs: createdAtUtcMs,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    mediaOffset,
    kind,
    createdAtUtcMs,
  ];
}
