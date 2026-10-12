import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/sessions/presentation/sessions_controller.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  test('session projections and loaded state have value equality', () {
    final first = SessionCollection(
      sessions: const [
        SessionSummary(id: 'one', title: 'Planning', isRecoverable: true),
      ],
    );
    final second = SessionCollection(
      sessions: const [
        SessionSummary(id: 'one', title: 'Planning', isRecoverable: true),
      ],
    );

    expect(first, second);
    expect(
      SessionsLoaded(
        kind: SessionLibraryKind.active,
        query: '',
        items: [
          SessionSearchHit(
            meeting: _meeting('one').copyWith(title: 'Planning'),
          ),
        ],
      ),
      SessionsLoaded(
        kind: SessionLibraryKind.active,
        query: '',
        items: [
          SessionSearchHit(
            meeting: _meeting('one').copyWith(title: 'Planning'),
          ),
        ],
      ),
    );
    expect(first.hashCode, second.hashCode);
  });

  test('failed state equality uses structured failure identity', () {
    expect(
      const SessionsLoadFailed(SessionRepositoryUnavailable('db.read')),
      const SessionsLoadFailed(SessionRepositoryUnavailable('db.read')),
    );
    expect(
      const SessionsLoadFailed(SessionRepositoryUnavailable('db.read')),
      isNot(const SessionsLoadFailed(SessionRepositoryUnavailable('db.write'))),
    );
  });

  test('controller switches library scope and performs local search', () async {
    final meeting = _meeting('planning');
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          SessionLibraryItem(meeting: meeting, committedAudioBytes: 4096),
        ],
        nextCursor: null,
      )
      ..searchResult = Ok([
        SessionSearchHit(
          meeting: meeting,
          transcriptSegmentId: 'segment-1',
          mediaOffset: const Duration(seconds: 7),
          committedAudioBytes: 4096,
        ),
      ]);
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2026, 10, 1, 2, 3)),
        ),
      ],
    );
    final subscription = container.listen(
      sessionsControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final initial = await container.read(sessionsControllerProvider.future);
    expect(initial, isA<SessionsLoaded>());
    expect((initial as SessionsLoaded).items.single.committedAudioBytes, 4096);
    expect(initial.kind, SessionLibraryKind.active);

    container.read(sessionsControllerProvider.notifier).search('世界');
    await pumpEventQueue();
    final searched = await container.read(sessionsControllerProvider.future);
    expect((searched as SessionsLoaded).query, '世界');
    expect(searched.items.single.mediaOffset, const Duration(seconds: 7));
    expect(repository.searchQueries, ['世界']);

    container.read(sessionsControllerProvider.notifier).showTrash();
    await pumpEventQueue();
    final trash = await container.read(sessionsControllerProvider.future);
    expect((trash as SessionsLoaded).kind, SessionLibraryKind.trash);
    expect(
      repository.watchedLibraryQueries.last.kind,
      SessionLibraryKind.trash,
    );
  });

  test('rename and trash intents persist through the repository', () async {
    final meeting = _meeting('planning');
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          SessionLibraryItem(meeting: meeting, committedAudioBytes: 1024),
        ],
        nextCursor: null,
      );
    final container = ProviderContainer.test(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2026, 10, 1, 2, 3)),
        ),
      ],
    );
    final subscription = container.listen(
      sessionsControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(sessionsControllerProvider.future);

    container.read(sessionsControllerProvider.notifier)
      ..rename('planning', '  Weekly review  ')
      ..moveToTrash('planning');
    await pumpEventQueue();

    expect(repository.savedMeetings.single.title, 'Weekly review');
    expect(repository.trashedMeetingIds, ['planning']);
  });

  test(
    'search leaves trash because repository search covers active meetings',
    () async {
      final repository = FakeSessionRepository();
      final container = ProviderContainer.test(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      final subscription = container.listen(
        sessionsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(sessionsControllerProvider.future);

      container.read(sessionsControllerProvider.notifier).showTrash();
      await pumpEventQueue();
      container.read(sessionsControllerProvider.notifier).search('planning');
      await pumpEventQueue();

      final searched = await container.read(sessionsControllerProvider.future);
      expect((searched as SessionsLoaded).kind, SessionLibraryKind.active);
      expect(searched.query, 'planning');
    },
  );

  test(
    'controller follows every keyset page from the watched first page',
    () async {
      const cursor = SessionLibraryCursor(createdAtUtcMs: 2, id: 'newer');
      final repository = FakeSessionRepository()
        ..activeLibraryPage = SessionLibraryPage(
          items: [
            SessionLibraryItem(
              meeting: _meeting('newer'),
              committedAudioBytes: 20,
            ),
          ],
          nextCursor: cursor,
        )
        ..queryLibraryOverride = (query) async {
          expect(query.before, cursor);
          return Ok(
            SessionLibraryPage(
              items: [
                SessionLibraryItem(
                  meeting: _meeting('older'),
                  committedAudioBytes: 10,
                ),
              ],
              nextCursor: null,
            ),
          );
        };
      final container = ProviderContainer.test(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      final subscription = container.listen(
        sessionsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final loaded = await container.read(sessionsControllerProvider.future);

      expect((loaded as SessionsLoaded).items, hasLength(2));
      expect(repository.queriedLibraryQueries, hasLength(1));
    },
  );

  test(
    'permanent deletion is serialized and failure keeps trash visible',
    () async {
      final gate = Completer<Result<void, SessionRepositoryFailure>>();
      final trashed = _meeting('trash').copyWith(
        lifecycle: MeetingLifecycle.trashed,
        lifecycleBeforeTrash: MeetingLifecycle.finalized,
        trashedAtUtcMs: 2,
      );
      final repository = FakeSessionRepository()
        ..trashLibraryPage = SessionLibraryPage(
          items: [
            SessionLibraryItem(meeting: trashed, committedAudioBytes: 0),
          ],
          nextCursor: null,
        )
        ..permanentlyDeleteOverride = (_) => gate.future;
      final container = ProviderContainer.test(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      final subscription = container.listen(
        sessionsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final notifier = container.read(sessionsControllerProvider.notifier);
      await container.read(sessionsControllerProvider.future);
      notifier.showTrash();
      await pumpEventQueue();

      notifier
        ..permanentlyDelete('trash')
        ..permanentlyDelete('trash');
      await pumpEventQueue();

      expect(repository.permanentlyDeletedMeetingIds, ['trash']);
      final pending = container.read(sessionsControllerProvider).value!;
      expect(
        (pending as SessionsLoaded).pendingPermanentDeletionIds,
        {'trash'},
      );
      expect(pending.items.single.meeting.id, 'trash');

      gate.complete(
        const Err(SessionRepositoryUnavailable('session_audio_delete_failed')),
      );
      await pumpEventQueue();

      final failed = container.read(sessionsControllerProvider).value!;
      expect(failed, isA<SessionsLoaded>());
      expect((failed as SessionsLoaded).pendingPermanentDeletionIds, isEmpty);
      expect(failed.failedPermanentDeletionIds, {'trash'});
      expect(failed.items.single.meeting.id, 'trash');
    },
  );
}

Meeting _meeting(String id) => Meeting(
  id: id,
  title: 'Planning',
  createdAtUtcMs: DateTime.utc(2026, 10, 1, 1).millisecondsSinceEpoch,
  mediaDuration: const Duration(minutes: 2, seconds: 3),
  lifecycle: MeetingLifecycle.finalized,
  languageMode: MeetingLanguageMode.mixed,
);
