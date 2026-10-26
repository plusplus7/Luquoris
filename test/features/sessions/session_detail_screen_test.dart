import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('detail exposes playback and every durable meeting timeline', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final repository = FakeSessionRepository()..detailResult = Ok(_detail());
    final playback = FakeSessionPlaybackService()
      ..loadResult = const Ok(_ready)
      ..seekResult = const Ok(
        SessionPlaybackSnapshot(
          sessionId: 'meeting-1',
          state: SessionPlaybackState.ready,
          position: Duration(seconds: 4),
          duration: Duration(seconds: 10),
        ),
      )
      ..playResult = const Ok(
        SessionPlaybackSnapshot(
          sessionId: 'meeting-1',
          state: SessionPlaybackState.playing,
          position: Duration(seconds: 4),
          duration: Duration(seconds: 10),
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionPlaybackServiceProvider.overrideWithValue(playback),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/sessions/meeting-1?atUs=4000000');
    await tester.pumpAndSettle();

    expect(find.text('Project sync'), findsOneWidget);
    expect(
      find.byKey(const Key('session-detail-open-editor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('session-detail-open-export')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('session-detail-playback')), findsOneWidget);
    expect(find.text('00:04 / 00:10'), findsOneWidget);
    expect(
      find.byKey(const Key('session-detail-segment:segment-1')),
      findsOneWidget,
    );
    expect(find.textContaining('Saved'), findsOneWidget);
    expect(find.textContaining('committed'), findsNothing);
    expect(
      find.byKey(const Key('session-detail-marker:bookmark-1')),
      findsOneWidget,
    );
    expect(playback.seekCalls, [const Duration(seconds: 4)]);

    await tester.tap(find.byKey(const Key('session-detail-play')));
    await tester.pump();
    expect(playback.playCalls, 1);

    await tester.scrollUntilVisible(
      find.byKey(const Key('session-detail-event:event-1')),
      300,
    );
    expect(
      find.byKey(const Key('session-detail-event:event-1')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Audio preparation failed. Original audio remains safe.'),
      300,
    );
    expect(
      find.text('Audio preparation failed. Original audio remains safe.'),
      findsOneWidget,
    );
    expect(find.text('Audio preparation'), findsOneWidget);
    expect(find.text('audioMerge'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(
        'An uncommitted audio tail was discarded during recovery.',
      ),
      300,
    );
    expect(
      find.text('An uncommitted audio tail was discarded during recovery.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('session-detail-marker:bookmark-1')),
      -300,
    );
    await tester.tap(find.byKey(const Key('session-detail-marker:bookmark-1')));
    await tester.pumpAndSettle();
    expect(playback.seekCalls, [
      const Duration(seconds: 4),
      const Duration(seconds: 4),
    ]);
  });

  testWidgets('playback failure leaves durable meeting details available', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final repository = FakeSessionRepository()..detailResult = Ok(_detail());
    final playback = FakeSessionPlaybackService()
      ..loadResult = const Err(
        SessionPlaybackFailure('recording_m4a_artifact_not_ready'),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionPlaybackServiceProvider.overrideWithValue(playback),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/sessions/meeting-1');
    await tester.pumpAndSettle();

    expect(find.text('Project sync'), findsOneWidget);
    expect(
      find.text('Playback audio is being prepared from saved segments.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('session-detail-marker:bookmark-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('session-detail-play')), findsNothing);
  });

  testWidgets(
    'durable transcription refreshes progress and preview without disturbing playback',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      final repository = FakeSessionRepository()..detailResult = Ok(_detail());
      final playback = FakeSessionPlaybackService()
        ..loadResult = const Ok(_ready);
      final jobs = FakeTranscriptionJobRepository();
      final transcripts = _TranscriptRepository(_transcriptDocument());
      addTearDown(jobs.dispose);
      await jobs.enqueue(
        _transcriptionJob(),
        _transcriptionRun(),
        storedAtUtcMs: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(repository),
            sessionPlaybackServiceProvider.overrideWithValue(playback),
            transcriptionJobRepositoryProvider.overrideWithValue(jobs),
            transcriptRepositoryProvider.overrideWithValue(transcripts),
          ],
          child: const LoquirisApp(),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(LoquirisApp));
      ProviderScope.containerOf(
        context,
      ).read(appRouterProvider).go('/sessions/meeting-1');
      await tester.pumpAndSettle();

      expect(find.text('Preparing the offline model'), findsOneWidget);
      expect(find.byKey(const Key('session-detail-playback')), findsOneWidget);

      await jobs.start('transcription-job', startedAtUtcMs: 2);
      await jobs.saveProgress(
        'transcription-job',
        progress: 0.42,
        checkpoint: const TranscriptionCheckpoint(
          completedMedia: Duration(seconds: 4),
          parameterVersion: 1,
        ),
        storedAtUtcMs: 3,
      );
      await tester.pumpAndSettle();
      expect(find.text('Transcribing locally 42%'), findsOneWidget);
      expect(find.byKey(const Key('session-detail-play')), findsOneWidget);

      transcripts.document = _transcriptDocument(completed: true);
      await jobs.complete(
        'transcription-job',
        _transcriptionRun(
          state: const AnalysisCompleted(
            startedAtUtcMs: 2,
            endedAtUtcMs: 4,
          ),
        ),
        const [_transcriptSegment],
        storedAtUtcMs: 4,
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript preview'), findsOneWidget);
      expect(find.text('Stable detail text'), findsOneWidget);
      expect(find.byKey(const Key('session-detail-play')), findsOneWidget);
    },
  );

  testWidgets('play command failure is explained without hiding details', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final repository = FakeSessionRepository()..detailResult = Ok(_detail());
    final playback = FakeSessionPlaybackService()
      ..loadResult = const Ok(_ready)
      ..playResult = const Err(SessionPlaybackFailure('playback_start_failed'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionPlaybackServiceProvider.overrideWithValue(playback),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/sessions/meeting-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-detail-play')));
    await tester.pump();

    expect(find.text('Project sync'), findsOneWidget);
    final failure = find.text(
      'Playback is unavailable. Meeting details and original saved audio are unchanged.',
    );
    expect(failure, findsOneWidget);
    expect(
      tester.getSemantics(failure),
      isSemantics(
        label:
            'Playback is unavailable. Meeting details and original saved audio are unchanged.',
        isLiveRegion: true,
      ),
    );
  });

  testWidgets('foreign playback snapshots are rejected', (tester) async {
    tester.useDevice(TestDevice.compact);
    final repository = FakeSessionRepository()..detailResult = Ok(_detail());
    final playback = FakeSessionPlaybackService()
      ..loadResult = const Ok(_ready)
      ..playResult = const Ok(
        SessionPlaybackSnapshot(
          sessionId: 'meeting-2',
          state: SessionPlaybackState.playing,
          position: Duration.zero,
          duration: Duration(seconds: 20),
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionPlaybackServiceProvider.overrideWithValue(playback),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(LoquirisApp));
    ProviderScope.containerOf(
      context,
    ).read(appRouterProvider).go('/sessions/meeting-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-detail-play')));
    await tester.pump();

    expect(find.text('00:00 / 00:10'), findsOneWidget);
    expect(
      find.text(
        'Playback is unavailable. Meeting details and original saved audio are unchanged.',
      ),
      findsOneWidget,
    );
  });
}

const _ready = SessionPlaybackSnapshot(
  sessionId: 'meeting-1',
  state: SessionPlaybackState.ready,
  position: Duration.zero,
  duration: Duration(seconds: 10),
);

SessionDetail _detail() => SessionDetail(
  meeting: const Meeting(
    id: 'meeting-1',
    title: 'Project sync',
    createdAtUtcMs: 1000,
    mediaDuration: Duration(seconds: 10),
    lifecycle: MeetingLifecycle.finalized,
    languageMode: MeetingLanguageMode.mixed,
  ),
  segments: [
    AudioSegment(
      id: 'segment-1',
      meetingId: 'meeting-1',
      sequence: 0,
      relativePath: _path('recordings/key/segment-00000.adts'),
      mediaStart: Duration.zero,
      mediaDuration: const Duration(seconds: 10),
      committedBytes: 80000,
      state: AudioSegmentState.committed,
    ),
  ],
  events: const [
    SessionEvent(
      id: 'event-1',
      meetingId: 'meeting-1',
      sequence: 0,
      type: SessionEventType.started,
      wallClockUtcMs: 1000,
      monotonicElapsed: Duration.zero,
      mediaOffset: Duration.zero,
    ),
  ],
  bookmarks: const [
    Bookmark(
      id: 'bookmark-1',
      meetingId: 'meeting-1',
      mediaOffset: Duration(seconds: 4),
      kind: BookmarkKind.highlight,
      createdAtUtcMs: 2000,
    ),
  ],
  processingJobs: const [
    ProcessingJob(
      id: 'job-1',
      meetingId: 'meeting-1',
      kind: ProcessingJobKind.audioMerge,
      createdAtUtcMs: 3000,
      state: ProcessingFailed(failureCode: 'recording_m4a_mux_failed'),
    ),
  ],
  recoveryDiagnostics: const [
    SessionRecoveryDiagnostic(code: 'recording_recovery_tail_discarded'),
  ],
);

AppRelativePath _path(String value) =>
    switch (AppRelativePath.tryParse(value)) {
      Ok(:final value) => value,
      Err() => throw StateError('fixture path invalid'),
    };

ProcessingJob _transcriptionJob() => const ProcessingJob(
  id: 'transcription-job',
  meetingId: 'meeting-1',
  kind: ProcessingJobKind.transcription,
  createdAtUtcMs: 1,
  state: ProcessingQueued(),
  targetRunId: 'transcription-run',
  modelId: 'model-1',
);

TranscriptRun _transcriptionRun({
  AnalysisState state = const AnalysisQueued(),
}) => TranscriptRun(
  id: 'transcription-run',
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

const _transcriptSegment = TranscriptSegment(
  id: 'transcript-segment',
  transcriptRunId: 'transcription-run',
  start: Duration.zero,
  end: Duration(seconds: 2),
  rawModelText: 'Stable detail text',
  displayedText: 'Stable detail text',
  revisionState: TranscriptRevisionState.machine,
);

TranscriptEditorDocument _transcriptDocument({bool completed = false}) =>
    TranscriptEditorDocument(
      meetingId: 'meeting-1',
      lifecycle: MeetingLifecycle.finalized,
      currentVersion: completed
          ? TranscriptVersion(
              run: _transcriptionRun(
                state: const AnalysisCompleted(
                  startedAtUtcMs: 2,
                  endedAtUtcMs: 4,
                ),
              ),
              segments: const [_transcriptSegment],
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
