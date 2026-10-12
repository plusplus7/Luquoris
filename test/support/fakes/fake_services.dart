import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

final class FakeAudioCaptureService implements AudioCaptureService {
  final List<AudioCaptureRequest> startRequests = [];
  final StreamController<AudioCaptureSnapshot> _snapshots =
      StreamController.broadcast(sync: true);

  Result<AudioCaptureSnapshot, AudioCaptureFailure> startResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.recording,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> pauseResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.pausedByUser,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> resumeResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.recording,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> stopResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.finalized,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );

  @override
  Stream<AudioCaptureSnapshot> get snapshots => _snapshots.stream;

  void emitSnapshot(AudioCaptureSnapshot snapshot) => _snapshots.add(snapshot);

  Future<void> dispose() => _snapshots.close();

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  ) async {
    startRequests.add(request);
    return startResult;
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> pause() async =>
      pauseResult;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> resume() async =>
      resumeResult;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> stop() async =>
      stopResult;
}

final class FakeTranscriptionEngine implements TranscriptionEngine {
  final List<TranscriptionRequest> requests = [];
  final List<TranscriptionDraftRequest> draftRequests = [];
  final List<String> stopDraftRequests = [];
  final List<String> cancellationRequests = [];
  final StreamController<TranscriptionEvent> _events =
      StreamController.broadcast(sync: true);
  Result<TranscriptionOutput, TranscriptionFailure> result = Ok(
    TranscriptionOutput(chunks: []),
  );
  Result<void, TranscriptionFailure> cancelResult = const Ok(null);
  Result<void, TranscriptionFailure> startDraftResult = const Ok(null);
  Result<void, TranscriptionFailure> stopDraftResult = const Ok(null);

  @override
  Stream<TranscriptionEvent> eventsFor(String runId) =>
      _events.stream.where((event) => event.runId == runId);

  void emit(TranscriptionEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();

  @override
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  ) async {
    requests.add(request);
    return result;
  }

  @override
  Future<Result<void, TranscriptionFailure>> startDraft(
    TranscriptionDraftRequest request,
  ) async {
    draftRequests.add(request);
    return startDraftResult;
  }

  @override
  Future<Result<void, TranscriptionFailure>> stopDraft(String runId) async {
    stopDraftRequests.add(runId);
    return stopDraftResult;
  }

  @override
  Future<Result<void, TranscriptionFailure>> cancel(String runId) async {
    cancellationRequests.add(runId);
    return cancelResult;
  }
}

