import 'package:drift/drift.dart';
import 'package:loquiris/data/database/tables/audit_columns.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';

/// Durable remote work shared with the native background repository.
class RemoteTranscriptionTasks extends Table with AuditColumns {
  /// Stable local run and request identity, never regenerated for network retries.
  @override
  TextColumn get id => text()();

  /// Local authoritative meeting.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// Immutable destination chosen by the user for this run.
  TextColumn get endpoint => text()();

  /// Opaque reference to a Keystore-encrypted credential outside this database.
  TextColumn get credentialRef => text()();

  /// Server profile frozen for this run.
  TextColumn get profileId => text()();

  /// Canonical sealed-upload declaration, populated after recording finalization.
  TextColumn get requestJson => text().nullable()();

  /// Server-side resumable upload identity.
  TextColumn get uploadId => text().nullable()();

  /// Server-side transcription job identity.
  TextColumn get jobId => text().nullable()();

  /// Hash of the frozen wire manifest, distinct from the native journal hash.
  TextColumn get manifestDigest => text().nullable()();

  /// Durable synchronization state observed by foreground and background work.
  TextColumn get state => text().withDefault(const Constant('waitingAudio'))();

  /// Typed failure code without text, paths or credentials.
  TextColumn get failureCode => text().nullable()();

  /// Server-confirmed bytes across every original file.
  IntColumn get confirmedBytes => integer().withDefault(const Constant(0))();

  /// Declared committed bytes, independent of retry count.
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();

  /// Consecutive transport attempts since the last successful synchronization.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Earliest UTC epoch millisecond at which background work may retry.
  IntColumn get retryAtUtcMs => integer().withDefault(const Constant(0))();

  /// UTC creation instant in milliseconds.
  IntColumn get createdAtUtcMs => integer()();

  /// UTC last durable observation in milliseconds.
  IntColumn get updatedAtUtcMs => integer()();

  /// Server-advertised retention duration in seconds.
  IntColumn get retentionSeconds => integer().nullable()();

  /// Actual remote retention deadline when known.
  IntColumn get expiresAtUtcMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local remote output and separately authored corrections survive server expiry.
class RemoteTranscriptVersions extends Table with AuditColumns {
  /// Stable local run identity, also sent to the server.
  @override
  TextColumn get id => text()();

  /// Owning meeting, without linking a fictitious bundled model.
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();

  /// Original meeting identity retained when restore creates a local copy.
  TextColumn get sourceMeetingId => text().nullable()();

  /// Original run identity retained when restore creates a local copy.
  TextColumn get sourceRunId => text().nullable()();

  /// Validated versioned server result including actual model provenance.
  TextColumn get resultJson => text()();

  /// User-authored replacement text; null preserves the machine output.
  TextColumn get editedText => text().nullable()();

  /// UTC import instant in milliseconds.
  IntColumn get createdAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
