import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/model_export_tables.dart';

/// Versioned post-session diarization analysis.
@TableIndex(
  name: 'idx_diarization_runs_meeting_created',
  columns: {
    #meetingId,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
  },
)
@TableIndex(
  name: 'ux_diarization_run_owner',
  columns: {#id, #meetingId},
  unique: true,
)
class DiarizationRuns extends Table with AuditColumns {
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

/// Stable meeting-local speaker cluster within one diarization run.
@TableIndex(
  name: 'ux_speakers_run_label',
  columns: {#analysisRunId, #label},
  unique: true,
)
@TableIndex(
  name: 'ux_speaker_run_owner',
  columns: {#id, #analysisRunId},
  unique: true,
)
@TableIndex(
  name: 'ux_speaker_meeting_owner',
  columns: {#id, #meetingId},
  unique: true,
)
class Speakers extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Owning diarization run.
  TextColumn get analysisRunId => text().references(
    DiarizationRuns,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// User-visible meeting-local label.
  TextColumn get label => text()();

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (analysis_run_id, meeting_id) REFERENCES diarization_runs(id, meeting_id) ON DELETE CASCADE',
  ];
}

/// Raw diarization assignment for one pause-free media interval.
@TableIndex(
  name: 'idx_speaker_assignments_run_start',
  columns: {#analysisRunId, #startUs},
)
@TableIndex(
  name: 'ux_speaker_assignment_owner',
  columns: {#id, #meetingId},
  unique: true,
)
class SpeakerAssignments extends Table with AuditColumns {
  /// Denormalized owner used to enforce meeting-local references.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Owning diarization run.
  TextColumn get analysisRunId => text().references(
    DiarizationRuns,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Assigned speaker, null when deliberately unassigned.
  TextColumn get speakerId => text().nullable()();

  /// Run owner paired with [speakerId] for the composite foreign key.
  TextColumn get speakerAnalysisRunId => text().nullable()();

  /// Inclusive pause-free start in microseconds.
  IntColumn get startUs => integer()();

  /// Exclusive pause-free end in microseconds.
  IntColumn get endUs => integer()();

  /// Calibrated confidence when available.
  RealColumn get confidence => real().nullable()();

  /// Whether multiple speakers overlap in this interval.
  BoolColumn get isOverlap => boolean()();

  /// Whether the interval needs explicit user confirmation.
  BoolColumn get needsConfirmation => boolean()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_us >= 0)',
    'CHECK (end_us > start_us)',
    'CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1)',
    'CHECK (is_overlap = 0 OR needs_confirmation = 1)',
    'CHECK ((speaker_id IS NULL) = (speaker_analysis_run_id IS NULL))',
    'CHECK (speaker_analysis_run_id IS NULL OR speaker_analysis_run_id = analysis_run_id)',
    'FOREIGN KEY (analysis_run_id, meeting_id) REFERENCES diarization_runs(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (speaker_id, speaker_analysis_run_id) REFERENCES speakers(id, analysis_run_id) ON DELETE SET NULL',
  ];
}
