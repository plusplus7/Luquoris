import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_remote_transcription_service.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('remote-test');
  const service = MethodChannelRemoteTranscriptionService(channel: channel);
  test('platform preparation and wake carry no audio or token', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'ok': true};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      await service.prepareDatabase(),
      isA<Ok<void, RemoteTranscriptionFailure>>(),
    );
    expect(
      await service.resume('/private/loquiris.sqlite'),
      isA<Ok<void, RemoteTranscriptionFailure>>(),
    );
    expect(await service.wake(), isA<Ok<void, RemoteTranscriptionFailure>>());
    expect(calls.map((c) => c.method), ['prepare', 'resume', 'wake']);
    expect(calls.first.arguments, isNull);
  });
  test('missing platform becomes typed unavailability', () async {
    expect(await service.wake(), isA<Err<void, RemoteTranscriptionFailure>>());
  });
}
