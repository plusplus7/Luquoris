import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  testWidgets('stable transcript corrections are revisions and reload', (
    tester,
  ) async {
    final transcripts = _FakeTranscriptRepository(_document());
    final revisions = _FakeRevisionRepository(transcripts);

    await _pumpEditor(tester, transcripts, revisions);

    expect(find.byKey(const Key('transcript-text:segment-1')), findsOneWidget);
    expect(find.text('Speaker 1'), findsWidgets);
    expect(find.text('Chinese'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('transcript-text:segment-1')),
      'Corrected text',
    );
    await tester.tap(find.byKey(const Key('transcript-save:segment-1')));
    await tester.pumpAndSettle();

    expect(revisions.applied, hasLength(1));
    expect(revisions.applied.single.change, isA<TranscriptTextChange>());
    expect(find.text('Corrected text'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('revision-history-item')), findsOneWidget);
  });

  testWidgets('active draft is visible but cannot be edited', (tester) async {
    final transcripts = _FakeTranscriptRepository(
      _document(
        lifecycle: MeetingLifecycle.recording,
        state: const AnalysisRunning(startedAtUtcMs: 2, progress: 0.4),
      ),
    );
    final revisions = _FakeRevisionRepository(transcripts);

    await _pumpEditor(tester, transcripts, revisions);

    expect(find.text('Machine text'), findsOneWidget);
    expect(find.byKey(const Key('transcript-read-only')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(revisions.applied, isEmpty);
  });

  testWidgets('editor unlocks only after a stable durable run completes', (
    tester,
  ) async {
    final transcripts = _FakeTranscriptRepository(
      _document(includeVersion: false),
    );
    final revisions = _FakeRevisionRepository(transcripts);
    final jobs = FakeTranscriptionJobRepository();
    await jobs.enqueue(
      _transcriptionJob(),
      _transcriptionRun(),
      storedAtUtcMs: 1,
    );

    await _pumpEditor(tester, transcripts, revisions, jobs: jobs);

    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.text('No transcript version is selected for this meeting.'),
      findsOneWidget,
    );

    transcripts.document = _document();
    await jobs.complete(
      'job-1',
      _transcriptionRun(
        state: const AnalysisCompleted(
          startedAtUtcMs: 2,
          endedAtUtcMs: 3,
        ),
      ),
      const [_stableSegment],
      storedAtUtcMs: 3,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transcript-text:segment-1')), findsOneWidget);
  });

  testWidgets('language and speaker corrections use typed revisions', (
    tester,
  ) async {
    final transcripts = _FakeTranscriptRepository(_document());
    final revisions = _FakeRevisionRepository(transcripts);

    await _pumpEditor(tester, transcripts, revisions);

    await tester.tap(find.byKey(const Key('transcript-language:segment-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chinese + English').last);
    await tester.pumpAndSettle();
    expect(revisions.applied.single.change, isA<LanguageLabelChange>());

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rename speaker'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alice');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(revisions.applied, hasLength(2));
    expect(revisions.applied.last.change, isA<SpeakerLabelChange>());
  });

  testWidgets('committed correction remains visible when refresh fails', (
    tester,
  ) async {
    final transcripts = _FakeTranscriptRepository(_document());
    final revisions = _FakeRevisionRepository(transcripts);

    await _pumpEditor(tester, transcripts, revisions);
    transcripts.failNextLoad = true;

    await tester.enterText(
      find.byKey(const Key('transcript-text:segment-1')),
      'Corrected text',
    );
    await tester.tap(find.byKey(const Key('transcript-save:segment-1')));
    await tester.pumpAndSettle();

    expect(revisions.applied, hasLength(1));
    expect(find.text('Corrected text'), findsOneWidget);
    expect(
      find.text(
        'Correction saved, but the latest data could not be refreshed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaving while a correction is pending has no async error', (
    tester,
  ) async {
    final transcripts = _FakeTranscriptRepository(_document());
    final gate = Completer<void>();
    final revisions = _BlockingRevisionRepository(transcripts, gate);

    await _pumpEditor(tester, transcripts, revisions);
    await tester.enterText(
      find.byKey(const Key('transcript-text:segment-1')),
      'Corrected text',
    );
    await tester.tap(find.byKey(const Key('transcript-save:segment-1')));
    await tester.pump();

    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(context).read(appRouterProvider).go('/sessions');
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  TranscriptRepository transcripts,
  RevisionRepository revisions, {
  FakeTranscriptionJobRepository? jobs,
}) async {
  final jobRepository = jobs ?? FakeTranscriptionJobRepository();
  addTearDown(jobRepository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        transcriptRepositoryProvider.overrideWithValue(transcripts),
        transcriptionJobRepositoryProvider.overrideWithValue(jobRepository),
        revisionRepositoryProvider.overrideWithValue(revisions),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.fromMillisecondsSinceEpoch(10, isUtc: true)),
        ),
      ],
      child: const LoquirisApp(),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byType(LoquirisApp));
  ProviderScope.containerOf(
    context,
  ).read(appRouterProvider).go('/sessions/meeting-1/edit');
  await tester.pumpAndSettle();
}

TranscriptEditorDocument _document({
  MeetingLifecycle lifecycle = MeetingLifecycle.finalized,
  AnalysisState state = const AnalysisCompleted(
    startedAtUtcMs: 2,
    endedAtUtcMs: 3,
  ),
  bool includeVersion = true,
}) {
  return TranscriptEditorDocument(
    meetingId: 'meeting-1',
    lifecycle: lifecycle,
    currentVersion: includeVersion
        ? TranscriptVersion(
            run: _transcriptionRun(state: state),
            segments: const [_stableSegment],
            isCurrent: true,
          )
        : null,
    languagesBySegmentId: const {
      'segment-1': LanguageDecision(
        id: 'language-1',
        transcriptSegmentId: 'segment-1',
        tag: LanguageTag.chinese,
        source: LanguageDecisionSource.automatic,
        confidence: 0.9,
      ),
    },
    speakersById: const {
      'speaker-1': Speaker(
        id: 'speaker-1',
        meetingId: 'meeting-1',
        analysisRunId: 'diarization-1',
        label: 'Speaker 1',
      ),
    },
    revisions: const [],
  );
}

ProcessingJob _transcriptionJob() => const ProcessingJob(
  id: 'job-1',
  meetingId: 'meeting-1',
  kind: ProcessingJobKind.transcription,
  createdAtUtcMs: 1,
  state: ProcessingQueued(),
  targetRunId: 'run-1',
  modelId: 'model',
);

TranscriptRun _transcriptionRun({
  AnalysisState state = const AnalysisQueued(),
}) => TranscriptRun(
  id: 'run-1',
  meetingId: 'meeting-1',
  provenance: const InferenceProvenance(
    engineId: 'engine',
    engineVersion: '1',
    modelId: 'model',
    modelVersion: '1',
    modelSha256: 'hash',
    parametersJson: '{}',
  ),
  createdAtUtcMs: 2,
  state: state,
);

const _stableSegment = TranscriptSegment(
  id: 'segment-1',
  transcriptRunId: 'run-1',
  start: Duration.zero,
  end: Duration(seconds: 2),
  rawModelText: 'Machine text',
  displayedText: 'Machine text',
  revisionState: TranscriptRevisionState.machine,
  languageDecisionId: 'language-1',
  speakerId: 'speaker-1',
);

final class _FakeTranscriptRepository implements TranscriptRepository {
  _FakeTranscriptRepository(this.document);

  TranscriptEditorDocument document;
  bool failNextLoad = false;

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async {
    if (failNextLoad) {
      failNextLoad = false;
      return const Err(AnalysisStoreUnavailable('editor_reload_failed'));
    }
    return Ok(document);
  }

  @override
  Stream<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  watchVersions(String meetingId) async* {
    yield await listVersions(meetingId);
  }

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async => Ok([?document.currentVersion]);

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectReadableVersion(
    TranscriptRun expectedRun,
    TranscriptProcessingInfo? expectedProcessing, {
    required int selectedAtUtcMs,
  }) => selectCurrent(
    expectedRun.meetingId,
    expectedRun.id,
    selectedAtUtcMs: selectedAtUtcMs,
  );

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  }) async => const Ok(null);

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  }) async =>
      Ok(TranscriptVersion(run: run, segments: segments, isCurrent: false));
}

