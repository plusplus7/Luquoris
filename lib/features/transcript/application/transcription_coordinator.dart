import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_ids.dart';
import 'package:loquiris/features/transcript/application/transcription_parameters.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

/// Typed base-model manifest installed by bootstrap.
final transcriptionModelManifestProvider = Provider<BundledModelManifest>(
  (ref) => throw UnimplementedError(
    'Transcription model manifest is not installed',
  ),
);

/// Fire-and-forget bridge invoked only after recording finalization persists.
final transcriptionFinalizationHandlerProvider =
    Provider<void Function(String)>(
      (ref) {
        final coordinator = ref.read(transcriptionCoordinatorProvider.notifier);
        return coordinator.recordingFinalized;
      },
    );

/// Coordinates durable transcription for the lifetime of the application.
final class TranscriptionCoordinator extends AsyncNotifier<void> {
  final Completer<void> _startupReady = Completer<void>();
  final Set<String> _scheduledMeetingIds = <String>{};
  final Map<String, Future<void>> _meetingTails = <String, Future<void>>{};
  final Map<String, Future<void>> _observedFinalizationTasks =
      <String, Future<void>>{};
  final Map<Timer, Completer<bool>> _finalizationPollWaiters =
      <Timer, Completer<bool>>{};
  Future<void> _inferenceTail = Future<void>.value();

  @override
  Future<void> build() async {
    ref.onDispose(_cancelFinalizationPollWaiters);
    try {
      final repository = ref.watch(transcriptionJobRepositoryProvider);
      final now = _nowUtcMs;
      final recovered = await repository.recoverOrphanedRunning(
        recoveredAtUtcMs: now,
      );
      if (recovered case Err()) return;
      final recoverable = await repository.listRecoverable();
      if (recoverable case Err()) return;
      for (final job
          in (recoverable as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>)
              .value) {
        _scheduledMeetingIds.add(job.meetingId);
        unawaited(_serializeInference(() => _resume(job)));
      }
    } on Object {
      // Optional AI startup never prevents recording or application launch.
    } finally {
      if (!_startupReady.isCompleted) _startupReady.complete();
    }
  }

  /// Accepts a finalized recording without retaining its asynchronous future.
  void recordingFinalized(String meetingId) {
    if (_observedFinalizationTasks.containsKey(meetingId)) return;
    late final Future<void> task;
    task = _scheduleAfterDurableFinalization(meetingId).whenComplete(() {
      if (identical(_observedFinalizationTasks[meetingId], task)) {
        final _ = _observedFinalizationTasks.remove(meetingId);
      }
    });
    _observedFinalizationTasks[meetingId] = task;
    unawaited(task);
  }

  /// Idempotently schedules the complete post-session pass for [meetingId].
  Future<void> scheduleFinalized(
    String meetingId, {
    PerformanceMode executionMode = PerformanceMode.postSession,
  }) async {
    await _startupReady.future;
    await _serializeMeeting(meetingId, () async {
      if (_scheduledMeetingIds.contains(meetingId) ||
          executionMode == PerformanceMode.recordingOnly) {
        return;
      }
      final detail = await _loadDetail(meetingId);
      if (detail == null ||
          detail.meeting.lifecycle != MeetingLifecycle.finalized) {
        return;
      }
      final manifest = ref.read(transcriptionModelManifestProvider);
      if (!isSupportedTranscriptionManifest(manifest)) return;
      final parameters = TranscriptionParameters.forMeeting(
        meeting: detail.meeting,
        manifest: manifest,
        executionMode: executionMode,
      );
      if (!parameters.isTranscriptionEnabled) return;
      final createdAtUtcMs = _stableCreationTime(detail);
      final runId = transcriptionRunId(
        meetingId: meetingId,
        parameters: parameters,
      );
      final job = ProcessingJob(
        id: transcriptionJobId(
          meetingId: meetingId,
          parameters: parameters,
        ),
        meetingId: meetingId,
        kind: ProcessingJobKind.transcription,
        createdAtUtcMs: createdAtUtcMs,
        state: const ProcessingQueued(),
        targetRunId: runId,
        modelId: parameters.modelId,
      );
      final run = TranscriptRun(
        id: runId,
        meetingId: meetingId,
        provenance: parameters.provenance,
        createdAtUtcMs: createdAtUtcMs,
        state: const AnalysisQueued(),
      );
      final queued = await ref
          .read(transcriptionJobRepositoryProvider)
          .enqueue(job, run, storedAtUtcMs: _nowUtcMs);
      if (queued case Err()) return;
      _scheduledMeetingIds.add(meetingId);
      final stored =
          (queued as Ok<ProcessingJob, AnalysisRepositoryFailure>).value;
      if (stored.state is ProcessingQueued ||
          stored.state is ProcessingPaused) {
        await _serializeInference(
          () => _execute(stored, detail, parameters),
        );
      }
    });
  }

