part of 'transcription_coordinator.dart';

extension _PairedTranscriptionDispatch on TranscriptionCoordinator {
  Future<Result<ProcessingJob, RefinementRunFailure>> _resumeExplicitRefinement(
    String jobId,
  ) async {
    Result<ProcessingJob, RefinementRunFailure> result = const Err(
      RefinementRunFailure('refinement_resume_unavailable'),
    );
    await _serializeInference(() async {
      final barrier = _dispatchRef.read(transcriptionInferenceBarrierProvider);
      final loaded = await _dispatchRef
          .read(transcriptionJobRepositoryProvider)
          .load(jobId);
      if (loaded case Err()) return;
      final job =
          (loaded as Ok<ProcessingJob, AnalysisRepositoryFailure>).value;
      if (job.state is! ProcessingPaused || job.targetRunId == null) return;
      final metadata = await _dispatchRef
          .read(transcriptProcessingRepositoryProvider)
          .load(job.targetRunId!);
      if (metadata case Ok(
        value: final info?,
      ) when info.role == TranscriptProcessingRole.refinement) {
        result = await _dispatchRef.read(refinementRunnerProvider).run(jobId);
        if (result case Err(
          :final failure,
        ) when failure.code == 'refinement_cleanup_unconfirmed') {
          barrier.retainUnconfirmedCleanup();
        }
      }
    });
    return result;
  }

  Future<bool> _scheduleExplicitFinalized(String meetingId) async {
    final loaded = await _dispatchRef
        .read(meetingProcessingSelectionRepositoryProvider)
        .load(meetingId);
    if (loaded case Err()) return true;
    final selection =
        (loaded as Ok<MeetingProcessingSelection?, AnalysisRepositoryFailure>)
            .value;
    if (selection == null) return false;
    if (selection.mode == MeetingProcessingMode.recordingOnly) return true;
    final scheduled = await _dispatchRef
        .read(refinementSchedulerProvider)
        .schedule(meetingId);
    if (scheduled case Ok(:final value?)) {
      _scheduledMeetingIds.add(meetingId);
      await _runExplicitJob(value);
    }
    return true;
  }

  Future<void> _runExplicitJob(ProcessingJob job) async {
    if (job.state is! ProcessingQueued && job.state is! ProcessingPaused) {
      return;
    }
    await _serializeInference(() async {
      final barrier = _dispatchRef.read(transcriptionInferenceBarrierProvider);
      final result = await _dispatchRef
          .read(refinementRunnerProvider)
          .run(job.id);
      if (result case Err(
        :final failure,
      ) when failure.code == 'refinement_cleanup_unconfirmed') {
        barrier.retainUnconfirmedCleanup();
      }
    });
  }

  Future<bool> _retryExplicitProcessing(ProcessingJob job) async {
    final runId = job.targetRunId;
    if (runId == null) return !await _allowLegacyForMeeting(job.meetingId);
    final processing = _dispatchRef.read(
      transcriptProcessingRepositoryProvider,
    );
    final loaded = await processing.load(runId);
    if (loaded case Err()) return true;
    final info =
        (loaded as Ok<TranscriptProcessingInfo?, AnalysisRepositoryFailure>)
            .value;
    if (info == null) return !await _allowLegacyForMeeting(job.meetingId);
    if (info.role != TranscriptProcessingRole.refinement) return true;
    var pending = job;
    if (job.state is ProcessingFailed) {
      final retried = await processing.retryRefinement(
        job.id,
        queuedAtUtcMs: _nowUtcMs,
      );
      if (retried case Err()) return true;
      pending = (retried as Ok<ProcessingJob, AnalysisRepositoryFailure>).value;
    }
    await _runExplicitJob(pending);
    return true;
  }

  Future<void> _recoverExplicitProcessing() async {
    final processing = _dispatchRef.read(
      transcriptProcessingRepositoryProvider,
    );
    final recovered = await processing.recoverOrphanedRefinements(
      recoveredAtUtcMs: _nowUtcMs,
    );
    if (recovered case Err()) return;
    final pending = await processing.listRecoverableRefinements();
    if (pending case Err()) return;
    for (final job
        in (pending as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>)
            .value) {
      _scheduledMeetingIds.add(job.meetingId);
      unawaited(_runExplicitJob(job));
    }
    final meetings = await _dispatchRef
        .read(meetingProcessingSelectionRepositoryProvider)
        .listFinalized();
    if (meetings case Err()) return;
    for (final id
        in (meetings as Ok<List<String>, AnalysisRepositoryFailure>).value) {
      if (_scheduledMeetingIds.contains(id)) continue;
      unawaited(
        _serializeMeeting(id, () async {
          await _scheduleExplicitFinalized(id);
        }),
      );
    }
  }

  Future<Result<LiveTranscriptionSession?, TranscriptionFailure>?>
  _explicitLivePolicy(String meetingId) async {
    try {
      final loaded = await _dispatchRef
          .read(meetingProcessingSelectionRepositoryProvider)
          .load(meetingId);
      if (loaded case Err()) {
        return const Err(
          TranscriptionUnavailable('processing_selection_unavailable'),
        );
      }
      final selection =
          (loaded as Ok<MeetingProcessingSelection?, AnalysisRepositoryFailure>)
              .value;
      return switch (selection?.mode) {
        null => null,
        MeetingProcessingMode.recordingOnly ||
        MeetingProcessingMode.postSession => const Ok(null),
        MeetingProcessingMode.twoPass => const Err(
          TranscriptionUnavailable('streaming_engine_unavailable'),
        ),
      };
    } on Object {
      return const Err(
        TranscriptionUnavailable('processing_selection_unavailable'),
      );
    }
  }

  Future<bool> _allowLegacyForMeeting(String meetingId) async {
    final selection = await _dispatchRef
        .read(meetingProcessingSelectionRepositoryProvider)
        .load(meetingId);
    return selection
            is Ok<MeetingProcessingSelection?, AnalysisRepositoryFailure> &&
        selection.value == null;
  }
}
