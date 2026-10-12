import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/native/recording_recovery_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/recovery');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('decodes manifest-derived recovery inventory', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recoveryInventory');
      expect(call.arguments, <String, Object?>{'v': 1});
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'recovery': <String, Object?>{
          'deletedIncompleteDerivedFiles': 2,
          'issueCodes': <String>[],
          'liveMeetingIds': <String>['meeting-live'],
          'invalidStorageKeys': <String>['corrupt-key'],
          'sessions': <Object?>[
            <String, Object?>{
              'meetingId': 'meeting-1',
              'storageKey': 'hash',
              'sampleRateHz': 16000,
              'integrityState': 'partial',
              'diagnostics': <Object?>[
                <String, Object?>{
                  'code': 'recording_recovery_timeline_gap',
                  'segmentSequence': 0,
                },
              ],
              'rawExportSegments': <Object?>[
                <String, Object?>{
                  'sequence': 0,
                  'relativePath': 'recordings/hash/segment-00000.adts',
                  'committedBytes': 128,
                },
              ],
              'segments': <Object?>[
                <String, Object?>{
                  'sequence': 0,
                  'relativePath': 'recordings/hash/segment-00000.adts',
                  'startSample': 16000,
                  'committedSamples': 32000,
                  'committedBytes': 128,
                  'state': 'committed',
                },
              ],
            },
          ],
        },
      };
    });
    const gateway = MethodChannelRecordingRecoveryGateway(channel: channel);

    final result = await gateway.scan();

    final inventory =
        (result as Ok<RecordingRecoveryInventory, RecordingRecoveryFailure>)
            .value;
    expect(inventory.deletedIncompleteDerivedFiles, 2);
    expect(inventory.liveMeetingIds, {'meeting-live'});
    expect(inventory.invalidStorageKeys, {'corrupt-key'});
    final segment = inventory.sessions.single.segments.single;
    expect(segment.mediaStart, const Duration(seconds: 1));
    expect(segment.mediaDuration, const Duration(seconds: 2));
    expect(segment.committedBytes, 128);
    expect(segment.state, AudioSegmentState.committed);
    final session = inventory.sessions.single;
    expect(session.integrityState, RecoveryIntegrityState.partial);
    expect(session.diagnostics.single.code, 'recording_recovery_timeline_gap');
    expect(session.diagnostics.single.segmentSequence, 0);
    expect(session.rawExportSegments.single.committedBytes, 128);
  });

  test('rejects a native path that escapes private storage', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': true,
        'recovery': <String, Object?>{
          'deletedIncompleteDerivedFiles': 0,
          'issueCodes': <String>[],
          'liveMeetingIds': <String>[],
          'invalidStorageKeys': <String>[],
          'sessions': <Object?>[
            <String, Object?>{
              'meetingId': 'meeting-1',
              'storageKey': 'hash',
              'sampleRateHz': 16000,
              'integrityState': 'partial',
              'diagnostics': <Object?>[],
              'rawExportSegments': <Object?>[],
              'segments': <Object?>[
                <String, Object?>{
                  'sequence': 0,
                  'relativePath': '../escape.adts',
                  'startSample': 0,
                  'committedSamples': 1024,
                  'committedBytes': 12,
                  'state': 'committed',
                },
              ],
            },
          ],
        },
      },
    );
    const gateway = MethodChannelRecordingRecoveryGateway(channel: channel);

    final result = await gateway.scan();

    expect(
      result,
      isA<Err<RecordingRecoveryInventory, RecordingRecoveryFailure>>().having(
        (value) => value.failure.code,
        'code',
        'recording_recovery_channel_invalid',
      ),
    );
  });

  test('returns a typed timeout when the native scan never responds', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => Completer<Object?>().future,
    );
    const gateway = MethodChannelRecordingRecoveryGateway(
      channel: channel,
      timeout: Duration(milliseconds: 10),
    );

    final result = await gateway.scan();

    expect(
      result,
      isA<Err<RecordingRecoveryInventory, RecordingRecoveryFailure>>().having(
        (value) => value.failure.code,
        'code',
        'recording_recovery_channel_timeout',
      ),
    );
  });
}
