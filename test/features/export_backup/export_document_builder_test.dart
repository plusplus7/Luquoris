import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/export_backup/application/export_document_builder.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  group('privacy-preserving export names', () {
    test('uses only Loquiris and UTC creation time for every format', () {
      const sensitiveTitle = 'Alice acquisition interview';
      final createdAt = DateTime.utc(2026, 10, 1, 9, 7, 5);

      final names = {
        for (final format in ExportFormat.values)
          format: ExportDocumentBuilder.defaultFileName(
            format: format,
            createdAtUtc: createdAt,
          ),
      };

      expect(
        names,
        {
          ExportFormat.audioM4a: 'Loquiris_20261001_090705.m4a',
          ExportFormat.audioSegments: 'Loquiris_20261001_090705_segments.zip',
          ExportFormat.text: 'Loquiris_20261001_090705.txt',
          ExportFormat.subtitles: 'Loquiris_20261001_090705.srt',
          ExportFormat.json: 'Loquiris_20261001_090705.json',
          ExportFormat.archive: 'Loquiris_20261001_090705.zip',
        },
      );
      expect(names.values.join(), isNot(contains(sensitiveTitle)));
      expect(names.values.join(), isNot(contains('Alice')));
    });
  });

  group('transcript documents', () {
    final document = _document();

    test('TXT is readable and uses corrected text and speaker labels', () {
      expect(
        ExportDocumentBuilder.plainText(document),
        '[00:00:01] Alice\nHello，世界。\n\n'
        '[01:02:03] Speaker 2\nLine one\nLine two\n',
      );
    });

    test('SRT uses corrected text and canonical millisecond timestamps', () {
      expect(
        ExportDocumentBuilder.subtitles(document),
        '1\n'
        '00:00:01,250 --> 00:00:03,500\n'
        'Alice: Hello，世界。\n\n'
        '2\n'
        '01:02:03,004 --> 01:02:05,040\n'
        'Speaker 2: Line one\nLine two\n',
      );
    });

    test('JSON preserves raw text, corrections, labels, and provenance', () {
      final decoded =
          jsonDecode(
                ExportDocumentBuilder.structuredJson(
                  detail: _detail(),
                  transcript: document,
                  transcriptVersions: [
                    document.currentVersion!,
                    _retainedVersion(),
                  ],
                ),
              )
              as Map<String, Object?>;
      final segments = decoded['segments']! as List<Object?>;
      final first = segments.first! as Map<String, Object?>;
      final speakers = decoded['speakers']! as List<Object?>;
      final languages = decoded['languageDecisions']! as List<Object?>;
      final revisions = decoded['revisions']! as List<Object?>;
      final versions = decoded['transcriptVersions']! as List<Object?>;

      expect(decoded['schemaVersion'], 1);
      expect(decoded['meetingId'], 'meeting-sensitive');
      expect(decoded['title'], 'Alice acquisition interview');
      expect(decoded['createdAtUtcMs'], 1790845625000);
      expect(decoded['mediaDurationMilliseconds'], 3725040);
      expect(decoded['lifecycle'], 'finalized');
      expect(decoded['languageMode'], 'mixed');
      expect(decoded['transcriptionMode'], 'postSession');
      expect(decoded['expectedSpeakerCount'], 2);
      expect(decoded['audioSegments'], isEmpty);
      expect(decoded['events'], isEmpty);
      expect(decoded['bookmarks'], isEmpty);
      expect(decoded['processingJobs'], isEmpty);
      expect(decoded['recoveryDiagnostics'], isEmpty);
      expect(decoded['transcriptRunId'], 'run-1');
      expect(decoded['engineId'], 'whisper.cpp');
      expect(decoded['modelId'], 'base-q5');
      expect(first['startMilliseconds'], 1250);
      expect(first['rawModelText'], 'hello 世界');
      expect(first['displayedText'], 'Hello，世界。');
      expect(first['revisionState'], 'corrected');
      expect(first['speakerLabel'], 'Alice');
      expect(first['language'], 'mixed');
      expect(first['languageSource'], 'manual');
      expect(
        speakers.cast<Map<String, Object?>>().firstWhere(
          (speaker) => speaker['id'] == 'speaker-1',
        )['label'],
        'Alice',
      );
      expect((languages.single! as Map<String, Object?>)['confidence'], isNull);
      expect((revisions.single! as Map<String, Object?>)['kind'], 'text');
      expect(versions, hasLength(2));
      expect(
        (versions.last! as Map<String, Object?>)['runId'],
        'run-retained',
      );
      final retainedSegments =
          (versions.last! as Map<String, Object?>)['segments']!
              as List<Object?>;
      final retainedSegment = retainedSegments.single! as Map<String, Object?>;
      expect(
        (retainedSegment['speaker']! as Map<String, Object?>)['label'],
        'Older speaker',
      );
      expect(
        (retainedSegment['languageDecision']! as Map<String, Object?>)['tag'],
        'english',
      );
      expect(
        (revisions.single! as Map<String, Object?>)['previousText'],
        'hello 世界',
      );
    });
  });
}

