import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_status.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  testWidgets('shows durable progress and completed transcript preview', (
    tester,
  ) async {
    final jobs = FakeTranscriptionJobRepository();
    final transcripts = _TranscriptRepository(_document());
    addTearDown(jobs.dispose);
    await jobs.enqueue(_job(), _run(), storedAtUtcMs: 1);
    await _pumpStatus(tester, jobs: jobs, transcripts: transcripts);

    expect(find.text('Preparing the offline model'), findsOneWidget);

    await jobs.start('job-1', startedAtUtcMs: 2);
    await jobs.saveProgress(
      'job-1',
      progress: 0.42,
      checkpoint: const TranscriptionCheckpoint(
        completedMedia: Duration(seconds: 4),
        parameterVersion: 1,
      ),
      storedAtUtcMs: 3,
    );
    await tester.pumpAndSettle();
    expect(find.text('Transcribing locally 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    transcripts.document = _document(completed: true);
    await jobs.complete(
      'job-1',
      _run(
        state: const AnalysisCompleted(
          startedAtUtcMs: 2,
          endedAtUtcMs: 4,
        ),
      ),
      const [_segment],
      storedAtUtcMs: 4,
    );
    await tester.pumpAndSettle();

    expect(find.text('Transcript preview'), findsOneWidget);
    expect(find.text('Stable text'), findsOneWidget);
    expect(find.text('Transcription completed'), findsOneWidget);
  });

  testWidgets('maps typed failure to safe copy and coalesces retry taps', (
    tester,
  ) async {
    final jobs = FakeTranscriptionJobRepository();
    final transcripts = _TranscriptRepository(_document());
    final gate = Completer<void>();
    var retryCalls = 0;
    addTearDown(jobs.dispose);
    await jobs.enqueue(
      _job(
        state: const ProcessingFailed(
          failureCode: 'model_sha256_mismatch',
        ),
      ),
      _run(
        state: const AnalysisFailed(
          startedAtUtcMs: 1,
          endedAtUtcMs: 2,
          progress: 0,
          failureCode: 'model_sha256_mismatch',
        ),
      ),
      storedAtUtcMs: 1,
    );
    await _pumpStatus(
      tester,
      jobs: jobs,
      transcripts: transcripts,
      retry: (jobId) async {
        retryCalls += 1;
        await gate.future;
      },
    );

    final safeFailure = find.text(
      'The bundled transcription model could not be verified. Your recording is safe.',
    );
    expect(safeFailure, findsOneWidget);
    expect(find.textContaining('model_sha256_mismatch'), findsNothing);
    expect(
      tester.getSemantics(safeFailure),
      isSemantics(
        label:
            'The bundled transcription model could not be verified. Your recording is safe.',
        isLiveRegion: true,
      ),
    );

    await tester.tap(find.byKey(const Key('transcription-retry')));
    await tester.pump();
    expect(retryCalls, 1);
    expect(find.text('Retrying transcription…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(retryCalls, 1);
  });

  testWidgets('shows a durable warning when only committed audio was used', (
    tester,
  ) async {
    final jobs = FakeTranscriptionJobRepository();
    final transcripts = _TranscriptRepository(_document(completed: true));
    addTearDown(jobs.dispose);
    await jobs.enqueue(
      _job(
        state: const ProcessingSucceededWithWarning(
          warningCode: 'transcription_audio_uncommitted_tail',
        ),
      ),
      _run(
        state: const AnalysisCompleted(
          startedAtUtcMs: 2,
          endedAtUtcMs: 4,
        ),
      ),
      storedAtUtcMs: 1,
    );

    await _pumpStatus(tester, jobs: jobs, transcripts: transcripts);

    expect(
      find.text(
        'The transcript is incomplete. Your recording is safe and you can try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('remains readable at two hundred percent text scale', (
    tester,
  ) async {
    final jobs = FakeTranscriptionJobRepository();
    final transcripts = _TranscriptRepository(_document());
    addTearDown(jobs.dispose);
    await jobs.enqueue(
      _job(state: const ProcessingRunning(progress: 0.68)),
      _run(
        state: const AnalysisRunning(startedAtUtcMs: 2, progress: 0.68),
      ),
      storedAtUtcMs: 1,
    );
    await _pumpStatus(
      tester,
      jobs: jobs,
      transcripts: transcripts,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('Transcribing locally 68%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpStatus(
  WidgetTester tester, {
  required FakeTranscriptionJobRepository jobs,
  required TranscriptRepository transcripts,
  TranscriptionRetryHandler? retry,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transcriptionJobRepositoryProvider.overrideWithValue(jobs),
        transcriptRepositoryProvider.overrideWithValue(transcripts),
        if (retry != null)
          transcriptionRetryHandlerProvider.overrideWithValue(retry),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: MeetingTranscriptionStatus(meetingId: 'meeting-1'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProcessingJob _job({ProcessingState state = const ProcessingQueued()}) =>
    ProcessingJob(
      id: 'job-1',
      meetingId: 'meeting-1',
      kind: ProcessingJobKind.transcription,
      createdAtUtcMs: 1,
      state: state,
      targetRunId: 'run-1',
      modelId: 'model-1',
    );

TranscriptRun _run({AnalysisState state = const AnalysisQueued()}) =>
    TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: const InferenceProvenance(
        engineId: 'engine-1',
        engineVersion: '1',
        modelId: 'model-1',
        modelVersion: '1',
        modelSha256: 'hash',
        parametersJson: '{}',
      ),
      createdAtUtcMs: 1,
      state: state,
    );

const _segment = TranscriptSegment(
  id: 'segment-1',
  transcriptRunId: 'run-1',
  start: Duration.zero,
  end: Duration(seconds: 2),
  rawModelText: 'Stable text',
  displayedText: 'Stable text',
  revisionState: TranscriptRevisionState.machine,
);

TranscriptEditorDocument _document({bool completed = false}) =>
    TranscriptEditorDocument(
      meetingId: 'meeting-1',
      lifecycle: MeetingLifecycle.finalized,
      currentVersion: completed
          ? TranscriptVersion(
              run: _run(
                state: const AnalysisCompleted(
                  startedAtUtcMs: 2,
                  endedAtUtcMs: 4,
                ),
              ),
              segments: const [_segment],
              isCurrent: true,
            )
          : null,
      languagesBySegmentId: const {},
      speakersById: const {},
      revisions: const [],
    );

final class _TranscriptRepository implements TranscriptRepository {
  _TranscriptRepository(this.document);

  TranscriptEditorDocument document;

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async => Ok(document);

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
