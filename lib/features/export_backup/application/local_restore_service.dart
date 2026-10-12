import 'dart:io';

import 'package:drift/drift.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Request to verify an app-private backup before any live-data mutation.
@immutable
final class RestoreVerificationRequest extends ValueObject {
  /// Creates a verification request.
  const RestoreVerificationRequest({
    required this.operationId,
    required this.archiveRelativePath,
    required this.currentSchemaVersion,
  });

  /// Stable restore operation identifier.
  final String operationId;

  /// Validated app-private archive location.
  final String archiveRelativePath;

  /// Highest database schema this application can import.
  final int currentSchemaVersion;

  @override
  List<Object?> get equalityValues => <Object?>[
    operationId,
    archiveRelativePath,
    currentSchemaVersion,
  ];
}

/// Fully verified payload staged outside authoritative live paths.
@immutable
final class RestoreStaging extends ValueObject {
  /// Creates verified restore staging metadata.
  RestoreStaging({
    required this.formatVersion,
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.databaseRelativePath,
    required this.checksumIndexRelativePath,
    required this.stagingRelativePath,
    required List<RestoreRecordingStaging> recordings,
  }) : recordings = List<RestoreRecordingStaging>.unmodifiable(recordings);

  /// Backup container version.
  final int formatVersion;

  /// Database schema inside the verified snapshot.
  final int schemaVersion;

  /// Injected export timestamp retained for provenance.
  final String exportedAtUtc;

  /// Verified staged SQLite snapshot.
  final AppRelativePath databaseRelativePath;

  /// Verified exact canonical checksum-index bytes.
  final AppRelativePath checksumIndexRelativePath;

  /// Root of all verified staged payload files.
  final AppRelativePath stagingRelativePath;

  /// Verified authoritative recording groups keyed by source meeting.
  final List<RestoreRecordingStaging> recordings;

  @override
  List<Object?> get equalityValues => <Object?>[
    formatVersion,
    schemaVersion,
    exportedAtUtc,
    databaseRelativePath,
    checksumIndexRelativePath,
    stagingRelativePath,
    recordings,
  ];
}

/// Verified recording payload staged for one source meeting.
@immutable
final class RestoreRecordingStaging extends ValueObject {
  /// Creates immutable verified recording metadata.
  RestoreRecordingStaging({
    required this.sourceMeetingId,
    required this.storageKey,
    required this.contentFingerprint,
    required List<RestoreSegmentStaging> segments,
  }) : segments = List<RestoreSegmentStaging>.unmodifiable(segments);

  /// Meeting identity decoded from the CRC-protected recording manifest.
  final String sourceMeetingId;

  /// SHA-256 storage key validated against [sourceMeetingId].
  final String storageKey;

  /// Semantic recording fingerprint independent of meeting identity.
  final String contentFingerprint;

  /// Verified committed segment prefixes in manifest order.
  final List<RestoreSegmentStaging> segments;

  @override
  List<Object?> get equalityValues => <Object?>[
    sourceMeetingId,
    storageKey,
    contentFingerprint,
    segments,
  ];
}

/// Verified authoritative segment metadata used to cross-check the database.
@immutable
final class RestoreSegmentStaging extends ValueObject {
  /// Creates immutable verified segment metadata.
  const RestoreSegmentStaging({
    required this.fileName,
    required this.committedBytes,
  });

  /// Exact allowlisted ADTS basename.
  final String fileName;

  /// Exact verified archive byte length.
  final int committedBytes;

  @override
  List<Object?> get equalityValues => <Object?>[fileName, committedBytes];
}

/// Native hostile-archive verification boundary.
// The interface isolates archive parsing from database import.
abstract interface class RestoreGateway {
  /// Verifies all hashes and atomically publishes private staging.
  Future<Result<RestoreStaging, BackupFailure>> verifyAndStage(
    RestoreVerificationRequest request,
  );

  /// Returns semantic fingerprints for existing live recording directories.
  Future<Result<Map<String, String?>, BackupFailure>> recordingFingerprints(
    List<String> meetingIds,
  );

  /// Atomically publishes one verified staged recording directory.
  Future<Result<bool, BackupFailure>> publishRecording(
    RestoreRecordingTransfer request,
  );

  /// Removes only directories newly published by a failed restore attempt.
  Future<Result<void, BackupFailure>> rollbackRecordings(
    String operationId,
    List<String> meetingIds,
  );

  /// Removes pending markers after the database transaction commits.
  Future<Result<void, BackupFailure>> finalizeRecordings(
    String operationId,
    List<String> meetingIds,
  );

