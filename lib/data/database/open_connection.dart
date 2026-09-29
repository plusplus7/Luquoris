import 'dart:io';

import 'package:drift/native.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Opens and eagerly migrates the app-private database behind a file snapshot.
Future<AppDatabase> openApplicationDatabase() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final databaseFile = File(
    path.join(supportDirectory.path, 'loquiris.sqlite'),
  );
  return openMigratedDatabaseFile(databaseFile);
}

/// Opens [databaseFile], restoring its closed-file snapshot if migration fails.
///
/// Callers must ensure no other connection is live while this operation runs.
/// [verifyOpen] is a test seam for forced mid-open failure verification.
Future<AppDatabase> openMigratedDatabaseFile(
  File databaseFile, {
  Future<void> Function(AppDatabase database)? verifyOpen,
}) async {
  await databaseFile.parent.create(recursive: true);
  final snapshot = await _DatabaseFileSnapshot.take(databaseFile);
  final database = AppDatabase(
    NativeDatabase.createInBackground(databaseFile),
  );
  try {
    await database.customSelect('PRAGMA user_version').getSingle();
    await verifyOpen?.call(database);
    snapshot.discard();
    return database;
  } on Object catch (error, stackTrace) {
    Object? closeError;
    try {
      await database.close();
    } on Object catch (caught) {
      closeError = caught;
    }
    try {
      await snapshot.restore();
    } on Object catch (restoreError) {
      Error.throwWithStackTrace(
        DatabaseSnapshotRestoreException(
          openError: error,
          closeError: closeError,
          restoreError: restoreError,
        ),
        stackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

/// Signals that a failed migration was followed by a failed snapshot restore.
final class DatabaseSnapshotRestoreException implements Exception {
  /// Creates a failure retaining all causes without exposing paths in text.
  const DatabaseSnapshotRestoreException({
    required this.openError,
    required this.closeError,
    required this.restoreError,
  });

  /// Original open or migration failure.
  final Object openError;

  /// Secondary close failure, when closing also failed.
  final Object? closeError;

  /// Snapshot restore failure that prevented safe rollback.
  final Object restoreError;

  @override
  String toString() => 'DatabaseSnapshotRestoreException';
}

final class _DatabaseFileSnapshot {
  const _DatabaseFileSnapshot({
    required this.databaseFile,
    required this.snapshotDirectory,
    required this.existingSuffixes,
  });

  static const _suffixes = <String>['', '-wal', '-shm'];

  final File databaseFile;
  final Directory snapshotDirectory;
  final List<String> existingSuffixes;

  static Future<_DatabaseFileSnapshot> take(File databaseFile) async {
    final snapshotDirectory = await Directory.systemTemp.createTemp(
      'loquiris-database-snapshot-',
    );
    final existingSuffixes = <String>[];
    for (final suffix in _suffixes) {
      final source = File('${databaseFile.path}$suffix');
      if (source.existsSync()) {
        existingSuffixes.add(suffix);
        source.copySync(
          path.join(snapshotDirectory.path, 'database$suffix'),
        );
      }
    }
    return _DatabaseFileSnapshot(
      databaseFile: databaseFile,
      snapshotDirectory: snapshotDirectory,
      existingSuffixes: existingSuffixes,
    );
  }

  Future<void> restore() async {
    for (final suffix in _suffixes) {
      final current = File('${databaseFile.path}$suffix');
      if (current.existsSync()) current.deleteSync();
    }
    for (final suffix in existingSuffixes) {
      File(
        path.join(snapshotDirectory.path, 'database$suffix'),
      ).copySync('${databaseFile.path}$suffix');
    }
    discard();
  }

  void discard() {
    if (snapshotDirectory.existsSync()) {
      snapshotDirectory.deleteSync(recursive: true);
    }
  }
}
