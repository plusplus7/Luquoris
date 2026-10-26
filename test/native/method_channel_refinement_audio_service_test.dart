import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_refinement_audio_service.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/refinement_audio');
  const service = MethodChannelRefinementAudioService(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'inspection sends complete identity and decodes content-only inventory',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'inspect');
        expect(call.arguments, {
          'v': 1,
          'meetingId': 'meeting',
          'expectedSha256': 'a' * 64,
        });
        return _ready();
      });
      final result = await service.inspect('meeting', expectedSha256: 'a' * 64);
      final inventory =
          (result as Ok<RefinementAudioInventory, RefinementAudioFailure>)
              .value;
      expect(inventory.sha256, 'a' * 64);
      expect(inventory.totalSamples, 1_024);
      expect(inventory.segmentCount, 1);
    },
  );

  test(
    'wrong owner version hash format or duration never authorizes queueing',
    () async {
      final responses = <Object?>[
        _ready()..['meetingId'] = 'another',
        _ready()..['v'] = 2,
        _ready()..['v'] = 1.0,
        _ready(
          inventory: {
            'sha256': 'a' * 64,
            'totalSamples': 1_024,
            'sampleRateHz': 16_000.0,
            'segmentCount': 1,
          },
        ),
        _ready(
          inventory: {
            'sha256': 'A' * 64,
            'totalSamples': 1_024,
            'sampleRateHz': 16_000,
            'segmentCount': 1,
          },
        ),
        _ready(
          inventory: {
            'sha256': 'a' * 64,
            'totalSamples': 0,
            'sampleRateHz': 16_000,
            'segmentCount': 1,
          },
        ),
        _ready(
          inventory: {
            'sha256': 'a' * 64,
            'totalSamples': 1_024,
            'sampleRateHz': 48_000,
            'segmentCount': 1,
          },
        ),
        _ready(
          inventory: {
            'sha256': 'a' * 64,
            'totalSamples': 1_024,
            'sampleRateHz': 16_000,
            'segmentCount': 0,
          },
        ),
        null,
      ];
      for (final response in responses) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        expect(
          await service.inspect('meeting'),
          isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
        );
      }
      messenger.setMockMethodCallHandler(channel, (_) async => _ready());
      expect(
        await service.inspect('meeting', expectedSha256: 'b' * 64),
        isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
      );
    },
  );

  test(
    'missing or malformed per-segment evidence cannot authorize a complete inventory',
    () async {
      for (final change in <Map<String, Object?>>[
        {'index': 0.0},
        {'index': 1},
        {'startSample': 1_024},
        {'committedSamples': 0},
        {'committedSamples': 1},
        {'committedSamples': 2_048},
        {'committedBytes': 0},
        {'committedBytes': 64 * 1_024 * 1_024 + 1},
        {'sha256': 'not-a-hash'},
        {'referenceSha256': null},
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => _ready(
            inventory: {
              'segments': [
                {..._wireSegment(), ...change},
              ],
            },
          ),
        );
        expect(
          await service.inspect('meeting'),
          isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
          reason: change.keys.single,
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => _ready(inventory: {'segments': <Object?>[]}),
      );
      expect(
        await service.inspect('meeting'),
        isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
      );
    },
  );

  test('recording priority remains a typed deferred result', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'v': 1,
        'ok': false,
        'meetingId': 'meeting',
        'failure': {'kind': 'deferred', 'code': 'refinement_recording_active'},
      },
    );
    final result = await service.inspect('meeting');
    expect(
      (result as Err<RefinementAudioInventory, RefinementAudioFailure>).failure,
      isA<RefinementAudioDeferred>(),
    );
  });

  test('invalid requests are rejected before any native work', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw StateError('unexpected native work'),
    );
    for (final meeting in ['', '../meeting', 'a' * 129]) {
      expect(
        await service.inspect(meeting),
        isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
      );
    }
    expect(
      await service.inspect('meeting', expectedSha256: 'bad'),
      isA<Err<RefinementAudioInventory, RefinementAudioFailure>>(),
    );
  });

  test(
    'platform details and timeout remain content-free typed failures',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'private/path/secret'),
      );
      var result = await service.inspect('meeting');
      expect(
        (result as Err<RefinementAudioInventory, RefinementAudioFailure>)
            .failure
            .code,
        'refinement_audio_unavailable',
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) => Completer<Object?>().future,
      );
      result = await const MethodChannelRefinementAudioService(
        channel: channel,
        timeout: Duration(milliseconds: 1),
      ).inspect('meeting');
      expect(
        (result as Err<RefinementAudioInventory, RefinementAudioFailure>)
            .failure
            .code,
        'refinement_audio_timeout',
      );
    },
  );
}

Map<String, Object?> _ready({Map<String, Object?>? inventory}) => {
  'v': 1,
  'ok': true,
  'meetingId': 'meeting',
  'inventory': {
    'sha256': 'a' * 64,
    'totalSamples': 1_024,
    'sampleRateHz': 16_000,
    'segmentCount': 1,
    'segments': [_wireSegment()],
    ...?inventory,
  },
};

Map<String, Object?> _wireSegment() => {
  'index': 0,
  'startSample': 0,
  'committedSamples': 1_024,
  'committedBytes': 11,
  'sha256': 'b' * 64,
  'referenceSha256': 'c' * 64,
};
