import 'dart:async';

import 'package:clock/clock.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/refinement_audio_validation.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/refinement_identity.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';
import 'package:meta/meta.dart';

/// Content-free failure to schedule an explicitly selected complete pass.
sealed class RefinementScheduleFailure implements Failure {
  const RefinementScheduleFailure(this.code);
  @override
  final String code;
}

/// Input, provenance, or persistence could not authorize a new run.
final class RefinementScheduleUnavailable extends RefinementScheduleFailure {
  /// Creates a stable rejection without native exception details.
  const RefinementScheduleUnavailable(super.code);
}

/// Durable finalization or higher-priority recording is not ready yet.
final class RefinementScheduleDeferred extends RefinementScheduleFailure {
  /// Creates a resumable scheduling outcome.
  const RefinementScheduleDeferred(super.code);
}

/// Idempotent queue construction; never runs an engine or changes current text.
final class RefinementScheduler {
  /// Injects durable authorities, read-only native inspection, and the clock.
  RefinementScheduler({
    required this.sessions,
    required this.selections,
    required this.processing,
    required this.jobs,
    required this.models,
    required this.transcripts,
    required this.audio,
    required this.clock,
  });

  /// Authoritative meeting lifecycle and persisted segment inventory.
  final SessionRepository sessions;

  /// Explicit frozen new-meeting role selection.
  final MeetingProcessingSelectionRepository selections;

  /// Atomic paired run/job/provenance writer.
  final TranscriptProcessingRepository processing;

  /// Existing queued or completed jobs, including restored aliases.
  final TranscriptionJobRepository jobs;

  /// Immutable local model catalog, not a runtime downloader.
  final ModelRepository models;

  /// Retained live draft versions that may precede refinement.
  final TranscriptRepository transcripts;

  /// Complete original audio inspection, never live draft PCM.
  final RefinementAudioInventoryService audio;

  /// Injected observation time; identities never depend on it.
  final Clock clock;
  final Map<String, Future<void>> _pending = {};

  /// Queues or reuses exact durable work; null means no new-mode opt-in.
  @useResult
  Future<Result<ProcessingJob?, RefinementScheduleFailure>> schedule(
    String meetingId,
  ) async {
    final previous = _pending[meetingId];
    final done = Completer<void>();
    _pending[meetingId] = done.future;
    try {
      if (previous != null) await previous;
      return Ok(await _schedule(meetingId));
    } on _ScheduleAbort catch (abort) {
      return Err(abort.failure);
    } finally {
      done.complete();
      if (identical(_pending[meetingId], done.future)) {
        final _ = _pending.remove(meetingId);
      }
    }
  }

