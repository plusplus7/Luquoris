import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
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
  LiveTranscriptionSession? _session;
  LiveTranscriptionSession? _finishingSession;
  Future<void>? _finishingTask;
  Future<void>? _startingFinish;
  Object _generation = Object();
  Completer<void>? _drained;
  var _acceptEvents = false;
  var _stopping = false;
  var _stopRequested = false;

  @override
  Future<LiveTranscriptState> build() async {
    _generation = Object();
    _startingFinish = null;
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
      _dispose();
    });
    _stopRequested = false;
    final start = ref.watch(liveTranscriptSessionStarterProvider);
    final result = await start(meetingId);
    if (disposed || !ref.mounted || _stopRequested) {
      return _finishLateStart(result, retainSession: !disposed && ref.mounted);
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
    final drained = Completer<void>();
    _drained = drained;
    _subscription = session.events.listen(
      _onEvent,
      onError: _onStreamError,
      onDone: () {
        if (!drained.isCompleted) drained.complete();
      },
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

  /// Flushes normal STOP without delaying recorder navigation or losing finals.
  Future<void> finish() {
    final session = _session;
    if (session == null && state.isLoading) return _finishStarting();
    if (session == null || session.finish == null) return stop();
    if (identical(_finishingSession, session) && _finishingTask != null) {
      return _finishingTask!;
    }
    _stopRequested = true;
    final keepAlive = ref.keepAlive();
    _finishingSession = session;
    final pending = _finishLive(session, _drained);
    _finishingTask = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(_finishingTask, pending)) {
          _finishingTask = null;
          _finishingSession = null;
        }
        keepAlive.close();
      }),
    );
    return pending;
  }

  Future<void> _finishStarting() {
    final existing = _startingFinish;
    if (existing != null) return existing;
    final keepAlive = ref.keepAlive();
    final pending = _finishAfterStartup(_generation);
    _startingFinish = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(_startingFinish, pending)) _startingFinish = null;
        keepAlive.close();
      }),
    );
    return pending;
  }

  Future<void> _finishAfterStartup(Object generation) async {
    try {
      await future;
    } on Object {
      return;
    }
    if (!ref.mounted || !identical(_generation, generation) || _stopRequested) {
      return;
    }
    await finish();
  }

  Future<void> _finishLive(
    LiveTranscriptionSession session,
    Completer<void>? drained,
  ) async {
    Result<void, TranscriptionFailure> result;
    try {
      result = await session.finish!();
      if (result.isOk) await drained?.future;
    } on Object {
      result = const Err(
        TranscriptionUnavailable('transcription_live_cleanup_unconfirmed'),
      );
    }
    if (!identical(_session, session)) return;
    if (result.isOk) {
      _acceptEvents = false;
      _subscription = null;
    }
    _settleStop(session, result);
  }

  /// Releases native live work while preserving the last visible draft.
  Future<void> stop() async {
    _stopRequested = true;
    if (_stopping) return;
    _stopping = true;
    _acceptEvents = false;
    _drainCompleted();
    final subscription = _subscription;
    _subscription = null;
    final session = _session;
    final pending = session == null
        ? Future<Result<void, TranscriptionFailure>>.value(const Ok(null))
        : _releaseLive(session);
    var detached = true;
    try {
      await subscription?.cancel();
    } on Object {
      detached = false;
    }
    final result = await pending;
    _settleStop(
      session,
      detached
          ? result
          : const Err(
              TranscriptionUnavailable(
                'transcription_live_cleanup_unconfirmed',
              ),
            ),
    );
    _stopping = false;
  }

  void _settleStop(
    LiveTranscriptionSession? session,
    Result<void, TranscriptionFailure> result,
  ) {
    if (!identical(_session, session)) return;
    if (result.isOk) _session = null;
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        LiveTranscriptState(
          meetingId: current.meetingId,
          runId: current.runId,
          chunks: current.chunks,
          status: result.isOk
              ? LiveTranscriptStatus.stopped
              : LiveTranscriptStatus.degraded,
          backlog: result.isOk ? Duration.zero : current.backlog,
          incomplete: current.incomplete || !result.isOk,
          degradationReason: result.isOk
              ? null
              : 'transcription_live_cleanup_unconfirmed',
        ),
      );
    }
  }

  Future<LiveTranscriptState> _finishLateStart(
    Result<LiveTranscriptionSession?, TranscriptionFailure> result, {
    required bool retainSession,
  }) async {
    Result<void, TranscriptionFailure> released = const Ok(null);
    if (result case Ok(value: final session?)) {
      if (retainSession) _session = session;
      released = await _releaseLive(session);
      if (released.isOk && identical(_session, session)) _session = null;
    }
    return LiveTranscriptState(
      status: released.isOk
          ? LiveTranscriptStatus.stopped
          : LiveTranscriptStatus.degraded,
      meetingId: meetingId,
      chunks: const [],
      incomplete: !released.isOk,
      degradationReason: released.isOk
          ? null
          : 'transcription_live_cleanup_unconfirmed',
    );
  }

  void _dispose() {
    _acceptEvents = false;
    _drainCompleted();
    _stopRequested = true;
    final session = _session;
    _session = null;
    if (session != null) {
      unawaited(_releaseLive(session));
    }
    try {
      unawaited(_subscription?.cancel().onError((_, _) {}));
    } on Object {
      // View detachment cannot prevent the independent native release.
    } finally {
      _subscription = null;
    }
  }

  void _drainCompleted() {
    final drained = _drained;
    if (drained != null && !drained.isCompleted) drained.complete();
  }

  Future<Result<void, TranscriptionFailure>> _releaseLive(
    LiveTranscriptionSession session,
  ) async {
    try {
      return await session.release();
    } on Object {
      return const Err(
        TranscriptionUnavailable('transcription_live_unavailable'),
      );
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
