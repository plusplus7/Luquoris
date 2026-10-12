import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/recording-permission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'requests microphone permission through the versioned channel',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'requestMicrophonePermission');
        expect(call.arguments, <String, Object?>{'v': 1});
        return <String, Object?>{'v': 1, 'ok': true};
      });
      const gateway = MethodChannelRecordingControlGateway(channel: channel);

      final result = await gateway.requestMicrophonePermission();

      expect(result, isA<Ok<void, AudioCaptureFailure>>());
    },
  );

  test(
    'returns a typed failure when microphone permission is denied',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, Object?>{
          'v': 1,
          'ok': false,
          'failure': <String, Object?>{
            'code': 'recording_permission_denied',
            'availableBytes': null,
            'requiredBytes': null,
          },
        },
      );
      const gateway = MethodChannelRecordingControlGateway(channel: channel);

      final result = await gateway.requestMicrophonePermission();

      expect(
        result,
        isA<Err<void, AudioCaptureFailure>>().having(
          (value) => value.failure.code,
          'code',
          'recording_permission_denied',
        ),
      );
    },
  );
}
