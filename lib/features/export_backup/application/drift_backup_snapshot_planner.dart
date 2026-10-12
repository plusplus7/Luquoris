import 'dart:io';

import 'package:drift/drift.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:path/path.dart' as path;

/// Creates a transactionally consistent SQLite snapshot and explicit audio plan.
final class DriftBackupSnapshotPlanner implements BackupSnapshotPlanner {
  /// Creates a planner from the live database and app-private files root.
  const DriftBackupSnapshotPlanner(
    this.database,
    this._resolveBaseDirectory, {
    Future<void> Function()? afterSnapshotCreated,
  }) : _afterSnapshotCreated = afterSnapshotCreated ?? _noopAfterSnapshot;

  /// Live local database.
  final AppDatabase database;

  final Future<Directory> Function() _resolveBaseDirectory;
  final Future<void> Function() _afterSnapshotCreated;

  @override
  Future<Result<BackupSnapshotPlan, BackupFailure>> create(
    String operationId,
  ) async {
    if (!_safeOperationId(operationId)) {
      return const Err(BackupUnavailable('backup_request_invalid'));
    }
    final relativePath = 'backup_staging/$operationId.sqlite';
    File? snapshot;
    try {
      final baseDirectory = await _resolveBaseDirectory();
      snapshot = File(
        path.joinAll(<String>[baseDirectory.path, ...relativePath.split('/')]),
      );
      await snapshot.parent.create(recursive: true);
      if (snapshot.existsSync()) snapshot.deleteSync();
      await database.customStatement('VACUUM INTO ?', <Object>[snapshot.path]);
      await _afterSnapshotCreated();
      final snapshotAlias =
          'backup_snapshot_${operationId.replaceAll('-', '_')}';
      var attached = false;
      late final List<QueryRow> rows;
      try {
        await database.customStatement(
          'ATTACH DATABASE ? AS $snapshotAlias',
          <Object>[snapshot.path],
        );
        attached = true;
        rows = await database.customSelect('''
          SELECT relative_path, committed_bytes
          FROM $snapshotAlias.audio_segments
          WHERE committed_bytes > 0
            AND state IN ('open', 'committed')
          ORDER BY relative_path
          ''').get();
      } finally {
        if (attached) {
          await database.customStatement('DETACH DATABASE $snapshotAlias');
        }
      }
      final audioPlan = <BackupAudioPlanEntry>[];
      for (final row in rows) {
        final relativeAudioPath = row.read<String>('relative_path');
        final parsed = AppRelativePath.tryParse(relativeAudioPath);
        if (parsed is Err<AppRelativePath, InvalidAppRelativePath> ||
            !_recordingPath.hasMatch(relativeAudioPath)) {
          throw const _BackupAudioPlanInvalid();
        }
        audioPlan.add(
          BackupAudioPlanEntry(
            relativePath: relativeAudioPath,
            committedBytes: row.read<int>('committed_bytes'),
          ),
        );
      }
      return Ok(
        BackupSnapshotPlan(
          snapshotRelativePath: relativePath,
          audioPlan: audioPlan,
        ),
      );
    } on _BackupAudioPlanInvalid {
      if (snapshot?.existsSync() ?? false) snapshot!.deleteSync();
      return const Err(BackupUnavailable('backup_audio_plan_invalid'));
    } on Object {
      if (snapshot?.existsSync() ?? false) snapshot!.deleteSync();
      return const Err(BackupUnavailable('backup_snapshot_failed'));
    }
  }

  @override
  Future<void> deleteSnapshot(String relativePath) async {
    if (!_snapshotPath.hasMatch(relativePath)) return;
    try {
      final baseDirectory = await _resolveBaseDirectory();
      final snapshot = File(
        path.joinAll(<String>[
          baseDirectory.path,
          ...relativePath.split('/'),
        ]),
      );
      if (snapshot.existsSync()) snapshot.deleteSync();
    } on Object {
      // Native packaging also removes the snapshot. Cleanup is best effort.
    }
  }

  static bool _safeOperationId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

  static final _snapshotPath = RegExp(
    r'^backup_staging/[A-Za-z0-9_-]{1,128}\.sqlite$',
  );
  static final _recordingPath = RegExp(
    r'^recordings/[a-f0-9]{64}/segment-[0-9]{5,}\.adts$',
  );
}

Future<void> _noopAfterSnapshot() async {}

final class _BackupAudioPlanInvalid implements Exception {
  const _BackupAudioPlanInvalid();
}

