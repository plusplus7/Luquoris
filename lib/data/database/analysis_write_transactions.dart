import 'package:drift/drift.dart';
import 'package:loquiris/data/database/app_database.dart';

/// Atomic write boundaries for versioned transcript and diarization graphs.
final class AnalysisWriteTransactions {
  /// Creates analysis write boundaries over [database].
  const AnalysisWriteTransactions(this.database);

  /// Database that owns the transaction and all affected tables.
  final AppDatabase database;

  /// Inserts one transcript version and its derived graph atomically.
  Future<void> createTranscriptVersion(
    TranscriptRunsCompanion run, {
    required List<TranscriptSegmentsCompanion> segments,
    required List<LanguageDecisionsCompanion> languageDecisions,
    List<TranscriptLanguageSelectionsCompanion> languageSelections =
        const <TranscriptLanguageSelectionsCompanion>[],
    MeetingTranscriptSelectionsCompanion? meetingSelection,
  }) async {
    final runId = _required(run.id, 'run.id');
    final meetingId = _required(run.meetingId, 'run.meetingId');
    final segmentIds = <String>{};
    final decisionSegmentById = <String, String>{};
    for (final segment in segments) {
      _requireEqual(segment.transcriptRunId, runId, 'segment.transcriptRunId');
      _requireEqual(segment.meetingId, meetingId, 'segment.meetingId');
      segmentIds.add(_required(segment.id, 'segment.id'));
    }
    for (final decision in languageDecisions) {
      final decisionId = _required(decision.id, 'decision.id');
      final segmentId = _required(
        decision.transcriptSegmentId,
        'decision.transcriptSegmentId',
      );
      if (!segmentIds.contains(segmentId)) {
        throw ArgumentError('language decision must target a supplied segment');
      }
      decisionSegmentById[decisionId] = segmentId;
    }
    for (final selection in languageSelections) {
      final segmentId = _required(
        selection.transcriptSegmentId,
        'languageSelection.transcriptSegmentId',
      );
      final decisionId = _required(
        selection.languageDecisionId,
        'languageSelection.languageDecisionId',
      );
      if (!segmentIds.contains(segmentId) ||
          decisionSegmentById[decisionId] != segmentId) {
        throw ArgumentError(
          'language selection must bind a supplied decision to its supplied segment',
        );
      }
    }
    if (meetingSelection != null) {
      _requireEqual(
        meetingSelection.meetingId,
        meetingId,
        'meetingSelection.meetingId',
      );
      _requireEqual(
        meetingSelection.transcriptRunId,
        runId,
        'meetingSelection.transcriptRunId',
      );
    }

    await database.transaction(() async {
      await database.into(database.transcriptRuns).insert(run);
      for (final segment in segments) {
        await database.into(database.transcriptSegments).insert(segment);
      }
      for (final decision in languageDecisions) {
        await database.into(database.languageDecisions).insert(decision);
      }
      for (final selection in languageSelections) {
        await database
            .into(database.transcriptLanguageSelections)
            .insert(selection);
      }
      if (meetingSelection != null) {
        await database
            .into(database.meetingTranscriptSelections)
            .insert(meetingSelection);
      }
    });
  }

  /// Inserts one diarization version, clusters, and assignments atomically.
  Future<void> createDiarizationVersion(
    DiarizationRunsCompanion run, {
    required List<SpeakersCompanion> speakers,
    required List<SpeakerAssignmentsCompanion> assignments,
  }) async {
    final runId = _required(run.id, 'run.id');
    final meetingId = _required(run.meetingId, 'run.meetingId');
    for (final speaker in speakers) {
      _requireEqual(speaker.analysisRunId, runId, 'speaker.analysisRunId');
      _requireEqual(speaker.meetingId, meetingId, 'speaker.meetingId');
    }
    for (final assignment in assignments) {
      _requireEqual(
        assignment.analysisRunId,
        runId,
        'assignment.analysisRunId',
      );
      _requireEqual(assignment.meetingId, meetingId, 'assignment.meetingId');
    }

    await database.transaction(() async {
      await database.into(database.diarizationRuns).insert(run);
      for (final speaker in speakers) {
        await database.into(database.speakers).insert(speaker);
      }
      for (final assignment in assignments) {
        await database.into(database.speakerAssignments).insert(assignment);
      }
    });
  }
}

String _required(Value<String> field, String name) {
  if (!field.present) throw ArgumentError('$name must be present');
  return field.value;
}

void _requireEqual(Value<String> field, String expected, String name) {
  if (!field.present || field.value != expected) {
    throw ArgumentError('$name must match its aggregate owner');
  }
}
