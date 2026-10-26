import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
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
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/native/method_channel_refinement_execution_service.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    fixture = await _Fixture.create();
  });
  tearDown(() => fixture.database.close());

  test(
    'complete original input publishes a separate raw version without selecting it',
    () async {
      final result = _ok(await fixture.runner.run(fixture.job.id));
      expect(result.state, const ProcessingSucceeded());
      expect(
        fixture.engine.inputs.single.profile.bundleManifestJson,
        fixture.profile.bundleManifestJson,
      );
      expect(fixture.engine.inputs.single.runId, fixture.job.targetRunId);
      expect(fixture.audio.expectedHashes.last, 'a' * 64);
      final version = _ok(
        await fixture.transcripts.listVersions('meeting'),
      ).single;
      expect(version.segments.single.rawModelText, ' 原文 API ');
      expect(version.segments.single.displayedText, ' 原文 API ');
      expect(version.isCurrent, isFalse);
      expect(
        _ok(await fixture.processing.load(version.run.id))!.completeness,
        TranscriptCompleteness.complete,
      );
      expect(
        _ok(await fixture.runner.run(fixture.job.id)).state,
        const ProcessingSucceeded(),
      );
      expect(fixture.engine.inputs, hasLength(1));
    },
  );

  test(
    'missing original audio produces a durable failure before model execution',
    () async {
      fixture.audio.outcome = const Err(
        RefinementAudioUnavailable('transcription_audio_missing'),
      );
      final result = _ok(await fixture.runner.run(fixture.job.id));
      expect(
        result.state,
        const ProcessingFailed(failureCode: 'transcription_audio_missing'),
      );
      expect(fixture.engine.inputs, isEmpty);
      final retained = _ok(
        await fixture.transcripts.listVersions('meeting'),
      ).single;
      expect(retained.run.state, isA<AnalysisFailed>());
      expect(retained.segments, isEmpty);
    },
  );

  test(
    'changed authoritative geometry cannot be processed merely because hash matches',
    () async {
      fixture.audio.outcome = Ok(
        RefinementAudioInventory(
          sha256: 'a' * 64,
          totalSamples: 2048,
          segments: const [
            RefinementAudioSegmentInventory(
              index: 0,
              startSample: 0,
              committedSamples: 2048,
              committedBytes: 11,
              sha256:
                  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              referenceSha256:
                  '6ee5f51e2361291caf2b24775f631cdea3d8da46ae89559a5a2153df6f4d1b8d',
            ),
          ],
        ),
      );
      final result = _ok(await fixture.runner.run(fixture.job.id));
      expect(result.state, isA<ProcessingFailed>());
      expect(fixture.engine.inputs, isEmpty);
    },
  );

  test(
    'capture deferral stays paused and resumes the same job without a new version identity',
    () async {
      fixture.engine.outcome = const Err(
        RefinementExecutionDeferred('refinement_recording_active'),
      );
      expect(
        _ok(await fixture.runner.run(fixture.job.id)).state,
        const ProcessingPaused(reasonCode: 'refinement_recording_active'),
      );
      expect(
        _ok(await fixture.jobs.loadRun(fixture.job.targetRunId!)).state,
        const AnalysisQueued(),
      );
      fixture.engine.outcome = Ok(_output());
      expect(
        _ok(await fixture.runner.run(fixture.job.id)).state,
        const ProcessingSucceeded(),
      );
      expect(fixture.engine.inputs.map((input) => input.runId).toSet(), {
        fixture.job.targetRunId,
      });
      expect(
        _ok(await fixture.transcripts.listVersions('meeting')),
        hasLength(1),
      );
    },
  );

  test('inventory deferral is persisted without invoking execution', () async {
    fixture.audio.outcome = const Err(
      RefinementAudioDeferred('refinement_recording_active'),
    );
    expect(
      _ok(await fixture.runner.run(fixture.job.id)).state,
      const ProcessingPaused(reasonCode: 'refinement_recording_active'),
    );
    expect(fixture.engine.inputs, isEmpty);
  });

  test(
    'duplicate run joins one owner and cancellation waits for native cleanup outcome',
    () async {
      final pending =
          Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
      fixture.engine.pending = pending;
      final first = fixture.runner.run(fixture.job.id);
      final second = fixture.runner.run(fixture.job.id);
      await fixture.engine.entered.future;
      _ok(await fixture.runner.requestCancellation(fixture.job.id));
      expect(fixture.engine.cancelledOwners, [
        (meeting: 'meeting', run: fixture.job.targetRunId!),
      ]);
      expect(
        _ok(await fixture.jobs.load(fixture.job.id)).state,
        isA<ProcessingRunning>(),
      );
      // A late success cannot override a latched cancellation, but the durable
      // terminal state must wait until the service has completed its cleanup.
      pending.complete(Ok(_output()));
      for (final result in await Future.wait([first, second])) {
        expect(
          _ok(result).state,
          const ProcessingFailed(failureCode: 'transcription_cancelled'),
        );
      }
      expect(fixture.engine.inputs, hasLength(1));
      final retained = _ok(
        await fixture.transcripts.listVersions('meeting'),
      ).single;
      expect(retained.run.state, isA<AnalysisFailed>());
      expect(retained.segments, isEmpty);
    },
  );

  test(
    'cancel before input verification completes cannot allocate an engine',
    () async {
      final pending =
          Completer<Result<RefinementAudioInventory, RefinementAudioFailure>>();
      fixture.audio.pending = pending;
      final operation = fixture.runner.run(fixture.job.id);
      await fixture.audio.entered.future;
      _ok(await fixture.runner.requestCancellation(fixture.job.id));
      pending.complete(Ok(_inventory()));
      expect(
        _ok(await operation).state,
        const ProcessingFailed(failureCode: 'transcription_cancelled'),
      );
      expect(fixture.engine.inputs, isEmpty);
    },
  );

  test(
    'meeting trashed during inference cannot receive the completed version',
    () async {
      final pending =
          Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
      fixture.engine.pending = pending;
      final operation = fixture.runner.run(fixture.job.id);
      await fixture.engine.entered.future;
      _ok(await fixture.sessions.moveToTrash('meeting', atUtcMs: 11));
      pending.complete(Ok(_output()));
      expect(_ok(await operation).state, isA<ProcessingFailed>());
      expect(
        await fixture.database
            .select(fixture.database.transcriptSegments)
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'a cancellation adapter exception stays typed while cancellation remains latched',
    () async {
      final pending =
          Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
      fixture.engine.pending = pending;
      final operation = fixture.runner.run(fixture.job.id);
      await fixture.engine.entered.future;
      fixture.engine.throwOnCancel = true;
      expect(
        (await fixture.runner.requestCancellation(fixture.job.id)).isErr,
        isTrue,
      );
      pending.complete(Ok(_output()));
      expect(
        _ok(await operation).state,
        const ProcessingFailed(failureCode: 'transcription_cancelled'),
      );
    },
  );

  test('wall clock rollback cannot strand a failed owned run', () async {
    final pending =
        Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
    fixture.engine.pending = pending;
    final operation = fixture.runner.run(fixture.job.id);
    await fixture.engine.entered.future;
    fixture.now = 1;
    pending.complete(
      const Err(RefinementExecutionUnavailable('injected_failure')),
    );
    expect(
      _ok(await operation).state,
      const ProcessingFailed(failureCode: 'injected_failure'),
    );
    final stored = await fixture.database
        .select(fixture.database.transcriptRuns)
        .getSingle();
    expect(stored.endedAtUtcMs, 10);
  });

  test(
    'cancellation is not acknowledged after a pause transaction reserves finishing',
    () async {
      final pending =
          Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>();
      fixture.engine.pending = pending;
      final operation = fixture.runner.run(fixture.job.id);
      await fixture.engine.entered.future;
      final locked = Completer<void>();
      final release = Completer<void>();
      final transaction = fixture.database.transaction(() async {
        locked.complete();
        await release.future;
      });
      await locked.future;
      pending.complete(
        const Err(RefinementExecutionDeferred('refinement_recording_active')),
      );
      await Future<void>.delayed(Duration.zero);
      try {
        expect(
          (await fixture.runner.requestCancellation(fixture.job.id)).isErr,
          isTrue,
        );
      } finally {
        release.complete();
        await transaction;
        await operation;
      }
      expect(
        _ok(await operation).state,
        const ProcessingPaused(reasonCode: 'refinement_recording_active'),
      );
    },
  );

  test(
    'real adapter timeout retains running ownership until native cleanup replies',
    () async {
      const channel = MethodChannel('test.refinement_runner_timeout');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final nativeDone = Completer<Object?>();
      final cancelRequested = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'transcribe') return nativeDone.future;
        cancelRequested.complete();
        return {
          'v': 1,
          'ok': true,
          'meetingId': 'meeting',
          'runId': fixture.job.targetRunId,
        };
      });
      final runner = RefinementRunner(
        sessions: fixture.sessions,
        jobs: fixture.jobs,
        processing: fixture.processing,
        audio: fixture.audio,
        execution: const MethodChannelRefinementExecutionService(
          channel: channel,
          timeout: Duration(milliseconds: 1),
        ),
        clock: fixture.clock,
      );
      final operation = runner.run(fixture.job.id);
      await cancelRequested.future;
      await Future<void>.delayed(Duration.zero);
      try {
        expect(
          _ok(await fixture.jobs.load(fixture.job.id)).state,
          isA<ProcessingRunning>(),
        );
        expect((await runner.run('other-job')).isErr, isTrue);
      } finally {
        nativeDone.complete({
          'v': 1,
          'ok': false,
          'meetingId': 'meeting',
          'runId': fixture.job.targetRunId,
          'failure': {
            'kind': 'cancelled',
            'code': 'refinement_execution_cancelled',
          },
        });
        await operation;
      }
      expect(
        _ok(await operation).state,
        const ProcessingFailed(failureCode: 'refinement_execution_timeout'),
      );
    },
  );

  test(
    'lost native acknowledgement retains an unconfirmed owner and durable running state',
    () async {
      fixture.engine.throwOnTranscribe = true;
      expect((await fixture.runner.run(fixture.job.id)).isErr, isTrue);
      expect(
        _ok(await fixture.jobs.load(fixture.job.id)).state,
        isA<ProcessingRunning>(),
      );
      expect((await fixture.runner.run('other-job')).isErr, isTrue);
      expect((await fixture.runner.run(fixture.job.id)).isErr, isTrue);
      expect(fixture.engine.inputs, hasLength(1));
    },
  );

  for (final timedOut in [false, true]) {
    test(
      'wrong-owner native reply cannot release an owned run (timeout=$timedOut)',
      () async {
        const channel = MethodChannel('test.refinement_runner_wrong_owner');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final nativeDone = Completer<Object?>();
        final cancelRequested = Completer<void>();
        final wrong = {
          'v': 1,
          'ok': false,
          'meetingId': 'wrong',
          'runId': fixture.job.targetRunId,
          'failure': {
            'kind': 'cancelled',
            'code': 'refinement_execution_cancelled',
          },
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'transcribe') {
            if (timedOut) return nativeDone.future;
            return wrong;
          }
          cancelRequested.complete();
          return {
            'v': 1,
            'ok': true,
            'meetingId': 'meeting',
            'runId': fixture.job.targetRunId,
          };
        });
        final runner = RefinementRunner(
          sessions: fixture.sessions,
          jobs: fixture.jobs,
          processing: fixture.processing,
          audio: fixture.audio,
          execution: const MethodChannelRefinementExecutionService(
            channel: channel,
            timeout: Duration(milliseconds: 1),
          ),
          clock: fixture.clock,
        );
        final operation = runner.run(fixture.job.id);
        if (timedOut) {
          await cancelRequested.future;
          nativeDone.complete(wrong);
        }
        expect((await operation).isErr, isTrue);
        expect(
          _ok(await fixture.jobs.load(fixture.job.id)).state,
          isA<ProcessingRunning>(),
        );
        expect((await runner.run('different-job')).isErr, isTrue);
      },
    );
  }

  for (final invalid in <TranscriptionOutput>[
    _output(runtime: 'other'),
    _output(warning: 'transcription_audio_uncommitted_tail'),
    _output(end: const Duration(milliseconds: 65)),
    _output(display: 'rewritten'),
    _output(stability: TranscriptStability.unstable),
  ]) {
    test(
      'untrusted incomplete or invalid engine output fails before publication ${invalid.engineVersion}/${invalid.warningCode}/${invalid.chunks.single.end}/${invalid.chunks.single.displayText}/${invalid.chunks.single.stability}',
      () async {
        fixture.engine.outcome = Ok(invalid);
        expect(
          _ok(await fixture.runner.run(fixture.job.id)).state,
          const ProcessingFailed(failureCode: 'refinement_output_invalid'),
        );
        expect(
          await fixture.database
              .select(fixture.database.transcriptSegments)
              .get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'failed work requires explicit same-identity retry and running work requires recovery',
    () async {
      _ok(
        await fixture.processing.startRefinement(
          fixture.job.id,
          startedAtUtcMs: 10,
        ),
      );
      expect((await fixture.runner.run(fixture.job.id)).isErr, isTrue);
      expect(fixture.engine.inputs, isEmpty);
      _ok(
        await fixture.processing.recoverOrphanedRefinements(
          recoveredAtUtcMs: 10,
        ),
      );
      fixture.engine.outcome = const Err(
        RefinementExecutionUnavailable('injected_failure'),
      );
      expect(
        _ok(await fixture.runner.run(fixture.job.id)).state,
        const ProcessingFailed(failureCode: 'injected_failure'),
      );
      fixture.engine.outcome = Ok(_output());
      _ok(await fixture.runner.run(fixture.job.id));
      expect(fixture.engine.inputs, hasLength(1));
      _ok(
        await fixture.processing.retryRefinement(
          fixture.job.id,
          queuedAtUtcMs: 10,
        ),
      );
      expect(
        _ok(await fixture.runner.run(fixture.job.id)).state,
        const ProcessingSucceeded(),
      );
    },
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

TranscriptionOutput _output({
  String runtime = '1.9.4',
  String? warning,
  Duration end = const Duration(milliseconds: 64),
  String display = ' 原文 API ',
  TranscriptStability stability = TranscriptStability.stable,
}) => TranscriptionOutput(
  engineVersion: runtime,
  warningCode: warning,
  chunks: [
    TranscriptChunk(
      segmentId: 'native-segment',
      start: Duration.zero,
      end: end,
      rawText: ' 原文 API ',
      displayText: display,
      stability: stability,
    ),
  ],
);

RefinementAudioInventory _inventory() => RefinementAudioInventory(
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
);

final class _Fixture {
  _Fixture(this.database);
  final db.AppDatabase database;
  final audio = _Inventory();
  final engine = _Execution();
  int now = 10;
  late final clock = Clock(
    () => DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
  );
  late final sessions = DriftSessionRepository(
    database,
    audioStore: _NoDelete(),
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final jobs = DriftTranscriptionJobRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final processing = DriftTranscriptProcessingRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
  late final transcripts = DriftTranscriptRepository(
    database,
    diagnosticSink: const DisabledDiagnosticLogSink(),
  );
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
  late ProcessingJob job;
  late final runner = RefinementRunner(
    sessions: sessions,
    jobs: jobs,
    processing: processing,
    audio: audio,
    execution: engine,
    clock: clock,
  );

  static Future<_Fixture> create() async {
    final fixture = _Fixture(db.AppDatabase(NativeDatabase.memory()));
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
    final selections = DriftMeetingProcessingSelectionRepository(
      fixture.database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    _ok(
      await selections.save(
        'meeting',
        MeetingProcessingSelection.postSession(refinement: fixture.profile),
        storedAtUtcMs: 2,
      ),
    );
    await fixture.database.customStatement(
      "UPDATE meetings SET lifecycle='finalized', media_duration_us=64000",
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
    fixture.job = _ok(
      await RefinementScheduler(
        sessions: fixture.sessions,
        selections: selections,
        processing: fixture.processing,
        jobs: fixture.jobs,
        models: DriftModelRepository(
          fixture.database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ),
        transcripts: fixture.transcripts,
        audio: fixture.audio,
        clock: Clock.fixed(DateTime.fromMillisecondsSinceEpoch(5, isUtc: true)),
      ).schedule('meeting'),
    )!;
    // Only execution-time inspections should wake cancellation tests.
    fixture.audio.entered = Completer<void>();
    return fixture;
  }
}

final class _Inventory implements RefinementAudioInventoryService {
  Result<RefinementAudioInventory, RefinementAudioFailure> outcome = Ok(
    _inventory(),
  );
  Completer<Result<RefinementAudioInventory, RefinementAudioFailure>>? pending;
  Completer<void> entered = Completer<void>();
  final expectedHashes = <String?>[];
  @override
  Future<Result<RefinementAudioInventory, RefinementAudioFailure>> inspect(
    String meetingId, {
    String? expectedSha256,
  }) async {
    expect(meetingId, 'meeting');
    expectedHashes.add(expectedSha256);
    if (!entered.isCompleted) entered.complete();
    return pending?.future ?? outcome;
  }
}

final class _Execution implements RefinementExecutionService {
  bool throwOnTranscribe = false;
  bool throwOnCancel = false;
  Result<TranscriptionOutput, RefinementExecutionFailure> outcome = Ok(
    _output(),
  );
  Completer<Result<TranscriptionOutput, RefinementExecutionFailure>>? pending;
  final entered = Completer<void>();
  final inputs = <RefinementExecutionInput>[];
  final cancelledOwners = <({String meeting, String run})>[];
  @override
  Future<Result<TranscriptionOutput, RefinementExecutionFailure>> transcribe(
    RefinementExecutionInput input,
  ) async {
    inputs.add(input);
    if (throwOnTranscribe) throw StateError('SECRET /private');
    if (!entered.isCompleted) entered.complete();
    return pending?.future ?? outcome;
  }

  @override
  Future<Result<void, RefinementExecutionFailure>> cancel({
    required String meetingId,
    required String runId,
  }) async {
    if (throwOnCancel) throw StateError('SECRET /private');
    cancelledOwners.add((meeting: meetingId, run: runId));
    return const Ok(null);
  }
}

final class _NoDelete implements MeetingAudioStore {
  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> paths,
  ) async => throw StateError('refinement must never delete original audio');
}
