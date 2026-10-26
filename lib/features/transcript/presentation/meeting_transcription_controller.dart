import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamNotifierProviderFamily;
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/refinement_runner.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';
import 'package:meta/meta.dart';

/// Invokes one durable transcription retry without exposing engine details.
typedef TranscriptionRetryHandler = Future<void> Function(String jobId);

/// Resumes a validated paused refinement through the shared inference queue.
typedef RefinementResumeHandler =
    Future<Result<ProcessingJob, RefinementRunFailure>> Function(String jobId);

/// Typed recovery bridge that preserves coordinator ownership and quarantine.
final refinementResumeHandlerProvider = Provider<RefinementResumeHandler>(
  (ref) => ref.read(transcriptionCoordinatorProvider.notifier).resumeRefinement,
);

/// Production retry bridge; tests may replace it with a controlled boundary.
final Provider<TranscriptionRetryHandler> transcriptionRetryHandlerProvider =
    Provider<TranscriptionRetryHandler>((ref) {
      return ref.read(transcriptionCoordinatorProvider.notifier).retry;
    });

/// Durable transcription jobs plus the selected stable transcript, if any.
@immutable
final class MeetingTranscriptionState {
  /// Creates one immutable meeting-local transcription projection.
  MeetingTranscriptionState({
    required List<ProcessingJob> jobs,
    required this.document,
    required Set<String> retryingJobIds,
    Set<String> resumableJobIds = const {},
    this.failure,
    this.retryFailed = false,
  }) : jobs = List<ProcessingJob>.unmodifiable(jobs),
       retryingJobIds = Set<String>.unmodifiable(retryingJobIds),
       resumableJobIds = Set<String>.unmodifiable(resumableJobIds);

  /// Durable transcription jobs in creation order.
  final List<ProcessingJob> jobs;

  /// Selected transcript and edit context after a stable run completes.
  final TranscriptEditorDocument? document;

  /// Typed local-store failure; never contains transcript or path data.
  final AnalysisRepositoryFailure? failure;

  /// Jobs whose repeated retry taps are currently coalesced.
  final Set<String> retryingJobIds;

  /// Paused jobs whose durable sidecar explicitly validates the refinement role.
  final Set<String> resumableJobIds;

  /// Whether the retry boundary threw before durable state could change.
  final bool retryFailed;

  /// Most recently created transcription job.
  ProcessingJob? get latestJob => jobs.lastOrNull;

  /// Returns an updated immutable projection.
  MeetingTranscriptionState copyWith({
    Set<String>? retryingJobIds,
    bool? retryFailed,
  }) => MeetingTranscriptionState(
    jobs: jobs,
    document: document,
    failure: failure,
    retryingJobIds: retryingJobIds ?? this.retryingJobIds,
    resumableJobIds: resumableJobIds,
    retryFailed: retryFailed ?? this.retryFailed,
  );
}

/// Watches only durable database state for one meeting's transcription UI.
final class MeetingTranscriptionController
    extends StreamNotifier<MeetingTranscriptionState> {
  /// Creates a controller for [meetingId].
  MeetingTranscriptionController(this.meetingId);

  /// Route-derived meeting identity.
  final String meetingId;
  final Set<String> _retryingJobIds = <String>{};

  /// Requests recovery without exposing an unhandled future to widget callbacks.
  void resume(String jobId) => unawaited(_resume(jobId));

  Future<void> _resume(String jobId) async {
    final current = state.value;
    if (current == null ||
        !current.resumableJobIds.contains(jobId) ||
        !_retryingJobIds.add(jobId)) {
      return;
    }
    _publishRetryState(retryFailed: false);
    try {
      final result = await ref.read(refinementResumeHandlerProvider)(jobId);
      if (ref.mounted && result is Err<ProcessingJob, RefinementRunFailure>) {
        _publishRetryState(retryFailed: true);
      }
    } on Object {
      if (ref.mounted) _publishRetryState(retryFailed: true);
    } finally {
      _retryingJobIds.remove(jobId);
      if (ref.mounted) _publishRetryState();
    }
  }

  @override
  Stream<MeetingTranscriptionState> build() => ref
      .watch(transcriptionJobRepositoryProvider)
      .watchMeeting(meetingId)
      .asyncMap(_project);

  /// Coalesces repeated retry requests for the same durable failed job.
  Future<void> retry(String jobId) async {
    final current = state.value;
    final job = current?.jobs
        .where((candidate) => candidate.id == jobId)
        .firstOrNull;
    if (job?.state is! ProcessingFailed || !_retryingJobIds.add(jobId)) {
      return;
    }
    _publishRetryState(retryFailed: false);
    try {
      await ref.read(transcriptionRetryHandlerProvider)(jobId);
    } on Object {
      if (ref.mounted) _publishRetryState(retryFailed: true);
    } finally {
      _retryingJobIds.remove(jobId);
      if (ref.mounted) _publishRetryState();
    }
  }

  Future<MeetingTranscriptionState> _project(
    Result<List<ProcessingJob>, AnalysisRepositoryFailure> result,
  ) async {
    if (result case Err(:final failure)) {
      return MeetingTranscriptionState(
        jobs: const [],
        document: null,
        retryingJobIds: _retryingJobIds,
        failure: failure,
      );
    }
    final jobs =
        (result as Ok<List<ProcessingJob>, AnalysisRepositoryFailure>).value;
    TranscriptEditorDocument? document;
    AnalysisRepositoryFailure? failure;
    final resumableJobIds = <String>{};
    for (final job in jobs) {
      if (job.state is! ProcessingPaused || job.targetRunId == null) continue;
      final metadata = await ref
          .read(transcriptProcessingRepositoryProvider)
          .load(job.targetRunId!);
      switch (metadata) {
        case Ok(value: final info?)
            when info.role == TranscriptProcessingRole.refinement:
          resumableJobIds.add(job.id);
        case Err(failure: final rejected):
          failure = rejected;
        case Ok():
          break;
      }
    }
    final loaded = await ref
        .read(transcriptRepositoryProvider)
        .loadEditor(meetingId);
    switch (loaded) {
      case Ok(:final value):
        if (value.currentVersion != null) document = value;
      case Err(failure: AnalysisNotFound()):
        break;
      case Err(failure: final failureValue):
        failure = failureValue;
    }
    return MeetingTranscriptionState(
      jobs: jobs,
      document: document,
      retryingJobIds: _retryingJobIds,
      failure: failure,
      resumableJobIds: resumableJobIds,
    );
  }

  void _publishRetryState({bool? retryFailed}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        retryingJobIds: _retryingJobIds,
        retryFailed: retryFailed,
      ),
    );
  }
}

/// Route-scoped durable transcription projection keyed by meeting identity.
final StreamNotifierProviderFamily<
  MeetingTranscriptionController,
  MeetingTranscriptionState,
  String
>
meetingTranscriptionControllerProvider = StreamNotifierProvider.autoDispose
    .family<MeetingTranscriptionController, MeetingTranscriptionState, String>(
      MeetingTranscriptionController.new,
    );
