import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Live capture service that confirms commands against persisted native state.
final class NativeAudioCaptureService implements AudioCaptureService {
  /// Creates the service over a quarantined native gateway.
  NativeAudioCaptureService(
    this._gateway, {
    this.snapshotPollInterval = const Duration(seconds: 1),
    this.commandPollInterval = const Duration(milliseconds: 50),
    this.commandTimeout = const Duration(seconds: 5),
  }) {
    _snapshots = StreamController<AudioCaptureSnapshot>.broadcast(
      onListen: _startSnapshotPolling,
      onCancel: _stopSnapshotPolling,
      sync: true,
    );
  }

  final RecordingControlGateway _gateway;

  /// Poll frequency while at least one Flutter observer is attached.
  final Duration snapshotPollInterval;

  /// Poll frequency used to confirm an accepted native command.
  final Duration commandPollInterval;

  /// Maximum wait for an accepted command to become durable.
  final Duration commandTimeout;

  late final StreamController<AudioCaptureSnapshot> _snapshots;
  Timer? _snapshotTimer;
  bool _snapshotReadInFlight = false;
  int? _lastPublishedRevision;

  @override
  Stream<AudioCaptureSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current() =>
      _gateway.current();

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  ) async {
    final permission = await _gateway.requestMicrophonePermission();
    if (permission case Err<void, AudioCaptureFailure>(:final failure)) {
      return Err(failure);
    }
    final accepted = await _gateway.dispatch(
      RecordingControlCommand.start,
      sessionId: request.sessionId,
    );
    return _confirm(
      accepted,
      (snapshot) =>
          snapshot.sessionId == request.sessionId &&
          snapshot.state == AudioCaptureState.recording,
    );
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovered(
    String sessionId,
  ) => _gateway.saveRecovery(sessionId);

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> continueRecovered(
    String sessionId,
  ) async {
    final accepted = await _gateway.dispatch(
      RecordingControlCommand.continueRecovery,
      sessionId: sessionId,
    );
    return _confirm(
      accepted,
      (snapshot) =>
          snapshot.sessionId == sessionId &&
          snapshot.state == AudioCaptureState.recording,
    );
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> pause() async {
    final accepted = await _gateway.dispatch(RecordingControlCommand.pause);
    return _confirm(
      accepted,
      (snapshot) => snapshot.state == AudioCaptureState.pausedByUser,
    );
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> resume() async {
    final accepted = await _gateway.dispatch(RecordingControlCommand.resume);
    return _confirm(
      accepted,
      (snapshot) => snapshot.state == AudioCaptureState.recording,
    );
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> stop() async {
    final accepted = await _gateway.dispatch(RecordingControlCommand.stop);
    return _confirm(
      accepted,
      (snapshot) => snapshot.state == AudioCaptureState.finalized,
    );
  }

  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> _confirm(
    Result<String, AudioCaptureFailure> accepted,
    bool Function(AudioCaptureSnapshot snapshot) completed,
  ) async {
    if (accepted case Err<String, AudioCaptureFailure>(:final failure)) {
      return Err(failure);
    }
    final commandId = (accepted as Ok<String, AudioCaptureFailure>).value;

    final stopwatch = Stopwatch()..start();
    while (true) {
      final remaining = commandTimeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        return const Err(AudioCaptureUnavailable('recording_command_timeout'));
      }
      Result<RecordingCommandReceipt, AudioCaptureFailure> observed;
      try {
        observed = await _gateway.receipt(commandId).timeout(remaining);
      } on TimeoutException {
        return const Err(AudioCaptureUnavailable('recording_command_timeout'));
      }
      switch (observed) {
        case Ok<RecordingCommandReceipt, AudioCaptureFailure>(
          value: RecordingCommandSucceeded(:final snapshot),
        ):
          if (completed(snapshot)) return Ok(snapshot);
          return const Err(
            AudioCaptureUnavailable('recording_command_invalid_outcome'),
          );
        case Ok<RecordingCommandReceipt, AudioCaptureFailure>(
          value: RecordingCommandFailed(:final failure),
        ):
          return Err(failure);
        case Ok<RecordingCommandReceipt, AudioCaptureFailure>(
          value: RecordingCommandPending(),
        ):
          break;
        case Err<RecordingCommandReceipt, AudioCaptureFailure>(:final failure):
          return Err(failure);
      }
      await Future<void>.delayed(commandPollInterval);
    }
  }

  void _startSnapshotPolling() {
    unawaited(_publishCurrentSnapshot());
    _snapshotTimer ??= Timer.periodic(
      snapshotPollInterval,
      (_) => unawaited(_publishCurrentSnapshot()),
    );
  }

  void _stopSnapshotPolling() {
    if (_snapshots.hasListener) return;
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  Future<void> _publishCurrentSnapshot() async {
    if (_snapshotReadInFlight) return;
    _snapshotReadInFlight = true;
    try {
      final result = await _gateway.current();
      if (result case Ok<AudioCaptureSnapshot, AudioCaptureFailure>(
        :final value,
      )) {
        if (_lastPublishedRevision == value.revision) return;
        _lastPublishedRevision = value.revision;
        if (!_snapshots.isClosed) _snapshots.add(value);
      }
    } finally {
      _snapshotReadInFlight = false;
    }
  }
}
