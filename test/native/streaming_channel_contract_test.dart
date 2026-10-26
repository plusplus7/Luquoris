import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/native/streaming_channel_contract.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  const owner = StreamingOwner(meetingId: 'meeting', runId: 'live', epoch: 7);
  final header = <String, Object?>{
    'v': 1,
    'meetingId': 'meeting',
    'runId': 'live',
    'epoch': 7,
  };
  final request = StreamingStartRequest(
    owner: owner,
    modelId: 'debug-zipformer',
    bundleSha256: 'a' * 64,
    parameterVersion: 1,
  );
  final text = <String, Object?>{
    ...header,
    'type': 'text',
    'sequence': 0,
    'utteranceId': 'utterance-1',
    'startSample': 3200,
    'endSampleExclusive': 6400,
    'captureEpoch': 2,
    'rawText': '  中文 API\n',
    'finalized': false,
  };

  test(
    'encodes exact owner and pinned model without arbitrary paths or PCM',
    () {
      expect(StreamingChannelContract.validRequest(request), isTrue);
      expect(StreamingChannelContract.encodeStart(request), {
        ...header,
        'modelId': 'debug-zipformer',
        'bundleSha256': 'a' * 64,
        'parameterVersion': 1,
      });
      expect(
        StreamingChannelContract.encodeClose(
          owner,
          StreamingCloseReason.stopped,
        ),
        {...header, 'reason': 'stopped'},
      );
      expect(
        StreamingChannelContract.encodeClose(
          owner,
          StreamingCloseReason.cancelled,
        ),
        {...header, 'reason': 'cancelled'},
      );
      expect(
        StreamingChannelContract.validRequest(
          StreamingStartRequest(
            owner: owner,
            modelId: '../weights',
            bundleSha256: 'a' * 64,
            parameterVersion: 1,
          ),
        ),
        isFalse,
      );
      expect(
        StreamingChannelContract.validRequest(
          StreamingStartRequest(
            owner: owner,
            modelId: 'model',
            bundleSha256: 'A' * 64,
            parameterVersion: 1,
          ),
        ),
        isFalse,
      );
      expect(
        StreamingChannelContract.validRequest(
          StreamingStartRequest(
            owner: owner,
            modelId: 'model',
            bundleSha256: 'a' * 64,
            parameterVersion: 2,
          ),
        ),
        isFalse,
      );
    },
  );

  test('retains exact raw text and maps samples to capture durations', () {
    expect(
      StreamingChannelContract.decodeEvent(text, owner),
      StreamingUtterance(
        owner: owner,
        sequence: 0,
        utteranceId: 'utterance-1',
        start: const Duration(milliseconds: 200),
        end: const Duration(milliseconds: 400),
        captureEpoch: 2,
        rawText: '  中文 API\n',
        status: StreamingUtteranceStatus.provisional,
      ),
    );
    expect(
      StreamingChannelContract.decodeEvent({
        ...text,
        'startSample': 1,
        'endSampleExclusive': 3,
        'finalized': true,
      }, owner),
      StreamingUtterance(
        owner: owner,
        sequence: 0,
        utteranceId: 'utterance-1',
        start: const Duration(microseconds: 62),
        end: const Duration(microseconds: 187),
        captureEpoch: 2,
        rawText: '  中文 API\n',
        status: StreamingUtteranceStatus.finalized,
      ),
    );
  });

  test(
    'gap never becomes speech and terminal failure requires release proof',
    () {
      expect(
        StreamingChannelContract.decodeEvent({
          ...header,
          'type': 'gap',
          'sequence': 1,
          'startSample': 6400,
          'endSampleExclusive': 6400,
          'captureEpoch': 3,
          'reason': 'pause',
        }, owner),
        const StreamingGap(
          owner: owner,
          sequence: 1,
          start: Duration(milliseconds: 400),
          end: Duration(milliseconds: 400),
          captureEpoch: 3,
          reason: StreamingGapReason.pause,
        ),
      );
      final failed = {
        ...header,
        'type': 'failure',
        'sequence': 2,
        'reason': 'memory',
        'released': true,
      };
      expect(
        StreamingChannelContract.decodeEvent(failed, owner),
        isA<StreamingFailed>()
            .having((event) => event.sequence, 'sequence', 2)
            .having(
              (event) => event.failure.code,
              'failure',
              'streaming_memory',
            ),
      );
      expect(
        StreamingChannelContract.decodeEvent({
          ...failed,
          'released': false,
        }, owner),
        isNull,
      );
      expect(
        StreamingChannelContract.decodeEvent({
          ...failed,
          'reason': 'native/path/leak',
        }, owner),
        isNull,
      );
    },
  );

  test('rejects foreign owner, malformed values and unowned fields', () {
    for (final patch in <Map<String, Object?>>[
      {'v': 2},
      {'meetingId': 'other'},
      {'runId': 'old'},
      {'epoch': 6},
      {'sequence': -1},
      {'sequence': 0x7fffffffffffffff},
      {'sequence': 0x7fffffffffffffff - 1},
      {'sequence': 1.0},
      {'captureEpoch': -1},
      {'startSample': -1},
      {'startSample': 6401},
      {'endSampleExclusive': 3200},
      {'endSampleExclusive': 0x7fffffffffffffff},
      {'finalized': 'true'},
      {'rawText': 1},
      {'rawText': 'x' * 16001},
      {'utteranceId': ''},
      {'path': '/secret'},
    ]) {
      expect(
        StreamingChannelContract.decodeEvent({...text, ...patch}, owner),
        isNull,
        reason: '$patch',
      );
    }
  });

  test('acknowledgement validates release rather than trusting an ok bit', () {
    final reply = {...header, 'ok': true, 'released': false};
    expect(StreamingChannelContract.isEnvelope(reply, owner), isTrue);
    for (final patch in <Map<String, Object?>>[
      {'epoch': 8},
      {'v': 2},
      {'released': 'true'},
      {'path': '/private'},
      {'ok': 1},
    ]) {
      expect(
        StreamingChannelContract.isEnvelope({...reply, ...patch}, owner),
        isFalse,
      );
    }
    expect(
      StreamingChannelContract.isEnvelope({...header, 'ok': true}, owner),
      isFalse,
    );
  });
}
