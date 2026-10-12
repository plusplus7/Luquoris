import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/native/recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('decodes a versioned native restoration snapshot', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'snapshot');
      expect(call.arguments, <String, Object?>{'v': 1});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'snapshot': <String, Object?>{
          'sessionId': 'meeting-1',
          'state': 'recording',
          'elapsedMilliseconds': 1234,
          'bytesWritten': 5678,
          'revision': 9,
          'inputHealth': <String, Object?>{
            'readCalls': 48,
            'pcmBytes': 196608,
            'shortReads': 1,
            'zeroReads': 2,
            'errorReads': 0,
            'maximumReadGapNanos': 22000000,
            'timestampRegressions': 0,
          },
        },
      };
    });
    const gateway = MethodChannelRecordingControlGateway(channel: channel);

    final result = await gateway.current();

    final snapshot =
        (result as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
    expect(snapshot.sessionId, 'meeting-1');
    expect(snapshot.state, AudioCaptureState.recording);
    expect(snapshot.elapsed, const Duration(milliseconds: 1234));
    expect(snapshot.bytesWritten, 5678);
    expect(snapshot.revision, 9);
    expect(
      snapshot.inputHealth,
      const AudioInputHealthSnapshot(
        readCalls: 48,
        pcmBytes: 196608,
        shortReads: 1,
        zeroReads: 2,
        errorReads: 0,
        maximumReadGap: Duration(milliseconds: 22),
        timestampRegressions: 0,
      ),
    );
  });

  test('saving recovery uses a non-capture snapshot command', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'saveRecovery');
      expect(call.arguments, <String, Object?>{
        'v': 1,
        'sessionId': 'meeting-1',
      });
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'playback': <String, Object?>{
          'state': 'ready',
          'fileName': 'playback.m4a',
          'accessUnitCount': 4,
          'mediaSamples': 4096,
          'bytesWritten': 1024,
        },
        'snapshot': <String, Object?>{
          'sessionId': 'meeting-1',
          'state': 'finalized',
          'elapsedMilliseconds': 1234,
          'bytesWritten': 5678,
          'revision': 10,
        },
      };
    });
    const gateway = MethodChannelRecordingControlGateway(channel: channel);

    final result = await gateway.saveRecovery('meeting-1');

    expect(
      (result as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value.state,
      AudioCaptureState.finalized,
    );
  });

  test(
    'saving recovery reports a structured playback rebuild failure',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, Object?>{
          'v': 1,
          'ok': true,
          'playback': <String, Object?>{
            'state': 'failed',
            'code': 'recording_m4a_mux_failed',
          },
          'snapshot': <String, Object?>{
            'sessionId': 'meeting-1',
            'state': 'finalized',
            'elapsedMilliseconds': 1234,
            'bytesWritten': 5678,
            'revision': 10,
          },
        },
      );
      const gateway = MethodChannelRecordingControlGateway(channel: channel);

      final result = await gateway.saveRecovery('meeting-1');

      expect(
        result,
        isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
          (value) => value.failure.code,
          'code',
          'recording_m4a_mux_failed',
        ),
      );
    },
  );

  test('decodes structured low-storage rejection', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, RecordingControlCommand.start.name);
      return <String, Object?>{
        'v': 1,
        'ok': false,
        'failure': <String, Object?>{
          'code': 'recording_storage_preflight_insufficient',
          'availableBytes': 10,
          'requiredBytes': 20,
        },
      };
    });
    const gateway = MethodChannelRecordingControlGateway(channel: channel);

    final result = await gateway.dispatch(
      RecordingControlCommand.start,
      sessionId: 'meeting-1',
    );

    final failure = (result as Err<String, AudioCaptureFailure>).failure;
    expect(failure, isA<AudioCaptureInsufficientStorage>());
    expect(
      (failure as AudioCaptureInsufficientStorage).availableBytes,
      10,
    );
    expect(failure.requiredBytes, 20);
  });

  test('decodes unavailable storage with required-space detail', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, RecordingControlCommand.start.name);
      return <String, Object?>{
        'v': 1,
        'ok': false,
        'failure': <String, Object?>{
          'code': 'recording_storage_unavailable',
          'availableBytes': null,
          'requiredBytes': 657830912,
        },
      };
    });
    const gateway = MethodChannelRecordingControlGateway(channel: channel);

    final result = await gateway.dispatch(
      RecordingControlCommand.start,
      sessionId: 'meeting-1',
    );

    final failure = (result as Err<String, AudioCaptureFailure>).failure;
    expect(failure, isA<AudioCaptureInsufficientStorage>());
    expect(
      (failure as AudioCaptureInsufficientStorage).availableBytes,
      isNull,
    );
    expect(failure.requiredBytes, 657830912);
  });

  test('rejects an unknown snapshot state instead of guessing', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': true,
        'snapshot': <String, Object?>{
          'sessionId': 'meeting-1',
          'state': 'futureState',
          'elapsedMilliseconds': 0,
          'bytesWritten': 0,
          'revision': 1,
        },
      },
    );
    const gateway = MethodChannelRecordingControlGateway(channel: channel);

    final result = await gateway.current();

    expect(
      result,
      isA<Err<AudioCaptureSnapshot, AudioCaptureFailure>>().having(
        (value) => value.failure.code,
        'code',
        'recording_channel_invalid',
      ),
    );
  });

  test(
    'decodes a durable failed command receipt with storage quantities',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'commandStatus');
        expect(call.arguments, <String, Object?>{
          'v': 1,
          'commandId': 'command-1',
        });
        return <String, Object?>{
          'v': 1,
          'ok': true,
          'receipt': <String, Object?>{
            'state': 'failed',
            'failure': <String, Object?>{
              'code': 'recording_storage_preflight_insufficient',
              'availableBytes': 10,
              'requiredBytes': 20,
            },
          },
        };
      });
      const gateway = MethodChannelRecordingControlGateway(channel: channel);

      final result = await gateway.receipt('command-1');

      final receipt =
          (result as Ok<RecordingCommandReceipt, AudioCaptureFailure>).value
              as RecordingCommandFailed;
      expect(receipt.failure, isA<AudioCaptureInsufficientStorage>());
    },
  );
}
