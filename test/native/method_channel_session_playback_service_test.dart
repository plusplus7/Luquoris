import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_session_playback_service.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/playback');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'load decodes validated native playback state without a private path',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'load');
        expect(call.arguments, <String, Object?>{
          'v': 1,
          'sessionId': 'meeting-1',
          'ownerId': 'detail-1',
        });
        return <String, Object?>{
          'v': 1,
          'ok': true,
          'snapshot': <String, Object?>{
            'sessionId': 'meeting-1',
            'state': 'ready',
            'positionMilliseconds': 0,
            'durationMilliseconds': 10000,
          },
        };
      });
      const service = MethodChannelSessionPlaybackService(channel: channel);

      final result = await service.load('meeting-1', ownerId: 'detail-1');

      expect(
        (result as Ok<SessionPlaybackSnapshot, SessionPlaybackFailure>).value,
        const SessionPlaybackSnapshot(
          sessionId: 'meeting-1',
          state: SessionPlaybackState.ready,
          position: Duration.zero,
          duration: Duration(seconds: 10),
        ),
      );
    },
  );

  test('load rejects a snapshot belonging to another meeting', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'snapshot': <String, Object?>{
          'sessionId': 'meeting-2',
          'state': 'ready',
          'positionMilliseconds': 0,
          'durationMilliseconds': 10000,
        },
      };
    });
    const service = MethodChannelSessionPlaybackService(channel: channel);

    final result = await service.load('meeting-1', ownerId: 'detail-1');

    expect(
      (result as Err<SessionPlaybackSnapshot, SessionPlaybackFailure>)
          .failure
          .code,
      'playback_snapshot_session_mismatch',
    );
  });
}
