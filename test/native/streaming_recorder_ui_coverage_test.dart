import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/services/service_contracts.dart';

import '../support/streaming_recorder_ui_coverage.dart';

void main() {
  test('an initial gap may precede a delayed nonempty PAUSE final', () async {
    final events = <TranscriptionEvent>[
      const TranscriptionDraftDegraded(
        runId: 'run',
        reason: 'transcription_live_discontinuity',
        backlog: Duration.zero,
        incomplete: true,
      ),
    ];
    var observations = 0;
    const endpoint = TranscriptionDraftUpdated(
      runId: 'run',
      chunk: TranscriptChunk(
        segmentId: 'u1',
        start: Duration(milliseconds: 200),
        end: Duration(seconds: 1),
        rawText: 'private speech marker',
        displayText: 'private speech marker',
        stability: TranscriptStability.stable,
      ),
      backlog: Duration.zero,
    );
    final finals = await waitForRecorderUiFinal(
      events: events,
      snapshot: () => {'wireGaps': 1},
      wait: () async {
        observations++;
        if (observations == 2) events.add(endpoint);
      },
      maximumObservations: 4,
    );
    expect(observations, 2);
    expect(finals.single, same(endpoint));
  });

  test(
    'native degradation still fails without waiting or leaking its text',
    () async {
      var waited = false;
      await expectLater(
        waitForRecorderUiFinal(
          events: [
            const TranscriptionDraftDegraded(
              runId: 'private-run',
              reason: '/private/path/token',
              backlog: Duration.zero,
              incomplete: true,
            ),
          ],
          snapshot: () => {'wireFailures': 1},
          wait: () async {
            waited = true;
          },
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'failure code',
                startsWith('recorder_ui_native_failure:'),
              )
              .having(
                (error) => error.message,
                'private content',
                isNot(contains('/private')),
              ),
        ),
      );
      expect(waited, isFalse);
    },
  );

  test('a gap without a final still exhausts a bounded wait', () async {
    var observations = 0;
    await expectLater(
      waitForRecorderUiFinal(
        events: [
          const TranscriptionDraftDegraded(
            runId: 'run',
            reason: 'transcription_live_discontinuity',
            backlog: Duration.zero,
            incomplete: true,
          ),
        ],
        snapshot: () => {'wireGaps': 1},
        wait: () async {
          observations++;
        },
        maximumObservations: 2,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'failure code',
          startsWith('recorder_ui_no_final:'),
        ),
      ),
    );
    expect(observations, 2);
  });

  test('late attachment and one pause retain explicit incomplete coverage', () {
    expect(
      recorderUiCoverageProblems(
        trace: _trace(),
        firstFinalStart: const Duration(milliseconds: 200),
        pausedFinalEnd: const Duration(seconds: 1),
        resumedFinalStart: const Duration(milliseconds: 1200),
      ),
      isEmpty,
    );
  });

  test('an attachment gap cannot replace the missing pause boundary', () {
    final trace = _trace();
    (trace['wireGapDetails']! as List<Map<String, Object>>).removeLast();
    trace['wireGaps'] = 1;
    trace['projectedGapNotices'] = 1;
    expect(
      recorderUiCoverageProblems(
        trace: trace,
        firstFinalStart: const Duration(milliseconds: 200),
        pausedFinalEnd: const Duration(seconds: 1),
        resumedFinalStart: const Duration(milliseconds: 1200),
      ),
      contains('missing_pause_boundary'),
    );
  });

  test('a repeated zero-length pause boundary still fails', () {
    final trace = _trace();
    (trace['wireGapDetails']! as List<Map<String, Object>>).add({
      'sequence': 4,
      'startUs': 1200000,
      'endUs': 1200000,
      'captureEpoch': 1,
      'reason': 'pause',
    });
    trace['wireGaps'] = 3;
    expect(
      recorderUiCoverageProblems(
        trace: trace,
        firstFinalStart: const Duration(milliseconds: 200),
        pausedFinalEnd: const Duration(seconds: 1),
        resumedFinalStart: const Duration(milliseconds: 1200),
      ),
      contains('unexpected_pause_gap'),
    );
  });

  test('a zero-length pause boundary does not invent incomplete coverage', () {
    final trace = _trace()
      ..['wireGaps'] = 1
      ..['wireGapDetails'] = [
        {
          'sequence': 3,
          'startUs': 1000000,
          'endUs': 1000000,
          'captureEpoch': 1,
          'reason': 'pause',
        },
      ]
      ..['projectedGapNotices'] = 0
      ..['projectedFailureReasons'] = <String>[]
      ..['viewFailureReasons'] = <String>[]
      ..['viewIncomplete'] = false;
    expect(
      recorderUiCoverageProblems(
        trace: trace,
        firstFinalStart: Duration.zero,
        pausedFinalEnd: const Duration(seconds: 1),
        resumedFinalStart: const Duration(seconds: 1),
      ),
      isEmpty,
    );
  });

  for (final entry in <String, Map<String, Object>>{
    'an unrequested focus interruption': {'reason': 'audioFocus'},
    'a wrong capture generation': {'captureEpoch': 2},
    'a repeated native sequence': {'sequence': 0},
    'a gap over the paused final': {'startUs': 900000},
    'a gap over resumed text': {'endUs': 1300000},
    'a negative-duration interval': {'endUs': 900000},
    'an unrecognized cause': {'reason': 'unknown'},
  }.entries) {
    test('rejects ${entry.key}', () {
      final trace = _trace();
      final gaps = trace['wireGapDetails']! as List<Map<String, Object>>;
      gaps[1] = {...gaps[1], ...entry.value};
      expect(
        recorderUiCoverageProblems(
          trace: trace,
          firstFinalStart: const Duration(milliseconds: 200),
          pausedFinalEnd: const Duration(seconds: 1),
          resumedFinalStart: const Duration(milliseconds: 1200),
        ),
        isNotEmpty,
      );
    });
  }

  for (final entry in <String, Map<String, Object>>{
    'truncated gap evidence': {'wireGapDetailsDropped': 1},
    'an unaccounted gap': {'wireGaps': 3},
    'a malformed wire event': {'wireRejected': 1},
    'a native failure': {
      'wireFailureReasons': ['engine'],
    },
    'a missing gap notice': {'projectedGapNotices': 1},
    'an extra gap notice': {'projectedGapNotices': 3},
    'a hidden incomplete flag': {'viewIncomplete': false},
    'a view that hides the gap cause': {'viewFailureReasons': <String>[]},
    'an unexpected view failure': {
      'viewFailureReasons': ['unrecognized'],
    },
    'an unexpected projected failure': {
      'projectedFailureReasons': ['transcription_live_backlog'],
    },
    'a view that never observed release': {'viewStatus': 'running'},
  }.entries) {
    test('rejects ${entry.key}', () {
      expect(
        recorderUiCoverageProblems(
          trace: {..._trace(), ...entry.value},
          firstFinalStart: const Duration(milliseconds: 200),
          pausedFinalEnd: const Duration(seconds: 1),
          resumedFinalStart: const Duration(milliseconds: 1200),
        ),
        isNotEmpty,
      );
    });
  }
}

Map<String, Object> _trace() => {
  'wireGaps': 2,
  'wireGapDetails': <Map<String, Object>>[
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
  ],
  'wireGapDetailsDropped': 0,
  'wireRejected': 0,
  'wireFailureReasons': <String>[],
  'projectedGapNotices': 2,
  'projectedFailureReasons': ['transcription_live_discontinuity'],
  'viewStatus': 'stopped',
  'viewIncomplete': true,
  'viewFailureReasons': ['transcription_live_discontinuity'],
};
