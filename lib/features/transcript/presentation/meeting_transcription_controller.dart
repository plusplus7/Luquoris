import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamNotifierProviderFamily;
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// Invokes one durable transcription retry without exposing engine details.
typedef TranscriptionRetryHandler = Future<void> Function(String jobId);

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
    this.failure,
    this.retryFailed = false,
  }) : jobs = List<ProcessingJob>.unmodifiable(jobs),
       retryingJobIds = Set<String>.unmodifiable(retryingJobIds);

  /// Durable transcription jobs in creation order.
  final List<ProcessingJob> jobs;

  /// Selected transcript and edit context after a stable run completes.
  final TranscriptEditorDocument? document;

  /// Typed local-store failure; never contains transcript or path data.
  final AnalysisRepositoryFailure? failure;

  /// Jobs whose repeated retry taps are currently coalesced.
  final Set<String> retryingJobIds;

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
    if (jobs.any((job) => job.state is ProcessingSucceeded)) {
      final loaded = await ref
          .read(transcriptRepositoryProvider)
          .loadEditor(meetingId);
      switch (loaded) {
        case Ok(:final value):
          document = value;
        case Err(failure: final failureValue):
          failure = failureValue;
      }
    }
    return MeetingTranscriptionState(
      jobs: jobs,
      document: document,
      retryingJobIds: _retryingJobIds,
      failure: failure,
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
