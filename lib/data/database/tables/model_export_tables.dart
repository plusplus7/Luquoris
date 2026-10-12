import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';

/// Immutable manifest for one model artifact bundled in the application.
@TableIndex(
  name: 'ux_model_manifests_hash',
  columns: {#sha256},
  unique: true,
)
@TableIndex(
  name: 'ux_model_manifest_provenance',
  columns: {#id, #version, #sha256, #expectedEngineId},
  unique: true,
)
class ModelManifests extends Table with AuditColumns {
  /// Exact model release version.
  TextColumn get version => text()();

  /// Reviewed upstream source reference.
  TextColumn get source => text()();

  /// Expected SHA-256 digest.
  TextColumn get sha256 => text()();

  /// Bundled byte length.
  IntColumn get bytes => integer()();

  /// Compatible inference-engine identifier.
  TextColumn get expectedEngineId => text()();

  /// SPDX identifier or reviewed fixed license key.
  TextColumn get licenseId => text()();

  /// App-relative bundled license snapshot.
  TextColumn get licenseSnapshotPath => text()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (bytes >= 0)',
    'CHECK (length(sha256) > 0)',
    'CHECK (length(license_snapshot_path) > 0)',
    "CHECK (license_snapshot_path NOT LIKE '/%')",
    'CHECK (instr(license_snapshot_path, char(92)) = 0)',
    'CHECK (instr(license_snapshot_path, char(0)) = 0)',
    "CHECK (license_snapshot_path NOT GLOB '[A-Za-z]:*')",
    "CHECK (('/' || license_snapshot_path || '/') NOT LIKE '%//%')",
    "CHECK (('/' || license_snapshot_path || '/') NOT LIKE '%/../%')",
    "CHECK (('/' || license_snapshot_path || '/') NOT LIKE '%/./%')",
  ];
}

/// One checked capability supplied by a model manifest.
@TableIndex(
  name: 'ux_model_capability',
  columns: {#modelId, #capability},
  unique: true,
)
class ModelCapabilityEntries extends Table with AuditColumns {
  /// Owning model manifest.
  TextColumn get modelId => text().references(
    ModelManifests,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Capability name mirrored from the domain enum.
  TextColumn get capability => text()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (capability IN ('transcription','languageIdentification','speakerDiarization'))",
  ];
}

/// One measured performance mode enabled for a model manifest.
@TableIndex(
  name: 'ux_model_mode',
  columns: {#modelId, #mode},
  unique: true,
)
class ModelModeEntries extends Table with AuditColumns {
  /// Owning model manifest.
  TextColumn get modelId => text().references(
    ModelManifests,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Enabled mode mirrored from the domain enum.
  TextColumn get mode => text()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (mode IN ('highQuality','balanced','powerSaving','recordingOnly','postSession'))",
  ];
}

/// Durable record of an explicit user-authorized export.
@TableIndex(
  name: 'idx_export_records_meeting_created',
  columns: {
    #meetingId,
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
  },
)
class ExportRecords extends Table with AuditColumns {
  /// Owning meeting.
  TextColumn get meetingId => text().references(
    Meetings,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Requested export representation.
  TextColumn get format => text()();

  /// Pending, completed, or failed.
  TextColumn get exportState => text()();

  /// App-relative private staging path for a completed export.
  TextColumn get relativePath => text().nullable()();

  /// Completed export byte length.
  IntColumn get bytes => integer().nullable()();

  /// Stable structured failure code.
  TextColumn get failureCode => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (format IN ('audioM4a','audioSegments','text','subtitles','json','archive'))",
    "CHECK (export_state IN ('pending','completed','failed'))",
    'CHECK (bytes IS NULL OR bytes >= 0)',
    'CHECK (relative_path IS NULL OR length(relative_path) > 0)',
    "CHECK (relative_path IS NULL OR relative_path NOT LIKE '/%')",
    'CHECK (relative_path IS NULL OR instr(relative_path, char(92)) = 0)',
    'CHECK (relative_path IS NULL OR instr(relative_path, char(0)) = 0)',
    "CHECK (relative_path IS NULL OR relative_path NOT GLOB '[A-Za-z]:*')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%//%')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%/../%')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%/./%')",
    "CHECK ((export_state = 'pending' AND relative_path IS NULL AND bytes IS NULL AND failure_code IS NULL) OR (export_state = 'completed' AND bytes IS NOT NULL AND failure_code IS NULL) OR (export_state = 'failed' AND relative_path IS NULL AND bytes IS NULL AND length(failure_code) > 0))",
  ];
}

/// Durable metadata for one explicit user-authorized backup attempt.
@TableIndex(
  name: 'idx_backup_records_created',
  columns: {IndexedColumn(#createdAt, orderBy: OrderingMode.desc)},
)
class BackupRecords extends Table with AuditColumns {
  /// Pending, completed, or failed.
  TextColumn get backupState => text()();

  /// App-relative private staging path for a completed backup.
  TextColumn get relativePath => text().nullable()();

  /// SHA-256 of the portable archive when completed.
  TextColumn get sha256 => text().nullable()();

  /// Completed archive byte length.
  IntColumn get bytes => integer().nullable()();

  /// Stable structured failure code.
  TextColumn get failureCode => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (backup_state IN ('pending','completed','failed'))",
    'CHECK (bytes IS NULL OR bytes >= 0)',
    'CHECK (relative_path IS NULL OR length(relative_path) > 0)',
    "CHECK (relative_path IS NULL OR relative_path NOT LIKE '/%')",
    'CHECK (relative_path IS NULL OR instr(relative_path, char(92)) = 0)',
    'CHECK (relative_path IS NULL OR instr(relative_path, char(0)) = 0)',
    "CHECK (relative_path IS NULL OR relative_path NOT GLOB '[A-Za-z]:*')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%//%')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%/../%')",
    "CHECK (relative_path IS NULL OR ('/' || relative_path || '/') NOT LIKE '%/./%')",
    "CHECK ((backup_state = 'pending' AND relative_path IS NULL AND sha256 IS NULL AND bytes IS NULL AND failure_code IS NULL) OR (backup_state = 'completed' AND relative_path IS NOT NULL AND length(sha256) > 0 AND bytes IS NOT NULL AND failure_code IS NULL) OR (backup_state = 'failed' AND relative_path IS NULL AND sha256 IS NULL AND bytes IS NULL AND length(failure_code) > 0))",
  ];
}
