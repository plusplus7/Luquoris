import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';

/// Durable meeting aggregate metadata.
@TableIndex(
  name: 'idx_meetings_created',
  columns: {
    #isDeleted,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
    IndexedColumn(#id, orderBy: OrderingMode.desc),
  },
)
class Meetings extends Table with AuditColumns {
  /// User-visible title.
  TextColumn get title => text()();

  /// Pause-free media duration in microseconds.
  IntColumn get mediaDurationUs =>
      integer().withDefault(const Constant<int>(0))();

  /// Persisted recording lifecycle.
  TextColumn get lifecycle => text()();

  /// User-selected recognition language hint.
  TextColumn get languageMode => text()();

  /// User-selected live draft or post-session transcription timing.
  TextColumn get transcriptionMode => text()
      .withDefault(const Constant<String>('postSession'))
      .check(
        const CustomExpression<bool>(
          "transcription_mode IN ('nearRealTime','postSession')",
        ),
      )();

  /// Optional two-to-six-speaker analysis guidance.
  IntColumn get expectedSpeakerCount => integer().nullable().check(
    const CustomExpression<bool>(
      'expected_speaker_count IS NULL OR '
      'expected_speaker_count BETWEEN 2 AND 6',
    ),
  )();

  /// UTC trash instant used for the seven-day retention period.
  IntColumn get trashedAtUtcMs => integer().nullable()();

  /// Durable lifecycle restored when the meeting leaves trash.
  TextColumn get lifecycleBeforeTrash => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (media_duration_us >= 0)',
    "CHECK (lifecycle IN ('draft','preparing','recording','pausedByUser','pausedByInterruption','stopping','finalized','recoverable','failedFinalization','trashed','deleting'))",
    "CHECK (language_mode IN ('chinese','english','mixed'))",
    "CHECK ((lifecycle IN ('trashed','deleting')) = (trashed_at_utc_ms IS NOT NULL))",
    "CHECK (lifecycle_before_trash IS NULL OR lifecycle_before_trash IN ('draft','preparing','recording','pausedByUser','pausedByInterruption','stopping','finalized','recoverable','failedFinalization'))",
    "CHECK ((lifecycle IN ('trashed','deleting')) = (lifecycle_before_trash IS NOT NULL))",
    "CHECK ((lifecycle IN ('trashed','deleting')) = is_deleted)",
    'CHECK ((trashed_at_utc_ms IS NULL AND deleted_at IS NULL) OR trashed_at_utc_ms = deleted_at)',
  ];
}

/// Single-row defaults remembered for the next recording setup.
class RecordingPreferences extends Table with AuditColumns {
  /// Default live draft or post-session transcription timing.
  TextColumn get transcriptionMode => text()();

  /// Default recognition language hint.
  TextColumn get languageMode => text()();

  /// Default speaker guidance; null requests automatic estimation.
  IntColumn get expectedSpeakerCount => integer().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (id = 'recording-defaults')",
    "CHECK (transcription_mode IN ('nearRealTime','postSession'))",
    "CHECK (language_mode IN ('chinese','english','mixed'))",
    'CHECK (expected_speaker_count IS NULL OR expected_speaker_count BETWEEN 2 AND 6)',
  ];
}

/// Metadata for authoritative audio bytes stored in private files.
@TableIndex(
  name: 'ux_audio_segments_meeting_sequence',
  columns: {#meetingId, #sequence},
  unique: true,
)
class AudioSegments extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Monotonic segment order within the meeting.
  IntColumn get sequence => integer()();

  /// Validated path relative to the private media directory.
  TextColumn get relativePath => text()();

  /// Pause-free media start in microseconds.
  IntColumn get mediaStartUs => integer()();

  /// Committed media duration in microseconds.
  IntColumn get mediaDurationUs => integer()();

  /// Bytes known to be durably committed.
  IntColumn get committedBytes => integer()();

  /// Segment integrity and commit state.
  TextColumn get state => text()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (sequence >= 0)',
    'CHECK (media_start_us >= 0)',
    'CHECK (media_duration_us >= 0)',
    'CHECK (committed_bytes >= 0)',
    "CHECK (state IN ('open','committed','corrupt','missing'))",
    'CHECK (length(relative_path) > 0)',
    "CHECK (relative_path NOT LIKE '/%')",
    'CHECK (instr(relative_path, char(92)) = 0)',
    'CHECK (instr(relative_path, char(0)) = 0)',
    "CHECK (relative_path NOT GLOB '[A-Za-z]:*')",
    "CHECK (('/' || relative_path || '/') NOT LIKE '%//%')",
    "CHECK (('/' || relative_path || '/') NOT LIKE '%/../%')",
    "CHECK (('/' || relative_path || '/') NOT LIKE '%/./%')",
  ];
}

/// Privacy-safe recovery findings retained for partial-session explanation.
@TableIndex(
  name: 'idx_recovery_findings_meeting_sequence',
  columns: {#meetingId, #segmentSequence},
)
class RecoveryFindings extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Manifest segment associated with the finding, when applicable.
  IntColumn get segmentSequence => integer().nullable()();

  /// Stable privacy-safe diagnostic code.
  TextColumn get code => text()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (segment_sequence IS NULL OR segment_sequence >= 0)',
    "CHECK (code IN ('recording_recovery_timeline_gap','recording_recovery_segment_missing','recording_recovery_segment_corrupt','recording_recovery_tail_discarded'))",
  ];
}

/// Persisted recording or interruption transition.
@TableIndex(
  name: 'ux_session_events_meeting_sequence',
  columns: {#meetingId, #sequence},
  unique: true,
)
class SessionEvents extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Monotonic event order within the meeting.
  IntColumn get sequence => integer()();

  /// Event classification.
  TextColumn get type => text()();

  /// Real UTC wall-clock time in epoch milliseconds.
  IntColumn get wallClockUtcMs => integer()();

  /// Monotonic elapsed time in microseconds.
  IntColumn get monotonicElapsedUs => integer()();

  /// Pause-free media position in microseconds.
  IntColumn get mediaOffsetUs => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (sequence >= 0)',
    'CHECK (wall_clock_utc_ms >= 0)',
    'CHECK (monotonic_elapsed_us >= 0)',
    'CHECK (media_offset_us >= 0)',
    "CHECK (type IN ('started','pausedByUser','resumedByUser','interrupted','stopped','recovered'))",
  ];
}

/// User-authored marker on the pause-free media timeline.
@TableIndex(
  name: 'idx_bookmarks_meeting_media',
  columns: {#meetingId, #mediaOffsetUs},
)
class Bookmarks extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Pause-free media position in microseconds.
  IntColumn get mediaOffsetUs => integer()();

  /// Bookmark or highlight classification.
  TextColumn get kind => text()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (media_offset_us >= 0)',
    "CHECK (kind IN ('bookmark','highlight'))",
  ];
}
