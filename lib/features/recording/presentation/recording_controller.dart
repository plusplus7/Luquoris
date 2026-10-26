import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/application/recording_inventory_synchronizer.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// Immutable active-recorder presentation state.
@immutable
final class RecordingViewState {
  /// Creates state from the last durable [snapshot] and optional [failure].
  const RecordingViewState({
    this.snapshot,
    this.failure,
    this.persistenceFailure,
    this.persistencePending = false,
  });

  /// Most recent authoritative native snapshot.
  final AudioCaptureSnapshot? snapshot;

  /// Most recent typed command/restoration failure.
  final AudioCaptureFailure? failure;

  /// Last failure synchronizing native authority into local meeting metadata.
  final SessionRepositoryFailure? persistenceFailure;

  /// Whether the current authoritative snapshot is still being persisted.
  final bool persistencePending;

  /// Whether Android still owns an unfinished recording session.
  bool get hasActiveSession => switch (snapshot?.state) {
    AudioCaptureState.preparing ||
    AudioCaptureState.recording ||
    AudioCaptureState.pausedByUser ||
    AudioCaptureState.pausedByInterruption ||
    AudioCaptureState.stopping => true,
    _ => false,
  };

  /// Returns a new immutable state while preserving omitted values.
  RecordingViewState copyWith({
    AudioCaptureSnapshot? snapshot,
    AudioCaptureFailure? failure,
    SessionRepositoryFailure? persistenceFailure,
    bool? persistencePending,
    bool clearFailure = false,
    bool clearPersistenceFailure = false,
  }) => RecordingViewState(
    snapshot: snapshot ?? this.snapshot,
    failure: clearFailure ? null : failure ?? this.failure,
    persistenceFailure: clearPersistenceFailure
        ? null
        : persistenceFailure ?? this.persistenceFailure,
    persistencePending: persistencePending ?? this.persistencePending,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingViewState &&
          _snapshotEquals(snapshot, other.snapshot) &&
          _failureEquals(failure, other.failure) &&
          _repositoryFailureEquals(
            persistenceFailure,
            other.persistenceFailure,
          ) &&
          persistencePending == other.persistencePending;

  @override
  int get hashCode => Object.hash(
    snapshot?.sessionId,
    snapshot?.state,
    snapshot?.elapsed,
    snapshot?.bytesWritten,
    snapshot?.revision,
    snapshot?.inputHealth,
    failure.runtimeType,
    failure?.code,
    persistenceFailure.runtimeType,
    persistenceFailure?.code,
    persistencePending,
  );

  static bool _snapshotEquals(
    AudioCaptureSnapshot? first,
    AudioCaptureSnapshot? second,
  ) =>
      identical(first, second) ||
      (first?.sessionId == second?.sessionId &&
          first?.state == second?.state &&
          first?.elapsed == second?.elapsed &&
          first?.bytesWritten == second?.bytesWritten &&
          first?.revision == second?.revision &&
          first?.inputHealth == second?.inputHealth);

  static bool _failureEquals(
    AudioCaptureFailure? first,
    AudioCaptureFailure? second,
  ) =>
      identical(first, second) ||
      (first.runtimeType == second.runtimeType && first?.code == second?.code);

  static bool _repositoryFailureEquals(
    SessionRepositoryFailure? first,
    SessionRepositoryFailure? second,
  ) =>
      identical(first, second) ||
      (first.runtimeType == second.runtimeType && first?.code == second?.code);
}

/// App-scoped recorder state restored from Android independently of any screen.
final class RecordingController extends AsyncNotifier<RecordingViewState> {
  StreamSubscription<AudioCaptureSnapshot>? _subscription;
  bool _restoring = false;
  AudioCaptureSnapshot? _snapshotObservedDuringRestore;
  Future<void> _persistenceTail = Future<void>.value();

  @override
  Future<RecordingViewState> build() async {
    final service = ref.watch(audioCaptureServiceProvider);
    _restoring = true;
    _subscription = service.snapshots.listen(_onSnapshot);
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    final restored = await service.current();
    final observed = _snapshotObservedDuringRestore;
    var snapshot = switch (restored) {
      Ok(:final value) =>
        observed != null && observed.revision >= value.revision
            ? observed
            : value,
      Err() => observed,
    };
    SessionRepositoryFailure? persistenceFailure;
    while (snapshot != null) {
      final synchronizedRevision = snapshot.revision;
      persistenceFailure = await _serializeSnapshotSynchronization(snapshot);
      final latest = _snapshotObservedDuringRestore;
      if (latest == null || latest.revision <= synchronizedRevision) break;
      snapshot = latest;
    }
    _restoring = false;
    _snapshotObservedDuringRestore = null;
    return RecordingViewState(
      snapshot: snapshot,
      failure: switch (restored) {
        Err(:final failure) when snapshot == null => failure,
        _ => null,
      },
      persistenceFailure: persistenceFailure,
    );
  }

  /// Starts a meeting; asynchronous errors are retained in [RecordingViewState].
  void start(String sessionId) {
    unawaited(
      _run(
        ref
            .read(audioCaptureServiceProvider)
            .start(AudioCaptureRequest(sessionId: sessionId)),
      ),
    );
  }

  /// Pauses active capture without dropping the command future.
  void pause() {
    unawaited(_run(ref.read(audioCaptureServiceProvider).pause()));
  }

  /// Resumes active capture without dropping the command future.
  void resume() {
    unawaited(_run(ref.read(audioCaptureServiceProvider).resume()));
  }

  /// Finalizes active capture without dropping the command future.
  void stop() {
    unawaited(_run(ref.read(audioCaptureServiceProvider).stop()));
  }

