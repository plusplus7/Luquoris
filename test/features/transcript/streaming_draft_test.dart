import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/transcript/domain/streaming_draft.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

void main() {
  const owner = StreamingOwner(meetingId: 'm', runId: 'live', epoch: 3);

  test(
    'capture gaps survive later text, failure and close without invented words',
    () {
      const gap = StreamingGap(
        owner: owner,
        sequence: 2,
        start: Duration(seconds: 9),
        end: Duration(seconds: 12),
        captureEpoch: 1,
        reason: StreamingGapReason.pause,
      );
      final initial = const StreamingDraft.empty(owner).accept(
        StreamingUtterance(
          owner: owner,
          sequence: 1,
          utteranceId: 'before',
          start: Duration.zero,
          end: const Duration(seconds: 9),
          rawText: '原文 API',
          status: StreamingUtteranceStatus.finalized,
        ),
      );
      final afterGap = initial.accept(gap);
      expect(afterGap.gaps, [gap]);
      expect(afterGap.utterances.map((u) => u.rawText), ['原文 API']);
      expect(afterGap.lastSequence, 2);
      final resumed = afterGap.accept(
        StreamingUtterance(
          owner: owner,
          sequence: 3,
          utteranceId: 'after',
          start: const Duration(seconds: 12),
          end: const Duration(seconds: 14),
          captureEpoch: 1,
          rawText: 'next',
          status: StreamingUtteranceStatus.provisional,
        ),
      );
      expect(resumed.utterances.map((u) => u.rawText), ['原文 API', 'next']);
      expect(resumed.gaps, [gap]);
      expect(resumed.close().gaps, [gap]);
      expect(
        resumed
            .accept(
              const StreamingFailed(
                owner: owner,
                sequence: 4,
                failure: StreamingUnavailable(StreamingFailureReason.engine),
              ),
            )
            .gaps,
        [gap],
      );
      expect(afterGap.accept(gap), same(afterGap));
      final closed = afterGap.close();
      expect(closed.accept(gap), same(closed));
      expect(afterGap.gaps.clear, throwsUnsupportedError);
    },
  );

  test('gap cannot rewrite finalized media or silently seal a provisional', () {
    final partial = const StreamingDraft.empty(owner).accept(
      StreamingUtterance(
        owner: owner,
        sequence: 0,
        utteranceId: 'first',
        start: Duration.zero,
        end: const Duration(seconds: 2),
        rawText: 'guess',
        status: StreamingUtteranceStatus.provisional,
      ),
    );
    const boundary = StreamingGap(
      owner: owner,
      sequence: 2,
      start: Duration(seconds: 2),
      end: Duration(seconds: 2),
      captureEpoch: 1,
      reason: StreamingGapReason.audioFocus,
    );
    expect(partial.accept(boundary), same(partial));
    final finalized = partial.accept(
      StreamingUtterance(
        owner: owner,
        sequence: 1,
        utteranceId: 'first',
        start: Duration.zero,
        end: const Duration(seconds: 2),
        rawText: 'final',
        status: StreamingUtteranceStatus.finalized,
      ),
    );
    final cut = finalized.accept(boundary);
    expect(cut.gaps, [boundary]);
    for (final bad in [
      const StreamingGap(
        owner: owner,
        sequence: 3,
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        captureEpoch: 1,
        reason: StreamingGapReason.pause,
      ),
      const StreamingGap(
        owner: owner,
        sequence: 3,
        start: Duration(seconds: 3),
        end: Duration(seconds: 2),
        captureEpoch: 1,
        reason: StreamingGapReason.pause,
      ),
      const StreamingGap(
        owner: owner,
        sequence: 3,
        start: Duration(seconds: 2),
        end: Duration(seconds: 3),
        captureEpoch: 0,
        reason: StreamingGapReason.pause,
      ),
    ]) {
      expect(cut.accept(bad), same(cut));
    }
    expect(
      cut.accept(
        StreamingUtterance(
          owner: owner,
          sequence: 3,
          utteranceId: 'new',
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 3),
          rawText: 'old epoch',
          status: StreamingUtteranceStatus.provisional,
        ),
      ),
      same(cut),
    );
    expect(
      cut
          .accept(
            StreamingUtterance(
              owner: owner,
              sequence: 3,
              utteranceId: 'new',
              start: const Duration(seconds: 2),
              end: const Duration(seconds: 3),
              captureEpoch: 1,
              rawText: 'valid',
              status: StreamingUtteranceStatus.provisional,
            ),
          )
          .utterances,
      hasLength(2),
    );
  });

  test(
    'same utterance cannot regress its capture end or change generation',
    () {
      final original = const StreamingDraft.empty(owner).accept(
        StreamingUtterance(
          owner: owner,
          sequence: 0,
          utteranceId: 'one',
          start: Duration.zero,
          end: const Duration(seconds: 2),
          captureEpoch: 1,
          rawText: 'original',
          status: StreamingUtteranceStatus.provisional,
        ),
      );
      for (final (end, epoch) in [(1, 1), (3, 0), (3, 2)]) {
        expect(
          original.accept(
            StreamingUtterance(
              owner: owner,
              sequence: 1,
              utteranceId: 'one',
              start: Duration.zero,
              end: Duration(seconds: end),
              captureEpoch: epoch,
              rawText: 'bad',
              status: StreamingUtteranceStatus.provisional,
            ),
          ),
          same(original),
        );
      }
    },
  );

  StreamingUtterance utterance(
    int sequence,
    String text, {
    bool finalText = false,
  }) => StreamingUtterance(
    owner: owner,
    sequence: sequence,
    utteranceId: 'u1',
    start: const Duration(seconds: 7),
    end: const Duration(seconds: 9),
    rawText: text,
    status: finalText
        ? StreamingUtteranceStatus.finalized
        : StreamingUtteranceStatus.provisional,
  );

  test('provisional hypothesis revises in place and final text is sealed', () {
    const initial = StreamingDraft.empty(owner);
    final partial = initial.accept(utterance(1, 'API'));
    expect(partial.utterances, hasLength(1));
    expect(partial.utterances.single.rawText, 'API');
    final revised = partial.accept(utterance(2, 'API latency'));
    expect(revised.utterances, hasLength(1));
    expect(revised.utterances.single.rawText, 'API latency');
    final finalized = revised.accept(
      utterance(3, 'API latency', finalText: true),
    );
    expect(
      finalized.utterances.single.status,
      StreamingUtteranceStatus.finalized,
    );
    expect(finalized.accept(utterance(4, 'rewrite')), same(finalized));
    expect(finalized.utterances.single.start, const Duration(seconds: 7));
    expect(finalized.utterances.single.end, const Duration(seconds: 9));
    expect(initial.utterances, isEmpty);
  });

  test('duplicate and reordered callbacks retain newest valid hypothesis', () {
    final newest = const StreamingDraft.empty(
      owner,
    ).accept(utterance(5, 'newest'));
    expect(newest.utterances, hasLength(1));
    expect(newest.accept(utterance(5, 'duplicate')), same(newest));
    expect(newest.accept(utterance(4, 'older')), same(newest));
  });

  test('closed owner retains its draft and rejects all late callbacks', () {
    final draft = const StreamingDraft.empty(
      owner,
    ).accept(utterance(1, 'retained'));
    final closed = draft.close();
    expect(closed.isClosed, isTrue);
    expect(closed.utterances, draft.utterances);
    expect(
      closed.accept(utterance(100, 'late', finalText: true)),
      same(closed),
    );
    expect(closed.close(), same(closed));
  });

  test(
    'terminal failure closes only the matching owner and preserves text',
    () {
      final draft = const StreamingDraft.empty(
        owner,
      ).accept(utterance(1, 'retained'));
      const failure = StreamingUnavailable(StreamingFailureReason.memory);
      final failed = draft.accept(
        const StreamingFailed(owner: owner, sequence: 2, failure: failure),
      );
      expect(failed.isClosed, isTrue);
      expect(failed.failure, same(failure));
      expect(failed.utterances, draft.utterances);
      expect(failed.accept(utterance(3, 'late')), same(failed));
    },
  );

  test('meeting run and owner generation must all match', () {
    final draft = const StreamingDraft.empty(
      owner,
    ).accept(utterance(1, 'original'));
    expect(draft.utterances, hasLength(1));
    for (final other in const [
      StreamingOwner(meetingId: 'other', runId: 'live', epoch: 3),
      StreamingOwner(meetingId: 'm', runId: 'old', epoch: 3),
      StreamingOwner(meetingId: 'm', runId: 'live', epoch: 2),
    ]) {
      final late = StreamingUtterance(
        owner: other,
        sequence: 100,
        utteranceId: 'u1',
        start: Duration.zero,
        end: const Duration(seconds: 1),
        rawText: 'foreign',
        status: StreamingUtteranceStatus.provisional,
      );
      expect(draft.accept(late), same(draft));
    }
  });

  test(
    'revisions cannot move utterance capture origin or overlap final text',
    () {
      final draft = const StreamingDraft.empty(
        owner,
      ).accept(utterance(1, 'original'));
      expect(draft.utterances, hasLength(1));
      final relocated = StreamingUtterance(
        owner: owner,
        sequence: 2,
        utteranceId: 'u1',
        start: const Duration(seconds: 8),
        end: const Duration(seconds: 10),
        rawText: 'relocated',
        status: StreamingUtteranceStatus.provisional,
      );
      expect(draft.accept(relocated), same(draft));
      final finalized = draft.accept(utterance(3, 'final', finalText: true));
      final overlapping = StreamingUtterance(
        owner: owner,
        sequence: 4,
        utteranceId: 'u2',
        start: const Duration(seconds: 8),
        end: const Duration(seconds: 10),
        rawText: 'overlap',
        status: StreamingUtteranceStatus.finalized,
      );
      expect(finalized.accept(overlapping), same(finalized));
      final next = StreamingUtterance(
        owner: owner,
        sequence: 5,
        utteranceId: 'u2',
        start: const Duration(seconds: 12),
        end: const Duration(seconds: 14),
        rawText: 'next',
        status: StreamingUtteranceStatus.finalized,
      );
      final appended = finalized.accept(next);
      expect(appended.utterances.map((u) => u.rawText), ['final', 'next']);
      expect(appended.utterances.clear, throwsUnsupportedError);
    },
  );
}
