import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/transcription_tables.dart';

/// Optional paired-processing provenance; absence preserves legacy run meaning.
@TableIndex(
  name: 'ux_transcript_processing_run',
  columns: {#transcriptRunId},
  unique: true,
)
class TranscriptProcessingMetadata extends Table with AuditColumns {
  /// Run extended by this metadata, without rewriting legacy run rows.
  TextColumn get transcriptRunId => text().references(
    TranscriptRuns,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Meeting owner used for same-recording link validation.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Independent liveDraft or refinement processing role.
  TextColumn get processingRole => text()();

  /// Optional source draft; null also permits refinement without live coverage.
  TextColumn get sourceRunId => text().nullable()();

  /// Complete or incomplete coverage, independent of job success.
  TextColumn get completeness => text()();

  /// Frozen complete manifest, including each artifact's immutable provenance.
  TextColumn get bundleManifestJson => text()();

  /// Finalized ordered authoritative audio inventory hash for refinement.
  TextColumn get audioInventorySha256 => text().nullable()();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (transcript_run_id, meeting_id) REFERENCES transcript_runs(id, meeting_id) ON DELETE CASCADE',
    'FOREIGN KEY (source_run_id, meeting_id) REFERENCES transcript_runs(id, meeting_id) ON DELETE NO ACTION',
    "CHECK (processing_role IN ('liveDraft','refinement'))",
    "CHECK (completeness IN ('complete','incomplete'))",
    'CHECK (source_run_id IS NULL OR source_run_id <> transcript_run_id)',
    "CHECK (source_run_id IS NULL OR processing_role = 'refinement')",
    'CHECK (json_valid(bundle_manifest_json))',
    "CHECK (json_type(bundle_manifest_json) = 'object')",
    r"CHECK (json_type(bundle_manifest_json, '$.schemaVersion') IS 'integer' AND json_extract(bundle_manifest_json, '$.schemaVersion') IN (1,2))",
    "CHECK (audio_inventory_sha256 IS NULL OR (length(audio_inventory_sha256) = 64 AND audio_inventory_sha256 NOT GLOB '*[^0-9a-f]*'))",
    "CHECK (processing_role <> 'refinement' OR audio_inventory_sha256 IS NOT NULL)",
  ];
}
