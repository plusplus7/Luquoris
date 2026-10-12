import 'package:flutter/services.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';

/// Android adapter for deterministic app-private backup publication.
final class MethodChannelBackupGateway
    implements BackupGateway, RestoreGateway {
  /// Creates a gateway with injectable channel and privacy-safe logging.
  const MethodChannelBackupGateway({
    required this._diagnosticSink,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.loquiris/backup_v1';
  static const _version = 1;

  final MethodChannel _channel;
  final DiagnosticLogSink _diagnosticSink;

  @override
  Future<Result<BackupNativeReceipt, BackupFailure>> create(
    BackupNativeRequest request,
  ) async {
    try {
      final value = await _channel.invokeMethod<Object?>('create', {
        'v': _version,
        'operationId': request.operationId,
        'schemaVersion': request.schemaVersion,
        'exportedAtUtc': request.exportedAtUtc,
        'snapshotRelativePath': request.snapshotRelativePath,
        'audioPlan': <Map<String, Object?>>[
          for (final segment in request.audioPlan)
            <String, Object?>{
              'relativePath': segment.relativePath,
              'committedBytes': segment.committedBytes,
            },
        ],
      });
      if (value is! Map<Object?, Object?> || value['v'] != _version) {
        return const Err(BackupUnavailable('backup_channel_invalid'));
      }
      if (value['ok'] != true) {
        return Err(BackupUnavailable(_failureCode(value)));
      }
      final receipt = value['receipt'];
      if (receipt is! Map<Object?, Object?>) {
        return const Err(BackupUnavailable('backup_channel_invalid'));
      }
      final rawPath = receipt['relativePath'];
      final sha256 = receipt['sha256'];
      final bytes = receipt['bytes'];
      if (rawPath is! String ||
          sha256 is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
          bytes is! int ||
          bytes < 0) {
        return const Err(BackupUnavailable('backup_channel_invalid'));
      }
      final relativePath = AppRelativePath.tryParse(rawPath);
      if (relativePath case Err<AppRelativePath, InvalidAppRelativePath>()) {
        return const Err(BackupUnavailable('backup_channel_invalid'));
      }
      final path =
          (relativePath as Ok<AppRelativePath, InvalidAppRelativePath>).value;
      if (!RegExp(
        r'^backups/loquiris-backup-[A-Za-z0-9_-]{1,128}\.zip$',
      ).hasMatch(path.value)) {
        return const Err(BackupUnavailable('backup_channel_invalid'));
      }
      return Ok(
        BackupNativeReceipt(
          relativePath: path,
          sha256: sha256,
          bytes: bytes,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('backup_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('backup_channel_unavailable'));
    }
  }

  @override
  Future<Result<RestoreStaging, BackupFailure>> verifyAndStage(
    RestoreVerificationRequest request,
  ) async {
    try {
      final value = await _channel.invokeMethod<Object?>(
        'verifyAndStageRestore',
        <String, Object?>{
          'v': _version,
          'operationId': request.operationId,
          'archiveRelativePath': request.archiveRelativePath,
          'currentSchemaVersion': request.currentSchemaVersion,
        },
      );
      if (value is! Map<Object?, Object?> || value['v'] != _version) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      if (value['ok'] != true) {
        return Err(BackupUnavailable(_failureCode(value)));
      }
      final verification = value['verification'];
      if (verification is! Map<Object?, Object?>) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      final formatVersion = verification['formatVersion'];
      final schemaVersion = verification['schemaVersion'];
      final exportedAtUtc = verification['exportedAtUtc'];
      final databasePath = _restorePath(
        verification['databaseRelativePath'],
        request.operationId,
        r'/database/loquiris\.sqlite$',
      );
      final checksumPath = _restorePath(
        verification['checksumIndexRelativePath'],
        request.operationId,
        r'/checksums\.json$',
      );
      final stagingPath = _restorePath(
        verification['stagingRelativePath'],
        request.operationId,
        r'$',
      );
      final recordings = _restoreRecordings(verification['recordings']);
      if (formatVersion is! int ||
          formatVersion != 1 ||
          schemaVersion is! int ||
          schemaVersion <= 0 ||
          schemaVersion > request.currentSchemaVersion ||
          exportedAtUtc is! String ||
          DateTime.tryParse(exportedAtUtc)?.isUtc != true ||
          databasePath == null ||
          checksumPath == null ||
          stagingPath == null ||
          recordings == null) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      return Ok(
        RestoreStaging(
          formatVersion: formatVersion,
          schemaVersion: schemaVersion,
          exportedAtUtc: exportedAtUtc,
          databaseRelativePath: databasePath,
          checksumIndexRelativePath: checksumPath,
          stagingRelativePath: stagingPath,
          recordings: recordings,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('restore_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('restore_channel_unavailable'));
    }
  }

  @override
  Future<Result<Map<String, String?>, BackupFailure>> recordingFingerprints(
    List<String> meetingIds,
  ) async {
    if (meetingIds.length > 10000 ||
        meetingIds.toSet().length != meetingIds.length ||
        meetingIds.any(_invalidMeetingId)) {
      return const Err(
        BackupUnavailable('restore_recording_request_invalid'),
      );
    }
    final response = await _invokeRestore('fingerprintRestoreRecordings', {
      'v': _version,
      'meetingIds': meetingIds,
    });
    if (response case Err(:final failure)) return Err(failure);
    final value = (response as Ok<Map<Object?, Object?>, BackupFailure>).value;
    final raw = value['fingerprints'];
    if (raw is! Map<Object?, Object?> || raw.length != meetingIds.length) {
      return const Err(BackupUnavailable('restore_channel_invalid'));
    }
    final result = <String, String?>{};
    for (final meetingId in meetingIds) {
      if (!raw.containsKey(meetingId)) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      final fingerprint = raw[meetingId];
      if (fingerprint != null &&
          (fingerprint is! String || !_sha256.hasMatch(fingerprint))) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      result[meetingId] = fingerprint as String?;
    }
    return Ok(Map<String, String?>.unmodifiable(result));
  }

  @override
  Future<Result<bool, BackupFailure>> publishRecording(
    RestoreRecordingTransfer request,
  ) async {
    if (_invalidOperationId(request.operationId) ||
        _invalidMeetingId(request.sourceMeetingId) ||
        _invalidMeetingId(request.targetMeetingId) ||
        !_sha256.hasMatch(request.contentFingerprint)) {
      return const Err(
        BackupUnavailable('restore_recording_request_invalid'),
      );
    }
    final response = await _invokeRestore('publishRestoreRecording', {
      'v': _version,
      'operationId': request.operationId,
      'sourceMeetingId': request.sourceMeetingId,
      'targetMeetingId': request.targetMeetingId,
      'contentFingerprint': request.contentFingerprint,
    });
    if (response case Err(:final failure)) return Err(failure);
    final value = (response as Ok<Map<Object?, Object?>, BackupFailure>).value;
    final published = value['published'];
    return published is bool
        ? Ok(published)
        : const Err(BackupUnavailable('restore_channel_invalid'));
  }

  @override
  Future<Result<void, BackupFailure>> rollbackRecordings(
    String operationId,
    List<String> meetingIds,
  ) => _invokeEmptyRestore(
    'rollbackRestoreRecordings',
    <String, Object?>{
      'v': _version,
      'operationId': operationId,
      'meetingIds': meetingIds,
    },
    valid:
        !_invalidOperationId(operationId) &&
        meetingIds.length <= 10000 &&
        meetingIds.toSet().length == meetingIds.length &&
        !meetingIds.any(_invalidMeetingId),
  );

  @override
  Future<Result<void, BackupFailure>> finalizeRecordings(
    String operationId,
    List<String> meetingIds,
  ) => _invokeEmptyRestore(
    'finalizeRestoreRecordings',
    <String, Object?>{
      'v': _version,
      'operationId': operationId,
      'meetingIds': meetingIds,
    },
    valid:
        !_invalidOperationId(operationId) &&
        meetingIds.length <= 10000 &&
        meetingIds.toSet().length == meetingIds.length &&
        !meetingIds.any(_invalidMeetingId),
  );

  @override
  Future<Result<void, BackupFailure>> discardStaging(String operationId) =>
      _invokeEmptyRestore(
        'discardRestoreStaging',
        <String, Object?>{'v': _version, 'operationId': operationId},
        valid: !_invalidOperationId(operationId),
      );

  Future<Result<void, BackupFailure>> _invokeEmptyRestore(
    String method,
    Map<String, Object?> arguments, {
    required bool valid,
  }) async {
    if (!valid) {
      return const Err(
        BackupUnavailable('restore_recording_request_invalid'),
      );
    }
    final response = await _invokeRestore(method, arguments);
    return switch (response) {
      Ok() => const Ok<void, BackupFailure>(null),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Map<Object?, Object?>, BackupFailure>> _invokeRestore(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final value = await _channel.invokeMethod<Object?>(method, arguments);
      if (value is! Map<Object?, Object?> || value['v'] != _version) {
        return const Err(BackupUnavailable('restore_channel_invalid'));
      }
      if (value['ok'] != true) {
        return Err(BackupUnavailable(_failureCode(value)));
      }
      return Ok(value);
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('restore_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(BackupUnavailable('restore_channel_unavailable'));
    }
  }

  List<RestoreRecordingStaging>? _restoreRecordings(Object? rawRecordings) {
    if (rawRecordings is! List<Object?> || rawRecordings.length > 10000) {
      return null;
    }
    final recordings = <RestoreRecordingStaging>[];
    final meetingIds = <String>{};
    final storageKeys = <String>{};
    for (final raw in rawRecordings) {
      if (raw is! Map<Object?, Object?>) return null;
      final sourceMeetingId = raw['sourceMeetingId'];
      final storageKey = raw['storageKey'];
      final contentFingerprint = raw['contentFingerprint'];
      final rawSegments = raw['segments'];
      if (sourceMeetingId is! String ||
          sourceMeetingId.isEmpty ||
          sourceMeetingId.length > 512 ||
          storageKey is! String ||
          !_sha256.hasMatch(storageKey) ||
          contentFingerprint is! String ||
          !_sha256.hasMatch(contentFingerprint) ||
          rawSegments is! List<Object?> ||
          rawSegments.length > 10000 ||
          !meetingIds.add(sourceMeetingId) ||
          !storageKeys.add(storageKey)) {
        return null;
      }
      final segments = _restoreSegments(rawSegments);
      if (segments == null) return null;
      recordings.add(
        RestoreRecordingStaging(
          sourceMeetingId: sourceMeetingId,
          storageKey: storageKey,
          contentFingerprint: contentFingerprint,
          segments: segments,
        ),
      );
    }
    return List<RestoreRecordingStaging>.unmodifiable(recordings);
  }

  List<RestoreSegmentStaging>? _restoreSegments(List<Object?> rawSegments) {
    final result = <RestoreSegmentStaging>[];
    final names = <String>{};
    for (final raw in rawSegments) {
      if (raw is! Map<Object?, Object?>) return null;
      final fileName = raw['fileName'];
      final committedBytes = raw['committedBytes'];
      if (fileName is! String ||
          !_segmentName.hasMatch(fileName) ||
          committedBytes is! int ||
          committedBytes <= 0 ||
          !names.add(fileName)) {
        return null;
      }
      result.add(
        RestoreSegmentStaging(
          fileName: fileName,
          committedBytes: committedBytes,
        ),
      );
    }
    return List<RestoreSegmentStaging>.unmodifiable(result);
  }

  AppRelativePath? _restorePath(
    Object? rawPath,
    String operationId,
    String suffixPattern,
  ) {
    if (rawPath is! String) return null;
    final parsed = AppRelativePath.tryParse(rawPath);
    if (parsed is! Ok<AppRelativePath, InvalidAppRelativePath>) return null;
    final expected = RegExp(
      '^restore_staging/${RegExp.escape(operationId)}$suffixPattern',
    );
    return expected.hasMatch(parsed.value.value) ? parsed.value : null;
  }

  String _failureCode(Map<Object?, Object?> value) {
    final failure = value['failure'];
    final code = failure is Map<Object?, Object?> ? failure['code'] : null;
    return code is String && RegExp(r'^[a-z0-9_]{1,128}$').hasMatch(code)
        ? code
        : 'backup_channel_invalid';
  }

  void _record(Object error, StackTrace stackTrace) {
    _diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.exportOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
  }

  static final _sha256 = RegExp(r'^[a-f0-9]{64}$');
  static final _operationId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _segmentName = RegExp(r'^segment-[0-9]{5,}\.adts$');

  static bool _invalidMeetingId(String value) =>
      value.isEmpty || value.codeUnits.length > 512;

  static bool _invalidOperationId(String value) =>
      !_operationId.hasMatch(value);
}
