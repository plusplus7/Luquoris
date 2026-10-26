import 'dart:convert';

import 'package:loquiris/services/service_contracts.dart';

/// Waits for a real endpoint under a bounded, injectable observation schedule.
Future<List<TranscriptionDraftUpdated>> waitForRecorderUiFinal({
  required List<TranscriptionEvent> events,
  required Map<String, Object> Function() snapshot,
  required Future<void> Function() wait,
  int maximumObservations = 200,
}) async {
  for (var attempt = 0; attempt < maximumObservations; attempt++) {
    if (events.whereType<TranscriptionDraftDegraded>().any(
      (event) => event.reason != 'transcription_live_discontinuity',
    )) {
      throw StateError('recorder_ui_native_failure:${jsonEncode(snapshot())}');
    }
    final finals = events.whereType<TranscriptionDraftUpdated>().where(
      (event) =>
          event.chunk.stability == TranscriptStability.stable &&
          event.chunk.rawText.trim().isNotEmpty,
    );
    if (finals.isNotEmpty) return finals.toList();
    await wait();
  }
  throw StateError('recorder_ui_no_final:${jsonEncode(snapshot())}');
}

/// Validates coverage evidence for a fresh recorder with exactly one pause.
///
/// This is a smoke-test oracle, not production qualification. Positive gaps must
/// remain visible as incomplete coverage, never be silently accepted as complete.
List<String> recorderUiCoverageProblems({
  required Map<String, Object> trace,
  required Duration firstFinalStart,
  required Duration pausedFinalEnd,
  required Duration resumedFinalStart,
}) {
  final problems = <String>[];
  if (firstFinalStart < Duration.zero ||
      pausedFinalEnd < firstFinalStart ||
      resumedFinalStart < pausedFinalEnd) {
    problems.add('invalid_text_bounds');
  }
  final gaps = trace['wireGapDetails'];
  if (gaps is! List<Object?>) return ['missing_gap_details'];
  if (trace['wireGapDetailsDropped'] != 0 || trace['wireGaps'] != gaps.length) {
    problems.add('incomplete_gap_evidence');
  }
  var initialSeen = false;
  var pauseSeen = false;
  var previousSequence = -1;
  var previousEnd = 0;
  var positiveGaps = 0;
  for (final gap in gaps) {
    if (gap case {
      'sequence': final int sequence,
      'startUs': final int start,
      'endUs': final int end,
      'captureEpoch': final int epoch,
      'reason': final String reason,
    }) {
      if (sequence <= previousSequence ||
          start < previousEnd ||
          end < start ||
          epoch < 0) {
        problems.add('invalid_gap_order');
      }
      previousSequence = sequence;
      previousEnd = end;
      if (end > start) positiveGaps++;
      switch (reason) {
        case 'discontinuity':
          if (initialSeen ||
              pauseSeen ||
              sequence != 0 ||
              epoch != 0 ||
              start != 0 ||
              end <= 0 ||
              end > firstFinalStart.inMicroseconds) {
            problems.add('unexpected_attachment_gap');
          }
          initialSeen = true;
        case 'pause':
          if (pauseSeen ||
              epoch != 1 ||
              start < pausedFinalEnd.inMicroseconds ||
              end > resumedFinalStart.inMicroseconds) {
            problems.add('unexpected_pause_gap');
          }
          pauseSeen = true;
        default:
          problems.add('unexpected_gap_reason');
      }
    } else {
      problems.add('malformed_gap_details');
    }
  }
  if (!pauseSeen) problems.add('missing_pause_boundary');
  final nativeFailures = trace['wireFailureReasons'];
  if (trace['wireRejected'] != 0 ||
      nativeFailures is! List<Object?> ||
      nativeFailures.isNotEmpty) {
    problems.add('native_delivery_failure');
  }
  final projectedReasons = trace['projectedFailureReasons'];
  final expectedReasons = positiveGaps > 0 ? 1 : 0;
  if (trace['projectedGapNotices'] != positiveGaps ||
      projectedReasons is! List<Object?> ||
      projectedReasons.length != expectedReasons ||
      projectedReasons.any(
        (reason) => reason != 'transcription_live_discontinuity',
      )) {
    problems.add('coverage_notice_mismatch');
  }
  final viewReasons = trace['viewFailureReasons'];
  if (viewReasons is! List<Object?> ||
      viewReasons.length != expectedReasons ||
      viewReasons.any(
        (reason) => reason != 'transcription_live_discontinuity',
      ) ||
      trace['viewIncomplete'] != (positiveGaps > 0) ||
      trace['viewStatus'] != 'stopped') {
    problems.add('coverage_view_mismatch');
  }
  return problems;
}
