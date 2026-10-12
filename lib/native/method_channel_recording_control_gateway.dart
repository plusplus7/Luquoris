import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Sole Dart owner of the Android recording-control wire contract.
final class MethodChannelRecordingControlGateway
    implements RecordingControlGateway {
  /// Creates the production gateway.
  const MethodChannelRecordingControlGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.loquiris/recording_control_v1';
  static const int _contractVersion = 1;

  final MethodChannel _channel;

  @override
  Future<Result<void, AudioCaptureFailure>>
  requestMicrophonePermission() async {
    final response = await _invoke('requestMicrophonePermission');
    return switch (response) {
      Ok<Map<Object?, Object?>, AudioCaptureFailure>() => const Ok(null),
      Err<Map<Object?, Object?>, AudioCaptureFailure>(:final failure) => Err(
        failure,
      ),
    };
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current() async {
    final response = await _invoke('snapshot');
    if (response case Err<Map<Object?, Object?>, AudioCaptureFailure>(
      :final failure,
    )) {
      return Err(failure);
    }
    final envelope =
        (response as Ok<Map<Object?, Object?>, AudioCaptureFailure>).value;
    return _parseSnapshot(envelope['snapshot']);
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovery(
    String sessionId,
  ) async {
    final response = await _invoke('saveRecovery', <String, Object?>{
      'sessionId': sessionId,
    });
    if (response case Err<Map<Object?, Object?>, AudioCaptureFailure>(
      :final failure,
    )) {
      return Err(failure);
    }
    final envelope =
        (response as Ok<Map<Object?, Object?>, AudioCaptureFailure>).value;
    final playback = envelope['playback'];
    if (playback is! Map<Object?, Object?>) {
      return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    switch (playback['state']) {
      case 'ready':
        if (playback['fileName'] is! String ||
            playback['accessUnitCount'] is! int ||
            playback['mediaSamples'] is! int ||
            playback['bytesWritten'] is! int) {
          return const Err(
            AudioCaptureUnavailable('recording_channel_invalid'),
          );
        }
      case 'failed':
        final code = playback['code'];
        if (code is! String || code.isEmpty) {
          return const Err(
            AudioCaptureUnavailable('recording_channel_invalid'),
          );
        }
        return Err(AudioCaptureUnavailable(code));
      default:
        return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    return _parseSnapshot(envelope['snapshot']);
  }

  Result<AudioCaptureSnapshot, AudioCaptureFailure> _parseSnapshot(
    Object? snapshotValue,
  ) {
    if (snapshotValue is! Map<Object?, Object?>) {
      return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    final stateName = snapshotValue['state'];
    final elapsed = snapshotValue['elapsedMilliseconds'];
    final bytes = snapshotValue['bytesWritten'];
    final revision = snapshotValue['revision'];
    final sessionId = snapshotValue['sessionId'];
    final inputHealthValue = snapshotValue['inputHealth'];
    final inputHealth = _parseInputHealth(inputHealthValue);
    final state = _parseState(stateName);
    if (state == null ||
        elapsed is! int ||
        elapsed < 0 ||
        bytes is! int ||
        bytes < 0 ||
        revision is! int ||
        revision < 0 ||
        (inputHealthValue != null && inputHealth == null) ||
        (sessionId != null && sessionId is! String) ||
        ((state == AudioCaptureState.idle) != (sessionId == null))) {
      return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    return Ok(
      AudioCaptureSnapshot(
        sessionId: sessionId as String?,
        state: state,
        elapsed: Duration(milliseconds: elapsed),
        bytesWritten: bytes,
        revision: revision,
        inputHealth: inputHealth,
      ),
    );
  }

  AudioInputHealthSnapshot? _parseInputHealth(Object? value) {
    if (value == null) return null;
    if (value is! Map<Object?, Object?>) return null;
    final readCalls = value['readCalls'];
    final pcmBytes = value['pcmBytes'];
    final shortReads = value['shortReads'];
    final zeroReads = value['zeroReads'];
    final errorReads = value['errorReads'];
    final maximumReadGapNanos = value['maximumReadGapNanos'];
    final timestampRegressions = value['timestampRegressions'];
    final counters = <Object?>[
      readCalls,
      pcmBytes,
      shortReads,
      zeroReads,
      errorReads,
      maximumReadGapNanos,
      timestampRegressions,
    ];
    if (counters.any((counter) => counter is! int || counter < 0)) return null;
    return AudioInputHealthSnapshot(
      readCalls: readCalls! as int,
      pcmBytes: pcmBytes! as int,
      shortReads: shortReads! as int,
      zeroReads: zeroReads! as int,
      errorReads: errorReads! as int,
      maximumReadGap: Duration(
        microseconds: (maximumReadGapNanos! as int) ~/ 1000,
      ),
      timestampRegressions: timestampRegressions! as int,
    );
  }

  @override
  Future<Result<String, AudioCaptureFailure>> dispatch(
    RecordingControlCommand command, {
    String? sessionId,
  }) async {
    final response = await _invoke(
      command.name,
      sessionId == null ? null : <String, Object?>{'sessionId': sessionId},
    );
    return switch (response) {
      Ok<Map<Object?, Object?>, AudioCaptureFailure>(:final value)
          when value['commandId'] is String =>
        Ok<String, AudioCaptureFailure>(value['commandId']! as String),
      Ok<Map<Object?, Object?>, AudioCaptureFailure>() => const Err(
        AudioCaptureUnavailable('recording_channel_invalid'),
      ),
      Err<Map<Object?, Object?>, AudioCaptureFailure>(:final failure) => Err(
        failure,
      ),
    };
  }

  @override
  Future<Result<RecordingCommandReceipt, AudioCaptureFailure>> receipt(
    String commandId,
  ) async {
    final response = await _invoke('commandStatus', <String, Object?>{
      'commandId': commandId,
    });
    if (response case Err<Map<Object?, Object?>, AudioCaptureFailure>(
      :final failure,
    )) {
      return Err(failure);
    }
    final envelope =
        (response as Ok<Map<Object?, Object?>, AudioCaptureFailure>).value;
    final value = envelope['receipt'];
    if (value is! Map<Object?, Object?> || value['state'] is! String) {
      return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    switch (value['state']) {
      case 'pending':
        return const Ok(RecordingCommandPending());
      case 'succeeded':
        final snapshot = _parseSnapshot(value['snapshot']);
        return switch (snapshot) {
          Ok<AudioCaptureSnapshot, AudioCaptureFailure>(:final value) => Ok(
            RecordingCommandSucceeded(value),
          ),
          Err<AudioCaptureSnapshot, AudioCaptureFailure>(:final failure) => Err(
            failure,
          ),
        };
      case 'failed':
        final failure = _parseFailure(value['failure']);
        return switch (failure) {
          Ok<AudioCaptureFailure, AudioCaptureFailure>(:final value) => Ok(
            RecordingCommandFailed(value),
          ),
          Err<AudioCaptureFailure, AudioCaptureFailure>(:final failure) => Err(
            failure,
          ),
        };
      default:
        return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
  }

  Future<Result<Map<Object?, Object?>, AudioCaptureFailure>> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final response = await _channel.invokeMethod<Object?>(
        method,
        <String, Object?>{
          'v': _contractVersion,
          ...?arguments,
        },
      );
      if (response is! Map<Object?, Object?> ||
          response['v'] != _contractVersion ||
          response['ok'] is! bool) {
        return const Err(
          AudioCaptureUnavailable('recording_channel_invalid'),
        );
      }
      if (response['ok'] == true) return Ok(response);
      final parsed = _parseFailure(response['failure']);
      return switch (parsed) {
        Ok<AudioCaptureFailure, AudioCaptureFailure>(:final value) => Err(
          value,
        ),
        Err<AudioCaptureFailure, AudioCaptureFailure>(:final failure) => Err(
          failure,
        ),
      };
    } on MissingPluginException {
      return const Err(
        AudioCaptureUnavailable('recording_channel_unavailable'),
      );
    } on PlatformException catch (error) {
      return Err(AudioCaptureUnavailable(error.code));
    }
  }

  Result<AudioCaptureFailure, AudioCaptureFailure> _parseFailure(
    Object? failureValue,
  ) {
    if (failureValue is! Map<Object?, Object?> ||
        failureValue['code'] is! String) {
      return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
    }
    final code = failureValue['code']! as String;
    if (code == 'recording_storage_unavailable' ||
        code == 'recording_storage_preflight_insufficient' ||
        code == 'recording_storage_critically_low') {
      final available = failureValue['availableBytes'];
      final required = failureValue['requiredBytes'];
      if ((available != null && available is! int) || required is! int) {
        return const Err(AudioCaptureUnavailable('recording_channel_invalid'));
      }
      return Ok(
        AudioCaptureInsufficientStorage(
          code: code,
          availableBytes: available as int?,
          requiredBytes: required,
        ),
      );
    }
    return Ok(AudioCaptureUnavailable(code));
  }

  AudioCaptureState? _parseState(Object? value) {
    if (value is! String) return null;
    for (final state in AudioCaptureState.values) {
      if (state.name == value) return state;
    }
    return null;
  }
}
