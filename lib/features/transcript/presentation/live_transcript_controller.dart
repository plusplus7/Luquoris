import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:meta/meta.dart';

/// User-visible lifecycle of an experimental live draft.
enum LiveTranscriptStatus {
  /// The meeting selected post-session processing, so no live engine opened.
  inactive,

  /// The bounded live engine is accepting incremental events.
  running,

  /// Live work stopped or lost content; the complete pass remains armed.
  degraded,

  /// The owner explicitly stopped and released the live engine.
  stopped,
}

/// Immutable presentation state for one active meeting's read-only draft.
@immutable
final class LiveTranscriptState {
  /// Creates one live draft snapshot.
  LiveTranscriptState({
    required this.status,
    required this.meetingId,
    required List<TranscriptChunk> chunks,
    this.runId,
    this.backlog = Duration.zero,
    this.incomplete = false,
    this.degradationReason,
  }) : chunks = List<TranscriptChunk>.unmodifiable(chunks);

  /// Current live lifecycle.
  final LiveTranscriptStatus status;

  /// Meeting shown by the owning route.
  final String meetingId;

  /// Native run identity, absent when live inference never opened.
  final String? runId;

  /// Reconciled timestamped hypotheses in media-time order.
  final List<TranscriptChunk> chunks;

  /// Audio waiting for live decoding.
  final Duration backlog;

  /// Whether live text may omit captured media or an unstable hypothesis.
  final bool incomplete;

  /// Stable privacy-safe degradation code, when live work stopped safely.
  final String? degradationReason;

  /// The complete post-session pass remains available for every live state.
  bool get fallbackArmed => true;

  /// Whether the live decoder is behind captured media.
  bool get isBacklogged => backlog > Duration.zero;

  LiveTranscriptState _copyWith({
    LiveTranscriptStatus? status,
    List<TranscriptChunk>? chunks,
    Duration? backlog,
    bool? incomplete,
    String? degradationReason,
  }) => LiveTranscriptState(
    status: status ?? this.status,
    meetingId: meetingId,
    runId: runId,
    chunks: chunks ?? this.chunks,
    backlog: backlog ?? this.backlog,
    incomplete: incomplete ?? this.incomplete,
    degradationReason: degradationReason ?? this.degradationReason,
  );
}

/// Owns one screen-scoped live session and reconciles its bounded event stream.
final class LiveTranscriptController
    extends AsyncNotifier<LiveTranscriptState> {
  /// Creates one controller keyed by stable [meetingId].
  LiveTranscriptController(this.meetingId);

  /// Meeting identity supplied by the provider family.
  final String meetingId;

  StreamSubscription<TranscriptionEvent>? _subscription;
  late TranscriptionCoordinator _coordinator;
  LiveTranscriptionSession? _session;
  var _acceptEvents = false;
  var _stopping = false;

  @override
  Future<LiveTranscriptState> build() async {
    ref.onDispose(_dispose);
    _coordinator = ref.watch(transcriptionCoordinatorProvider.notifier);
    final result = await _coordinator.startLiveDraft(meetingId);
    if (!ref.mounted) {
      if (result case Ok(value: final session?)) {
        final _ = await _coordinator.stopLiveDraft(session);
      }
      return LiveTranscriptState(
        status: LiveTranscriptStatus.stopped,
        meetingId: meetingId,
        chunks: const [],
      );
    }
    return switch (result) {
      Err(:final failure) => LiveTranscriptState(
        status: LiveTranscriptStatus.degraded,
        meetingId: meetingId,
        chunks: const [],
        incomplete: true,
        degradationReason: failure.code,
      ),
      Ok(value: null) => LiveTranscriptState(
        status: LiveTranscriptStatus.inactive,
        meetingId: meetingId,
        chunks: const [],
      ),
      Ok(:final value) => _start(value!),
    };
  }

  LiveTranscriptState _start(LiveTranscriptionSession session) {
    _session = session;
    _acceptEvents = true;
    _subscription = session.events.listen(
      _onEvent,
      onError: _onStreamError,
    );
    return LiveTranscriptState(
      status: LiveTranscriptStatus.running,
      meetingId: session.meetingId,
      runId: session.runId,
      chunks: const [],
    );
  }

  void _onEvent(TranscriptionEvent event) {
    final current = state.value;
    final session = _session;
    if (!_acceptEvents ||
        current == null ||
        session == null ||
        event.runId != session.runId) {
      return;
    }
    switch (event) {
      case TranscriptionDraftUpdated(:final chunk, :final backlog):
        final chunks = _replaceChunk(current.chunks, chunk);
        state = AsyncData(
          current._copyWith(chunks: chunks, backlog: backlog),
        );
      case TranscriptionDraftDegraded(
        :final reason,
        :final backlog,
        :final incomplete,
      ):
        state = AsyncData(
          current._copyWith(
            status: LiveTranscriptStatus.degraded,
            backlog: backlog,
            incomplete: current.incomplete || incomplete,
            degradationReason: reason,
          ),
        );
      case TranscriptionProgressUpdated():
        break;
    }
  }

  void _onStreamError(Object _, StackTrace _) {
    final current = state.value;
    if (!_acceptEvents || current == null) return;
    state = AsyncData(
      current._copyWith(
        status: LiveTranscriptStatus.degraded,
        incomplete: true,
        degradationReason: 'transcription_live_unavailable',
      ),
    );
  }

  /// Releases native live work while preserving the last visible draft.
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    _acceptEvents = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final session = _session;
    _session = null;
    if (session != null) {
      final _ = await _coordinator.stopLiveDraft(session);
    }
    if (ref.mounted) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current._copyWith(
            status: LiveTranscriptStatus.stopped,
            backlog: Duration.zero,
          ),
        );
      }
    }
  }

  void _dispose() {
    _acceptEvents = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final session = _session;
    _session = null;
    if (session != null) {
      unawaited(_coordinator.stopLiveDraft(session));
    }
  }
}

List<TranscriptChunk> _replaceChunk(
  List<TranscriptChunk> existing,
  TranscriptChunk incoming,
) {
  final chunks = <TranscriptChunk>[];
  var replaced = false;
  for (final chunk in existing) {
    if (chunk.segmentId != incoming.segmentId) {
      chunks.add(chunk);
      continue;
    }
    replaced = true;
    if (chunk.stability == TranscriptStability.stable &&
        incoming.stability == TranscriptStability.unstable) {
      chunks.add(chunk);
    } else {
      chunks.add(incoming);
    }
  }
  if (!replaced) chunks.add(incoming);
  chunks.sort((left, right) {
    final byStart = left.start.compareTo(right.start);
    return byStart != 0 ? byStart : left.end.compareTo(right.end);
  });
  return List<TranscriptChunk>.unmodifiable(chunks);
}

/// Screen-scoped draft state keyed by stable meeting identity.
final AsyncNotifierProviderFamily<
  LiveTranscriptController,
  LiveTranscriptState,
  String
>
liveTranscriptControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LiveTranscriptController, LiveTranscriptState, String>(
      LiveTranscriptController.new,
    );
