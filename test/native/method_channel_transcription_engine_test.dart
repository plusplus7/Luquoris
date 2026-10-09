import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/transcription');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<Object?> rawEvents;

  setUp(() {
    rawEvents = StreamController<Object?>.broadcast(sync: true);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await rawEvents.close();
  });

  test('transcribe sends the complete versioned request contract', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'transcribe');
      expect(call.arguments, <String, Object?>{
        'v': 1,
        'runId': 'run-1',
        'meetingId': 'meeting-1',
        'segmentReferences': <String>[
          'recordings/storage-key/segment-00000.adts',
        ],
        'modelId': 'whisper-base-q5_1',
        'languageHint': 'mixed',
        'parameterVersion': 7,
      });
      return _completedResponse(runId: 'run-1');
    });
    final engine = _engine(channel, rawEvents.stream);

    final result = await engine.transcribe(_request());

    final output =
        (result as Ok<TranscriptionOutput, TranscriptionFailure>).value;
    expect(output.engineVersion, '1.9.4');
    expect(output.warningCode, 'transcription_audio_uncommitted_tail');
  });

  test('eventsFor filters other runs and decodes ordered progress', () async {
    final engine = _engine(channel, rawEvents.stream);
    final events = <TranscriptionEvent>[];
    final subscription = engine.eventsFor('run-1').listen(events.add);
    await pumpEventQueue();

    rawEvents
      ..add(_progressEvent(runId: 'run-2', fraction: 0.8))
      ..add(_progressEvent(runId: 'run-1', fraction: 0.25))
      ..add(_progressEvent(runId: 'run-1', fraction: 0.75));
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect(
      events.cast<TranscriptionProgressUpdated>().map(
        (event) => event.fraction,
      ),
      <double>[0.25, 0.75],
    );
    expect(
      (events.first as TranscriptionProgressUpdated).remaining,
      const Duration(seconds: 3),
    );
    await subscription.cancel();
  });

  test(
    'transcribe decodes stable chunks without rewriting model text',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => _completedResponse(runId: 'run-1'),
      );
      final engine = _engine(channel, rawEvents.stream);

      final result = await engine.transcribe(_request());

      final chunk = (result as Ok<TranscriptionOutput, TranscriptionFailure>)
          .value
          .chunks
          .single;
      expect(chunk.segmentId, 'segment-000000');
      expect(chunk.start, const Duration(milliseconds: 120));
      expect(chunk.end, const Duration(milliseconds: 940));
      expect(chunk.rawText, ' raw model text ');
      expect(chunk.displayText, 'raw model text');
      expect(chunk.stability, TranscriptStability.stable);
    },
  );

  test('cancel sends one typed run-scoped cancellation request', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      expect(call.method, 'cancel');
      expect(call.arguments, <String, Object?>{'v': 1, 'runId': 'run-1'});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'runId': 'run-1',
        'cancelled': true,
      };
    });
    final engine = _engine(channel, rawEvents.stream);

    final result = await engine.cancel('run-1');

    expect(result, isA<Ok<void, TranscriptionFailure>>());
    expect(calls, 1);
  });

  test('transcribe rejects malformed terminal payloads', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': true,
        'runId': 'run-1',
        'result': <String, Object?>{
          'engineVersion': '1.9.4',
          'chunks': <Object?>['not-a-chunk'],
        },
      },
    );
    final engine = _engine(channel, rawEvents.stream);

    final result = await engine.transcribe(_request());

    expect(_failureCode(result), 'transcription_channel_invalid');
  });

  test('transcribe rejects a terminal result for another run', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => _completedResponse(runId: 'run-other'),
    );
    final engine = _engine(channel, rawEvents.stream);

    final result = await engine.transcribe(_request());

    expect(_failureCode(result), 'transcription_channel_run_mismatch');
  });

  test(
    'transcribe rejects absolute or traversing segment references',
    () async {
      var invoked = false;
      messenger.setMockMethodCallHandler(channel, (_) async {
        invoked = true;
        return _completedResponse(runId: 'run-1');
      });
      final engine = _engine(channel, rawEvents.stream);
      final request = _request(
        segmentPaths: <String>['../private/segment-00000.adts'],
      );

      final result = await engine.transcribe(request);

      expect(_failureCode(result), 'transcription_request_invalid');
      expect(invoked, isFalse);
    },
  );

  test(
    'transcribe maps timeout and missing plugin to stable failures',
    () async {
      final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      var engine = _engine(
        channel,
        rawEvents.stream,
        timeout: const Duration(milliseconds: 1),
      );

      expect(
        _failureCode(await engine.transcribe(_request())),
        'transcription_channel_timeout',
      );

      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException('private plugin detail'),
      );
      engine = _engine(channel, rawEvents.stream);
      expect(
        _failureCode(await engine.transcribe(_request())),
        'transcription_channel_unavailable',
      );
    },
  );

  test('platform exception text never enters a failure code', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(
        code: 'private_absolute_path',
        message: '/data/user/0/com.loquiris/files/recordings/secret',
      ),
    );
    final engine = _engine(channel, rawEvents.stream);

    final result = await engine.transcribe(_request());

    expect(_failureCode(result), 'transcription_channel_unavailable');
    expect(
      _failureCode(result),
      isNot(contains('/data/user/0')),
    );
  });
}

MethodChannelTranscriptionEngine _engine(
  MethodChannel channel,
  Stream<Object?> events, {
  Duration timeout = const Duration(seconds: 8),
}) => MethodChannelTranscriptionEngine(
  channel: channel,
  eventStream: events,
  timeout: timeout,
);

TranscriptionRequest _request({List<String>? segmentPaths}) =>
    TranscriptionRequest(
      runId: 'run-1',
      audio: AudioInput(
        sessionId: 'meeting-1',
        segmentPaths:
            segmentPaths ??
            <String>['recordings/storage-key/segment-00000.adts'],
      ),
      parameterVersion: 7,
    );

Map<String, Object?> _completedResponse({required String runId}) =>
    <String, Object?>{
      'v': 1,
      'ok': true,
      'runId': runId,
      'result': <String, Object?>{
        'engineVersion': '1.9.4',
        'warningCode': 'transcription_audio_uncommitted_tail',
        'chunks': <Object?>[
          <String, Object?>{
            'segmentId': 'segment-000000',
            'startMilliseconds': 120,
            'endMilliseconds': 940,
            'rawText': ' raw model text ',
            'displayText': 'raw model text',
            'stability': 'stable',
          },
        ],
      },
    };

Map<String, Object?> _progressEvent({
  required String runId,
  required double fraction,
}) => <String, Object?>{
  'v': 1,
  'runId': runId,
  'type': 'progress',
  'fraction': fraction,
  'remainingMilliseconds': 3000,
};

String _failureCode(
  Result<TranscriptionOutput, TranscriptionFailure> result,
) => (result as Err<TranscriptionOutput, TranscriptionFailure>).failure.code;
