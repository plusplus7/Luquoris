import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/model_export_tables.dart';
// Drift resolves the custom composite target FKs through these imports.
// ignore: unused_import
import 'package:loquiris/data/database/tables/speaker_tables.dart';
// Drift also resolves transcript target FKs through this import.
// ignore: unused_import
import 'package:loquiris/data/database/tables/transcription_tables.dart';

/// Non-destructive typed human correction encoded as validated JSON payload.
@TableIndex(
  name: 'idx_revisions_meeting_created',
  columns: {#meetingId, #createdAt},
)
@TableIndex(
  name: 'idx_revisions_transcript_target',
  columns: {#transcriptSegmentId, #createdAt},
)
@TableIndex(
  name: 'idx_revisions_assignment_target',
  columns: {#speakerAssignmentId, #createdAt},
)
@TableIndex(
  name: 'idx_revisions_speaker_target',
  columns: {#speakerId, #createdAt},
)
class Revisions extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Transcript segment revised by text or language corrections.
  TextColumn get transcriptSegmentId => text().nullable()();

  /// Speaker interval revised by an assignment correction.
  TextColumn get speakerAssignmentId => text().nullable()();

  /// Meeting-local speaker revised by a label correction.
  TextColumn get speakerId => text().nullable()();

  /// Closed revision payload discriminator.
  TextColumn get revisionKind => text()();

  /// Schema-shaped payload retaining typed before and after values.
  TextColumn get payloadJson => text()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (revision_kind IN ('transcriptText','languageLabel','speakerAssignment','speakerLabel'))",
    "CHECK ((revision_kind IN ('transcriptText','languageLabel') AND transcript_segment_id IS NOT NULL AND speaker_assignment_id IS NULL AND speaker_id IS NULL) OR (revision_kind = 'speakerAssignment' AND transcript_segment_id IS NULL AND speaker_assignment_id IS NOT NULL AND speaker_id IS NULL) OR (revision_kind = 'speakerLabel' AND transcript_segment_id IS NULL AND speaker_assignment_id IS NULL AND speaker_id IS NOT NULL))",
    'CHECK (json_valid(payload_json))',
    r"CHECK ((revision_kind = 'transcriptText' AND COALESCE(json_type(payload_json, '$.previousText') = 'text', 0) AND COALESCE(json_type(payload_json, '$.revisedText') = 'text', 0)) OR (revision_kind = 'languageLabel' AND COALESCE(json_extract(payload_json, '$.previous') IN ('chinese','english','mixed','uncertain'), 0) AND COALESCE(json_extract(payload_json, '$.revised') IN ('chinese','english','mixed','uncertain'), 0)) OR (revision_kind = 'speakerAssignment' AND COALESCE(json_type(payload_json, '$.startUs') = 'integer', 0) AND COALESCE(json_type(payload_json, '$.endUs') = 'integer', 0) AND json_extract(payload_json, '$.startUs') >= 0 AND json_extract(payload_json, '$.endUs') > json_extract(payload_json, '$.startUs') AND COALESCE(json_type(payload_json, '$.previousSpeakerId') IN ('text','null'), 0) AND COALESCE(json_type(payload_json, '$.revisedSpeakerId') IN ('text','null'), 0) AND COALESCE(json_type(payload_json, '$.needsConfirmation') IN ('true','false'), 0)) OR (revision_kind = 'speakerLabel' AND COALESCE(json_type(payload_json, '$.previous') = 'text', 0) AND COALESCE(json_type(payload_json, '$.revised') = 'text', 0)))",
    'FOREIGN KEY (transcript_segment_id, meeting_id) REFERENCES transcript_segments(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (speaker_assignment_id, meeting_id) REFERENCES speaker_assignments(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (speaker_id, meeting_id) REFERENCES speakers(id, meeting_id) ON DELETE CASCADE',
  ];
}

/// Durable resumable local processing work.
@TableIndex(
  name: 'idx_processing_jobs_meeting_created',
  columns: {
    #meetingId,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
  },
)
class ProcessingJobs extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Requested processing capability.
  TextColumn get jobKind => text()();

  /// Queued, running, paused, succeeded, or failed.
  TextColumn get jobState => text()();

  /// Normalized completion fraction for active work.
  RealColumn get progress => real().nullable()();

  /// Stable pause reason.
  TextColumn get reasonCode => text().nullable()();

  /// Stable terminal failure code.
  TextColumn get failureCode => text().nullable()();

  /// Target transcript run for transcription or language work.
  TextColumn get transcriptRunId => text().nullable()();

  /// Target diarization run for speaker analysis work.
  TextColumn get diarizationRunId => text().nullable()();

  /// Model selected for inference, when applicable.
  TextColumn get modelId => text().nullable().references(
    ModelManifests,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Opaque resumable checkpoint that excludes transcript content.
  TextColumn get checkpoint => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (job_kind IN ('transcription','languageIdentification','speakerDiarization','audioMerge','waveform'))",
    "CHECK (job_state IN ('queued','running','paused','succeeded','failed'))",
    'CHECK (progress IS NULL OR progress BETWEEN 0 AND 1)',
    "CHECK ((job_kind IN ('transcription','languageIdentification') AND transcript_run_id IS NOT NULL AND diarization_run_id IS NULL AND model_id IS NOT NULL) OR (job_kind = 'speakerDiarization' AND transcript_run_id IS NULL AND diarization_run_id IS NOT NULL AND model_id IS NOT NULL) OR (job_kind IN ('audioMerge','waveform') AND transcript_run_id IS NULL AND diarization_run_id IS NULL AND model_id IS NULL))",
    "CHECK ((job_state = 'queued' AND progress IS NULL AND reason_code IS NULL AND failure_code IS NULL) OR (job_state = 'running' AND progress IS NOT NULL AND reason_code IS NULL AND failure_code IS NULL) OR (job_state = 'paused' AND length(reason_code) > 0 AND failure_code IS NULL) OR (job_state = 'succeeded' AND reason_code IS NULL AND failure_code IS NULL) OR (job_state = 'failed' AND reason_code IS NULL AND length(failure_code) > 0))",
    'FOREIGN KEY (transcript_run_id, meeting_id) REFERENCES transcript_runs(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (diarization_run_id, meeting_id) REFERENCES diarization_runs(id, meeting_id) ON DELETE CASCADE',
  ];
}
