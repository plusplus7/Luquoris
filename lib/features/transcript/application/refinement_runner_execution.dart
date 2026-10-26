part of 'refinement_runner.dart';

// Native execution and publication are separate from process owner management.
extension _RefinementRunnerExecution on RefinementRunner {
  Future<ProcessingJob> _work(
    _ActiveRefinement owner,
    ProcessingJob job,
    TranscriptRun run,
    ProcessingModelProfile profile,
    String expectedHash,
  ) async {
    if (owner.cancelled) return _cancel(job.id);
    final detail = _value(await sessions.loadDetail(job.meetingId));
    final inspected = await audio.inspect(
      job.meetingId,
      expectedSha256: expectedHash,
    );
    if (owner.cancelled) return _cancel(job.id);
    if (inspected case Err(:final failure)) {
      return switch (failure) {
        RefinementAudioDeferred() => _pause(job.id, failure.code),
        RefinementAudioCancelled() => _cancel(job.id),
        RefinementAudioUnavailable() => _fail(job.id, failure.code),
      };
    }
    final inventory =
        (inspected as Ok<RefinementAudioInventory, RefinementAudioFailure>)
            .value;
    final rejection = refinementAudioInventoryRejection(detail, inventory);
    if (inventory.sha256 != expectedHash || rejection != null) {
      return _fail(job.id, rejection ?? 'refinement_audio_changed');
    }
    final input = RefinementExecutionInput(
      meetingId: job.meetingId,
      runId: run.id,
      audioInventorySha256: expectedHash,
      totalSamples: inventory.totalSamples,
      profile: profile,
    );
    owner
      ..input = input
      ..inNative = true;
    final Result<TranscriptionOutput, RefinementExecutionFailure> result;
    try {
      result = await execution.transcribe(input);
    } on Object {
      _retainUnconfirmed(owner);
    } finally {
      if (!owner.cleanupUnconfirmed) owner.inNative = false;
    }
    if (result case Err(failure: RefinementExecutionUnsettled())) {
      _retainUnconfirmed(owner);
    }
    if (owner.cancelled) return _cancel(job.id);
    if (result case Err(:final failure)) {
      return switch (failure) {
        RefinementExecutionDeferred() => _pause(job.id, failure.code),
        RefinementExecutionCancelled() => _cancel(job.id),
        RefinementExecutionUnavailable() => _fail(job.id, failure.code),
        RefinementExecutionUnsettled() => _retainUnconfirmed(owner),
      };
    }
    final output =
        (result as Ok<TranscriptionOutput, RefinementExecutionFailure>).value;
    final segments = _segments(run.id, output, input);
    if (segments == null) return _fail(job.id, 'refinement_output_invalid');
    // No await between the cancellation check and commit reservation. A later
    // cancel is rejected as finishing rather than acknowledging a false cancel.
    owner.committing = true;
    final running = run.state;
    if (running is! AnalysisRunning) {
      throw const _RunAbort(
        RefinementRunFailure('refinement_provenance_invalid'),
      );
    }
    final endedAt = _now;
    _value(
      await jobs.complete(
        job.id,
        run.copyWith(
          state: AnalysisCompleted(
            startedAtUtcMs: running.startedAtUtcMs,
            endedAtUtcMs: endedAt,
          ),
        ),
        segments,
        storedAtUtcMs: endedAt,
      ),
    );
    return _value(await jobs.load(job.id));
  }
}
