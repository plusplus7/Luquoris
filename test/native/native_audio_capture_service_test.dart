import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/native/recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  const active = AudioCaptureSnapshot(
    sessionId: 'meeting-1',
    state: AudioCaptureState.recording,
    elapsed: Duration(seconds: 9),
    bytesWritten: 72,
    revision: 4,
  );

  test('current restores the authoritative native snapshot', () async {
    final gateway = _FakeRecordingControlGateway()..snapshot = const Ok(active);
    final service = NativeAudioCaptureService(gateway);

    final result = await service.current();

    expect(
      result,
      isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
        (value) => value.value,
        'snapshot',
        same(active),
      ),
    );
  });

  test(
    'start waits until native persistence reports the requested meeting',
    () async {
      late final _FakeRecordingControlGateway gateway;
      gateway = _FakeRecordingControlGateway()
        ..onDispatch = (command, sessionId) {
          expect(command, RecordingControlCommand.start);
          expect(sessionId, 'meeting-1');
          gateway.receiptResult = const Ok(RecordingCommandSucceeded(active));
        };
      final service = NativeAudioCaptureService(
        gateway,
        commandTimeout: const Duration(milliseconds: 100),
        commandPollInterval: Duration.zero,
      );

      final result = await service.start(
        const AudioCaptureRequest(sessionId: 'meeting-1'),
      );

      expect(
        result,
        isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
          (value) => value.value,
          'snapshot',
          same(active),
        ),
      );
    },
  );

  test('explicit continuation waits for a recording receipt', () async {
    late final _FakeRecordingControlGateway gateway;
    gateway = _FakeRecordingControlGateway()
      ..onDispatch = (command, sessionId) {
        expect(command, RecordingControlCommand.continueRecovery);
        expect(sessionId, 'meeting-1');
        gateway.receiptResult = const Ok(RecordingCommandSucceeded(active));
      };
    final service = NativeAudioCaptureService(
      gateway,
      commandTimeout: const Duration(milliseconds: 100),
      commandPollInterval: Duration.zero,
    );

    final result = await service.continueRecovered('meeting-1');

    expect(result, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
  });

  test('saving recovery never dispatches a microphone command', () async {
    const finalized = AudioCaptureSnapshot(
      sessionId: 'meeting-1',
      state: AudioCaptureState.finalized,
      elapsed: Duration(seconds: 9),
      bytesWritten: 72,
      revision: 5,
    );
    final gateway = _FakeRecordingControlGateway()
      ..saveRecoveryResult = const Ok(finalized);
    final service = NativeAudioCaptureService(gateway);

    final result = await service.saveRecovered('meeting-1');

    expect(result, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
    expect(gateway.dispatchCalls, 0);
  });

  test('typed dispatch failure is returned without polling', () async {
    const failure = AudioCaptureInsufficientStorage(
      code: 'recording_storage_preflight_insufficient',
      availableBytes: 10,
      requiredBytes: 20,
    );
    final gateway = _FakeRecordingControlGateway()
      ..dispatchResult = const Err(failure);
    final service = NativeAudioCaptureService(gateway);

    final result = await service.start(
      const AudioCaptureRequest(sessionId: 'meeting-1'),
    );

    expect(
      result,
      isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
        (value) => value.failure,
        'failure',
        same(failure),
      ),
    );
    expect(gateway.snapshotCalls, 0);
  });

  test(
    'accepted command that never persists becomes a typed timeout',
    () async {
      final gateway = _FakeRecordingControlGateway()
        ..snapshot = const Ok(
          AudioCaptureSnapshot(
            state: AudioCaptureState.idle,
            elapsed: Duration.zero,
            bytesWritten: 0,
          ),
        );
      final service = NativeAudioCaptureService(
        gateway,
        commandTimeout: Duration.zero,
        commandPollInterval: Duration.zero,
      );

      final result = await service.pause();

      expect(
        result,
        isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
          (value) => value.failure.code,
          'code',
          'recording_command_timeout',
        ),
      );
    },
  );

  test('snapshot stream emits an immediate restored value', () async {
    final gateway = _FakeRecordingControlGateway()..snapshot = const Ok(active);
    final service = NativeAudioCaptureService(
      gateway,
      snapshotPollInterval: const Duration(hours: 1),
    );

    await expectLater(service.snapshots, emits(active));
  });
}

final class _FakeRecordingControlGateway implements RecordingControlGateway {
  Result<AudioCaptureSnapshot, AudioCaptureFailure> snapshot = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.idle,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<String, AudioCaptureFailure> dispatchResult =
      const Ok<String, AudioCaptureFailure>('command-1');
  Result<RecordingCommandReceipt, AudioCaptureFailure> receiptResult = const Ok(
    RecordingCommandPending(),
  );
  void Function(RecordingControlCommand command, String? sessionId)? onDispatch;
  int snapshotCalls = 0;
  int dispatchCalls = 0;
  Result<AudioCaptureSnapshot, AudioCaptureFailure> saveRecoveryResult =
      const Err(AudioCaptureUnavailable('not-configured'));

  @override
  Future<Result<void, AudioCaptureFailure>>
  requestMicrophonePermission() async => const Ok(null);

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current() async {
    snapshotCalls += 1;
    return snapshot;
  }

  @override
  Future<Result<String, AudioCaptureFailure>> dispatch(
    RecordingControlCommand command, {
    String? sessionId,
  }) async {
    dispatchCalls += 1;
    onDispatch?.call(command, sessionId);
    return dispatchResult;
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovery(
    String sessionId,
  ) async => saveRecoveryResult;

  @override
  Future<Result<RecordingCommandReceipt, AudioCaptureFailure>> receipt(
    String commandId,
  ) async => receiptResult;
}