  /// Best-effort removal of verified private restore staging.
  Future<Result<void, BackupFailure>> discardStaging(String operationId);
}

/// Native request to publish authoritative audio for one imported meeting.
@immutable
final class RestoreRecordingTransfer extends ValueObject {
  /// Creates a validated value-only transfer request.
  const RestoreRecordingTransfer({
    required this.operationId,
    required this.sourceMeetingId,
    required this.targetMeetingId,
    required this.contentFingerprint,
  });

  /// Restore operation owning the verified staging directory.
  final String operationId;

  /// Meeting identity encoded by the staged recording manifest.
  final String sourceMeetingId;

  /// Live meeting identity selected by deterministic conflict handling.
  final String targetMeetingId;

  /// Verified semantic audio fingerprint.
  final String contentFingerprint;

  @override
  List<Object?> get equalityValues => <Object?>[
    operationId,
    sourceMeetingId,
    targetMeetingId,
    contentFingerprint,
  ];
}

/// User-confirmed request to restore one private backup archive.
@immutable
final class RestoreRequest extends ValueObject {
  /// Creates an immutable restore request.
  const RestoreRequest({
    required this.operationId,
    required this.archiveRelativePath,
  });

  /// Stable operation identity.
  final String operationId;

  /// App-private backup or imported archive path.
  final String archiveRelativePath;

  @override
  List<Object?> get equalityValues => <Object?>[
    operationId,
    archiveRelativePath,
  ];
}

/// User-confirmed restore application boundary.
// The interface keeps presentation independent from the concrete orchestrator.
// ignore: one_member_abstracts
abstract interface class RestoreService {
  /// Restores a verified package using the caller's active-locale title marker.
  Future<Result<RestoreImportReceipt, BackupFailure>> restore(
    RestoreRequest request, {
    required String Function(String originalTitle) restoredCopyTitle,
  });
}

/// Coordinates hostile-archive verification, audio publication, and DB merge.
final class LocalRestoreService implements RestoreService {
  /// Creates the restore orchestrator from injectable private boundaries.
  const LocalRestoreService({
    required this.liveDatabase,
    required this.gateway,
    required this.resolveBaseDirectory,
  });

  /// Live database receiving imported records.
  final AppDatabase liveDatabase;

  /// Native archive and authoritative-recording boundary.
  final RestoreGateway gateway;

  /// Resolves the app-private files root.
  final Future<Directory> Function() resolveBaseDirectory;

  /// Restores a verified package without silently overwriting live meetings.
  @override
  Future<Result<RestoreImportReceipt, BackupFailure>> restore(
    RestoreRequest request, {
    required String Function(String originalTitle) restoredCopyTitle,
  }) async {
    final verified = await gateway.verifyAndStage(
      RestoreVerificationRequest(
        operationId: request.operationId,
        archiveRelativePath: request.archiveRelativePath,
        currentSchemaVersion: liveDatabase.schemaVersion,
      ),
    );
    if (verified case Err(:final failure)) return Err(failure);
    final staging = (verified as Ok<RestoreStaging, BackupFailure>).value;
    AppDatabase? sourceDatabase;
    final publishedMeetingIds = <String>[];
    try {
      final base = await resolveBaseDirectory();
      final sourceFile = _resolvePrivateFile(
        base,
        staging.databaseRelativePath,
      );
      if (sourceFile == null || !sourceFile.existsSync()) {
        return const Err(BackupUnavailable('restore_staging_invalid'));
      }
      sourceDatabase = await openMigratedDatabaseFile(sourceFile);
      final sourceAudio = await _sourceAudioFingerprints(
        sourceDatabase,
        staging.recordings,
      );
      if (sourceAudio case Err(:final failure)) return Err(failure);
      final audioFingerprints =
          (sourceAudio as Ok<Map<String, String>, BackupFailure>).value;
      final importer = DriftRestoreImporter(
        liveDatabase: liveDatabase,
        restoredCopyTitle: restoredCopyTitle,
      );
      final imported = await importer.import(
        sourceDatabase,
        sourceAudioFingerprints: audioFingerprints,
        liveAudioFingerprint: _liveAudioFingerprint,
        beforeMeetingInsert: (transfer) async {
          if (!transfer.hasAuthoritativeAudio) {
            return const Ok<void, RestoreImportFailure>(null);
          }
          final publication = await gateway.publishRecording(
            RestoreRecordingTransfer(
              operationId: request.operationId,
              sourceMeetingId: transfer.sourceMeetingId,
              targetMeetingId: transfer.targetMeetingId,
              contentFingerprint: transfer.contentFingerprint,
            ),
          );
          return switch (publication) {
            Ok(:final value) => () {
              if (value) publishedMeetingIds.add(transfer.targetMeetingId);
              return const Ok<void, RestoreImportFailure>(null);
            }(),
            Err(:final failure) => Err(
              RestoreImportFailure(failure.code),
            ),
          };
        },
      );
      if (imported case Err(:final failure)) {
        if (publishedMeetingIds.isNotEmpty) {
          final rollback = await gateway.rollbackRecordings(
            request.operationId,
            publishedMeetingIds,
          );
          if (rollback case Err(:final failure)) return Err(failure);
        }
        return Err(BackupUnavailable(failure.code));
      }
      if (publishedMeetingIds.isNotEmpty) {
        await gateway.finalizeRecordings(
          request.operationId,
          publishedMeetingIds,
        );
      }
      return Ok(
        (imported as Ok<RestoreImportReceipt, RestoreImportFailure>).value,
      );
    } on Object {
      if (publishedMeetingIds.isNotEmpty) {
        await gateway.rollbackRecordings(
          request.operationId,
          publishedMeetingIds,
        );
      }
      return const Err(BackupUnavailable('restore_import_failed'));
    } finally {
      await sourceDatabase?.close();
      await gateway.discardStaging(request.operationId);
    }
  }