final class _FakeRevisionRepository implements RevisionRepository {
  _FakeRevisionRepository(this.transcripts);

  final _FakeTranscriptRepository transcripts;
  final List<Revision> applied = [];

  @override
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(
    Revision revision,
  ) async {
    applied.add(revision);
    final current = transcripts.document.currentVersion!;
    final segments = current.segments.map((segment) {
      if (segment.id != revision.targetId) return segment;
      return switch (revision.change) {
        TranscriptTextChange(:final revisedText) => segment.copyWith(
          displayedText: revisedText,
          revisionState: TranscriptRevisionState.corrected,
        ),
        _ => segment,
      };
    }).toList();
    transcripts.document = TranscriptEditorDocument(
      meetingId: transcripts.document.meetingId,
      lifecycle: transcripts.document.lifecycle,
      currentVersion: TranscriptVersion(
        run: current.run,
        segments: segments,
        isCurrent: true,
      ),
      languagesBySegmentId: transcripts.document.languagesBySegmentId,
      speakersById: transcripts.document.speakersById,
      revisions: [...transcripts.document.revisions, revision],
    );
    return Ok(revision);
  }

  @override
  Future<Result<List<Revision>, AnalysisRepositoryFailure>> listMeeting(
    String meetingId,
  ) async => Ok(List.unmodifiable(applied));

  @override
  Future<Result<SpeakerAssignment, AnalysisRepositoryFailure>>
  materializeSpeakerAssignment(SpeakerAssignment rawAssignment) async =>
      Ok(rawAssignment);

  @override
  Future<Result<Speaker, AnalysisRepositoryFailure>> materializeSpeaker(
    Speaker rawSpeaker,
  ) async => Ok(rawSpeaker);
}

final class _BlockingRevisionRepository extends _FakeRevisionRepository {
  _BlockingRevisionRepository(super.transcripts, this.gate);

  final Completer<void> gate;

  @override
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(
    Revision revision,
  ) async {
    await gate.future;
    return super.apply(revision);
  }
}
