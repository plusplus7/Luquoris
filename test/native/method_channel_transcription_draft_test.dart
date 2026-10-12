import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/transcription-draft');
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

  test('startDraft sends the complete versioned live request', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startDraft');
      expect(call.arguments, <String, Object?>{
        'v': 1,
        'runId': 'draft-1',
        'meetingId': 'meeting-1',
        'modelId': 'whisper-base-q5_1',
        'languageHint': 'mixed',
        'parameterVersion': 1,
      });
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'runId': 'draft-1',
        'started': true,
      };
    });
    final engine = draftEngine(channel, rawEvents.stream);

    final result = await engine.startDraft(draftRequest());

    expect(result, isA<Ok<void, TranscriptionFailure>>());
  });

  test('stopDraft is a typed idempotent run-scoped request', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      expect(call.method, 'stopDraft');
      expect(call.arguments, <String, Object?>{'v': 1, 'runId': 'draft-1'});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'runId': 'draft-1',
        'stopped': true,
      };
    });
    final engine = draftEngine(channel, rawEvents.stream);

    expect(
      await engine.stopDraft('draft-1'),
      isA<Ok<void, TranscriptionFailure>>(),
    );
    expect(
      await engine.stopDraft('draft-1'),
      isA<Ok<void, TranscriptionFailure>>(),
    );
    expect(calls, 2);
  });

  test(
    'eventsFor decodes live draft backlog and explicit degradation',
    () async {
      final engine = draftEngine(channel, rawEvents.stream);
      final events = <TranscriptionEvent>[];
      final subscription = engine.eventsFor('draft-1').listen(events.add);
      await pumpEventQueue();

      rawEvents
        ..add(<String, Object?>{
          'v': 1,
          'runId': 'draft-1',
          'type': 'draft',
          'chunk': <String, Object?>{
            'segmentId': 'draft-0-800-0',
            'startMilliseconds': 0,
            'endMilliseconds': 800,
            'rawText': ' 原始 text ',
            'displayText': '原始 text',
            'stability': 'unstable',
          },
          'backlogMilliseconds': 120,
        })
        ..add(<String, Object?>{
          'v': 1,
          'runId': 'draft-1',
          'type': 'draftDegraded',
          'reason': 'transcription_live_thermal',
          'backlogMilliseconds': 240,
          'incomplete': true,
        });
      await pumpEventQueue();

      final draft = events.first as TranscriptionDraftUpdated;
      expect(draft.chunk.rawText, ' 原始 text ');
      expect(draft.chunk.stability, TranscriptStability.unstable);
      expect(draft.backlog, const Duration(milliseconds: 120));
      final degraded = events.last as TranscriptionDraftDegraded;
      expect(degraded.reason, 'transcription_live_thermal');
      expect(degraded.backlog, const Duration(milliseconds: 240));
      expect(degraded.incomplete, isTrue);
      await subscription.cancel();
    },
  );

  test('malformed and unsafe live events are ignored', () async {
    final engine = draftEngine(channel, rawEvents.stream);
    final events = <TranscriptionEvent>[];
    final subscription = engine.eventsFor('draft-1').listen(events.add);
    await pumpEventQueue();

    rawEvents
      ..add(<String, Object?>{
        'v': 1,
        'runId': 'draft-1',
        'type': 'draft',
        'chunk': <String, Object?>{'segmentId': 'missing-fields'},
        'backlogMilliseconds': 0,
      })
      ..add(<String, Object?>{
        'v': 1,
        'runId': 'draft-1',
        'type': 'draftDegraded',
        'reason': '/data/user/0/private',
        'backlogMilliseconds': 0,
        'incomplete': true,
      })
      ..add(<String, Object?>{
        'v': 1,
        'runId': 'draft-1',
        'type': 'progress',
        'fraction': double.nan,
        'remainingMilliseconds': null,
      });
    await pumpEventQueue();

    expect(events, isEmpty);
    await subscription.cancel();
  });

  test(
    'native and model failures remain visible as draft degradation',
    () async {
      final engine = draftEngine(channel, rawEvents.stream);
      final events = <TranscriptionEvent>[];
      final subscription = engine.eventsFor('draft-1').listen(events.add);
      await pumpEventQueue();
      for (final code in <String>[
        'transcription_model_hash_mismatch',
        'transcription_native_out_of_memory',
      ]) {
        rawEvents.add(<String, Object?>{
          'v': 1,
          'runId': 'draft-1',
          'type': 'draftDegraded',
          'reason': code,
          'backlogMilliseconds': 0,
          'incomplete': true,
        });
      }
      await pumpEventQueue();
      expect(
        events.whereType<TranscriptionDraftDegraded>().map(
          (event) => event.reason,
        ),
        <String>[
          'transcription_model_hash_mismatch',
          'transcription_native_out_of_memory',
        ],
      );
      await subscription.cancel();
    },
  );
}

MethodChannelTranscriptionEngine draftEngine(
  MethodChannel channel,
  Stream<Object?> events,
) => MethodChannelTranscriptionEngine(
  channel: channel,
  eventStream: events,
  timeout: const Duration(seconds: 8),
);

TranscriptionDraftRequest draftRequest() => const TranscriptionDraftRequest(
  runId: 'draft-1',
  meetingId: 'meeting-1',
);