  Future<Result<Map<String, String>, BackupFailure>> _sourceAudioFingerprints(
    AppDatabase sourceDatabase,
    List<RestoreRecordingStaging> recordings,
  ) async {
    final recordingByMeeting = <String, RestoreRecordingStaging>{
      for (final recording in recordings) recording.sourceMeetingId: recording,
    };
    if (recordingByMeeting.length != recordings.length) {
      return const Err(BackupUnavailable('restore_recording_index_invalid'));
    }
    final rows = await sourceDatabase.customSelect('''
      SELECT m.id,
        EXISTS(
          SELECT 1 FROM audio_segments a WHERE a.meeting_id = m.id
        ) AS has_audio
      FROM meetings m
      ORDER BY m.id
      ''').get();
    final sourceMeetingIds = <String>{};
    final result = <String, String>{};
    for (final row in rows) {
      final meetingId = row.read<String>('id');
      final hasAudio = row.read<int>('has_audio') == 1;
      final recording = recordingByMeeting[meetingId];
      if (hasAudio != (recording != null)) {
        return const Err(
          BackupUnavailable('restore_recording_index_mismatch'),
        );
      }
      if (recording != null &&
          !await _databaseRecordingMatches(
            sourceDatabase,
            meetingId,
            recording,
          )) {
        return const Err(
          BackupUnavailable('restore_recording_index_mismatch'),
        );
      }
      sourceMeetingIds.add(meetingId);
      result[meetingId] = recording?.contentFingerprint ?? _emptyAudioHash;
    }
    if (!sourceMeetingIds.containsAll(recordingByMeeting.keys)) {
      return const Err(BackupUnavailable('restore_recording_index_mismatch'));
    }
    return Ok(Map<String, String>.unmodifiable(result));
  }

  Future<bool> _databaseRecordingMatches(
    AppDatabase sourceDatabase,
    String meetingId,
    RestoreRecordingStaging recording,
  ) async {
    final rows = await sourceDatabase
        .customSelect(
          '''
      SELECT relative_path, committed_bytes
      FROM audio_segments
      WHERE meeting_id = ?
      ORDER BY sequence
      ''',
          variables: <Variable<Object>>[Variable<String>(meetingId)],
        )
        .get();
    if (rows.length != recording.segments.length) return false;
    for (var index = 0; index < rows.length; index += 1) {
      final expected = recording.segments[index];
      if (rows[index].read<String>('relative_path') !=
              'recordings/${recording.storageKey}/${expected.fileName}' ||
          rows[index].read<int>('committed_bytes') != expected.committedBytes) {
        return false;
      }
    }
    return true;
  }

  Future<String?> _liveAudioFingerprint(String meetingId) async {
    final result = await gateway.recordingFingerprints(<String>[meetingId]);
    return switch (result) {
      Ok(:final value) => value[meetingId] ?? _emptyAudioHash,
      Err() => throw const _RestoreAudioInspectionFailure(),
    };
  }

  File? _resolvePrivateFile(
    Directory base,
    AppRelativePath relativePath,
  ) {
    final root = base.absolute.path;
    final resolved = File(
      path.joinAll(<String>[root, ...relativePath.value.split('/')]),
    ).absolute;
    return path.isWithin(root, resolved.path) ? resolved : null;
  }

  static const _emptyAudioHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
}

final class _RestoreAudioInspectionFailure implements Exception {
  const _RestoreAudioInspectionFailure();
}
