import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';

/// Optional explicit processing choice; absence retains legacy meeting meaning.
@TableIndex(
  name: 'ux_meeting_processing_selection',
  columns: {#meetingId},
  unique: true,
)
class MeetingProcessingSelections extends Table with AuditColumns {
  /// Meeting whose processing choice was made before microphone startup.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Explicit recordingOnly, postSession, or twoPass selection.
  TextColumn get processingMode => text()();

  /// Exact streaming bundle snapshot, independent of the refinement bundle.
  TextColumn get liveBundleManifestJson => text().nullable()();

  /// Exact streaming runtime, including v1 manifests without runtime versions.
  TextColumn get liveEngineVersion => text().nullable()();

  /// Frozen streaming settings with an explicit parameterVersion.
  TextColumn get liveParametersJson => text().nullable()();

  /// Exact complete-pass bundle snapshot retained until durable finalization.
  TextColumn get refinementBundleManifestJson => text().nullable()();

  /// Exact complete-pass runtime; never silently substituted into live work.
  TextColumn get refinementEngineVersion => text().nullable()();

  /// Frozen complete-pass settings with an explicit parameterVersion.
  TextColumn get refinementParametersJson => text().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (processing_mode IN ('recordingOnly','postSession','twoPass'))",
    "CHECK ((processing_mode = 'twoPass' AND live_bundle_manifest_json IS NOT NULL AND live_engine_version IS NOT NULL AND live_parameters_json IS NOT NULL) OR (processing_mode <> 'twoPass' AND live_bundle_manifest_json IS NULL AND live_engine_version IS NULL AND live_parameters_json IS NULL))",
    "CHECK ((processing_mode IN ('twoPass','postSession') AND refinement_bundle_manifest_json IS NOT NULL AND refinement_engine_version IS NOT NULL AND refinement_parameters_json IS NOT NULL) OR (processing_mode = 'recordingOnly' AND refinement_bundle_manifest_json IS NULL AND refinement_engine_version IS NULL AND refinement_parameters_json IS NULL))",
    'CHECK (live_engine_version IS NULL OR length(trim(live_engine_version)) > 0)',
    'CHECK (refinement_engine_version IS NULL OR length(trim(refinement_engine_version)) > 0)',
    "CHECK (live_bundle_manifest_json IS NULL OR (json_valid(live_bundle_manifest_json) AND json_type(live_bundle_manifest_json) = 'object'))",
    "CHECK (refinement_bundle_manifest_json IS NULL OR (json_valid(refinement_bundle_manifest_json) AND json_type(refinement_bundle_manifest_json) = 'object'))",
    r"CHECK (live_bundle_manifest_json IS NULL OR (json_type(live_bundle_manifest_json, '$.schemaVersion') IS 'integer' AND json_extract(live_bundle_manifest_json, '$.schemaVersion') IN (1,2)))",
    r"CHECK (refinement_bundle_manifest_json IS NULL OR (json_type(refinement_bundle_manifest_json, '$.schemaVersion') IS 'integer' AND json_extract(refinement_bundle_manifest_json, '$.schemaVersion') IN (1,2)))",
    "CHECK (live_parameters_json IS NULL OR (json_valid(live_parameters_json) AND json_type(live_parameters_json) = 'object'))",
    "CHECK (refinement_parameters_json IS NULL OR (json_valid(refinement_parameters_json) AND json_type(refinement_parameters_json) = 'object'))",
    r"CHECK (live_parameters_json IS NULL OR (json_type(live_parameters_json, '$.parameterVersion') IS 'integer' AND json_extract(live_parameters_json, '$.parameterVersion') > 0))",
    r"CHECK (refinement_parameters_json IS NULL OR (json_type(refinement_parameters_json, '$.parameterVersion') IS 'integer' AND json_extract(refinement_parameters_json, '$.parameterVersion') > 0))",
  ];
}
