import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';

/// Result of loading the local meeting library.
@immutable
sealed class SessionsSnapshot {
  const SessionsSnapshot();
}

/// Successfully loaded local meetings.
final class SessionsLoaded extends SessionsSnapshot {
  /// Creates a successful snapshot.
  SessionsLoaded({
    required this.kind,
    required this.query,
    required List<SessionSearchHit> items,
    Set<String> pendingPermanentDeletionIds = const {},
    Set<String> failedPermanentDeletionIds = const {},
  }) : items = List.unmodifiable(items),
       pendingPermanentDeletionIds = Set.unmodifiable(
         pendingPermanentDeletionIds,
       ),
       failedPermanentDeletionIds = Set.unmodifiable(
         failedPermanentDeletionIds,
       );

  /// Active library or local trash.
  final SessionLibraryKind kind;

  /// Normalized local search text; empty when browsing the selected library.
  final String query;

  /// Visible meetings or deterministic title/transcript hits.
  final List<SessionSearchHit> items;

  /// Meeting IDs whose confirmed private-data cleanup is still running.
  final Set<String> pendingPermanentDeletionIds;

  /// Meeting IDs whose cleanup failed and remain retryable in trash.
  final Set<String> failedPermanentDeletionIds;

  /// Returns the same library content with updated deletion intent state.
  SessionsLoaded copyWith({
    Set<String>? pendingPermanentDeletionIds,
    Set<String>? failedPermanentDeletionIds,
  }) => SessionsLoaded(
    kind: kind,
    query: query,
    items: items,
    pendingPermanentDeletionIds:
        pendingPermanentDeletionIds ?? this.pendingPermanentDeletionIds,
    failedPermanentDeletionIds:
        failedPermanentDeletionIds ?? this.failedPermanentDeletionIds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionsLoaded &&
          kind == other.kind &&
          query == other.query &&
          _setsEqual(
            pendingPermanentDeletionIds,
            other.pendingPermanentDeletionIds,
          ) &&
          _setsEqual(
            failedPermanentDeletionIds,
            other.failedPermanentDeletionIds,
          ) &&
          _itemsEqual(items, other.items);

  @override
  int get hashCode => Object.hash(
    kind,
    query,
    Object.hashAll(items.map(_itemHash)),
    Object.hashAll(pendingPermanentDeletionIds.toList()..sort()),
    Object.hashAll(failedPermanentDeletionIds.toList()..sort()),
  );

  static bool _setsEqual(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);

  static bool _itemsEqual(
    List<SessionSearchHit> first,
    List<SessionSearchHit> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      final left = first[index];
      final right = second[index];
      if (left.meeting != right.meeting ||
          left.transcriptSegmentId != right.transcriptSegmentId ||
          left.mediaOffset != right.mediaOffset ||
          left.committedAudioBytes != right.committedAudioBytes) {
        return false;
      }
    }
    return true;
  }

  static int _itemHash(SessionSearchHit item) => Object.hash(
    item.meeting,
    item.transcriptSegmentId,
    item.mediaOffset,
    item.committedAudioBytes,
  );
}

/// Expected local repository failure.
final class SessionsLoadFailed extends SessionsSnapshot {
  /// Creates a failed snapshot from a typed boundary value.
  const SessionsLoadFailed(this.failure);

  /// Stable, structured failure.
  final SessionRepositoryFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionsLoadFailed &&
          failure.runtimeType == other.failure.runtimeType &&
          failure.code == other.failure.code;

  @override
  int get hashCode => Object.hash(failure.runtimeType, failure.code);
}

/// Owns local meeting-library browsing, search, and durable list actions.
final class SessionsController extends StreamNotifier<SessionsSnapshot> {
  SessionLibraryKind _kind = SessionLibraryKind.active;
  String _query = '';
  final Set<String> _pendingPermanentDeletionIds = {};
  final Set<String> _failedPermanentDeletionIds = {};

  @override
  Stream<SessionsSnapshot> build() {
    final repository = ref.watch(sessionRepositoryProvider);
    final query = _query;
    if (query.isNotEmpty) {
      return repository
          .watchSearch(query)
          .map(
            (result) => switch (result) {
              Ok(:final value) => _withDeletionState(
                SessionsLoaded(kind: _kind, query: query, items: value),
              ),
              Err(:final failure) => SessionsLoadFailed(failure),
            },
          );
    }
    final kind = _kind;
    return repository
        .watchLibrary(SessionLibraryQuery(kind: kind, limit: 100))
        .asyncMap(
          (result) => _librarySnapshot(repository, kind, result),
        );
  }

