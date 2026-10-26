import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_remote_transcription_service.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('remote-connection-test');
  const service = MethodChannelRemoteTranscriptionService(channel: channel);
  test(
    'connection reload exposes origin and reference without returning a token',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {
              'ok': true,
              'value': {
                'endpoint': 'http://192.168.1.20:18000',
                'credentialRef': 'opaque-reference',
              },
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final loaded = await service.loadConnection();
      expect(
        loaded,
        isA<Ok<RemoteSavedConnection?, RemoteTranscriptionFailure>>(),
      );
      final value =
          (loaded as Ok<RemoteSavedConnection?, RemoteTranscriptionFailure>)
              .value!;
      expect(value.endpoint, 'http://192.168.1.20:18000');
      expect(value.credentialRef, 'opaque-reference');
    },
  );
}