/// Deletes only validated complete artifacts below the private backup directory.
final class PrivateBackupArtifactCleaner implements BackupArtifactCleaner {
  /// Creates a cleaner from the app-private files root.
  const PrivateBackupArtifactCleaner(this._resolveBaseDirectory);

  final Future<Directory> Function() _resolveBaseDirectory;

  @override
  Future<void> delete(AppRelativePath relativePath) async {
    if (!_backupPath.hasMatch(relativePath.value)) return;
    try {
      final baseDirectory = await _resolveBaseDirectory();
      final file = File(
        path.joinAll(<String>[
          baseDirectory.path,
          ...relativePath.value.split('/'),
        ]),
      );
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // Cleanup failure is intentionally non-throwing at this boundary.
    }
  }

  static final _backupPath = RegExp(
    r'^backups/loquiris-backup-[A-Za-z0-9_-]{1,128}\.zip$',
  );
}

/// Removes only incomplete backup staging artifacts left by process death.
final class PrivateBackupStartupCleaner {
  /// Creates a startup cleaner from the app-private files root.
  const PrivateBackupStartupCleaner(
    this._resolveBaseDirectory, [
    this._database,
  ]);

  final Future<Directory> Function() _resolveBaseDirectory;
  final AppDatabase? _database;

  /// Deletes bounded staging snapshots and unpublished archive temporaries.
  Future<int> clean() async {
    try {
      final baseDirectory = await _resolveBaseDirectory();
      var deleted = 0;
      deleted += _deleteMatching(
        Directory(path.join(baseDirectory.path, 'backup_staging')),
        _snapshotName,
      );
      deleted += _deleteMatching(
        Directory(path.join(baseDirectory.path, 'backups')),
        _temporaryArchiveName,
      );
      deleted += _deleteMatchingDirectories(
        Directory(path.join(baseDirectory.path, 'restore_staging')),
        _restoreStagingName,
      );
      if (_database != null) {
        deleted += await _reconcileRestorePublications(baseDirectory);
      }
      return deleted;
    } on Object {
      return 0;
    }
  }

  int _deleteMatching(Directory directory, RegExp allowedName) {
    if (!directory.existsSync()) return 0;
    var deleted = 0;
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File && allowedName.hasMatch(path.basename(entity.path))) {
        entity.deleteSync();
        deleted += 1;
      }
    }
    return deleted;
  }

  int _deleteMatchingDirectories(Directory directory, RegExp allowedName) {
    if (!directory.existsSync()) return 0;
    var deleted = 0;
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory &&
          allowedName.hasMatch(path.basename(entity.path))) {
        entity.deleteSync(recursive: true);
        deleted += 1;
      }
    }
    return deleted;
  }

  Future<int> _reconcileRestorePublications(Directory baseDirectory) async {
    final recordings = Directory(path.join(baseDirectory.path, 'recordings'));
    if (!recordings.existsSync()) return 0;
    var cleaned = 0;
    for (final entity in recordings.listSync(followLinks: false)) {
      if (entity is Directory &&
          _restoreRecordingTemporary.hasMatch(path.basename(entity.path))) {
        entity.deleteSync(recursive: true);
        cleaned += 1;
        continue;
      }
      if (entity is! Directory ||
          !_storageKey.hasMatch(path.basename(entity.path))) {
        continue;
      }
      final marker = File(path.join(entity.path, _restoreMarkerName));
      if (!marker.existsSync()) continue;
      final storageKey = path.basename(entity.path);
      final referenced = await _database!
          .customSelect(
            'SELECT 1 FROM audio_segments '
            'WHERE relative_path GLOB ? LIMIT 1',
            variables: <Variable<Object>>[
              Variable<String>('recordings/$storageKey/*'),
            ],
          )
          .getSingleOrNull();
      if (referenced == null) {
        entity.deleteSync(recursive: true);
      } else {
        marker.deleteSync();
      }
      cleaned += 1;
    }
    return cleaned;
  }

  static final _snapshotName = RegExp(r'^[A-Za-z0-9_-]{1,128}\.sqlite$');
  static final _temporaryArchiveName = RegExp(
    r'^\.[A-Za-z0-9_-]{1,128}\.zip\.tmp$',
  );
  static final _restoreStagingName = RegExp(
    r'^(?:\.)?[A-Za-z0-9_-]{1,128}(?:\.tmp)?$',
  );
  static final _storageKey = RegExp(r'^[a-f0-9]{64}$');
  static final _restoreRecordingTemporary = RegExp(
    r'^\.restore-[A-Za-z0-9_-]{1,128}-[a-f0-9]{64}\.tmp$',
  );
  static const _restoreMarkerName = '.restore-pending';
}