  Future<SessionsSnapshot> _librarySnapshot(
    SessionRepository repository,
    SessionLibraryKind kind,
    Result<SessionLibraryPage, SessionRepositoryFailure> firstResult,
  ) async {
    if (firstResult case Err(:final failure)) {
      return SessionsLoadFailed(failure);
    }
    final firstPage =
        (firstResult as Ok<SessionLibraryPage, SessionRepositoryFailure>).value;
    final items = <SessionLibraryItem>[...firstPage.items];
    final seenCursors = <String>{};
    var cursor = firstPage.nextCursor;
    while (cursor != null) {
      final cursorKey = '${cursor.createdAtUtcMs}\u0000${cursor.id}';
      if (!seenCursors.add(cursorKey)) {
        return const SessionsLoadFailed(
          SessionRepositoryUnavailable('session_library_cursor_cycle'),
        );
      }
      final nextResult = await repository.queryLibrary(
        SessionLibraryQuery(kind: kind, limit: 100, before: cursor),
      );
      switch (nextResult) {
        case Ok(:final value):
          items.addAll(value.items);
          cursor = value.nextCursor;
        case Err(:final failure):
          return SessionsLoadFailed(failure);
      }
    }
    return _withDeletionState(
      SessionsLoaded(
        kind: kind,
        query: '',
        items: items
            .map(
              (item) => SessionSearchHit(
                meeting: item.meeting,
                committedAudioBytes: item.committedAudioBytes,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  /// Retries without discarding any screen-local navigation state.
  void retry() => ref.invalidateSelf();

  /// Shows the normal meeting library and clears search.
  void showActive() => _selectLibrary(SessionLibraryKind.active);

  /// Shows seven-day local trash and clears search.
  void showTrash() => _selectLibrary(SessionLibraryKind.trash);

  /// Runs deterministic local title/transcript search.
  void search(String value) {
    final normalized = value.trim();
    final targetKind = normalized.isEmpty ? _kind : SessionLibraryKind.active;
    if (_query == normalized && _kind == targetKind) return;
    _kind = targetKind;
    _query = normalized;
    ref.invalidateSelf();
  }

  /// Persists a trimmed, non-empty meeting title.
  void rename(String meetingId, String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) return;
    final meeting = _meeting(meetingId);
    if (meeting == null || meeting.title == normalized) return;
    unawaited(
      _mutate(
        ref
            .read(sessionRepositoryProvider)
            .renameMeeting(
              meetingId,
              normalized,
              atUtcMs: ref
                  .read(clockProvider)
                  .now()
                  .toUtc()
                  .millisecondsSinceEpoch,
            ),
      ),
    );
  }

  /// Moves an active meeting to seven-day local trash.
  void moveToTrash(String meetingId) {
    unawaited(
      _mutate(
        ref
            .read(sessionRepositoryProvider)
            .moveToTrash(
              meetingId,
              atUtcMs: ref
                  .read(clockProvider)
                  .now()
                  .toUtc()
                  .millisecondsSinceEpoch,
            ),
      ),
    );
  }

  /// Restores a trashed meeting with its prior lifecycle.
  void restoreFromTrash(String meetingId) {
    unawaited(
      _mutate(
        ref
            .read(sessionRepositoryProvider)
            .restoreFromTrash(
              meetingId,
              atUtcMs: ref
                  .read(clockProvider)
                  .now()
                  .toUtc()
                  .millisecondsSinceEpoch,
            ),
      ),
    );
  }

  /// Permanently removes a confirmed trash item and its private data.
  void permanentlyDelete(String meetingId) {
    final meeting = _meeting(meetingId);
    if (meeting == null ||
        (meeting.lifecycle != MeetingLifecycle.trashed &&
            meeting.lifecycle != MeetingLifecycle.deleting) ||
        !_pendingPermanentDeletionIds.add(meetingId)) {
      return;
    }
    _failedPermanentDeletionIds.remove(meetingId);
    _publishDeletionState();
    final repository = ref.read(sessionRepositoryProvider);
    unawaited(_finishPermanentDelete(meetingId, repository));
  }

  Future<void> _finishPermanentDelete(
    String meetingId,
    SessionRepository repository,
  ) async {
    final result = await repository.permanentlyDelete(meetingId);
    if (!ref.mounted) return;
    _pendingPermanentDeletionIds.remove(meetingId);
    switch (result) {
      case Ok():
        _failedPermanentDeletionIds.remove(meetingId);
        ref.invalidateSelf();
      case Err():
        _failedPermanentDeletionIds.add(meetingId);
        _publishDeletionState();
    }
  }

  SessionsLoaded _withDeletionState(SessionsLoaded loaded) => loaded.copyWith(
    pendingPermanentDeletionIds: Set.unmodifiable(
      _pendingPermanentDeletionIds,
    ),
    failedPermanentDeletionIds: Set.unmodifiable(_failedPermanentDeletionIds),
  );

  void _publishDeletionState() {
    if (state.value case final SessionsLoaded loaded) {
      state = AsyncData(_withDeletionState(loaded));
    }
  }

  void _selectLibrary(SessionLibraryKind kind) {
    if (_kind == kind && _query.isEmpty) return;
    _kind = kind;
    _query = '';
    ref.invalidateSelf();
  }

  Meeting? _meeting(String meetingId) => switch (state.value) {
    SessionsLoaded(:final items) =>
      items.where((item) => item.meeting.id == meetingId).firstOrNull?.meeting,
    _ => null,
  };

  Future<void> _mutate<T>(
    Future<Result<T, SessionRepositoryFailure>> pending,
  ) async {
    final result = await pending;
    if (!ref.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidateSelf();
      case Err(:final failure):
        state = AsyncData(SessionsLoadFailed(failure));
    }
  }
}

/// Screen-lifetime meeting library state.
final StreamNotifierProvider<SessionsController, SessionsSnapshot>
sessionsControllerProvider =
    StreamNotifierProvider.autoDispose<SessionsController, SessionsSnapshot>(
      SessionsController.new,
    );