TranscriptVersion _retainedVersion() => TranscriptVersion(
  run: const TranscriptRun(
    id: 'run-retained',
    meetingId: 'meeting-sensitive',
    provenance: InferenceProvenance(
      engineId: 'whisper.cpp',
      engineVersion: '1.6.0',
      modelId: 'tiny-q5',
      modelVersion: '1',
      modelSha256: 'retained-hash',
      parametersJson: '{}',
    ),
    createdAtUtcMs: 0,
    state: AnalysisCompleted(startedAtUtcMs: 0, endedAtUtcMs: 1),
  ),
  segments: const [
    TranscriptSegment(
      id: 'retained-segment',
      transcriptRunId: 'run-retained',
      start: Duration.zero,
      end: Duration(seconds: 1),
      rawModelText: 'older output',
      displayedText: 'older output',
      revisionState: TranscriptRevisionState.machine,
      languageDecisionId: 'retained-language',
      speakerId: 'retained-speaker',
    ),
  ],
  isCurrent: false,
  languagesBySegmentId: const {
    'retained-segment': LanguageDecision(
      id: 'retained-language',
      transcriptSegmentId: 'retained-segment',
      tag: LanguageTag.english,
      source: LanguageDecisionSource.automatic,
      confidence: 0.82,
    ),
  },
  speakersById: const {
    'retained-speaker': Speaker(
      id: 'retained-speaker',
      meetingId: 'meeting-sensitive',
      analysisRunId: 'retained-diarization',
      label: 'Older speaker',
    ),
  },
);

SessionDetail _detail() => SessionDetail(
  meeting: const Meeting(
    id: 'meeting-sensitive',
    title: 'Alice acquisition interview',
    createdAtUtcMs: 1790845625000,
    mediaDuration: Duration(
      hours: 1,
      minutes: 2,
      seconds: 5,
      milliseconds: 40,
    ),
    lifecycle: MeetingLifecycle.finalized,
    languageMode: MeetingLanguageMode.mixed,
    expectedSpeakerCount: 2,
  ),
  segments: const [],
  events: const [],
  bookmarks: const [],
  processingJobs: const [],
  recoveryDiagnostics: const [],
);

TranscriptEditorDocument _document() => TranscriptEditorDocument(
  meetingId: 'meeting-sensitive',
  lifecycle: MeetingLifecycle.finalized,
  currentVersion: TranscriptVersion(
    run: const TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-sensitive',
      provenance: InferenceProvenance(
        engineId: 'whisper.cpp',
        engineVersion: '1.7.6',
        modelId: 'base-q5',
        modelVersion: '1',
        modelSha256: 'abc123',
        parametersJson: '{"threads":4}',
      ),
      createdAtUtcMs: 1,
      state: AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2),
    ),
    segments: const [
      TranscriptSegment(
        id: 'segment-1',
        transcriptRunId: 'run-1',
        start: Duration(milliseconds: 1250),
        end: Duration(milliseconds: 3500),
        rawModelText: 'hello 世界',
        displayedText: 'Hello，世界。',
        revisionState: TranscriptRevisionState.corrected,
        languageDecisionId: 'language-1',
        speakerId: 'speaker-1',
      ),
      TranscriptSegment(
        id: 'segment-2',
        transcriptRunId: 'run-1',
        start: Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 4),
        end: Duration(hours: 1, minutes: 2, seconds: 5, milliseconds: 40),
        rawModelText: 'Line one\nLine two',
        displayedText: 'Line one\nLine two',
        revisionState: TranscriptRevisionState.machine,
        speakerId: 'speaker-2',
      ),
    ],
    isCurrent: true,
  ),
  languagesBySegmentId: const {
    'segment-1': LanguageDecision(
      id: 'language-1',
      transcriptSegmentId: 'segment-1',
      tag: LanguageTag.mixed,
      source: LanguageDecisionSource.manual,
      confidence: null,
    ),
  },
  speakersById: const {
    'speaker-1': Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-sensitive',
      analysisRunId: 'diarization-1',
      label: 'Alice',
    ),
    'speaker-2': Speaker(
      id: 'speaker-2',
      meetingId: 'meeting-sensitive',
      analysisRunId: 'diarization-1',
      label: 'Speaker 2',
    ),
  },
  revisions: const [
    Revision(
      id: 'revision-1',
      meetingId: 'meeting-sensitive',
      targetId: 'segment-1',
      change: TranscriptTextChange(
        previousText: 'hello 世界',
        revisedText: 'Hello，世界。',
      ),
      createdAtUtcMs: 3,
    ),
  ],
);
