import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Native inventory assembled from authoritative recording manifests.
final class RecordingRecoveryInventory {
  /// Creates an immutable startup inventory.
  RecordingRecoveryInventory({
    required List<SessionRecoveryEvidence> sessions,
    required this.deletedIncompleteDerivedFiles,
    required List<String> issueCodes,
    Set<String> liveMeetingIds = const <String>{},
    Set<String> invalidStorageKeys = const <String>{},
  }) : sessions = List.unmodifiable(sessions),
       issueCodes = List.unmodifiable(issueCodes),
       liveMeetingIds = Set.unmodifiable(liveMeetingIds),
       invalidStorageKeys = Set.unmodifiable(invalidStorageKeys);

  /// Valid manifest evidence grouped by meeting.
  final List<SessionRecoveryEvidence> sessions;

  /// Safely removed rebuildable partial outputs.
  final int deletedIncompleteDerivedFiles;

  /// Privacy-safe native diagnostics for entries that could not be reconciled.
  final List<String> issueCodes;

  /// Meetings currently owned by a live recorder and excluded from recovery.
  final Set<String> liveMeetingIds;

  /// Opaque recording directories whose manifests could not be trusted.
  final Set<String> invalidStorageKeys;
}

/// Alias naming one native manifest projection at the gateway boundary.
typedef RecordingRecoverySessionEvidence = SessionRecoveryEvidence;

/// Expected failure while reading the native recovery inventory.
final class RecordingRecoveryFailure implements Failure {
  /// Creates a failure with a stable [code].
  const RecordingRecoveryFailure(this.code);

  @override
  final String code;
}

/// Read-only native boundary that never starts microphone capture.
// This interface remains injectable so startup tests never touch platform IO.
// ignore: one_member_abstracts
abstract interface class RecordingRecoveryGateway {
  /// Scans authoritative manifests, segment files, and derived temporaries.
  Future<Result<RecordingRecoveryInventory, RecordingRecoveryFailure>> scan();
}

