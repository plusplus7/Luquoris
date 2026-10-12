import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/features/export_backup/domain/export_entities.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';

void main() {
  test('meeting identity survives immutable edits', () {
    const meeting = Meeting(
      id: 'meeting-1',
      title: 'Planning',
      createdAtUtcMs: 1,
      mediaDuration: Duration(minutes: 5),
      lifecycle: MeetingLifecycle.finalized,
      languageMode: MeetingLanguageMode.mixed,
      transcriptionMode: MeetingTranscriptionMode.nearRealTime,
      expectedSpeakerCount: 4,
      currentTranscriptRunId: 'run-1',
    );

    final renamed = meeting.copyWith(title: 'Planning review');

    expect(renamed.id, meeting.id);
    expect(renamed.title, 'Planning review');
    expect(renamed.currentTranscriptRunId, 'run-1');
    expect(renamed.transcriptionMode, MeetingTranscriptionMode.nearRealTime);
    expect(renamed.expectedSpeakerCount, 4);
    expect(renamed, isNot(meeting));
  });

  test('trashed meeting retains the lifecycle restored later', () {
    const meeting = Meeting(
      id: 'meeting-1',
      title: 'Interrupted recording',
      createdAtUtcMs: 1,
      mediaDuration: Duration(minutes: 5),
      lifecycle: MeetingLifecycle.trashed,
      lifecycleBeforeTrash: MeetingLifecycle.recoverable,
      languageMode: MeetingLanguageMode.mixed,
      trashedAtUtcMs: 2,
    );

    expect(meeting.lifecycleBeforeTrash, MeetingLifecycle.recoverable);
    expect(
      meeting
          .copyWith(
            lifecycle: meeting.lifecycleBeforeTrash,
            lifecycleBeforeTrash: null,
            trashedAtUtcMs: null,
          )
          .lifecycle,
      MeetingLifecycle.recoverable,
    );
  });

  test('audio, event, and bookmark preserve independent timelines', () {
    final audio = AudioSegment(
      id: 'audio-1',
      meetingId: 'meeting-1',
      sequence: 0,
      relativePath: _path('meetings/meeting-1/0000.aac'),
      mediaStart: Duration.zero,
      mediaDuration: const Duration(minutes: 5),
      committedBytes: 1200,
      state: AudioSegmentState.committed,
    );
    const event = SessionEvent(
      id: 'event-1',
      meetingId: 'meeting-1',
      sequence: 1,
      type: SessionEventType.pausedByUser,
      wallClockUtcMs: 10000,
      monotonicElapsed: Duration(seconds: 20),
      mediaOffset: Duration(seconds: 15),
    );
    const bookmark = Bookmark(
      id: 'bookmark-1',
      meetingId: 'meeting-1',
      mediaOffset: Duration(seconds: 15),
      kind: BookmarkKind.highlight,
      createdAtUtcMs: 10001,
    );

    expect(audio.relativePath.value.startsWith('/'), isFalse);
    expect(event.monotonicElapsed, isNot(event.mediaOffset));
    expect(bookmark.mediaOffset, event.mediaOffset);
  });

  test('transcript versions retain raw output and human revisions', () {
    const run = TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: InferenceProvenance(
        engineId: 'whisper.cpp',
        engineVersion: '1.7.6',
        modelId: 'whisper-base-q5',
        modelVersion: '1',
        modelSha256: 'abc123',
        parametersJson: '{"threads":4,"language":"mixed"}',
      ),
      createdAtUtcMs: 20,
      state: AnalysisCompleted(startedAtUtcMs: 21, endedAtUtcMs: 22),
    );
    const segment = TranscriptSegment(
      id: 'segment-1',
      transcriptRunId: 'run-1',
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      rawModelText: 'hello 世界',
      displayedText: 'Hello，世界。',
      revisionState: TranscriptRevisionState.corrected,
      languageDecisionId: 'language-1',
      speakerId: 'speaker-1',
    );
    const revision = Revision(
      id: 'revision-1',
      meetingId: 'meeting-1',
      targetId: 'segment-1',
      change: TranscriptTextChange(
        previousText: 'hello 世界',
        revisedText: 'Hello，世界。',
      ),
      createdAtUtcMs: 30,
    );

    expect(run.id, segment.transcriptRunId);
    expect(segment.rawModelText, isNot(segment.displayedText));
    expect(revision.targetId, segment.id);
  });

  test('speaker and language identities remain meeting and run local', () {
    const speaker = Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-1',
      analysisRunId: 'diarization-1',
      label: 'Speaker 1',
    );
    const language = LanguageDecision(
      id: 'language-1',
      transcriptSegmentId: 'segment-1',
      tag: LanguageTag.mixed,
      source: LanguageDecisionSource.manual,
      confidence: null,
    );

    expect(speaker.meetingId, 'meeting-1');
    expect(speaker.analysisRunId, 'diarization-1');
    expect(language.tag, LanguageTag.mixed);
    expect(language.source, LanguageDecisionSource.manual);
  });

  test('jobs, models, and exports encode success and failure as variants', () {
    final model = InstalledModel(
      id: 'whisper-base-q5',
      version: '1',
      source: 'https://huggingface.co/ggerganov/whisper.cpp',
      sha256: 'abc123',
      bytes: 100,
      capabilities: const <ModelCapability>[ModelCapability.transcription],
      expectedEngineId: 'whisper.cpp',
      licenseId: 'MIT',
      licenseSnapshotPath: _path('licenses/whisper-base-q5.txt'),
      enabledModes: const <PerformanceMode>[PerformanceMode.postSession],
    );
    const job = ProcessingJob(
      id: 'job-1',
      meetingId: 'meeting-1',
      kind: ProcessingJobKind.transcription,
      createdAtUtcMs: 40,
      state: ProcessingRunning(progress: 0.5),
    );
    final export = ExportRecord(
      id: 'export-1',
      meetingId: 'meeting-1',
      format: LocalExportFormat.json,
      createdAtUtcMs: 50,
      state: ExportCompleted(
        relativePath: _path('exports/meeting-1.json'),
        bytes: 200,
      ),
    );

    expect(model.capabilities, contains(ModelCapability.transcription));
    expect(job.state, const ProcessingRunning(progress: 0.5));
    expect(
      export.state,
      ExportCompleted(
        relativePath: _path('exports/meeting-1.json'),
        bytes: 200,
      ),
    );
  });

  test('domain values support structural equality and immutable updates', () {
    final audio = AudioSegment(
      id: 'audio-1',
      meetingId: 'meeting-1',
      sequence: 0,
      relativePath: _path('meetings/meeting-1/0000.aac'),
      mediaStart: Duration.zero,
      mediaDuration: const Duration(seconds: 10),
      committedBytes: 20,
      state: AudioSegmentState.open,
    );
    const event = SessionEvent(
      id: 'event-1',
      meetingId: 'meeting-1',
      sequence: 1,
      type: SessionEventType.started,
      wallClockUtcMs: 1,
      monotonicElapsed: Duration.zero,
      mediaOffset: Duration.zero,
    );
    const bookmark = Bookmark(
      id: 'bookmark-1',
      meetingId: 'meeting-1',
      mediaOffset: Duration(seconds: 2),
      kind: BookmarkKind.bookmark,
      createdAtUtcMs: 2,
    );
    const run = TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: InferenceProvenance(
        engineId: 'engine-1',
        engineVersion: '1',
        modelId: 'model-1',
        modelVersion: '1',
        modelSha256: 'abc',
        parametersJson: '{}',
      ),
      createdAtUtcMs: 3,
      state: AnalysisRunning(startedAtUtcMs: 4, progress: 0.2),
    );
    const segment = TranscriptSegment(
      id: 'segment-1',
      transcriptRunId: 'run-1',
      start: Duration.zero,
      end: Duration(seconds: 2),
      rawModelText: 'raw',
      displayedText: 'raw',
      revisionState: TranscriptRevisionState.machine,
    );
    const language = LanguageDecision(
      id: 'language-1',
      transcriptSegmentId: 'segment-1',
      tag: LanguageTag.uncertain,
      source: LanguageDecisionSource.automatic,
      confidence: 0.4,
    );
    const revision = Revision(
      id: 'revision-1',
      meetingId: 'meeting-1',
      targetId: 'segment-1',
      change: TranscriptTextChange(
        previousText: 'raw',
        revisedText: 'edited',
      ),
      createdAtUtcMs: 4,
    );
    const speaker = Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-1',
      analysisRunId: 'analysis-1',
      label: 'Speaker 1',
    );
    const job = ProcessingJob(
      id: 'job-1',
      meetingId: 'meeting-1',
      kind: ProcessingJobKind.transcription,
      createdAtUtcMs: 5,
      state: ProcessingQueued(),
    );
    final model = InstalledModel(
      id: 'model-1',
      version: '1',
      source: 'https://example.invalid/model-source',
      sha256: 'abc',
      bytes: 10,
      capabilities: const <ModelCapability>[ModelCapability.transcription],
      expectedEngineId: 'engine-1',
      licenseId: 'MIT',
      licenseSnapshotPath: _path('licenses/model-1.txt'),
      enabledModes: const <PerformanceMode>[PerformanceMode.postSession],
    );
    const export = ExportRecord(
      id: 'export-1',
      meetingId: 'meeting-1',
      format: LocalExportFormat.audioM4a,
      createdAtUtcMs: 6,
      state: ExportPending(),
    );

    expect(audio.copyWith(state: AudioSegmentState.committed), isNot(audio));
    expect(event.copyWith(type: SessionEventType.stopped), isNot(event));
    expect(bookmark.copyWith(kind: BookmarkKind.highlight), isNot(bookmark));
    expect(run, run.copyWith());
    expect(segment.copyWith(displayedText: 'edited'), isNot(segment));
    expect(language.copyWith(tag: LanguageTag.mixed), isNot(language));
    expect(
      revision,
      const Revision(
        id: 'revision-1',
        meetingId: 'meeting-1',
        targetId: 'segment-1',
        change: TranscriptTextChange(
          previousText: 'raw',
          revisedText: 'edited',
        ),
        createdAtUtcMs: 4,
      ),
    );
    expect(speaker, speaker.copyWith());
    expect(const ProcessingQueued(), const ProcessingQueued());
    expect(
      const ProcessingPaused(reasonCode: 'thermal'),
      const ProcessingPaused(reasonCode: 'thermal'),
    );
    expect(const ProcessingSucceeded(), const ProcessingSucceeded());
    expect(
      const ProcessingFailed(failureCode: 'engine'),
      const ProcessingFailed(failureCode: 'engine'),
    );
    expect(job, job.copyWith());
    expect(model, model.copyWith());
    expect(const ExportPending(), const ExportPending());
    expect(
      const ExportFailed(failureCode: 'storage'),
      const ExportFailed(failureCode: 'storage'),
    );
    expect(export, export.copyWith());
  });
}

AppRelativePath _path(String value) => AppRelativePath.tryParse(value).fold(
  (path) => path,
  (failure) => throw StateError(failure.code),
);