  /// Requeues one failed durable job and resumes the same deterministic run.
  Future<void> retry(String jobId) async {
    await _startupReady.future;
    final repository = ref.read(transcriptionJobRepositoryProvider);
    final loaded = await repository.load(jobId);
    if (loaded case Err()) return;
    final job = (loaded as Ok<ProcessingJob, AnalysisRepositoryFailure>).value;
    await _serializeMeeting(job.meetingId, () async {
      final detail = await _loadDetail(job.meetingId);
      if (detail == null) return;
      final manifest = ref.read(transcriptionModelManifestProvider);
      if (!isSupportedTranscriptionManifest(manifest)) return;
      final parameters = TranscriptionParameters.forMeeting(
        meeting: detail.meeting,
        manifest: manifest,
      );
      final retried = await repository.retry(
        job.id,
        queuedAtUtcMs: _nowUtcMs,
      );
      if (retried case Err()) return;
      await _serializeInference(
        () => _execute(
          (retried as Ok<ProcessingJob, AnalysisRepositoryFailure>).value,
          detail,
          parameters,
        ),
      );
    });
  }

  /// Waits until every currently queued startup or inference action settles.
  Future<void> waitForIdle() async {
    await _startupReady.future;
    while (true) {
      final inference = _inferenceTail;
      final meetings = _meetingTails.values.toList(growable: false);
      await Future.wait<void>(<Future<void>>[inference, ...meetings]);
      if (identical(inference, _inferenceTail) && _meetingTails.isEmpty) return;
    }
  }

  Future<void> _scheduleAfterDurableFinalization(String meetingId) async {
    await _startupReady.future;
    const maximumAttempts = 40;
    for (var attempt = 0; attempt < maximumAttempts; attempt += 1) {
      if (!ref.mounted || _scheduledMeetingIds.contains(meetingId)) return;
      final detail = await _loadDetail(meetingId);
      if (detail?.meeting.lifecycle == MeetingLifecycle.finalized) {
        await scheduleFinalized(meetingId);
        return;
      }
      if (!await _waitForFinalizationPoll()) return;
    }
  }