/// Method-channel implementation of [RecordingRecoveryGateway].
final class MethodChannelRecordingRecoveryGateway
    implements RecordingRecoveryGateway {
  /// Creates the production gateway or an isolated channel-backed test seam.
  const MethodChannelRecordingRecoveryGateway({
    MethodChannel? channel,
    this.timeout = const Duration(seconds: 15),
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.loquiris/recording_control_v1';
  static const int _contractVersion = 1;

  final MethodChannel _channel;

  /// Upper bound preventing native recovery from blocking app startup forever.
  final Duration timeout;

  @override
  Future<Result<RecordingRecoveryInventory, RecordingRecoveryFailure>>
  scan() async {
    try {
      final response = await _channel
          .invokeMethod<Object?>(
            'recoveryInventory',
            const <String, Object?>{'v': _contractVersion},
          )
          .timeout(timeout);
      if (response is! Map<Object?, Object?> ||
          response['v'] != _contractVersion ||
          response['ok'] is! bool) {
        return _invalid();
      }
      if (response['ok'] != true) {
        final failure = response['failure'];
        if (failure is Map<Object?, Object?> && failure['code'] is String) {
          return Err(RecordingRecoveryFailure(failure['code']! as String));
        }
        return _invalid();
      }
      return _parseInventory(response['recovery']);
    } on MissingPluginException {
      return const Err(
        RecordingRecoveryFailure('recording_recovery_channel_unavailable'),
      );
    } on PlatformException catch (error) {
      return Err(RecordingRecoveryFailure(error.code));
    } on TimeoutException {
      return const Err(
        RecordingRecoveryFailure('recording_recovery_channel_timeout'),
      );
    }
  }

  Result<RecordingRecoveryInventory, RecordingRecoveryFailure> _parseInventory(
    Object? value,
  ) {
    if (value is! Map<Object?, Object?> ||
        value['sessions'] is! List<Object?> ||
        value['issueCodes'] is! List<Object?> ||
        value['liveMeetingIds'] is! List<Object?> ||
        value['invalidStorageKeys'] is! List<Object?> ||
        value['deletedIncompleteDerivedFiles'] is! int) {
      return _invalid();
    }
    final deleted = value['deletedIncompleteDerivedFiles']! as int;
    final rawIssues = value['issueCodes']! as List<Object?>;
    final rawLiveMeetingIds = value['liveMeetingIds']! as List<Object?>;
    final rawInvalidStorageKeys = value['invalidStorageKeys']! as List<Object?>;
    if (deleted < 0 ||
        rawIssues.any((issue) => issue is! String) ||
        rawLiveMeetingIds.any((id) => id is! String || id.isEmpty) ||
        rawInvalidStorageKeys.any((key) => !_isSafeStorageKey(key))) {
      return _invalid();
    }

    final sessions = <SessionRecoveryEvidence>[];
    final meetingIds = <String>{};
    for (final rawSession in value['sessions']! as List<Object?>) {
      if (rawSession is! Map<Object?, Object?> ||
          rawSession['meetingId'] is! String ||
          rawSession['storageKey'] is! String ||
          rawSession['sampleRateHz'] is! int ||
          rawSession['integrityState'] is! String ||
          rawSession['diagnostics'] is! List<Object?> ||
          rawSession['rawExportSegments'] is! List<Object?> ||
          rawSession['segments'] is! List<Object?>) {
        return _invalid();
      }
      final meetingId = rawSession['meetingId']! as String;
      final storageKey = rawSession['storageKey']! as String;
      final sampleRateHz = rawSession['sampleRateHz']! as int;
      final integrityState = RecoveryIntegrityState.values
          .where(
            (candidate) => candidate.name == rawSession['integrityState'],
          )
          .firstOrNull;
      if (meetingId.isEmpty ||
          !_isSafeStorageKey(storageKey) ||
          sampleRateHz <= 0 ||
          integrityState == null ||
          !meetingIds.add(meetingId)) {
        return _invalid();
      }
      final segments = <SessionRecoverySegmentEvidence>[];
      for (final rawSegment in rawSession['segments']! as List<Object?>) {
        final segment = _parseSegment(
          rawSegment,
          sampleRateHz,
          segments.length,
          storageKey,
        );
        if (segment == null) return _invalid();
        segments.add(segment);
      }
      final diagnostics = <SessionRecoveryDiagnostic>[];
      for (final rawDiagnostic in rawSession['diagnostics']! as List<Object?>) {
        if (rawDiagnostic is! Map<Object?, Object?> ||
            rawDiagnostic['code'] is! String ||
            (rawDiagnostic['segmentSequence'] != null &&
                rawDiagnostic['segmentSequence'] is! int)) {
          return _invalid();
        }
        final code = rawDiagnostic['code']! as String;
        final sequence = rawDiagnostic['segmentSequence'] as int?;
        if (code.isEmpty || sequence != null && sequence < 0) {
          return _invalid();
        }
        if (sequence != null &&
            segments.every((segment) => segment.sequence != sequence)) {
          return _invalid();
        }
        diagnostics.add(
          SessionRecoveryDiagnostic(
            code: code,
            segmentSequence: sequence,
          ),
        );
      }
      if ((integrityState == RecoveryIntegrityState.complete) !=
          diagnostics.isEmpty) {
        return _invalid();
      }
      final rawExportSegments = <SessionRecoveryRawExportSegment>[];
      for (final rawExport
          in rawSession['rawExportSegments']! as List<Object?>) {
        if (rawExport is! Map<Object?, Object?> ||
            rawExport['sequence'] is! int ||
            rawExport['relativePath'] is! String ||
            rawExport['committedBytes'] is! int) {
          return _invalid();
        }
        final sequence = rawExport['sequence']! as int;
        final committedBytes = rawExport['committedBytes']! as int;
        final relativePath = switch (AppRelativePath.tryParse(
          rawExport['relativePath']! as String,
        )) {
          Ok(:final value) => value,
          Err() => null,
        };
        final source = segments
            .where((segment) => segment.sequence == sequence)
            .firstOrNull;
        if (relativePath == null ||
            source == null ||
            source.state != AudioSegmentState.committed ||
            source.relativePath != relativePath ||
            committedBytes <= 0 ||
            committedBytes != source.committedBytes ||
            (rawExportSegments.isNotEmpty &&
                sequence <= rawExportSegments.last.sequence)) {
          return _invalid();
        }
        rawExportSegments.add(
          SessionRecoveryRawExportSegment(
            sequence: sequence,
            relativePath: relativePath,
            committedBytes: committedBytes,
          ),
        );
      }
      final committedSegments = segments.where(
        (segment) =>
            segment.state == AudioSegmentState.committed &&
            segment.committedBytes > 0,
      );
      if (rawExportSegments.length != committedSegments.length) {
        return _invalid();
      }
      sessions.add(
        SessionRecoveryEvidence(
          meetingId: meetingId,
          storageKey: storageKey,
          segments: segments,
          integrityState: integrityState,
          diagnostics: diagnostics,
          rawExportSegments: rawExportSegments,
        ),
      );
    }
    return Ok(
      RecordingRecoveryInventory(
        sessions: sessions,
        deletedIncompleteDerivedFiles: deleted,
        issueCodes: rawIssues.cast<String>(),
        liveMeetingIds: rawLiveMeetingIds.cast<String>().toSet(),
        invalidStorageKeys: rawInvalidStorageKeys.cast<String>().toSet(),
      ),
    );
  }

  SessionRecoverySegmentEvidence? _parseSegment(
    Object? value,
    int sampleRateHz,
    int expectedSequence,
    String storageKey,
  ) {
    if (value is! Map<Object?, Object?> ||
        value['sequence'] is! int ||
        value['relativePath'] is! String ||
        value['startSample'] is! int ||
        value['committedSamples'] is! int ||
        value['committedBytes'] is! int ||
        value['state'] is! String) {
      return null;
    }
    final sequence = value['sequence']! as int;
    final startSample = value['startSample']! as int;
    final committedSamples = value['committedSamples']! as int;
    final committedBytes = value['committedBytes']! as int;
    final state = AudioSegmentState.values
        .where((candidate) => candidate.name == value['state'])
        .firstOrNull;
    final relativePath = switch (AppRelativePath.tryParse(
      value['relativePath']! as String,
    )) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (sequence != expectedSequence ||
        startSample < 0 ||
        committedSamples < 0 ||
        committedBytes < 0 ||
        state == null ||
        relativePath == null ||
        !relativePath.value.startsWith('recordings/$storageKey/') ||
        (state == AudioSegmentState.committed &&
            (committedSamples == 0 || committedBytes == 0))) {
      return null;
    }
    return SessionRecoverySegmentEvidence(
      sequence: sequence,
      relativePath: relativePath,
      mediaStart: Duration(
        microseconds:
            startSample * Duration.microsecondsPerSecond ~/ sampleRateHz,
      ),
      mediaDuration: Duration(
        microseconds:
            committedSamples * Duration.microsecondsPerSecond ~/ sampleRateHz,
      ),
      committedBytes: committedBytes,
      state: state,
    );
  }

  Err<RecordingRecoveryInventory, RecordingRecoveryFailure> _invalid() =>
      const Err(
        RecordingRecoveryFailure('recording_recovery_channel_invalid'),
      );

  bool _isSafeStorageKey(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      !value.contains('/') &&
      !value.contains(r'\') &&
      !value.contains('\u0000');
}
