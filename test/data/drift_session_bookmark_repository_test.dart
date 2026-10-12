import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart'
    as domain;

void main() {
  test('saveBookmark durably stores its pause-aware media position', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSessionRepository(
      database,
      audioStore: _NoOpAudioStore(),
      diagnosticSink: _NoOpDiagnosticSink(),
    );
    await repository.saveMeeting(
      const domain.Meeting(
        id: 'meeting-1',
        title: 'Meeting',
        createdAtUtcMs: 1,
        mediaDuration: Duration(seconds: 42),
        lifecycle: domain.MeetingLifecycle.recording,
        languageMode: domain.MeetingLanguageMode.mixed,
      ),
    );
    const bookmark = domain.Bookmark(
      id: 'bookmark-1',
      meetingId: 'meeting-1',
      mediaOffset: Duration(seconds: 37),
      kind: domain.BookmarkKind.highlight,
      createdAtUtcMs: 2,
    );

    final result = await repository.saveBookmark(bookmark);

    expect(result.isOk, isTrue);
    expect(
      result.fold<domain.Bookmark?>((value) => value, (_) => null),
      bookmark,
    );
    final stored = await database.select(database.bookmarks).getSingle();
    expect(stored.id, 'bookmark-1');
    expect(stored.meetingId, 'meeting-1');
    expect(stored.mediaOffsetUs, const Duration(seconds: 37).inMicroseconds);
    expect(stored.kind, 'highlight');
  });
}

final class _NoOpAudioStore implements MeetingAudioStore {
  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> paths,
  ) async => const Ok<void, MeetingAudioStoreFailure>(null);
}

final class _NoOpDiagnosticSink implements DiagnosticLogSink {
  @override
  void record(DiagnosticEvent event) {}
}
