import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';

void main() {
  test('app-relative paths reject absolute and traversal input', () {
    expect(
      AppRelativePath.tryParse('meetings/m-1/0001.aac'),
      isA<Ok<AppRelativePath, InvalidAppRelativePath>>(),
    );
    expect(
      AppRelativePath.tryParse('/private/audio.aac'),
      isA<Err<AppRelativePath, InvalidAppRelativePath>>(),
    );
    expect(
      AppRelativePath.tryParse('../audio.aac'),
      isA<Err<AppRelativePath, InvalidAppRelativePath>>(),
    );
    expect(
      AppRelativePath.tryParse('meetings/../audio.aac'),
      isA<Err<AppRelativePath, InvalidAppRelativePath>>(),
    );
    expect(
      AppRelativePath.tryParse(r'C:\audio.aac'),
      isA<Err<AppRelativePath, InvalidAppRelativePath>>(),
    );
  });

  test('failed transcript run retains complete reproducible provenance', () {
    const provenance = InferenceProvenance(
      engineId: 'whisper.cpp',
      engineVersion: '1.7.6',
      modelId: 'whisper-base-q5',
      modelVersion: '1',
      modelSha256: 'abc123',
      parametersJson: '{"threads":4,"language":"mixed"}',
    );
    const run = TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: provenance,
      createdAtUtcMs: 10,
      state: AnalysisFailed(
        startedAtUtcMs: 11,
        endedAtUtcMs: 12,
        progress: 0.4,
        failureCode: 'engine_decode_failed',
      ),
    );

    expect(run.provenance, provenance);
    expect(run.state, isA<AnalysisFailed>());
    expect((run.state as AnalysisFailed).failureCode, 'engine_decode_failed');
  });

  test('diarization run owns interval assignments and uncertainty', () {
    const run = DiarizationRun(
      id: 'diarization-1',
      meetingId: 'meeting-1',
      provenance: InferenceProvenance(
        engineId: 'sherpa-onnx',
        engineVersion: '1',
        modelId: 'speaker-model',
        modelVersion: '1',
        modelSha256: 'def456',
        parametersJson: '{"expectedSpeakers":6}',
      ),
      createdAtUtcMs: 20,
      state: AnalysisCompleted(startedAtUtcMs: 21, endedAtUtcMs: 30),
    );
    const assignment = SpeakerAssignment(
      id: 'assignment-1',
      analysisRunId: 'diarization-1',
      speakerId: 'speaker-1',
      start: Duration(seconds: 4),
      end: Duration(seconds: 7),
      confidence: 0.3,
      isOverlap: true,
      needsConfirmation: true,
    );

    expect(assignment.analysisRunId, run.id);
    expect(assignment.needsConfirmation, isTrue);
    expect(assignment.isOverlap, isTrue);
  });

  test('model manifest carries distribution and runtime compatibility', () {
    final licensePath = AppRelativePath.tryParse(
      'licenses/whisper-base-q5.txt',
    ).fold((value) => value, (failure) => throw StateError(failure.code));
    final model = InstalledModel(
      id: 'whisper-base-q5',
      version: '1',
      source: 'https://huggingface.co/ggerganov/whisper.cpp',
      sha256: 'abc123',
      bytes: 100,
      capabilities: const <ModelCapability>[
        ModelCapability.transcription,
        ModelCapability.languageIdentification,
      ],
      expectedEngineId: 'whisper.cpp',
      licenseId: 'MIT',
      licenseSnapshotPath: licensePath,
      enabledModes: const <PerformanceMode>[
        PerformanceMode.balanced,
        PerformanceMode.postSession,
      ],
    );

    expect(model.expectedEngineId, 'whisper.cpp');
    expect(model.licenseSnapshotPath, licensePath);
    expect(model.enabledModes, contains(PerformanceMode.postSession));
  });

  test('nullable transcript metadata can be explicitly cleared', () {
    const segment = TranscriptSegment(
      id: 'segment-1',
      transcriptRunId: 'run-1',
      start: Duration.zero,
      end: Duration(seconds: 1),
      rawModelText: 'hello',
      displayedText: 'hello',
      revisionState: TranscriptRevisionState.machine,
      languageDecisionId: 'language-1',
      speakerId: 'speaker-1',
    );
    const language = LanguageDecision(
      id: 'language-1',
      transcriptSegmentId: 'segment-1',
      tag: LanguageTag.english,
      source: LanguageDecisionSource.automatic,
      confidence: 0.9,
    );

    expect(
      segment.copyWith(languageDecisionId: null, speakerId: null),
      const TranscriptSegment(
        id: 'segment-1',
        transcriptRunId: 'run-1',
        start: Duration.zero,
        end: Duration(seconds: 1),
        rawModelText: 'hello',
        displayedText: 'hello',
        revisionState: TranscriptRevisionState.machine,
      ),
    );
    expect(language.copyWith(confidence: null).confidence, isNull);
  });

  test('trash timing and typed revision payload remain explicit', () {
    const meeting = Meeting(
      id: 'meeting-1',
      title: 'Planning',
      createdAtUtcMs: 1,
      mediaDuration: Duration(minutes: 1),
      lifecycle: MeetingLifecycle.trashed,
      lifecycleBeforeTrash: MeetingLifecycle.finalized,
      languageMode: MeetingLanguageMode.mixed,
      trashedAtUtcMs: 2,
    );
    const revision = Revision(
      id: 'revision-1',
      meetingId: 'meeting-1',
      targetId: 'assignment-1',
      change: SpeakerAssignmentChange(
        start: Duration(seconds: 4),
        end: Duration(seconds: 7),
        previousSpeakerId: 'speaker-1',
        revisedSpeakerId: null,
        needsConfirmation: true,
      ),
      createdAtUtcMs: 3,
    );

    expect(meeting.trashedAtUtcMs, 2);
    expect(revision.change, isA<SpeakerAssignmentChange>());
  });
}