  Future<bool> _waitForFinalizationPoll() {
    if (!ref.mounted) return Future<bool>.value(false);
    final completer = Completer<bool>();
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 250), () {
      final waiter = _finalizationPollWaiters.remove(timer);
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(ref.mounted);
      }
    });
    _finalizationPollWaiters[timer] = completer;
    return completer.future;
  }

  void _cancelFinalizationPollWaiters() {
    final waiters = _finalizationPollWaiters.entries.toList(growable: false);
    _finalizationPollWaiters.clear();
    for (final MapEntry(key: timer, value: completer) in waiters) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(false);
    }
  }

  Future<void> _resume(ProcessingJob job) async {
    final detail = await _loadDetail(job.meetingId);
    if (detail == null) return;
    final manifest = ref.read(transcriptionModelManifestProvider);
    if (!isSupportedTranscriptionManifest(manifest)) return;
    final parameters = TranscriptionParameters.forMeeting(
      meeting: detail.meeting,
      manifest: manifest,
    );
    await _execute(job, detail, parameters);
  }

  Future<SessionDetail?> _loadDetail(String meetingId) async {
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .loadDetail(
            meetingId,
          );
      return switch (result) {
        Ok(:final value) => value,
        Err() => null,
      };
    } on Object {
      return null;
    }
  }

  Future<void> _execute(
    ProcessingJob job,
    SessionDetail detail,
    TranscriptionParameters parameters,
  ) async {
    final repository = ref.read(transcriptionJobRepositoryProvider);
    final runId = job.targetRunId;
    if (runId == null) return;
    final startedAtUtcMs = _nowUtcMs;
    final started = await repository.start(
      job.id,
      startedAtUtcMs: startedAtUtcMs,
    );
    if (started case Err()) return;

    final verification = await ref
        .read(modelManagerProvider)
        .verify(parameters.modelId);
    if (verification case Err(:final failure)) {
      final _ = await repository.fail(
        job.id,
        failureCode: failure.code,
        failedAtUtcMs: _nowUtcMs,
      );
      return;
    }

    final segmentPaths =
        detail.segments
            .where(
              (segment) =>
                  segment.state == AudioSegmentState.committed &&
                  segment.committedBytes > 0,
            )
            .toList(growable: false)
          ..sort((left, right) => left.sequence.compareTo(right.sequence));
    if (segmentPaths.isEmpty) {
      final _ = await repository.fail(
        job.id,
        failureCode: 'transcription_audio_unavailable',
        failedAtUtcMs: _nowUtcMs,
      );
      return;
    }

    final engine = ref.read(transcriptionEngineProvider);
    var progressTail = Future<void>.value();
    var lastProgress = 0.0;
    final subscription = engine.eventsFor(runId).listen((event) {
      if (event is! TranscriptionProgressUpdated ||
          event.fraction < lastProgress) {
        return;
      }
      lastProgress = event.fraction;
      progressTail = progressTail.then((_) async {
        final _ = await repository.saveProgress(
          job.id,
          progress: event.fraction,
          checkpoint: TranscriptionCheckpoint(
            completedMedia: _completedMedia(
              detail.meeting.mediaDuration,
              event.fraction,
            ),
            parameterVersion: parameters.parameterVersion,
          ),
          storedAtUtcMs: _nowUtcMs,
        );
      });
    });

    Result<TranscriptionOutput, TranscriptionFailure> result;
    try {
      result = await engine.transcribe(
        TranscriptionRequest(
          runId: runId,
          audio: AudioInput(
            sessionId: job.meetingId,
            segmentPaths: segmentPaths
                .map((segment) => segment.relativePath.value)
                .toList(growable: false),
          ),
          modelId: parameters.modelId,
          languageHint: parameters.languageHint,
          parameterVersion: parameters.parameterVersion,
        ),
      );
    } on Object {
      result = const Err(
        TranscriptionUnavailable('transcription_execution_failed'),
      );
    } finally {
      await subscription.cancel();
      await progressTail;
    }

    if (result case Err(:final failure)) {
      final _ = await repository.fail(
        job.id,
        failureCode: failure.code,
        failedAtUtcMs: _nowUtcMs,
      );
      return;
    }
    final output =
        (result as Ok<TranscriptionOutput, TranscriptionFailure>).value;
    if (output.engineVersion != parameters.engineVersion) {
      final _ = await repository.fail(
        job.id,
        failureCode: 'transcription_engine_version_mismatch',
        failedAtUtcMs: _nowUtcMs,
      );
      return;
    }
    final segments = _stableSegments(runId, output.chunks);
    if (segments == null) {
      final _ = await repository.fail(
        job.id,
        failureCode: 'transcription_output_invalid',
        failedAtUtcMs: _nowUtcMs,
      );
      return;
    }
    final endedAtUtcMs = _nowUtcMs;
    final _ = await repository.complete(
      job.id,
      TranscriptRun(
        id: runId,
        meetingId: job.meetingId,
        provenance: parameters.provenance,
        createdAtUtcMs: job.createdAtUtcMs,
        state: AnalysisCompleted(
          startedAtUtcMs: startedAtUtcMs,
          endedAtUtcMs: endedAtUtcMs,
        ),
      ),
      segments,
      storedAtUtcMs: endedAtUtcMs,
    );
  }

  Future<void> _serializeMeeting(
    String meetingId,
    Future<void> Function() action,
  ) {
    final previous = _meetingTails[meetingId] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then((_) => _contain(action)).whenComplete(() {
      if (identical(_meetingTails[meetingId], next)) {
        final _ = _meetingTails.remove(meetingId);
      }
    });
    _meetingTails[meetingId] = next;
    return next;
  }

  Future<void> _serializeInference(Future<void> Function() action) {
    final next = _inferenceTail.then((_) => _contain(action));
    _inferenceTail = next;
    return next;
  }

  Future<void> _contain(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // All coordinator failures are contained to optional AI work.
    }
  }

  int get _nowUtcMs =>
      ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch;
}

int _stableCreationTime(SessionDetail detail) {
  for (final event in detail.events.reversed) {
    if (event.type == SessionEventType.stopped) return event.wallClockUtcMs;
  }
  return detail.meeting.createdAtUtcMs;
}

Duration _completedMedia(Duration total, double progress) => Duration(
  microseconds: (total.inMicroseconds * progress).round(),
);

List<TranscriptSegment>? _stableSegments(
  String runId,
  List<TranscriptChunk> chunks,
) {
  final segments = <TranscriptSegment>[];
  var previousEnd = Duration.zero;
  for (final chunk in chunks) {
    if (chunk.stability != TranscriptStability.stable ||
        chunk.start < previousEnd ||
        chunk.end <= chunk.start) {
      return null;
    }
    segments.add(
      TranscriptSegment(
        id: transcriptionSegmentId(
          runId: runId,
          start: chunk.start,
          end: chunk.end,
        ),
        transcriptRunId: runId,
        start: chunk.start,
        end: chunk.end,
        rawModelText: chunk.rawText,
        displayedText: chunk.displayText,
        revisionState: TranscriptRevisionState.machine,
      ),
    );
    previousEnd = chunk.end;
  }
  return List<TranscriptSegment>.unmodifiable(segments);
}

/// Process-lifetime transcription state; deliberately not auto-disposed.
final AsyncNotifierProvider<TranscriptionCoordinator, void>
transcriptionCoordinatorProvider =
    AsyncNotifierProvider<TranscriptionCoordinator, void>(
      TranscriptionCoordinator.new,
    );
