import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/model_export_tables.dart';
// Drift resolves the custom composite speaker FK through this import.
// ignore: unused_import
import 'package:loquiris/data/database/tables/speaker_tables.dart';

/// Versioned speech-to-text analysis with complete inference provenance.
@TableIndex(
  name: 'idx_transcript_runs_meeting_created',
  columns: {
    #meetingId,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
  },
)
@TableIndex(
  name: 'ux_transcript_run_owner',
  columns: {#id, #meetingId},
  unique: true,
)
class TranscriptRuns extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Stable inference-engine identifier.
  TextColumn get engineId => text()();

  /// Exact inference-engine version.
  TextColumn get engineVersion => text()();

  /// Bundled model manifest used by the run.
  TextColumn get modelId => text().references(
    ModelManifests,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Exact model version copied into immutable run provenance.
  TextColumn get modelVersion => text()();

  /// Model digest copied into immutable run provenance.
  TextColumn get modelSha256 => text()();

  /// Canonical JSON of the actual inference parameters.
  TextColumn get parametersJson => text()();

  /// Queued, running, completed, or failed.
  TextColumn get runState => text()();

  /// UTC start instant when work has begun.
  IntColumn get startedAtUtcMs => integer().nullable()();

  /// UTC terminal instant for completed or failed work.
  IntColumn get endedAtUtcMs => integer().nullable()();

  /// Normalized completion fraction.
  RealColumn get progress => real().withDefault(const Constant<double>(0))();

  /// Structured privacy-safe terminal failure code.
  TextColumn get failureCode => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (model_id, model_version, model_sha256, engine_id) REFERENCES model_manifests(id, version, sha256, expected_engine_id) ON DELETE RESTRICT',
    "CHECK (run_state IN ('queued','running','completed','failed'))",
    'CHECK (progress BETWEEN 0 AND 1)',
    'CHECK (json_valid(parameters_json))',
    'CHECK (started_at_utc_ms IS NULL OR started_at_utc_ms >= 0)',
    'CHECK (ended_at_utc_ms IS NULL OR ended_at_utc_ms >= started_at_utc_ms)',
    "CHECK ((run_state = 'queued' AND started_at_utc_ms IS NULL AND ended_at_utc_ms IS NULL AND failure_code IS NULL) OR (run_state = 'running' AND started_at_utc_ms IS NOT NULL AND ended_at_utc_ms IS NULL AND failure_code IS NULL) OR (run_state = 'completed' AND started_at_utc_ms IS NOT NULL AND ended_at_utc_ms IS NOT NULL AND progress = 1 AND failure_code IS NULL) OR (run_state = 'failed' AND started_at_utc_ms IS NOT NULL AND ended_at_utc_ms IS NOT NULL AND length(failure_code) > 0))",
  ];
}

/// One-to-one selection of the current transcript version for a meeting.
@TableIndex(
  name: 'ux_meeting_transcript_selection',
  columns: {#meetingId},
  unique: true,
)
class MeetingTranscriptSelections extends Table with AuditColumns {
  /// Meeting whose current transcript is selected.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Explicitly selected transcript run.
  TextColumn get transcriptRunId => text().references(
    TranscriptRuns,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (transcript_run_id, meeting_id) REFERENCES transcript_runs(id, meeting_id) ON DELETE CASCADE',
  ];
}

/// Stable timestamped transcript output inside one run.
@TableIndex(
  name: 'idx_transcript_segments_run_start',
  columns: {#transcriptRunId, #startUs},
)
@TableIndex(
  name: 'ux_transcript_segment_owner',
  columns: {#id, #meetingId},
  unique: true,
)
class TranscriptSegments extends Table with AuditColumns {
  /// Denormalized owner used to enforce meeting-local references.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Owning transcript run.
  TextColumn get transcriptRunId => text().references(
    TranscriptRuns,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Inclusive pause-free start in microseconds.
  IntColumn get startUs => integer()();

  /// Exclusive pause-free end in microseconds.
  IntColumn get endUs => integer()();

  /// Untouched local engine output.
  TextColumn get rawModelText => text()();

  /// Current user-visible text.
  TextColumn get displayedText => text()();

  /// Whether displayed text includes a human correction.
  TextColumn get revisionState => text()();

  /// Current meeting-local speaker selected for display/export.
  TextColumn get speakerId => text().nullable()();

  /// Owner paired with [speakerId] for the composite foreign key.
  TextColumn get speakerMeetingId => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_us >= 0)',
    'CHECK (end_us > start_us)',
    "CHECK (revision_state IN ('machine','corrected'))",
    'CHECK ((speaker_id IS NULL) = (speaker_meeting_id IS NULL))',
    'CHECK (speaker_meeting_id IS NULL OR speaker_meeting_id = meeting_id)',
    'FOREIGN KEY (transcript_run_id, meeting_id) REFERENCES transcript_runs(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (speaker_id, speaker_meeting_id) REFERENCES speakers(id, meeting_id) ON DELETE SET NULL',
  ];
}

/// Versioned automatic or human language classification.
@TableIndex(
  name: 'idx_language_decisions_segment_created',
  columns: {
    #transcriptSegmentId,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
  },
)
@TableIndex(
  name: 'ux_language_decision_owner',
  columns: {#id, #transcriptSegmentId},
  unique: true,
)
class LanguageDecisions extends Table with AuditColumns {
  /// Target stable transcript segment.
  TextColumn get transcriptSegmentId => text().references(
    TranscriptSegments,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Chinese, English, mixed, or uncertain.
  TextColumn get tag => text()();

  /// Automatic or manual provenance.
  TextColumn get source => text()();

  /// Calibrated confidence when available.
  RealColumn get confidence => real().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (tag IN ('chinese','english','mixed','uncertain'))",
    "CHECK (source IN ('automatic','manual'))",
    'CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1)',
  ];
}

/// One-to-one selection of the current language decision for a segment.
@TableIndex(
  name: 'ux_transcript_language_selection',
  columns: {#transcriptSegmentId},
  unique: true,
)
class TranscriptLanguageSelections extends Table with AuditColumns {
  /// Stable transcript segment whose language is selected.
  TextColumn get transcriptSegmentId => text().references(
    TranscriptSegments,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Explicitly selected automatic or human language decision.
  TextColumn get languageDecisionId => text().references(
    LanguageDecisions,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (language_decision_id, transcript_segment_id) REFERENCES language_decisions(id, transcript_segment_id) ON DELETE CASCADE',
  ];
}
