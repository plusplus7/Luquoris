import 'dart:convert';

import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Builds deterministic, offline export representations from selected data.
abstract final class ExportDocumentBuilder {
  /// Creates a non-sensitive filename without meeting-derived user content.
  static String defaultFileName({
    required ExportFormat format,
    required DateTime createdAtUtc,
  }) {
    final instant = createdAtUtc.toUtc();
    final timestamp =
        '${_digits(instant.year, 4)}${_digits(instant.month, 2)}'
        '${_digits(instant.day, 2)}_${_digits(instant.hour, 2)}'
        '${_digits(instant.minute, 2)}${_digits(instant.second, 2)}';
    final suffix = switch (format) {
      ExportFormat.audioM4a => '.m4a',
      ExportFormat.audioSegments => '_segments.zip',
      ExportFormat.text => '.txt',
      ExportFormat.subtitles => '.srt',
      ExportFormat.json => '.json',
      ExportFormat.archive => '.zip',
    };
    return 'Loquiris_$timestamp$suffix';
  }

  /// Formats the selected transcript as readable timestamped text.
  static String plainText(TranscriptEditorDocument document) {
    final buffer = StringBuffer();
    final segments =
        document.currentVersion?.segments ?? const <TranscriptSegment>[];
    for (var index = 0; index < segments.length; index += 1) {
      final segment = segments[index];
      final speaker = _speakerLabel(document, segment.speakerId);
      buffer
        ..writeln(
          '[${_textTimestamp(segment.start)}]${speaker == null ? '' : ' $speaker'}',
        )
        ..writeln(segment.displayedText);
      if (index < segments.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Formats the selected transcript as SRT with millisecond timestamps.
  static String subtitles(TranscriptEditorDocument document) {
    final buffer = StringBuffer();
    final segments =
        document.currentVersion?.segments ?? const <TranscriptSegment>[];
    for (var index = 0; index < segments.length; index += 1) {
      final segment = segments[index];
      final speaker = _speakerLabel(document, segment.speakerId);
      buffer
        ..writeln(index + 1)
        ..writeln(
          '${_srtTimestamp(segment.start)} --> ${_srtTimestamp(segment.end)}',
        )
        ..writeln(
          '${speaker == null ? '' : '$speaker: '}${segment.displayedText}',
        );
      if (index < segments.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Encodes meeting state, selected transcript, and local provenance.
  static String structuredJson({
    required SessionDetail detail,
    required TranscriptEditorDocument? transcript,
    required List<TranscriptVersion> transcriptVersions,
  }) {
    final meeting = detail.meeting;
    final version = transcript?.currentVersion;
    final run = version?.run;
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'schemaVersion': 1,
      'meetingId': meeting.id,
      'title': meeting.title,
      'createdAtUtcMs': meeting.createdAtUtcMs,
      'mediaDurationMilliseconds': meeting.mediaDuration.inMilliseconds,
      'lifecycle': meeting.lifecycle.name,
      'languageMode': meeting.languageMode.name,
      'transcriptionMode': meeting.transcriptionMode.name,
      'expectedSpeakerCount': meeting.expectedSpeakerCount,
      'currentTranscriptRunId': meeting.currentTranscriptRunId,
      'audioSegments': [
        for (final segment in detail.segments)
          <String, Object?>{
            'id': segment.id,
            'sequence': segment.sequence,
            'relativePath': segment.relativePath.value,
            'mediaStartMilliseconds': segment.mediaStart.inMilliseconds,
            'mediaDurationMilliseconds': segment.mediaDuration.inMilliseconds,
            'committedBytes': segment.committedBytes,
            'state': segment.state.name,
          },
      ],
      'events': [
        for (final event in detail.events)
          <String, Object?>{
            'id': event.id,
            'sequence': event.sequence,
            'type': event.type.name,
            'wallClockUtcMs': event.wallClockUtcMs,
            'monotonicElapsedMilliseconds':
                event.monotonicElapsed.inMilliseconds,
            'mediaOffsetMilliseconds': event.mediaOffset.inMilliseconds,
          },
      ],
      'bookmarks': [
        for (final bookmark in detail.bookmarks)
          <String, Object?>{
            'id': bookmark.id,
            'mediaOffsetMilliseconds': bookmark.mediaOffset.inMilliseconds,
            'kind': bookmark.kind.name,
            'createdAtUtcMs': bookmark.createdAtUtcMs,
          },
      ],
      'processingJobs': [
        for (final job in detail.processingJobs)
          <String, Object?>{
            'id': job.id,
            'kind': job.kind.name,
            'createdAtUtcMs': job.createdAtUtcMs,
            'state': _processingState(job.state),
            'targetRunId': job.targetRunId,
            'modelId': job.modelId,
            'checkpoint': job.checkpoint,
          },
      ],
      'recoveryDiagnostics': [
        for (final diagnostic in detail.recoveryDiagnostics)
          <String, Object?>{
            'code': diagnostic.code,
            'segmentSequence': diagnostic.segmentSequence,
          },
      ],
      'transcriptRunId': run?.id,
      'engineId': run?.provenance.engineId,
      'engineVersion': run?.provenance.engineVersion,
      'modelId': run?.provenance.modelId,
      'modelVersion': run?.provenance.modelVersion,
      'modelSha256': run?.provenance.modelSha256,
      'parametersJson': run?.provenance.parametersJson,
      'speakers': [
        for (final speaker
            in (transcript?.speakersById.values.toList()
                  ?..sort((first, second) => first.id.compareTo(second.id))) ??
                const <Speaker>[])
          <String, Object?>{
            'id': speaker.id,
            'analysisRunId': speaker.analysisRunId,
            'label': speaker.label,
          },
      ],
      'languageDecisions': [
        for (final decision
            in (transcript?.languagesBySegmentId.values.toList()?..sort(
                  (first, second) => first.transcriptSegmentId.compareTo(
                    second.transcriptSegmentId,
                  ),
                )) ??
                const <LanguageDecision>[])
          <String, Object?>{
            'id': decision.id,
            'transcriptSegmentId': decision.transcriptSegmentId,
            'tag': decision.tag.name,
            'source': decision.source.name,
            'confidence': decision.confidence,
          },
      ],
      'revisions': [
        for (final revision in transcript?.revisions ?? const <Revision>[])
          <String, Object?>{
            'id': revision.id,
            'targetId': revision.targetId,
            'createdAtUtcMs': revision.createdAtUtcMs,
            ..._revisionChange(revision.change),
          },
      ],
      'transcriptVersions': [
        for (final retained in transcriptVersions)
          <String, Object?>{
            'runId': retained.run.id,
            'isCurrent': retained.isCurrent,
            'createdAtUtcMs': retained.run.createdAtUtcMs,
            'state': _analysisState(retained.run.state),
            'engineId': retained.run.provenance.engineId,
            'engineVersion': retained.run.provenance.engineVersion,
            'modelId': retained.run.provenance.modelId,
            'modelVersion': retained.run.provenance.modelVersion,
            'modelSha256': retained.run.provenance.modelSha256,
            'parametersJson': retained.run.provenance.parametersJson,
            'segments': [
              for (final segment in retained.segments)
                <String, Object?>{
                  'id': segment.id,
                  'startMilliseconds': segment.start.inMilliseconds,
                  'endMilliseconds': segment.end.inMilliseconds,
                  'rawModelText': segment.rawModelText,
                  'displayedText': segment.displayedText,
                  'revisionState': segment.revisionState.name,
                  'speakerId': segment.speakerId,
                  'languageDecisionId': segment.languageDecisionId,
                  'speaker': switch (retained.speakersById[segment.speakerId]) {
                    final speaker? => <String, Object?>{
                      'id': speaker.id,
                      'analysisRunId': speaker.analysisRunId,
                      'label': speaker.label,
                    },
                    null => null,
                  },
                  'languageDecision':
                      switch (retained.languagesBySegmentId[segment.id]) {
                        final decision? => <String, Object?>{
                          'id': decision.id,
                          'tag': decision.tag.name,
                          'source': decision.source.name,
                          'confidence': decision.confidence,
                        },
                        null => null,
                      },
                },
            ],
          },
      ],
      'segments': [
        for (final segment in version?.segments ?? const <TranscriptSegment>[])
          <String, Object?>{
            'id': segment.id,
            'startMilliseconds': segment.start.inMilliseconds,
            'endMilliseconds': segment.end.inMilliseconds,
            'rawModelText': segment.rawModelText,
            'displayedText': segment.displayedText,
            'revisionState': switch (segment.revisionState) {
              TranscriptRevisionState.machine => 'machine',
              TranscriptRevisionState.corrected => 'corrected',
            },
            'speakerId': segment.speakerId,
            'speakerLabel': transcript == null
                ? null
                : _speakerLabel(transcript, segment.speakerId),
            'language':
                switch (transcript?.languagesBySegmentId[segment.id]?.tag) {
                  LanguageTag.chinese => 'chinese',
                  LanguageTag.english => 'english',
                  LanguageTag.mixed => 'mixed',
                  LanguageTag.uncertain => 'uncertain',
                  null => null,
                },
            'languageSource':
                switch (transcript?.languagesBySegmentId[segment.id]?.source) {
                  LanguageDecisionSource.automatic => 'automatic',
                  LanguageDecisionSource.manual => 'manual',
                  null => null,
                },
          },
      ],
    });
  }

  static String? _speakerLabel(
    TranscriptEditorDocument document,
    String? speakerId,
  ) => speakerId == null ? null : document.speakersById[speakerId]?.label;

  static String _textTimestamp(Duration value) =>
      '${_digits(value.inHours, 2)}:'
      '${_digits(value.inMinutes.remainder(60), 2)}:'
      '${_digits(value.inSeconds.remainder(60), 2)}';

  static String _srtTimestamp(Duration value) =>
      '${_textTimestamp(value)},${_digits(value.inMilliseconds.remainder(1000), 3)}';

  static String _digits(int value, int width) =>
      value.toString().padLeft(width, '0');

  static Map<String, Object?> _processingState(ProcessingState state) =>
      switch (state) {
        ProcessingQueued() => const <String, Object?>{'kind': 'queued'},
        ProcessingRunning(:final progress) => <String, Object?>{
          'kind': 'running',
          'progress': progress,
        },
        ProcessingPaused(:final reasonCode) => <String, Object?>{
          'kind': 'paused',
          'reasonCode': reasonCode,
        },
        ProcessingSucceeded() => const <String, Object?>{
          'kind': 'succeeded',
        },
        ProcessingSucceededWithWarning(:final warningCode) => <String, Object?>{
          'kind': 'succeeded',
          'warningCode': warningCode,
        },
        ProcessingFailed(:final failureCode) => <String, Object?>{
          'kind': 'failed',
          'failureCode': failureCode,
        },
      };

  static Map<String, Object?> _analysisState(AnalysisState state) =>
      switch (state) {
        AnalysisQueued() => const <String, Object?>{'kind': 'queued'},
        AnalysisRunning(:final startedAtUtcMs, :final progress) =>
          <String, Object?>{
            'kind': 'running',
            'startedAtUtcMs': startedAtUtcMs,
            'progress': progress,
          },
        AnalysisCompleted(:final startedAtUtcMs, :final endedAtUtcMs) =>
          <String, Object?>{
            'kind': 'completed',
            'startedAtUtcMs': startedAtUtcMs,
            'endedAtUtcMs': endedAtUtcMs,
          },
        AnalysisFailed(
          :final startedAtUtcMs,
          :final endedAtUtcMs,
          :final progress,
          :final failureCode,
        ) =>
          <String, Object?>{
            'kind': 'failed',
            'startedAtUtcMs': startedAtUtcMs,
            'endedAtUtcMs': endedAtUtcMs,
            'progress': progress,
            'failureCode': failureCode,
          },
      };

  static Map<String, Object?> _revisionChange(
    RevisionChange change,
  ) => switch (change) {
    TranscriptTextChange(:final previousText, :final revisedText) =>
      <String, Object?>{
        'kind': 'text',
        'previousText': previousText,
        'revisedText': revisedText,
      },
    LanguageLabelChange(:final previous, :final revised) => <String, Object?>{
      'kind': 'language',
      'previous': previous.name,
      'revised': revised.name,
    },
    SpeakerAssignmentChange(
      :final start,
      :final end,
      :final previousSpeakerId,
      :final revisedSpeakerId,
      :final needsConfirmation,
    ) =>
      <String, Object?>{
        'kind': 'speakerAssignment',
        'startMilliseconds': start.inMilliseconds,
        'endMilliseconds': end.inMilliseconds,
        'previousSpeakerId': previousSpeakerId,
        'revisedSpeakerId': revisedSpeakerId,
        'needsConfirmation': needsConfirmation,
      },
    SpeakerLabelChange(:final previous, :final revised) => <String, Object?>{
      'kind': 'speakerLabel',
      'previous': previous,
      'revised': revised,
    },
  };
}
