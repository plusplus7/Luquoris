import 'dart:async';

import 'package:clock/clock.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/refinement_audio_validation.dart';
import 'package:loquiris/features/transcript/application/refinement_run_validation.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';
import 'package:meta/meta.dart';

part 'refinement_runner_execution.dart';

/// A run could not be owned or its durable state could not be established.
final class RefinementRunFailure implements Failure {
  /// Creates a stable content-free runner rejection.
  const RefinementRunFailure(this.code);
  @override
  final String code;
}

/// Executes only explicitly marked refinements; repositories own every durable transition.
final class RefinementRunner {
  /// Injects durable authorities, optional native boundaries and observation time.
  RefinementRunner({
    required this.sessions,
    required this.jobs,
    required this.processing,
    required this.audio,
    required this.execution,
    required this.clock,
  });

  /// Authoritative lifecycle and all original segment geometry.
  final SessionRepository sessions;

  /// Durable job/run completion and failure transactions.
  final TranscriptionJobRepository jobs;

  /// Explicit role ownership, claim, recovery and resumable pause transactions.
  final TranscriptProcessingRepository processing;

  /// Fresh verification of the exact complete original inventory.
  final RefinementAudioInventoryService audio;

  /// Full-profile complete-pass execution, never a draft or legacy engine.
  final RefinementExecutionService execution;

  /// Injected observation clock; identities and output text never depend on it.
  final Clock clock;
  _ActiveRefinement? _active;

  /// Returns the resulting durable job, including pause/failure; duplicate calls join one owner.
  ///
  /// Failed work needs explicit repository retry, and orphaned running work needs
  /// startup recovery. This method never silently reclaims an existing owner.
  @useResult
  Future<Result<ProcessingJob, RefinementRunFailure>> run(String jobId) {
    final current = _active;
    if (current != null) {
      return current.jobId == jobId
          ? current.done.future
          : Future.value(
              const Err(RefinementRunFailure('refinement_worker_busy')),
            );
    }
    final owner = _ActiveRefinement(jobId);
    _active = owner;
    unawaited(_drive(owner));
    return owner.done.future;
  }

  /// Latches cancellation while retaining ownership until native cleanup resolves.
  @useResult
  Future<Result<void, RefinementRunFailure>> requestCancellation(
    String jobId,
  ) async {
    final owner = _active;
    if (owner == null || owner.jobId != jobId) {
      return const Err(
        RefinementRunFailure('refinement_execution_owner_missing'),
      );
    }
    if (owner.committing) {
      return const Err(RefinementRunFailure('refinement_execution_finishing'));
    }
    owner.cancelled = true;
    final input = owner.input;
    if (!owner.inNative || input == null) return const Ok(null);
    try {
      return (await execution.cancel(
        meetingId: input.meetingId,
        runId: input.runId,
      )).fold(
        (_) => const Ok(null),
        (failure) => Err(RefinementRunFailure(_safeCode(failure.code))),
      );
    } on Object {
      return const Err(
        RefinementRunFailure('refinement_cancellation_unavailable'),
      );
    }
  }

  Future<void> _drive(_ActiveRefinement owner) async {
    Result<ProcessingJob, RefinementRunFailure> result;
    try {
      result = Ok(await _execute(owner));
    } on _RunAbort catch (abort) {
      result = Err(abort.failure);
    } on Object {
      result = const Err(RefinementRunFailure('refinement_execution_failed'));
    }
    if (!owner.cleanupUnconfirmed && identical(_active, owner)) _active = null;
    owner.done.complete(result);
  }

  Future<ProcessingJob> _execute(_ActiveRefinement owner) async {
    final job = _value(await jobs.load(owner.jobId));
    final runId = job.targetRunId;
    _require(
      runId != null && job.kind == ProcessingJobKind.transcription,
      'refinement_provenance_invalid',
    );
    final run = _value(await jobs.loadRun(runId!));
    final info = _value(await processing.load(runId));
    final profile = info == null
        ? null
        : refinementProfileForRun(job, run, info);
    if (profile == null) {
      throw const _RunAbort(
        RefinementRunFailure('refinement_provenance_invalid'),
      );
    }
    if (job.state is ProcessingSucceeded ||
        job.state is ProcessingSucceededWithWarning ||
        job.state is ProcessingFailed) {
      return job;
    }
    _require(
      job.state is ProcessingQueued || job.state is ProcessingPaused,
      'refinement_execution_already_owned',
    );
    final startedAt = _now;
    _value(await processing.startRefinement(job.id, startedAtUtcMs: startedAt));
    owner.minimumTimestampMs = startedAt;
    try {
      final claimed = _value(await jobs.loadRun(runId));
      return await _work(
        owner,
        job,
        claimed,
        profile,
        info!.audioInventorySha256!,
      );
    } on _RunAbort catch (abort) {
      if (owner.cleanupUnconfirmed) rethrow;
      return _fail(job.id, abort.failure.code);
    } on Object {
      return _fail(job.id, 'refinement_execution_failed');
    }
  }

  List<TranscriptSegment>? _segments(
    String runId,
    TranscriptionOutput output,
    RefinementExecutionInput input,
  ) => refinementSegments(runId, output, input);

  Future<ProcessingJob> _pause(String id, String code) async {
    _active?.committing = true;
    return _value(
      await processing.pauseRefinement(
        id,
        reasonCode: _safeCode(code),
        pausedAtUtcMs: _now,
      ),
    );
  }

  Future<ProcessingJob> _fail(String id, String code) async {
    _active?.committing = true;
    return _value(
      await jobs.fail(id, failureCode: _safeCode(code), failedAtUtcMs: _now),
    );
  }

  Future<ProcessingJob> _cancel(String id) async {
    _active?.committing = true;
    return _value(await jobs.cancel(id, cancelledAtUtcMs: _now));
  }

  int get _now {
    final observed = clock.now().millisecondsSinceEpoch;
    final minimum = _active?.minimumTimestampMs ?? 0;
    return observed < minimum ? minimum : observed;
  }

  Never _retainUnconfirmed(_ActiveRefinement owner) {
    owner
      ..cleanupUnconfirmed = true
      ..inNative = true;
    throw const _RunAbort(
      RefinementRunFailure('refinement_cleanup_unconfirmed'),
    );
  }

  void _require(bool condition, String code) {
    if (!condition) throw _RunAbort(RefinementRunFailure(code));
  }

  T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw _RunAbort(
      RefinementRunFailure(_safeCode(failure.code)),
    ),
  };
}

final class _ActiveRefinement {
  _ActiveRefinement(this.jobId);
  final String jobId;
  final done = Completer<Result<ProcessingJob, RefinementRunFailure>>();
  RefinementExecutionInput? input;
  bool cancelled = false;
  bool inNative = false;
  bool committing = false;
  bool cleanupUnconfirmed = false;
  int minimumTimestampMs = 0;
}

final class _RunAbort implements Exception {
  const _RunAbort(this.failure);
  final RefinementRunFailure failure;
}

String _safeCode(String code) =>
    _code.hasMatch(code) ? code : 'refinement_execution_failed';
final _code = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
