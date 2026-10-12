import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:uuid/uuid.dart';

/// Creates stable local marker identifiers with an injectable test seam.
typedef BookmarkIdFactory = String Function(BookmarkKind kind);

/// Identifier source for user-authored bookmarks and highlights.
final bookmarkIdFactoryProvider = Provider<BookmarkIdFactory>(
  (ref) =>
      (kind) => const Uuid().v4(),
);

/// Screen-scoped recording actions that combine native time with local writes.
final class ActiveRecordingActions {
  /// Creates actions for one URL-addressed meeting.
  const ActiveRecordingActions(this.ref, this.meetingId);

  /// Provider reference used only at the side-effect boundary.
  final Ref ref;

  /// Meeting identity from the active-recording route.
  final String meetingId;

  /// Stores a marker at the latest authoritative pause-aware media time.
  Future<Result<Bookmark, SessionRepositoryFailure>> addMarker(
    BookmarkKind kind,
  ) async {
    final snapshot = ref.read(recordingControllerProvider).value?.snapshot;
    if (snapshot == null ||
        snapshot.sessionId != meetingId ||
        !_canMark(snapshot.state)) {
      return const Err(SessionInvalidLifecycle());
    }
    final bookmark = Bookmark(
      id: ref.read(bookmarkIdFactoryProvider)(kind),
      meetingId: meetingId,
      mediaOffset: snapshot.elapsed,
      kind: kind,
      createdAtUtcMs: ref
          .read(clockProvider)
          .now()
          .toUtc()
          .millisecondsSinceEpoch,
    );
    return ref.read(sessionRepositoryProvider).saveBookmark(bookmark);
  }
}

bool _canMark(AudioCaptureState state) => switch (state) {
  AudioCaptureState.recording ||
  AudioCaptureState.pausedByUser ||
  AudioCaptureState.pausedByInterruption => true,
  _ => false,
};

/// Provides marker actions for one active meeting route.
final ProviderFamily<ActiveRecordingActions, String>
activeRecordingActionsProvider = Provider.autoDispose
    .family<ActiveRecordingActions, String>(ActiveRecordingActions.new);
