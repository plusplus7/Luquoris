import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/native/method_channel_refinement_execution_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/refinement_execution');
  const service = MethodChannelRefinementExecutionService(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'full frozen profile crosses the seam and raw original language is unchanged',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'transcribe');
        final wire = call.arguments as Map<Object?, Object?>;
        expect(
          wire['manifest'],
          jsonDecode(_input().profile.bundleManifestJson),
        );
        expect(wire['parameters'], {
          'executionMode': 'postSession',
          'requestedTiming': 'live',
          'languageHint': 'mixed',
          'parameterVersion': 1,
        });
        expect(wire['audioInventorySha256'], 'a' * 64);
        expect(wire['meetingId'], 'meeting');
        expect(wire['runId'], 'run');
        return _ready();
      });
      final result = await service.transcribe(_input());
      final output =
          (result as Ok<TranscriptionOutput, RefinementExecutionFailure>).value;
      expect(output.engineVersion, '1.9.4');
      expect(output.chunks.single.rawText, ' 原文 API ');
      expect(output.chunks.single.displayText, ' 原文 API ');
      expect(output.chunks.single.stability, TranscriptStability.stable);
    },
  );

  test(
    'wrong ownership, timing, runtime, overlap and rewritten text never become a version',
    () async {
      for (final response in <Object?>[
        null,
        _ready()..['v'] = 1.0,
        _ready()..['meetingId'] = 'wrong',
        _ready()..['runId'] = 'old',
        _ready()..['engineVersion'] = 'other',
        _ready(segments: [_segment()..['endMs'] = 65]),
        _ready(segments: [_segment()..['startMs'] = -1]),
        _ready(segments: [_segment()..['startMs'] = 64]),
        _ready(segments: [_segment()..['endMs'] = 64.0]),
        _ready(segments: [_segment()..['endMs'] = 0x7fffffffffffffff]),
        _ready(segments: [_segment()..['displayText'] = 'translated']),
        _ready(segments: [_segment(), _segment()]),
        _ready(segments: [_segment(), _segment()..['id'] = 'other']),
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        expect(
          await service.transcribe(_input()),
          isA<Err<TranscriptionOutput, RefinementExecutionFailure>>(),
        );
      }
    },
  );

  test(
    'defer and cancellation stay actionable and native details stay private',
    () async {
      for (final (kind, matcher) in [
        ('deferred', isA<RefinementExecutionDeferred>()),
        ('cancelled', isA<RefinementExecutionCancelled>()),
        ('unavailable', isA<RefinementExecutionUnavailable>()),
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => _failure(kind),
        );
        final result = await service.transcribe(_input());
        expect(
          (result as Err<TranscriptionOutput, RefinementExecutionFailure>)
              .failure,
          matcher,
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => _failure('unavailable', code: '/private SECRET'),
      );
      final invalid = await service.transcribe(_input());
      expect(
        (invalid as Err<TranscriptionOutput, RefinementExecutionFailure>)
            .failure
            .code,
        'refinement_execution_channel_invalid',
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async =>
            throw PlatformException(code: 'SECRET', message: '/private/audio'),
      );
      final exception = await service.transcribe(_input());
      expect(
        (exception as Err<TranscriptionOutput, RefinementExecutionFailure>)
            .failure
            .code,
        'refinement_cleanup_unconfirmed',
      );
    },
  );

  test(
    'timeout requests owner-scoped native cancellation without claiming release',
    () async {
      final calls = <String>[];
      final nativeDone = Completer<Object?>();
      final cancellationRequested = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'transcribe') return nativeDone.future;
        expect(call.arguments, {
          'v': 1,
          'meetingId': 'meeting',
          'runId': 'run',
        });
        cancellationRequested.complete();
        return {'v': 1, 'ok': true, 'meetingId': 'meeting', 'runId': 'run'};
      });
      const short = MethodChannelRefinementExecutionService(
        channel: channel,
        timeout: Duration(milliseconds: 1),
      );
      final operation = short.transcribe(_input());
      var settled = false;
      unawaited(
        operation.then((_) {
          settled = true;
        }),
      );
      await cancellationRequested.future;
      await Future<void>.delayed(Duration.zero);
      try {
        expect(
          settled,
          isFalse,
          reason: 'cancel acknowledgement does not release native resources',
        );
      } finally {
        nativeDone.complete(_failure('cancelled'));
      }
      final result = await operation;
      expect(calls, ['transcribe', 'cancel']);
      expect(
        (result as Err<TranscriptionOutput, RefinementExecutionFailure>)
            .failure
            .code,
        'refinement_execution_timeout',
      );
    },
  );

  test(
    'cancel checks echoed owner and malformed local input causes no native work',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return {'v': 1, 'ok': true, 'meetingId': 'meeting', 'runId': 'wrong'};
      });
      expect(
        await service.cancel(meetingId: 'meeting', runId: 'run'),
        isA<Err<void, RefinementExecutionFailure>>(),
      );
      expect(
        await service.transcribe(_input(hash: 'bad')),
        isA<Err<TranscriptionOutput, RefinementExecutionFailure>>(),
      );
      expect(calls, 1);
    },
  );

  test(
    'unrepresentable audio duration is rejected before platform work',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return _ready();
      });
      final normal = _input();
      final input = RefinementExecutionInput(
        meetingId: normal.meetingId,
        runId: normal.runId,
        audioInventorySha256: normal.audioInventorySha256,
        totalSamples: 0x7ffffffffffffc00,
        profile: normal.profile,
      );
      expect(
        await service.transcribe(input),
        isA<Err<TranscriptionOutput, RefinementExecutionFailure>>(),
      );
      expect(calls, 0);
    },
  );
}

RefinementExecutionInput _input({String? hash}) => RefinementExecutionInput(
  meetingId: 'meeting',
  runId: 'run',
  audioInventorySha256: hash ?? 'a' * 64,
  totalSamples: 1024,
  profile:
      (ProcessingModelProfile.tryCreate(
                bundleManifestJson: File(
                  'models/manifests/whisper-base-q5_1.json',
                ).readAsStringSync(),
                engineVersion: '1.9.4',
                parametersJson:
                    '{"executionMode":"postSession","requestedTiming":"live","languageHint":"mixed","parameterVersion":1}',
              )
              as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
          .value,
);
Map<String, Object?> _segment() => {
  'id': 'segment',
  'startMs': 0,
  'endMs': 64,
  'rawText': ' 原文 API ',
  'displayText': ' 原文 API ',
};
Map<String, Object?> _ready({List<Object?>? segments}) => {
  'v': 1,
  'ok': true,
  'meetingId': 'meeting',
  'runId': 'run',
  'engineVersion': '1.9.4',
  'segments': segments ?? [_segment()],
};
Map<String, Object?> _failure(
  String kind, {
  String code = 'refinement_recording_active',
}) => {
  'v': 1,
  'ok': false,
  'meetingId': 'meeting',
  'runId': 'run',
  'failure': {'kind': kind, 'code': code},
};
