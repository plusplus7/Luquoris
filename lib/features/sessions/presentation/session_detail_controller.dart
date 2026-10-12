import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// URL-derived identity and optional initial media-time anchor.
@immutable
final class SessionDetailRequest {
  /// Creates a detail request.
  const SessionDetailRequest({required this.meetingId, this.initialOffset});

  /// Meeting identity.
  final String meetingId;

  /// Optional pause-free seek position.
  final Duration? initialOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionDetailRequest &&
          meetingId == other.meetingId &&
          initialOffset == other.initialOffset;

  @override
  int get hashCode => Object.hash(meetingId, initialOffset);
}

/// Loaded durable detail plus independently fallible derived playback.
@immutable
final class SessionDetailViewState {
  /// Creates detail state.
  const SessionDetailViewState({
    required this.detail,
    this.playback,
    this.playbackFailure,
  });

  /// Transactionally consistent durable meeting projection.
  final SessionDetail detail;

  /// Latest validated playback observation.
  final SessionPlaybackSnapshot? playback;

  /// Local playback failure that does not hide durable meeting data.
  final SessionPlaybackFailure? playbackFailure;

  /// Returns a state with updated playback data while retaining meeting detail.
  SessionDetailViewState copyWith({
    SessionPlaybackSnapshot? playback,
    SessionPlaybackFailure? playbackFailure,
    bool clearFailure = false,
  }) => SessionDetailViewState(
    detail: detail,
    playback: playback ?? this.playback,
    playbackFailure: clearFailure
        ? null
        : playbackFailure ?? this.playbackFailure,
  );
}

/// Owns one session-detail projection and its screen-scoped native player.
final class SessionDetailController
    extends AsyncNotifier<SessionDetailViewState> {
  /// Creates a controller for one route-derived [request].
  SessionDetailController(this.request);

  /// Meeting identity and optional initial playback offset.
  final SessionDetailRequest request;
  final String _ownerId = 'session-detail-${_nextOwnerId++}';
  Timer? _poller;

  static int _nextOwnerId = 0;

  @override
  Future<SessionDetailViewState> build() async {
    final playbackService = ref.watch(sessionPlaybackServiceProvider);
    ref.onDispose(() {
      _poller?.cancel();
      unawaited(playbackService.release(ownerId: _ownerId));
    });
    final detailResult = await ref
        .watch(sessionRepositoryProvider)
        .loadDetail(request.meetingId);
    final detail = switch (detailResult) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.code),
    };
    final loaded = await playbackService.load(
      request.meetingId,
      ownerId: _ownerId,
    );
    var result = loaded;
    final initialOffset = request.initialOffset;
    if (loaded is Ok<SessionPlaybackSnapshot, SessionPlaybackFailure> &&
        initialOffset != null) {
      result = await playbackService.seek(initialOffset, ownerId: _ownerId);
    }
    return switch (_validateSession(result)) {
      Ok(:final value) => SessionDetailViewState(
        detail: detail,
        playback: value,
      ),
      Err(:final failure) => SessionDetailViewState(
        detail: detail,
        playbackFailure: failure,
      ),
    };
  }

  /// Toggles play/pause without changing durable meeting state.
  Future<void> togglePlayback() async {
    final current = state.value?.playback;
    if (current == null) return;
    final service = ref.read(sessionPlaybackServiceProvider);
    final result = current.state == SessionPlaybackState.playing
        ? await service.pause(ownerId: _ownerId)
        : await service.play(ownerId: _ownerId);
    _apply(result);
  }

  /// Seeks to one pause-free media-time offset.
  Future<void> seek(Duration position) async {
    if (state.value?.playback == null) return;
    _apply(
      await ref
          .read(sessionPlaybackServiceProvider)
          .seek(position, ownerId: _ownerId),
    );
  }

  void _apply(Result<SessionPlaybackSnapshot, SessionPlaybackFailure> result) {
    final current = state.value;
    if (current == null) return;
    switch (_validateSession(result)) {
      case Ok(:final value):
        state = AsyncData(
          current.copyWith(playback: value, clearFailure: true),
        );
        if (value.state == SessionPlaybackState.playing) {
          _poller ??= Timer.periodic(
            const Duration(milliseconds: 500),
            (_) => unawaited(_refreshPlayback()),
          );
        } else {
          _poller?.cancel();
          _poller = null;
        }
      case Err(:final failure):
        _poller?.cancel();
        _poller = null;
        state = AsyncData(current.copyWith(playbackFailure: failure));
    }
  }

  Future<void> _refreshPlayback() async {
    _apply(
      await ref.read(sessionPlaybackServiceProvider).current(ownerId: _ownerId),
    );
  }

  Result<SessionPlaybackSnapshot, SessionPlaybackFailure> _validateSession(
    Result<SessionPlaybackSnapshot, SessionPlaybackFailure> result,
  ) => switch (result) {
    Ok(:final value) when value.sessionId != request.meetingId => const Err(
      SessionPlaybackFailure('playback_snapshot_session_mismatch'),
    ),
    _ => result,
  };
}

/// Screen-scoped session detail state keyed by URL identity and offset.
final AsyncNotifierProviderFamily<
  SessionDetailController,
  SessionDetailViewState,
  SessionDetailRequest
>
sessionDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      SessionDetailController,
      SessionDetailViewState,
      SessionDetailRequest
    >(
      SessionDetailController.new,
    );
