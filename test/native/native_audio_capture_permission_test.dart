import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/native_audio_capture_service.dart';
import 'package:loquiris/native/recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  test('denied microphone permission prevents native start dispatch', () async {
    final gateway = _PermissionAwareRecordingControlGateway(
      permissionResult: const Err(
        AudioCaptureUnavailable('recording_permission_denied'),
      ),
    );
    final service = NativeAudioCaptureService(
      gateway,
      commandPollInterval: Duration.zero,
    );

    final result = await service.start(
      const AudioCaptureRequest(sessionId: 'meeting-1'),
    );

    expect(
      result,
      isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
        (value) => value.failure.code,
        'code',
        'recording_permission_denied',
      ),
    );
    expect(gateway.permissionRequests, 1);
    expect(gateway.dispatchCalls, 0);
  });

  test('granted microphone permission continues to native start', () async {
    final gateway = _PermissionAwareRecordingControlGateway(
      permissionResult: const Ok(null),
    );
    final service = NativeAudioCaptureService(
      gateway,
      commandPollInterval: Duration.zero,
    );

    final result = await service.start(
      const AudioCaptureRequest(sessionId: 'meeting-1'),
    );

    expect(result, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
    expect(gateway.permissionRequests, 1);
    expect(gateway.dispatchCalls, 1);
  });
}

final class _PermissionAwareRecordingControlGateway
    implements RecordingControlGateway {
  _PermissionAwareRecordingControlGateway({required this.permissionResult});

  final Result<void, AudioCaptureFailure> permissionResult;
  int permissionRequests = 0;
  int dispatchCalls = 0;

  @override
  Future<Result<void, AudioCaptureFailure>>
  requestMicrophonePermission() async {
    permissionRequests += 1;
    return permissionResult;
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current() async =>
      const Ok(
        AudioCaptureSnapshot(
          state: AudioCaptureState.idle,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );

  @override
  Future<Result<String, AudioCaptureFailure>> dispatch(
    RecordingControlCommand command, {
    String? sessionId,
  }) async {
    dispatchCalls += 1;
    return const Ok('command-1');
  }

  @override
  Future<Result<RecordingCommandReceipt, AudioCaptureFailure>> receipt(
    String commandId,
  ) async => const Ok(
    RecordingCommandSucceeded(
      AudioCaptureSnapshot(
        sessionId: 'meeting-1',
        state: AudioCaptureState.recording,
        elapsed: Duration.zero,
        bytesWritten: 0,
      ),
    ),
  );

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovery(
    String sessionId,
  ) async => const Err(AudioCaptureUnavailable('not-configured'));
}