  /// Retries failed finalization metadata without issuing a capture command.
  void retryFinalizationPersistence() {
    final current = state.value;
    final snapshot = current?.snapshot;
    if (current == null ||
        snapshot == null ||
        snapshot.state != AudioCaptureState.finalized ||
        current.persistencePending ||
        current.persistenceFailure == null) {
      return;
    }
    state = AsyncData(current.copyWith(persistencePending: true));
    _queueSnapshotSynchronization(snapshot);
  }

  /// Accepts an authoritative command snapshot through this coordinator's
  /// monotonic state and serialized persistence path.
  void acceptAuthoritativeSnapshot(AudioCaptureSnapshot snapshot) {
    _onSnapshot(snapshot);
  }

  Future<void> _run(
    Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> pending,
  ) async {
    Result<AudioCaptureSnapshot, AudioCaptureFailure> result;
    try {
      result = await pending;
    } on Object {
      result = const Err(
        AudioCaptureUnavailable('recording_command_unexpected'),
      );
    }
    if (!ref.mounted) return;
    final previous = state.value ?? const RecordingViewState();
    final next = switch (result) {
      Ok(:final value) => _withSnapshot(previous, value),
      Err(:final failure) => previous.copyWith(failure: failure),
    };
    state = AsyncData(next);
    if (result case Ok(:final value)) {
      final accepted = next.snapshot;
      if (!identical(next, previous) &&
          accepted != null &&
          accepted.revision == value.revision) {
        _queueSnapshotSynchronization(value);
      }
    }
  }

  void _onSnapshot(AudioCaptureSnapshot snapshot) {
    if (!ref.mounted) return;
    if (_restoring) {
      final observed = _snapshotObservedDuringRestore;
      if (observed == null || snapshot.revision >= observed.revision) {
        _snapshotObservedDuringRestore = snapshot;
      }
      return;
    }
    final previous = state.value ?? const RecordingViewState();
    final next = _withSnapshot(previous, snapshot);
    state = AsyncData(next);
    if (!identical(next, previous)) {
      _queueSnapshotSynchronization(snapshot);
    }
  }

  RecordingViewState _withSnapshot(
    RecordingViewState previous,
    AudioCaptureSnapshot incoming,
  ) {
    final current = previous.snapshot;
    if (current != null && incoming.revision < current.revision) {
      return previous;
    }
    if (current != null &&
        incoming.revision == current.revision &&
        RecordingViewState._snapshotEquals(current, incoming)) {
      return previous;
    }
    return RecordingViewState(
      snapshot: incoming,
      persistenceFailure: previous.persistenceFailure,
      persistencePending: true,
    );
  }

  void _queueSnapshotSynchronization(AudioCaptureSnapshot snapshot) {
    unawaited(
      _serializeSnapshotSynchronization(snapshot).then((failure) {
        if (!ref.mounted) return;
        final current = state.value ?? const RecordingViewState();
        if (current.snapshot?.revision != snapshot.revision) return;
        state = AsyncData(
          current.copyWith(
            persistenceFailure: failure,
            persistencePending: false,
            clearPersistenceFailure: failure == null,
          ),
        );
      }),
    );
  }

  Future<SessionRepositoryFailure?> _serializeSnapshotSynchronization(
    AudioCaptureSnapshot snapshot,
  ) {
    final completion = Completer<SessionRepositoryFailure?>();
    _persistenceTail = _persistenceTail.then((_) async {
      try {
        completion.complete(await _synchronizeSnapshot(snapshot));
      } on Object catch (error, stackTrace) {
        completion.completeError(error, stackTrace);
        rethrow;
      }
    });
    return completion.future;
  }

  Future<SessionRepositoryFailure?> _synchronizeSnapshot(
    AudioCaptureSnapshot snapshot,
  ) async {
    final meetingId = snapshot.sessionId;
    if (meetingId == null || snapshot.state == AudioCaptureState.idle) {
      return null;
    }
    final result = await ref
        .read(sessionRepositoryProvider)
        .synchronizeRecordingProgress(
          meetingId,
          lifecycle: _meetingLifecycle(snapshot.state),
          mediaDuration: snapshot.elapsed,
          atUtcMs: ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch,
        );
    if (result case Err(:final failure)) return failure;
    if (snapshot.state != AudioCaptureState.finalized) return null;
    final inventory = await ref
        .read(recordingInventorySynchronizerProvider)
        .synchronize(finalizedMeetingId: meetingId);
    return switch (inventory) {
      Ok() => null,
      Err(:final failure) => failure,
    };
  }
}

MeetingLifecycle _meetingLifecycle(AudioCaptureState state) => switch (state) {
  AudioCaptureState.idle => MeetingLifecycle.draft,
  AudioCaptureState.preparing => MeetingLifecycle.preparing,
  AudioCaptureState.recording => MeetingLifecycle.recording,
  AudioCaptureState.pausedByUser => MeetingLifecycle.pausedByUser,
  AudioCaptureState.pausedByInterruption =>
    MeetingLifecycle.pausedByInterruption,
  AudioCaptureState.stopping => MeetingLifecycle.stopping,
  AudioCaptureState.finalized => MeetingLifecycle.finalized,
  AudioCaptureState.recoverable => MeetingLifecycle.recoverable,
  AudioCaptureState.failedFinalization => MeetingLifecycle.failedFinalization,
};

/// Process-lifetime active recorder state; deliberately not auto-disposed.
final AsyncNotifierProvider<RecordingController, RecordingViewState>
recordingControllerProvider =
    AsyncNotifierProvider<RecordingController, RecordingViewState>(
      RecordingController.new,
    );
