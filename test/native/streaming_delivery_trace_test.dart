import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/native/method_channel_streaming_transcription_engine.dart';
import 'package:loquiris/native/streaming_platform_port.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

import '../support/streaming_delivery_trace.dart';
import '../support/streaming_recorder_ui_coverage.dart';

void main() {
  test(
    'real projection and controller preserve both coverage notices at STOP',
    () async {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final engine = MethodChannelStreamingTranscriptionEngine(
        port: trace.wrapPort(port),
      );
      final adapter = StreamingLiveTranscriptAdapter(engine);
      final container = ProviderContainer(
        overrides: [
          liveTranscriptSessionStarterProvider.overrideWithValue((_) async {
            final opened = await adapter.open(
              const StreamingStartRequest(
                owner: _owner,
                modelId: 'probe',
                bundleSha256:
                    '0000000000000000000000000000000000000000000000000000000000000000',
                parameterVersion: 1,
              ),
            );
            final session =
                (opened as Ok<LiveTranscriptionSession, TranscriptionFailure>)
                    .value;
            return Ok(
              LiveTranscriptionSession(
                meetingId: session.meetingId,
                runId: session.runId,
                events: session.events.map((event) {
                  trace.recordProjection(event);
                  return event;
                }),
                finish: session.finish,
                release: session.release,
              ),
            );
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        expect((await engine.dispose()).isOk, isTrue);
      });
      final provider = liveTranscriptControllerProvider(_owner.meetingId);
      final observer = container.listen(
        provider,
        (_, next) => trace.recordView(next.value),
      );
      addTearDown(observer.close);
      await container.read(provider.future);
      port
        ..receive({
          ..._header,
          'type': 'gap',
          'sequence': 0,
          'startSample': 0,
          'endSampleExclusive': 3200,
          'captureEpoch': 0,
          'reason': 'discontinuity',
        })
        ..receive({..._wireText, 'sequence': 1, 'startSample': 3200})
        ..receive({
          ..._header,
          'type': 'gap',
          'sequence': 2,
          'startSample': 16000,
          'endSampleExclusive': 19200,
          'captureEpoch': 1,
          'reason': 'pause',
        })
        ..receive({
          ..._wireText,
          'sequence': 3,
          'utteranceId': 'u2',
          'captureEpoch': 1,
          'startSample': 19200,
          'endSampleExclusive': 32000,
        });
      await pumpEventQueue();
      await container.read(provider.notifier).finish();
      await pumpEventQueue();
      final state = container.read(provider).requireValue;
      expect(state.status, LiveTranscriptStatus.stopped);
      expect(state.incomplete, isTrue);
      expect(state.chunks, hasLength(2));
      expect(trace.snapshot, containsPair('projectedGapNotices', 2));
      expect(
        recorderUiCoverageProblems(
          trace: trace.snapshot,
          firstFinalStart: const Duration(milliseconds: 200),
          pausedFinalEnd: const Duration(seconds: 1),
          resumedFinalStart: const Duration(milliseconds: 1200),
        ),
        isEmpty,
      );
    },
  );

  test(
    'gap diagnostics retain reason and media bounds without private data',
    () {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final wrapped = trace.wrapPort(port)..onEvent((_) {});
      port
        ..receive({
          ..._header,
          'type': 'gap',
          'sequence': 0,
          'startSample': 0,
          'endSampleExclusive': 3200,
          'captureEpoch': 0,
          'reason': 'discontinuity',
        })
        ..receive({
          ..._header,
          'type': 'gap',
          'sequence': 3,
          'startSample': 16000,
          'endSampleExclusive': 19200,
          'captureEpoch': 1,
          'reason': 'pause',
        })
        ..receive({
          ..._header,
          'type': 'gap',
          'sequence': 5,
          'startSample': 32000,
          'endSampleExclusive': 32000,
          'captureEpoch': 2,
          'reason': 'audioFocus',
        });
      expect(trace.snapshot['wireGapDetails'], [
        {
          'sequence': 0,
          'startUs': 0,
          'endUs': 200000,
          'captureEpoch': 0,
          'reason': 'discontinuity',
        },
        {
          'sequence': 3,
          'startUs': 1000000,
          'endUs': 1200000,
          'captureEpoch': 1,
          'reason': 'pause',
        },
        {
          'sequence': 5,
          'startUs': 2000000,
          'endUs': 2000000,
          'captureEpoch': 2,
          'reason': 'audioFocus',
        },
      ]);
      expect(trace.snapshot, containsPair('wireGapDetailsDropped', 0));
      final external =
          trace.snapshot['wireGapDetails']! as List<Map<String, Object>>;
      external.first['reason'] = '/private/path/token';
      expect(
        (trace.snapshot['wireGapDetails']! as List<Map<String, Object>>)
            .first['reason'],
        'discontinuity',
      );
      expect(jsonEncode(trace.snapshot), isNot(contains('private-owner')));
      expect(jsonEncode(trace.snapshot), isNot(contains('private-run')));
      wrapped.close();
    },
  );

  test(
    'gap diagnostics stay bounded while retaining an exact overflow count',
    () {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final wrapped = trace.wrapPort(port)..onEvent((_) {});
      for (var sequence = 0; sequence < 35; sequence++) {
        port.receive({
          ..._header,
          'type': 'gap',
          'sequence': sequence,
          'startSample': sequence * 3200,
          'endSampleExclusive': sequence * 3200 + 3200,
          'captureEpoch': sequence,
          'reason': 'pause',
        });
      }
      expect(trace.snapshot, containsPair('wireGaps', 35));
      expect(trace.snapshot['wireGapDetails'], hasLength(32));
      expect(trace.snapshot, containsPair('wireGapDetailsDropped', 3));
      wrapped.close();
    },
  );

  test('synchronous open errors are counted and rethrown unchanged', () {
    final trace = StreamingDeliveryTrace(_owner);
    final failure = StateError('/private/path/token');
    final wrapped = trace.wrapPort(_Port()..synchronousFailure = failure);
    expect(() => wrapped.request('open', _header), throwsA(same(failure)));
    expect(trace.snapshot, containsPair('openRequests', 1));
    expect(trace.snapshot, containsPair('openTransportErrors', 1));
    expect(jsonEncode(trace.snapshot), isNot(contains('/private/path')));
    wrapped.close();
  });

  test(
    'wire and projected finals are counted without altering delivered text',
    () async {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final engine = MethodChannelStreamingTranscriptionEngine(
        port: trace.wrapPort(port),
      );
      final opened = await StreamingLiveTranscriptAdapter(engine).open(
        const StreamingStartRequest(
          owner: _owner,
          modelId: 'probe',
          bundleSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
          parameterVersion: 1,
        ),
      );
      final session =
          (opened as Ok<LiveTranscriptionSession, TranscriptionFailure>).value;
      final seen = <TranscriptionEvent>[];
      final listener = session.events.listen((event) {
        trace.recordProjection(event);
        seen.add(event);
      });
      addTearDown(listener.cancel);
      port.receive(_wireText);
      await pumpEventQueue();
      expect(
        seen.whereType<TranscriptionDraftUpdated>().single.chunk.rawText,
        'private speech marker',
      );
      expect(trace.snapshot, containsPair('wireNonemptyFinals', 1));
      expect(trace.snapshot, containsPair('openRequests', 1));
      expect(trace.snapshot, containsPair('openAccepted', 1));
      expect(trace.snapshot, containsPair('projectedNonemptyFinals', 1));
      expect(
        jsonEncode(trace.snapshot),
        isNot(contains('private speech marker')),
      );
      expect(jsonEncode(trace.snapshot), isNot(contains('private-owner')));
      expect((await session.release()).isOk, isTrue);
      expect((await engine.dispose()).isOk, isTrue);
    },
  );

  test(
    'safe reports distinguish malformed input and allowlisted failure reasons',
    () {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final wrapped = trace.wrapPort(port)..onEvent((_) {});
      port
        ..receive({
          ..._header,
          'type': 'failure',
          'sequence': 0,
          'reason': 'backlog',
          'released': true,
        })
        ..receive({
          ..._header,
          'type': 'failure',
          'sequence': 1,
          'reason': '/private/path/token',
          'released': true,
        })
        ..receive({..._wireText, 'meetingId': 'foreign-private-meeting'});
      trace
        ..recordProjection(
          const TranscriptionDraftDegraded(
            runId: 'private-run',
            reason: '/private/path/token',
            backlog: Duration.zero,
            incomplete: true,
          ),
        )
        ..recordView(
          LiveTranscriptState(
            status: LiveTranscriptStatus.degraded,
            meetingId: 'private-owner',
            runId: 'private-run',
            chunks: const [
              TranscriptChunk(
                segmentId: 'secret-id',
                start: Duration.zero,
                end: Duration(seconds: 1),
                rawText: 'private speech marker',
                displayText: 'private speech marker',
                stability: TranscriptStability.stable,
              ),
            ],
            degradationReason: '/private/path/token',
          ),
        );
      expect(trace.snapshot, containsPair('wireRejected', 2));
      expect(trace.snapshot, containsPair('wireFailureReasons', ['backlog']));
      expect(
        trace.snapshot,
        containsPair('projectedFailureReasons', ['unrecognized']),
      );
      expect(trace.snapshot, containsPair('viewNonemptyFinals', 1));
      final report = jsonEncode(trace.snapshot);
      for (final sensitive in [
        'private speech',
        'private-owner',
        'private-run',
        '/private/path',
        'secret-id',
        'foreign-private',
      ]) {
        expect(report, isNot(contains(sensitive)));
      }
      wrapped.close();
    },
  );

  test(
    'transport tracing preserves the exact request future and raw event object',
    () async {
      final trace = StreamingDeliveryTrace(_owner);
      final port = _Port();
      final wrapped = trace.wrapPort(port);
      final ack = Completer<Object?>();
      port.pending = ack.future;
      expect(identical(wrapped.request('open', _header), ack.future), isTrue);
      Object? observed;
      wrapped.onEvent((raw) {
        observed = raw;
      });
      port.receive(_wireText);
      expect(identical(observed, _wireText), isTrue);
      ack.complete({..._header, 'ok': true, 'released': false});
      await ack.future;
      wrapped.close();
      expect(port.closed, isTrue);
    },
  );
}

const _owner = StreamingOwner(
  meetingId: 'private-owner',
  runId: 'private-run',
  epoch: 1,
);
const _header = <String, Object?>{
  'v': 1,
  'meetingId': 'private-owner',
  'runId': 'private-run',
  'epoch': 1,
};
const _wireText = <String, Object?>{
  ..._header,
  'type': 'text',
  'sequence': 0,
  'utteranceId': 'u1',
  'startSample': 0,
  'endSampleExclusive': 16000,
  'captureEpoch': 0,
  'rawText': 'private speech marker',
  'finalized': true,
};

final class _Port implements StreamingPlatformPort {
  void Function(Object?) receive = (_) {};
  Future<Object?>? pending;
  bool closed = false;
  StateError? synchronousFailure;
  @override
  Future<Object?> request(String method, Map<String, Object?> arguments) {
    final failure = synchronousFailure;
    if (failure != null) throw failure;
    return pending ??
        Future.value({..._header, 'ok': true, 'released': method == 'close'});
  }

  @override
  void onEvent(void Function(Object?) callback) {
    receive = callback;
  }

  @override
  void close() {
    closed = true;
  }
}
