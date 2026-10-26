import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_meeting_processing_selection_repository.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/data/repositories/drift_transcript_processing_repository.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/refinement_runner.dart';
import 'package:loquiris/features/transcript/application/refinement_scheduler.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/application/transcription_ids.dart';
import 'package:loquiris/features/transcript/application/transcription_parameters.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_controller.dart';
import 'package:loquiris/features/transcript/presentation/meeting_transcription_status.dart';
import 'package:loquiris/native/method_channel_refinement_execution_service.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

import '../support/fakes/fake_services.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _DispatchFixture fixture;
  setUp(() async => fixture = await _DispatchFixture.create());
  tearDown(() => fixture.close());

  test(
    'explicit capture-only never falls back to legacy complete pass',
    () async {
      await fixture.choose(const MeetingProcessingSelection.recordingOnly());
      await fixture.start();
      await fixture.finalize();
      await fixture.coordinator.scheduleFinalized('meeting');
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
      expect(fixture.legacy.requests, isEmpty);
      expect(fixture.execution.inputs, isEmpty);
    },
  );

  test(
    'explicit complete pass runs frozen profile and never auto-selects text',
    () async {
      await fixture.choose();
      await fixture.start();
      await fixture.finalize();
      await Future.wait([
        fixture.coordinator.scheduleFinalized('meeting'),
        fixture.coordinator.scheduleFinalized('meeting'),
      ]);
      expect(fixture.execution.inputs, hasLength(1));
      expect(fixture.execution.inputs.single.profile, fixture.profile);
      expect(fixture.legacy.requests, isEmpty);
      final version = _ok(
        await fixture.transcripts.listVersions('meeting'),
      ).single;
      expect(version.isCurrent, isFalse);
      expect(version.segments.single.rawModelText, ' 原文 API ');
      expect(
        _ok(await fixture.processing.load(version.run.id))!.role,
        TranscriptProcessingRole.refinement,
      );
    },
  );

  test(
    'explicit new two-pass cannot be reinterpreted as the legacy live engine',
    () async {
      await fixture.choose(
        MeetingProcessingSelection.twoPass(
          live: fixture.profile,
          refinement: fixture.profile,
        ),
      );
      await fixture.database.customStatement(
        "UPDATE meetings SET lifecycle='recording', transcription_mode='nearRealTime'",
      );
      await fixture.start();
      final result = await fixture.coordinator.startLiveDraft('meeting');
      expect(
        result,
        isA<Err<LiveTranscriptionSession?, TranscriptionFailure>>(),
      );
      expect(fixture.legacy.draftRequests, isEmpty);
    },
  );

  test(
    'startup finds finalized explicit selection even before any job exists',
    () async {
      await fixture.choose();
      await fixture.finalize();
      await fixture.start();
      await fixture.coordinator.waitForIdle();
      expect(fixture.execution.inputs, hasLength(1));
      expect(fixture.legacy.requests, isEmpty);
      expect(
        _ok(await fixture.jobs.watchMeeting('meeting').first).single.state,
        const ProcessingSucceeded(),
      );
    },
  );

  test(
    'startup recovers orphan refinement through its own role claim',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final job = _ok(await fixture.scheduler.schedule('meeting'))!;
      _ok(await fixture.processing.startRefinement(job.id, startedAtUtcMs: 5));
      await fixture.start();
      await fixture.coordinator.waitForIdle();
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        const ProcessingSucceeded(),
      );
      expect(fixture.execution.inputs.single.runId, job.targetRunId);
      expect(fixture.legacy.requests, isEmpty);
    },
  );

  test(
    'paused refinement explicitly resumes same identity without legacy retry',
    () async {
      await fixture.choose();
      await fixture.start();
      await fixture.finalize();
      fixture.execution.outcome = const Err(
        RefinementExecutionDeferred('refinement_battery_low'),
      );
      await fixture.coordinator.scheduleFinalized('meeting');
      final job = _ok(await fixture.jobs.watchMeeting('meeting').first).single;
      expect(
        job.state,
        const ProcessingPaused(reasonCode: 'refinement_battery_low'),
      );
      final provider = meetingTranscriptionControllerProvider('meeting');
      fixture.container.listen(provider, (_, _) {});
      final projection = await fixture.container.read(provider.future);
      expect(projection.resumableJobIds, {job.id});
      fixture.execution.outcome = Ok(_output());
      final resumed = await fixture.coordinator.resumeRefinement(job.id);
      expect(resumed, isA<Ok<ProcessingJob, RefinementRunFailure>>());
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        const ProcessingSucceeded(),
      );
      expect(fixture.execution.inputs.map((input) => input.runId).toSet(), {
        job.targetRunId,
      });
      expect(fixture.legacy.requests, isEmpty);
    },
  );

  test(
    'resume refuses legacy paused jobs without invoking either engine',
    () async {
      await fixture.start();
      await fixture.finalize();
      final job = await fixture.enqueueLegacy();
      _ok(await fixture.jobs.start(job.id, startedAtUtcMs: 4));
      await fixture.database.customStatement(
        "UPDATE processing_jobs SET job_state='paused', reason_code='refinement_battery_low' WHERE id=?",
        [job.id],
      );
      final result = await fixture.coordinator.resumeRefinement(job.id);
      expect(result, isA<Err<ProcessingJob, RefinementRunFailure>>());
      final provider = meetingTranscriptionControllerProvider('meeting');
      fixture.container.listen(provider, (_, _) {});
      expect(
        (await fixture.container.read(provider.future)).resumableJobIds,
        isEmpty,
      );
      expect(
        _ok(await fixture.jobs.load(job.id)).state,
        isA<ProcessingPaused>(),
      );
      expect(fixture.legacy.requests, isEmpty);
      expect(fixture.execution.inputs, isEmpty);
    },
  );

  test('failed refinement retry preserves frozen provenance', () async {
    await fixture.choose();
    await fixture.start();
    await fixture.finalize();
    fixture.execution.outcome = const Err(
      RefinementExecutionUnavailable('transcription_native_failed'),
    );
    await fixture.coordinator.scheduleFinalized('meeting');
    final job = _ok(await fixture.jobs.watchMeeting('meeting').first).single;
    expect(job.state, isA<ProcessingFailed>());
    fixture.execution.outcome = Ok(_output());
    await fixture.coordinator.retry(job.id);
    expect(
      _ok(await fixture.jobs.load(job.id)).state,
      const ProcessingSucceeded(),
    );
    expect(fixture.execution.inputs, hasLength(2));
    expect(fixture.legacy.requests, isEmpty);
  });

  test(
    'presentation coalesces resume taps and observes committed completion',
    () async {
      await fixture.choose();
      await fixture.start();
      await fixture.finalize();
      fixture.execution.outcome = const Err(
        RefinementExecutionDeferred('refinement_battery_low'),
      );
      await fixture.coordinator.scheduleFinalized('meeting');
      final job = _ok(await fixture.jobs.watchMeeting('meeting').first).single;
      final provider = meetingTranscriptionControllerProvider('meeting');
      fixture.container.listen(provider, (_, _) {});
      await fixture.container.read(provider.future);
      final gate =
          Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
      fixture.execution.pending = gate.future;
      fixture.container.read(provider.notifier)
        ..resume(job.id)
        ..resume(job.id);
      expect(fixture.container.read(provider).requireValue.retryingJobIds, {
        job.id,
      });
      for (var i = 0; i < 50 && fixture.execution.inputs.length < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(fixture.execution.inputs, hasLength(2));
      gate.complete(Ok(_output()));
      await fixture.coordinator.waitForIdle();
      for (
        var i = 0;
        i < 50 &&
            fixture.container.read(provider).value?.latestJob?.state
                is! ProcessingSucceeded;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        fixture.container.read(provider).requireValue.latestJob?.state,
        isA<ProcessingSucceeded>(),
      );
      expect(fixture.execution.inputs, hasLength(2));
      expect(fixture.legacy.requests, isEmpty);
    },
  );

  testWidgets(
    'paused refinement status resumes the durable job through the coordinator',
    (tester) async {
      await tester.runAsync(() async {
        await fixture.choose();
        await fixture.start();
        await fixture.finalize();
        fixture.execution.outcome = const Err(
          RefinementExecutionDeferred('refinement_battery_low'),
        );
        await fixture.coordinator.scheduleFinalized('meeting');
        final provider = meetingTranscriptionControllerProvider('meeting');
        fixture.container.listen(provider, (_, _) {});
        await fixture.container.read(provider.future);
        fixture.execution.outcome = Ok(_output());
      });
      tester.useDevice(TestDevice.compact);
      await tester.pumpLocalizedContent(
        UncontrolledProviderScope(
          container: fixture.container,
          child: const MeetingTranscriptionStatus(meetingId: 'meeting'),
        ),
      );
      expect(
        find.text(
          'Refinement is paused because the battery is low. Charge this device before resuming.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Resume refinement'));
      for (
        var i = 0;
        i < 50 &&
            fixture.container
                    .read(meetingTranscriptionControllerProvider('meeting'))
                    .value
                    ?.latestJob
                    ?.state
                is! ProcessingSucceeded;
        i++
      ) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      await tester.pump();
      expect(find.text('Transcription completed'), findsOneWidget);
      expect(fixture.execution.inputs, hasLength(2));
      expect(fixture.legacy.requests, isEmpty);
    },
  );

  test('resume survives closing and reopening its route projection', () async {
    await fixture.choose();
    await fixture.start();
    await fixture.finalize();
    fixture.execution.outcome = const Err(
      RefinementExecutionDeferred('refinement_battery_low'),
    );
    await fixture.coordinator.scheduleFinalized('meeting');
    final job = _ok(await fixture.jobs.watchMeeting('meeting').first).single;
    final provider = meetingTranscriptionControllerProvider('meeting');
    final subscription = fixture.container.listen(provider, (_, _) {});
    await fixture.container.read(provider.future);
    final gate =
        Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
    fixture.execution.pending = gate.future;
    fixture.container.read(provider.notifier).resume(job.id);
    for (var i = 0; i < 50 && fixture.execution.inputs.length < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fixture.execution.inputs, hasLength(2));
    subscription.close();
    await fixture.container.pump();
    gate.complete(Ok(_output()));
    await fixture.coordinator.waitForIdle();
    fixture.container.listen(provider, (_, _) {});
    final reopened = await fixture.container.read(provider.future);
    expect(reopened.latestJob?.state, isA<ProcessingSucceeded>());
    expect(reopened.retryingJobIds, isEmpty);
    expect(reopened.resumableJobIds, isEmpty);
    expect(
      _ok(await fixture.jobs.load(job.id)).state,
      isA<ProcessingSucceeded>(),
    );
  });

  test(
    'unreadable explicit configuration fails closed instead of legacy reinterpretation',
    () async {
      await fixture.choose();
      await fixture.database.customStatement(
        'UPDATE meeting_processing_selections SET refinement_bundle_manifest_json=\'{"schemaVersion":1}\'',
      );
      await fixture.start();
      await fixture.finalize();
      await fixture.coordinator.scheduleFinalized('meeting');
      expect(fixture.legacy.requests, isEmpty);
      expect(fixture.execution.inputs, isEmpty);
      expect(
        await fixture.database.select(fixture.database.processingJobs).get(),
        isEmpty,
      );
    },
  );

  test(
    'unconfirmed real channel ownership blocks later legacy inference and same-process recovery',
    () async {
      const channel = MethodChannel('test/refinement-dispatch-ownership');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              channel,
              (call) async => {
                'version': 1,
                'ok': false,
                'meetingId': 'other',
                'runId': 'other',
                'code': 'transcription_native_failed',
              },
            );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      fixture.nativeExecution = const MethodChannelRefinementExecutionService(
        channel: channel,
      );
      await fixture.choose();
      await fixture.start();
      await fixture.finalize();
      await fixture.coordinator.scheduleFinalized('meeting');
      final refinement = _ok(
        await fixture.jobs.watchMeeting('meeting').first,
      ).single;
      expect(refinement.state, isA<ProcessingRunning>());
      await fixture.insertLegacyMeeting();
      await fixture.coordinator.scheduleFinalized('legacy');
      expect(fixture.legacy.requests, isEmpty);
      expect(
        _ok(await fixture.jobs.watchMeeting('legacy').first).single.state,
        const ProcessingQueued(),
      );
      fixture.container.invalidate(transcriptionCoordinatorProvider);
      await fixture.start();
      await fixture.coordinator.waitForIdle();
      expect(fixture.legacy.requests, isEmpty);
      expect(
        _ok(await fixture.jobs.load(refinement.id)).state,
        isA<ProcessingRunning>(),
      );
    },
  );

  test(
    'restored capture-only configuration fences queued unextended legacy job at startup',
    () async {
      await fixture.choose(const MeetingProcessingSelection.recordingOnly());
      await fixture.finalize();
      final historical = await fixture.enqueueLegacy();
      await fixture.start();
      await fixture.coordinator.waitForIdle();
      expect(fixture.legacy.requests, isEmpty);
      expect(
        _ok(await fixture.jobs.load(historical.id)).state,
        const ProcessingQueued(),
      );
    },
  );

  test(
    'restored capture-only configuration fences failed unextended legacy retry',
    () async {
      await fixture.choose(const MeetingProcessingSelection.recordingOnly());
      await fixture.finalize();
      final historical = await fixture.enqueueLegacy(failed: true);
      await fixture.start();
      await fixture.coordinator.retry(historical.id);
      expect(fixture.legacy.requests, isEmpty);
      expect(
        _ok(await fixture.jobs.load(historical.id)).state,
        const ProcessingFailed(failureCode: 'transcription_native_failed'),
      );
    },
  );

  test(
    'restored explicit post selection is not suppressed by an old queued legacy job',
    () async {
      await fixture.choose();
      await fixture.finalize();
      final historical = await fixture.enqueueLegacy();
      await fixture.start();
      await fixture.coordinator.waitForIdle();
      expect(fixture.legacy.requests, isEmpty);
      expect(fixture.execution.inputs, hasLength(1));
      expect(
        _ok(await fixture.jobs.load(historical.id)).state,
        const ProcessingQueued(),
      );
    },
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

final class _DispatchFixture {
  _DispatchFixture(this.database);
  final db.AppDatabase database;
  final legacy = FakeTranscriptionEngine();
  final execution = _Execution();
  RefinementExecutionService? nativeExecution;
  final audio = _Inventory();
  final clock = Clock.fixed(
    DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
  );
  static const sink = DisabledDiagnosticLogSink();
  late final sessions = DriftSessionRepository(
    database,
    audioStore: _NoDelete(),
    diagnosticSink: sink,
  );
  late final jobs = DriftTranscriptionJobRepository(
    database,
    diagnosticSink: sink,
  );
  late final transcripts = DriftTranscriptRepository(
    database,
    diagnosticSink: sink,
  );
  late final processing = DriftTranscriptProcessingRepository(
    database,
    diagnosticSink: sink,
  );
  late final selections = DriftMeetingProcessingSelectionRepository(
    database,
    diagnosticSink: sink,
  );
  late final models = DriftModelRepository(database, diagnosticSink: sink);
  late final ProcessingModelProfile profile = _ok(
    ProcessingModelProfile.tryCreate(
      bundleManifestJson: File(
        'models/manifests/whisper-base-q5_1.json',
      ).readAsStringSync(),
      engineVersion: '1.9.4',
      parametersJson:
          '{"executionMode":"postSession","requestedTiming":"live","languageHint":"mixed","parameterVersion":1}',
    ),
  );
  late final scheduler = RefinementScheduler(
    sessions: sessions,
    selections: selections,
    processing: processing,
    jobs: jobs,
    models: models,
    transcripts: transcripts,
    audio: audio,
    clock: clock,
  );
  late final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(clock),
      sessionRepositoryProvider.overrideWithValue(sessions),
      transcriptionJobRepositoryProvider.overrideWithValue(jobs),
      transcriptRepositoryProvider.overrideWithValue(transcripts),
      modelRepositoryProvider.overrideWithValue(models),
      modelManagerProvider.overrideWithValue(
        FakeModelManager()
          ..verifyResult = Ok(
            ModelDescriptor(
              id: profile.manifest.id,
              version: profile.manifest.version,
              bytes: profile.manifest.bytes,
            ),
          ),
      ),
      transcriptionModelManifestProvider.overrideWithValue(profile.manifest),
      transcriptionEngineProvider.overrideWithValue(legacy),
      meetingProcessingSelectionRepositoryProvider.overrideWithValue(
        selections,
      ),
      transcriptProcessingRepositoryProvider.overrideWithValue(processing),
      refinementAudioInventoryServiceProvider.overrideWithValue(audio),
      refinementExecutionServiceProvider.overrideWithValue(
        nativeExecution ?? execution,
      ),
    ],
  );
  TranscriptionCoordinator get coordinator =>
      container.read(transcriptionCoordinatorProvider.notifier);
  Future<void> start() =>
      container.read(transcriptionCoordinatorProvider.future);
  Future<void> choose([MeetingProcessingSelection? selection]) async {
    _ok(
      await selections.save(
        'meeting',
        selection ??
            MeetingProcessingSelection.postSession(refinement: profile),
        storedAtUtcMs: 2,
      ),
    );
  }

  Future<void> finalize() => database.customStatement(
    "UPDATE meetings SET lifecycle='finalized', media_duration_us=64000",
  );

  Future<void> insertLegacyMeeting() async {
    await database
        .into(database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: 'legacy',
            createdAt: 1,
            updatedAt: 1,
            title: 'legacy',
            lifecycle: 'finalized',
            languageMode: 'mixed',
          ),
        );
    await database
        .into(database.audioSegments)
        .insert(
          db.AudioSegmentsCompanion.insert(
            id: 'legacy-audio',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'legacy',
            sequence: 0,
            relativePath: 'recordings/legacy/original.adts',
            mediaStartUs: 0,
            mediaDurationUs: 64000,
            committedBytes: 11,
            state: 'committed',
          ),
        );
  }

  Future<ProcessingJob> enqueueLegacy({bool failed = false}) async {
    final meeting = _ok(await sessions.loadDetail('meeting')).meeting;
    final parameters = TranscriptionParameters.forMeeting(
      meeting: meeting,
      manifest: profile.manifest,
    );
    final runId = transcriptionRunId(
      meetingId: 'meeting',
      parameters: parameters,
    );
    final job = ProcessingJob(
      id: transcriptionJobId(meetingId: 'meeting', parameters: parameters),
      meetingId: 'meeting',
      kind: ProcessingJobKind.transcription,
      createdAtUtcMs: 1,
      state: const ProcessingQueued(),
      targetRunId: runId,
      modelId: profile.manifest.id,
    );
    _ok(
      await jobs.enqueue(
        job,
        TranscriptRun(
          id: runId,
          meetingId: 'meeting',
          provenance: parameters.provenance,
          createdAtUtcMs: 1,
          state: const AnalysisQueued(),
        ),
        storedAtUtcMs: 3,
      ),
    );
    if (!failed) return job;
    _ok(await jobs.start(job.id, startedAtUtcMs: 4));
    return _ok(
      await jobs.fail(
        job.id,
        failureCode: 'transcription_native_failed',
        failedAtUtcMs: 5,
      ),
    );
  }

  Future<void> close() async {
    container.dispose();
    await legacy.dispose();
    await database.close();
  }

  static Future<_DispatchFixture> create() async {
    final fixture = _DispatchFixture(db.AppDatabase(NativeDatabase.memory()));
    await fixture.database
        .into(fixture.database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: 'meeting',
            createdAt: 1,
            updatedAt: 1,
            title: 'meeting',
            lifecycle: 'draft',
            languageMode: 'mixed',
          ),
        );
    await fixture.database
        .into(fixture.database.audioSegments)
        .insert(
          db.AudioSegmentsCompanion.insert(
            id: 'audio',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'meeting',
            sequence: 0,
            relativePath: 'recordings/key/original.adts',
            mediaStartUs: 0,
            mediaDurationUs: 64000,
            committedBytes: 11,
            state: 'committed',
          ),
        );
    _ok(
      await fixture.models.registerBundled(
        fixture.profile.manifest.toInstalledModel(),
        observedAtUtcMs: 2,
      ),
    );
    return fixture;
  }
}