  Future<ProcessingJob?> _schedule(String meetingId) async {
    final selection = _value(await selections.load(meetingId));
    if (selection == null) return null;
    final profile = selection.refinement;
    if (profile == null) return null;
    final detail = _value(await sessions.loadDetail(meetingId));
    _require(
      detail.meeting.lifecycle == MeetingLifecycle.finalized,
      'refinement_not_finalized',
      deferred: true,
    );
    _require(
      detail.segments.isNotEmpty,
      'refinement_inventory_not_durable',
      deferred: true,
    );
    final inventory = _value(await audio.inspect(meetingId));
    _validateAudio(detail, inventory);
    final existing = await _existing(meetingId, profile, inventory.sha256);
    if (existing != null) return existing;
    final bound = await _bindModel(profile);
    final source = await _liveSource(meetingId, selection.live);
    _require(
      _value(await selections.load(meetingId)) == selection,
      'refinement_selection_changed',
    );
    final identity = _value(
      RefinementIdentity.tryCreate(
        meetingId: meetingId,
        audioInventorySha256: inventory.sha256,
        profile: profile,
      ),
    );
    final run = TranscriptRun(
      id: identity.runId,
      meetingId: meetingId,
      provenance: bound,
      createdAtUtcMs: detail.meeting.createdAtUtcMs,
      state: const AnalysisQueued(),
    );
    return _value(
      await processing.enqueueRefinement(
        ProcessingJob(
          id: identity.jobId,
          meetingId: meetingId,
          kind: ProcessingJobKind.transcription,
          createdAtUtcMs: run.createdAtUtcMs,
          state: const ProcessingQueued(),
          targetRunId: run.id,
          modelId: bound.modelId,
        ),
        run,
        TranscriptProcessingInfo(
          role: TranscriptProcessingRole.refinement,
          completeness: TranscriptCompleteness.incomplete,
          bundleManifestJson: profile.bundleManifestJson,
          sourceRunId: source,
          audioInventorySha256: inventory.sha256,
        ),
        storedAtUtcMs: clock.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _validateAudio(
    SessionDetail detail,
    RefinementAudioInventory inventory,
  ) {
    final rejection = refinementAudioInventoryRejection(detail, inventory);
    if (rejection != null) _require(false, rejection);
  }

  Future<ProcessingJob?> _existing(
    String meetingId,
    ProcessingModelProfile profile,
    String audioHash,
  ) async {
    final retained = _value(await jobs.watchMeeting(meetingId).first);
    for (final job in retained) {
      final runId = job.targetRunId;
      if (runId == null) continue;
      final info = _value(await processing.load(runId));
      if (info == null ||
          info.role != TranscriptProcessingRole.refinement ||
          info.bundleManifestJson != profile.bundleManifestJson ||
          info.audioInventorySha256 != audioHash) {
        continue;
      }
      final run = _value(await jobs.loadRun(runId));
      if (!_matchesProfile(run, profile)) continue;
      _require(
        run.meetingId == meetingId && job.modelId == run.provenance.modelId,
        'refinement_provenance_conflict',
      );
      return job;
    }
    return null;
  }

  Future<InferenceProvenance> _bindModel(ProcessingModelProfile profile) async {
    final installed = _value(await models.listInstalled());
    for (final model in installed) {
      if (model.sha256 == profile.manifest.sha256) {
        return _value(profile.bindToInstalledModel(model));
      }
    }
    final registered = _value(
      await models.registerBundled(
        profile.manifest.toInstalledModel(),
        observedAtUtcMs: clock.now().millisecondsSinceEpoch,
      ),
    );
    return _value(profile.bindToInstalledModel(registered));
  }

  Future<String?> _liveSource(
    String meetingId,
    ProcessingModelProfile? profile,
  ) async {
    if (profile == null) return null;
    for (final version in _value(await transcripts.listVersions(meetingId))) {
      final info = _value(await processing.load(version.run.id));
      if (info?.role == TranscriptProcessingRole.liveDraft &&
          info?.bundleManifestJson == profile.bundleManifestJson &&
          _matchesProfile(version.run, profile)) {
        return version.run.id;
      }
    }
    return null;
  }

  bool _matchesProfile(TranscriptRun run, ProcessingModelProfile profile) =>
      run.provenance.engineId == profile.manifest.engineId &&
      run.provenance.engineVersion == profile.engineVersion &&
      run.provenance.modelVersion == profile.manifest.version &&
      run.provenance.modelSha256 == profile.manifest.sha256 &&
      run.provenance.parametersJson == profile.parametersJson;

  void _require(bool condition, String code, {bool deferred = false}) {
    if (!condition) {
      throw _ScheduleAbort(
        deferred
            ? RefinementScheduleDeferred(code)
            : RefinementScheduleUnavailable(code),
      );
    }
  }

  T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw _ScheduleAbort(
      failure is RefinementAudioDeferred
          ? RefinementScheduleDeferred(failure.code)
          : RefinementScheduleUnavailable(failure.code),
    ),
  };
}

final class _ScheduleAbort implements Exception {
  const _ScheduleAbort(this.failure);
  final RefinementScheduleFailure failure;
}