final class FakeTranscriptionJobRepository
    implements TranscriptionJobRepository {
  final StreamController<String> _changes = StreamController.broadcast(
    sync: true,
  );
  final List<({ProcessingJob job, TranscriptRun run, int storedAtUtcMs})>
  enqueueCalls = [];
  final List<({String jobId, int startedAtUtcMs})> startCalls = [];
  final List<
    ({
      String jobId,
      double progress,
      TranscriptionCheckpoint checkpoint,
      int storedAtUtcMs,
    })
  >
  progressCalls = [];
  final List<int> recoveryCalls = [];
  final List<
    ({
      String jobId,
      TranscriptRun run,
      List<TranscriptSegment> segments,
      int storedAtUtcMs,
    })
  >
  completionCalls = [];
  final List<({String jobId, String failureCode, int failedAtUtcMs})>
  failureCalls = [];
  final List<({String jobId, int queuedAtUtcMs})> retryCalls = [];
  final List<({String jobId, int cancelledAtUtcMs})> cancellationCalls = [];

  final Map<String, ProcessingJob> jobs = {};
  final Map<String, TranscriptRun> runs = {};
  final Map<String, String> _selectedRunByMeeting = {};
  AnalysisRepositoryFailure? failure;
  AnalysisRepositoryFailure? completionFailure;

  Future<void> dispose() => _changes.close();

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> enqueue(
    ProcessingJob job,
    TranscriptRun run, {
    required int storedAtUtcMs,
  }) async {
    enqueueCalls.add((job: job, run: run, storedAtUtcMs: storedAtUtcMs));
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final existing = jobs[job.id];
    if (existing != null) return Ok(existing);
    jobs[job.id] = job;
    runs[run.id] = run;
    _changes.add(job.meetingId);
    return Ok(job);
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> load(
    String jobId,
  ) async {
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    return job == null ? const Err(AnalysisNotFound()) : Ok(job);
  }

  @override
  Future<Result<TranscriptRun, AnalysisRepositoryFailure>> loadRun(
    String runId,
  ) async {
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final run = runs[runId];
    return run == null ? const Err(AnalysisNotFound()) : Ok(run);
  }

  @override
  Stream<Result<List<ProcessingJob>, AnalysisRepositoryFailure>> watchMeeting(
    String meetingId,
  ) async* {
    yield _meetingSnapshot(meetingId);
    await for (final changedMeetingId in _changes.stream) {
      if (changedMeetingId == meetingId) yield _meetingSnapshot(meetingId);
    }
  }

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  listRecoverable() async {
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    return Ok(
      jobs.values
          .where(
            (job) =>
                job.state is ProcessingQueued ||
                job.state is ProcessingRunning ||
                job.state is ProcessingPaused,
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> start(
    String jobId, {
    required int startedAtUtcMs,
  }) async {
    startCalls.add((jobId: jobId, startedAtUtcMs: startedAtUtcMs));
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    if (job == null) return const Err(AnalysisNotFound());
    final updated = job.copyWith(
      state: const ProcessingRunning(progress: 0),
    );
    jobs[jobId] = updated;
    final runId = job.targetRunId;
    final run = runId == null ? null : runs[runId];
    if (run != null) {
      runs[run.id] = run.copyWith(
        state: AnalysisRunning(
          startedAtUtcMs: startedAtUtcMs,
          progress: 0,
        ),
      );
    }
    _changes.add(job.meetingId);
    return Ok(updated);
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> saveProgress(
    String jobId, {
    required double progress,
    required TranscriptionCheckpoint checkpoint,
    required int storedAtUtcMs,
  }) async {
    progressCalls.add((
      jobId: jobId,
      progress: progress,
      checkpoint: checkpoint,
      storedAtUtcMs: storedAtUtcMs,
    ));
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    if (job == null) return const Err(AnalysisNotFound());
    final updated = job.copyWith(
      state: ProcessingRunning(progress: progress),
      checkpoint: checkpoint.toStorageJson(),
    );
    jobs[jobId] = updated;
    final runId = job.targetRunId;
    final run = runId == null ? null : runs[runId];
    if (run?.state case final AnalysisRunning running) {
      runs[run!.id] = run.copyWith(
        state: AnalysisRunning(
          startedAtUtcMs: running.startedAtUtcMs,
          progress: progress,
        ),
      );
    }
    _changes.add(job.meetingId);
    return Ok(updated);
  }

  @override
  Future<Result<List<ProcessingJob>, AnalysisRepositoryFailure>>
  recoverOrphanedRunning({required int recoveredAtUtcMs}) async {
    recoveryCalls.add(recoveredAtUtcMs);
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final recovered = <ProcessingJob>[];
    for (final entry in jobs.entries.toList(growable: false)) {
      if (entry.value.state is! ProcessingRunning) continue;
      final updated = entry.value.copyWith(
        state: const ProcessingPaused(reasonCode: 'process_restarted'),
      );
      jobs[entry.key] = updated;
      recovered.add(updated);
      final runId = updated.targetRunId;
      if (runId != null) {
        final run = runs[runId];
        if (run != null) {
          runs[runId] = run.copyWith(state: const AnalysisQueued());
        }
      }
      _changes.add(updated.meetingId);
    }
    return Ok(recovered);
  }

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> complete(
    String jobId,
    TranscriptRun completedRun,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
    String? warningCode,
  }) async {
    completionCalls.add((
      jobId: jobId,
      run: completedRun,
      segments: List<TranscriptSegment>.unmodifiable(segments),
      storedAtUtcMs: storedAtUtcMs,
    ));
    final configuredCompletionFailure = completionFailure;
    if (configuredCompletionFailure != null) {
      return Err(configuredCompletionFailure);
    }
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    if (job == null) return const Err(AnalysisNotFound());
    jobs[jobId] = job.copyWith(
      state: warningCode == null
          ? const ProcessingSucceeded()
          : ProcessingSucceededWithWarning(warningCode: warningCode),
      checkpoint: warningCode == null
          ? null
          : TranscriptionCompletionWarning(
              warningCode: warningCode,
            ).toStorageJson(),
    );
    runs[completedRun.id] = completedRun;
    final isCurrent = !_selectedRunByMeeting.containsKey(
      completedRun.meetingId,
    );
    if (isCurrent) {
      _selectedRunByMeeting[completedRun.meetingId] = completedRun.id;
    }
    _changes.add(job.meetingId);
    return Ok(
      TranscriptVersion(
        run: completedRun,
        segments: segments,
        isCurrent: isCurrent,
      ),
    );
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> fail(
    String jobId, {
    required String failureCode,
    required int failedAtUtcMs,
  }) async {
    failureCalls.add((
      jobId: jobId,
      failureCode: failureCode,
      failedAtUtcMs: failedAtUtcMs,
    ));
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    if (job == null) return const Err(AnalysisNotFound());
    final updated = job.copyWith(
      state: ProcessingFailed(failureCode: failureCode),
    );
    jobs[jobId] = updated;
    final runId = job.targetRunId;
    final run = runId == null ? null : runs[runId];
    if (run?.state case final AnalysisRunning running) {
      runs[run!.id] = run.copyWith(
        state: AnalysisFailed(
          startedAtUtcMs: running.startedAtUtcMs,
          endedAtUtcMs: failedAtUtcMs,
          progress: running.progress,
          failureCode: failureCode,
        ),
      );
    }
    _changes.add(job.meetingId);
    return Ok(updated);
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> retry(
    String jobId, {
    required int queuedAtUtcMs,
  }) async {
    retryCalls.add((jobId: jobId, queuedAtUtcMs: queuedAtUtcMs));
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final job = jobs[jobId];
    if (job == null) return const Err(AnalysisNotFound());
    final updated = job.copyWith(state: const ProcessingQueued());
    jobs[jobId] = updated;
    final runId = job.targetRunId;
    final run = runId == null ? null : runs[runId];
    if (run != null) runs[run.id] = run.copyWith(state: const AnalysisQueued());
    _changes.add(job.meetingId);
    return Ok(updated);
  }

  @override
  Future<Result<ProcessingJob, AnalysisRepositoryFailure>> cancel(
    String jobId, {
    required int cancelledAtUtcMs,
  }) async {
    cancellationCalls.add((jobId: jobId, cancelledAtUtcMs: cancelledAtUtcMs));
    return fail(
      jobId,
      failureCode: 'transcription_cancelled',
      failedAtUtcMs: cancelledAtUtcMs,
    );
  }

  Result<List<ProcessingJob>, AnalysisRepositoryFailure> _meetingSnapshot(
    String meetingId,
  ) {
    final configuredFailure = failure;
    if (configuredFailure != null) return Err(configuredFailure);
    final matching =
        jobs.values
            .where((job) => job.meetingId == meetingId)
            .toList(growable: false)
          ..sort((left, right) {
            final byCreated = left.createdAtUtcMs.compareTo(
              right.createdAtUtcMs,
            );
            return byCreated != 0 ? byCreated : left.id.compareTo(right.id);
          });
    return Ok(List<ProcessingJob>.unmodifiable(matching));
  }
}

final class FakeLanguageIdentificationEngine
    implements LanguageIdentificationEngine {
  final List<LanguageIdentificationRequest> requests = [];
  Result<LanguageIdentification, LanguageIdentificationFailure> result =
      const Ok(
        LanguageIdentification(
          segmentId: 'fake-segment',
          language: IdentifiedLanguage.uncertain,
          confidence: 0,
        ),
      );

  @override
  Future<Result<LanguageIdentification, LanguageIdentificationFailure>>
  identify(
    LanguageIdentificationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

final class FakeSpeakerDiarizationEngine implements SpeakerDiarizationEngine {
  final List<SpeakerDiarizationRequest> requests = [];
  Result<SpeakerDiarizationOutput, SpeakerDiarizationFailure> result = Ok(
    SpeakerDiarizationOutput(turns: []),
  );

  @override
  Future<Result<SpeakerDiarizationOutput, SpeakerDiarizationFailure>> analyze(
    SpeakerDiarizationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

final class FakeModelManager implements ModelManager {
  final List<String> verifiedModelIds = [];
  Result<ModelInventory, ModelFailure> listResult = Ok(
    ModelInventory(models: []),
  );
  Result<ModelDescriptor, ModelFailure> verifyResult = const Ok(
    ModelDescriptor(id: 'fake-model', version: 'test', bytes: 0),
  );

  @override
  Future<Result<ModelInventory, ModelFailure>> listInstalled() async =>
      listResult;

  @override
  Future<Result<ModelDescriptor, ModelFailure>> verify(String modelId) async {
    verifiedModelIds.add(modelId);
    return verifyResult;
  }
}

final class FakeThermalAndPerformanceMonitor
    implements ThermalAndPerformanceMonitor {
  int currentCalls = 0;
  Result<DevicePerformanceSnapshot, PerformanceFailure> result = Ok(
    DevicePerformanceSnapshot(
      observedAtMonotonic: Duration.zero,
      processCpuTime: Duration.zero,
      processPssBytes: 0,
      thermalState: ThermalState.unknown,
      isCharging: false,
    ),
  );

  @override
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>>
  current() async {
    currentCalls += 1;
    return result;
  }
}

final class FakeSessionRepository implements SessionRepository {
  final List<SessionSummary> savedSessions = [];
  Result<SessionCollection, SessionRepositoryFailure> listResult = Ok(
    SessionCollection(sessions: const []),
  );
  Result<SessionSummary, SessionRepositoryFailure>? saveResult;

  @override
  Future<Result<SessionCollection, SessionRepositoryFailure>> list() async =>
      listResult;

  @override
  Future<Result<SessionSummary, SessionRepositoryFailure>> save(
    SessionSummary session,
  ) async {
    savedSessions.add(session);
    return saveResult ?? Ok(session);
  }

  @override
  Stream<Result<SessionLibraryPage, SessionRepositoryFailure>> watchLibrary(
    SessionLibraryQuery query,
  ) => Stream.value(
    Ok(SessionLibraryPage(meetings: const [], nextCursor: null)),
  );

  @override
  Future<Result<SessionLibraryPage, SessionRepositoryFailure>> queryLibrary(
    SessionLibraryQuery query,
  ) async => Ok(SessionLibraryPage(meetings: const [], nextCursor: null));

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  ) async => Ok(meeting);

  @override
  Future<Result<List<SessionSearchHit>, SessionRepositoryFailure>> search(
    String query,
  ) async => const Ok(<SessionSearchHit>[]);

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> moveToTrash(
    String meetingId, {
    required int atUtcMs,
  }) async => const Err(SessionRepositoryUnavailable('fake_not_configured'));

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> restoreFromTrash(
    String meetingId, {
    required int atUtcMs,
  }) async => const Err(SessionRepositoryUnavailable('fake_not_configured'));

  @override
  Future<Result<void, SessionRepositoryFailure>> permanentlyDelete(
    String meetingId,
  ) async => const Ok<void, SessionRepositoryFailure>(null);

  @override
  Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
  accountStorage() async => const Ok(
    SessionStorageAccounting(activeMeetingBytes: 0, trashBytes: 0),
  );

  @override
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
  }) async => Ok(
    SessionRecoveryReport(
      markedRecoverableIds: const [],
      unchangedIds: evidence.map((item) => item.meetingId).toList(),
    ),
  );
}

final class FakeExportService implements ExportService {
  final List<ExportRequest> requests = [];
  Result<ExportReceipt, ExportFailure> result = const Ok(
    ExportReceipt(outputPath: '/tmp/loquiris-export'),
  );

  @override
  Future<Result<ExportReceipt, ExportFailure>> export(
    ExportRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}