final class _Inventory implements RefinementAudioInventoryService {
  @override
  Future<Result<RefinementAudioInventory, RefinementAudioFailure>> inspect(
    String meetingId, {
    String? expectedSha256,
  }) async => Ok(
    RefinementAudioInventory(
      sha256: 'a' * 64,
      totalSamples: 1024,
      segments: [
        RefinementAudioSegmentInventory(
          index: 0,
          startSample: 0,
          committedSamples: 1024,
          committedBytes: 11,
          sha256: 'b' * 64,
          referenceSha256:
              '6ee5f51e2361291caf2b24775f631cdea3d8da46ae89559a5a2153df6f4d1b8d',
        ),
      ],
    ),
  );
}

final class _Execution implements RefinementExecutionService {
  Future<Result<TranscriptionOutput, RefinementExecutionFailure>>? pending;
  Result<TranscriptionOutput, RefinementExecutionFailure> outcome = Ok(
    _output(),
  );
  final inputs = <RefinementExecutionInput>[];
  @override
  Future<Result<TranscriptionOutput, RefinementExecutionFailure>> transcribe(
    RefinementExecutionInput input,
  ) async {
    inputs.add(input);
    return pending ?? outcome;
  }

  @override
  Future<Result<void, RefinementExecutionFailure>> cancel({
    required String meetingId,
    required String runId,
  }) async => const Ok(null);
}

TranscriptionOutput _output() => TranscriptionOutput(
  engineVersion: '1.9.4',
  chunks: [
    const TranscriptChunk(
      segmentId: 'native',
      start: Duration.zero,
      end: Duration(milliseconds: 64),
      rawText: ' 原文 API ',
      displayText: ' 原文 API ',
      stability: TranscriptStability.stable,
    ),
  ],
);

final class _NoDelete implements MeetingAudioStore {
  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> paths,
  ) async => throw StateError('must never delete audio');
}
