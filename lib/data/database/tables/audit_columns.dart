import 'package:drift/drift.dart';

/// Shared identity, revision, and soft-delete columns for every durable table.
mixin AuditColumns on Table {
  /// Stable UUID-style identifier.
  TextColumn get id => text()();

  /// UTC creation instant in epoch milliseconds.
  IntColumn get createdAt =>
      integer().customConstraint('NOT NULL CHECK (created_at >= 0)')();

  /// UTC last-update instant in epoch milliseconds.
  IntColumn get updatedAt => integer().customConstraint(
    'NOT NULL CHECK (updated_at >= created_at)',
  )();

  /// Monotonic row revision used by restore conflict handling.
  IntColumn get rowRevision => integer().customConstraint(
    'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
  )();

  /// Whether this row is hidden by a soft delete.
  BoolColumn get isDeleted => boolean().customConstraint(
    'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR '
    '(is_deleted = 1 AND deleted_at IS NOT NULL))',
  )();

  /// UTC soft-delete instant in epoch milliseconds.
  IntColumn get deletedAt => integer().nullable().customConstraint(
    'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  )();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  bool get isStrict => true;
}
