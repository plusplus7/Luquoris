import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  testWidgets('pending repository renders the delayed loading state', (
    tester,
  ) async {
    final repository = _PendingSessionRepository();
    await _pumpApp(tester, repository);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('sessions-loading')),
      findsOneWidget,
    );
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('sessions-loading')),
    );
    expect(semantics.label, 'Loading meetings');
  });

  testWidgets('empty repository offers the primary recording action', (
    tester,
  ) async {
    await _pumpApp(tester, FakeSessionRepository());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sessions-empty')),
      findsOneWidget,
    );
    expect(find.text('Start a recording'), findsOneWidget);
  });

  testWidgets('typed repository failure renders a retry without leaking code', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..libraryFailure = const SessionRepositoryUnavailable(
        'database.internal.path',
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sessions-error')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('database.internal.path'), findsNothing);
  });

  testWidgets('recoverable meeting is called out without reopening capture', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'recover-1',
            'Interrupted interview',
            lifecycle: MeetingLifecycle.recoverable,
            duration: const Duration(minutes: 1, seconds: 2),
            committedAudioBytes: 1000,
          ),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sessions-recovery')),
      findsOneWidget,
    );
    expect(find.text('Review recording'), findsOneWidget);
    expect(find.textContaining('1:02'), findsOneWidget);
    expect(find.textContaining('1 kB'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('meeting-status:recover-1')),
      findsOneWidget,
    );
    expect(find.textContaining('Resume recording'), findsNothing);
  });

  testWidgets('every recoverable meeting remains explicitly identifiable', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'recover-1',
            'Interrupted interview',
            lifecycle: MeetingLifecycle.recoverable,
          ),
          _item(
            'recover-2',
            'Interrupted lecture',
            lifecycle: MeetingLifecycle.recoverable,
          ),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('recovery-card:recover-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('recovery-card:recover-2')),
      findsOneWidget,
    );
  });

  testWidgets('recovery review saves without opening microphone capture', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'recover-save',
            'Interrupted interview',
            lifecycle: MeetingLifecycle.recoverable,
          ),
        ],
        nextCursor: null,
      );
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    await _pumpApp(tester, repository, capture: capture);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review recording'));
    await tester.pumpAndSettle();

    expect(find.text('Save recovered recording'), findsOneWidget);
    expect(find.text('Continue recording'), findsOneWidget);
    expect(capture.savedRecoveryIds, isEmpty);
    expect(capture.continuedRecoveryIds, isEmpty);

    await tester.tap(find.text('Save recovered recording'));
    await tester.pumpAndSettle();

    expect(capture.savedRecoveryIds, ['recover-save']);
    expect(capture.continuedRecoveryIds, isEmpty);
    expect(repository.recoveryResolutions, [
      ('recover-save', RecoveryResolution.save),
    ]);
  });

  testWidgets('continuation starts only after the explicit review action', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'recover-continue',
            'Interrupted lecture',
            lifecycle: MeetingLifecycle.recoverable,
          ),
        ],
        nextCursor: null,
      );
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    await _pumpApp(tester, repository, capture: capture);
    await tester.pumpAndSettle();

    expect(capture.continuedRecoveryIds, isEmpty);
    await tester.tap(find.text('Review recording'));
    await tester.pumpAndSettle();
    expect(capture.continuedRecoveryIds, isEmpty);
    await tester.tap(find.text('Continue recording'));
    await tester.pumpAndSettle();

    expect(capture.continuedRecoveryIds, ['recover-continue']);
    expect(repository.recoveryResolutions, [
      ('recover-continue', RecoveryResolution.continueRecording),
    ]);
    expect(
      find.byKey(
        const ValueKey<String>('active-recording:recover-continue'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact shell exposes primary destinations', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, FakeSessionRepository());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('meeting rows show duration, size, lifecycle, and actions', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'planning',
            'Planning',
            duration: const Duration(minutes: 2, seconds: 3),
            committedAudioBytes: 1500000,
          ),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Planning'), findsOneWidget);
    expect(find.textContaining('2:03'), findsOneWidget);
    expect(find.textContaining('1.5 MB'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('meeting-status:planning')),
      findsOneWidget,
    );
    expect(find.byTooltip('Meeting actions'), findsOneWidget);
  });

  testWidgets('search opens a transcript hit at its media offset', (
    tester,
  ) async {
    final meeting = _meeting('search', 'Mixed language lecture');
    final repository = FakeSessionRepository()
      ..searchResult = Ok([
        SessionSearchHit(
          meeting: meeting,
          transcriptSegmentId: 'segment-1',
          mediaOffset: const Duration(seconds: 7),
          committedAudioBytes: 900,
        ),
      ]);
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), '世界');
    await tester.pumpAndSettle();

    expect(repository.searchQueries, ['世界']);
    expect(find.text('Mixed language lecture'), findsOneWidget);
    await tester.tap(find.text('Mixed language lecture'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('session-detail:search')),
      findsOneWidget,
    );
  });

  testWidgets(
    'multiple transcript hits from one meeting have stable row keys',
    (
      tester,
    ) async {
      final meeting = _meeting('search', 'Repeated phrase');
      final repository = FakeSessionRepository()
        ..searchResult = Ok([
          SessionSearchHit(
            meeting: meeting,
            transcriptSegmentId: 'segment-1',
            mediaOffset: const Duration(seconds: 7),
          ),
          SessionSearchHit(
            meeting: meeting,
            transcriptSegmentId: 'segment-2',
            mediaOffset: const Duration(seconds: 14),
          ),
        ]);
      await _pumpApp(tester, repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'phrase');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('meeting-card:search:segment-1:7000000'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('meeting-card:search:segment-2:14000000'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('rename and trash actions use controller intents', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [_item('planning', 'Planning')],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Weekly review');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.savedMeetings.single.title, 'Weekly review');

    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    expect(repository.trashedMeetingIds, ['planning']);
  });

  testWidgets('trash navigation exposes lifecycle-preserving restore', (
    tester,
  ) async {
    final trashed = _meeting('trashed', 'Old lecture').copyWith(
      lifecycle: MeetingLifecycle.trashed,
      lifecycleBeforeTrash: MeetingLifecycle.recoverable,
      trashedAtUtcMs: DateTime.utc(2026, 10, 1, 3).millisecondsSinceEpoch,
    );
    final repository = FakeSessionRepository()
      ..trashLibraryPage = SessionLibraryPage(
        items: [
          SessionLibraryItem(meeting: trashed, committedAudioBytes: 2048),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Old lecture'), findsOneWidget);
    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(repository.restoredMeetingIds, ['trashed']);
  });

  testWidgets(
    'permanent deletion requires confirmation and disclaims external copies',
    (tester) async {
      final trashed = _meeting('trashed', 'Old lecture').copyWith(
        lifecycle: MeetingLifecycle.trashed,
        lifecycleBeforeTrash: MeetingLifecycle.finalized,
        trashedAtUtcMs: DateTime.utc(2026, 10, 1, 3).millisecondsSinceEpoch,
      );
      final repository = FakeSessionRepository()
        ..trashLibraryPage = SessionLibraryPage(
          items: [
            SessionLibraryItem(meeting: trashed, committedAudioBytes: 2048),
          ],
          nextCursor: null,
        );
      await _pumpApp(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trash'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nothing is deleted automatically'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Meeting actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(find.textContaining('audio, transcript'), findsOneWidget);
      expect(
        find.textContaining('copies you exported or backed up'),
        findsOneWidget,
      );
      final confirmation = find.byKey(
        const Key('confirm-permanent-delete'),
      );
      expect(
        tester.getSemantics(confirmation),
        isSemantics(
          label: 'Delete permanently',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final confirmationSize = tester.getSize(confirmation);
      expect(confirmationSize.width, greaterThanOrEqualTo(48));
      expect(confirmationSize.height, greaterThanOrEqualTo(48));
      expect(repository.permanentlyDeletedMeetingIds, isEmpty);

      await tester.tap(find.text('Delete permanently').last);
      await tester.pumpAndSettle();
      expect(repository.permanentlyDeletedMeetingIds, ['trashed']);
    },
  );

  testWidgets('deleting reservation cannot be restored and offers retry', (
    tester,
  ) async {
    final deleting = _meeting('deleting', 'Cleanup pending').copyWith(
      lifecycle: MeetingLifecycle.deleting,
      lifecycleBeforeTrash: MeetingLifecycle.finalized,
      trashedAtUtcMs: DateTime.utc(2026, 10, 1, 3).millisecondsSinceEpoch,
    );
    final repository = FakeSessionRepository()
      ..trashLibraryPage = SessionLibraryPage(
        items: [
          SessionLibraryItem(meeting: deleting, committedAudioBytes: 2048),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();

    expect(find.text('Restore'), findsNothing);
    expect(find.text('Retry permanent deletion'), findsOneWidget);

    Navigator.of(
      tester.element(find.text('Retry permanent deletion')),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanup pending'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('session-detail:deleting')),
      findsNothing,
    );
  });

  testWidgets('native-active meeting cannot be moved to trash', (tester) async {
    final repository = FakeSessionRepository()
      ..activeLibraryPage = SessionLibraryPage(
        items: [
          _item(
            'recording',
            'Live meeting',
            lifecycle: MeetingLifecycle.recording,
          ),
        ],
        nextCursor: null,
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();

    expect(find.text('Move to trash'), findsNothing);
  });

  testWidgets('pending deletion is serialized and failure stays retryable', (
    tester,
  ) async {
    final gate = Completer<Result<void, SessionRepositoryFailure>>();
    final trashed = _meeting('trashed', 'Old lecture').copyWith(
      lifecycle: MeetingLifecycle.trashed,
      lifecycleBeforeTrash: MeetingLifecycle.finalized,
      trashedAtUtcMs: DateTime.utc(2026, 10, 1, 3).millisecondsSinceEpoch,
    );
    final repository = FakeSessionRepository()
      ..trashLibraryPage = SessionLibraryPage(
        items: [
          SessionLibraryItem(meeting: trashed, committedAudioBytes: 0),
        ],
        nextCursor: null,
      )
      ..permanentlyDeleteOverride = (_) => gate.future;
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-permanent-delete')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('permanent-delete-pending:trashed')),
      findsOneWidget,
    );
    expect(find.byTooltip('Meeting actions'), findsNothing);
    expect(repository.permanentlyDeletedMeetingIds, ['trashed']);

    await tester.tap(find.text('Old lecture'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('session-detail:trashed')),
      findsNothing,
    );

    gate.complete(
      const Err(SessionRepositoryUnavailable('session_audio_delete_failed')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Deletion did not finish'), findsOneWidget);
    expect(find.text('Old lecture'), findsOneWidget);
    expect(find.byTooltip('Meeting actions'), findsOneWidget);
  });

  testWidgets('switching library scope clears visible search text', (
    tester,
  ) async {
    await _pumpApp(tester, FakeSessionRepository());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'planning');
    await tester.pumpAndSettle();
    expect(find.text('planning'), findsOneWidget);

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('planning'), findsNothing);
  });
}

SessionLibraryItem _item(
  String id,
  String title, {
  MeetingLifecycle lifecycle = MeetingLifecycle.finalized,
  Duration duration = Duration.zero,
  int committedAudioBytes = 0,
}) => SessionLibraryItem(
  meeting: _meeting(id, title, lifecycle: lifecycle, duration: duration),
  committedAudioBytes: committedAudioBytes,
);

Meeting _meeting(
  String id,
  String title, {
  MeetingLifecycle lifecycle = MeetingLifecycle.finalized,
  Duration duration = Duration.zero,
}) => Meeting(
  id: id,
  title: title,
  createdAtUtcMs: DateTime.utc(2026, 10, 1, 1).millisecondsSinceEpoch,
  mediaDuration: duration,
  lifecycle: lifecycle,
  languageMode: MeetingLanguageMode.mixed,
);

Future<void> _pumpApp(
  WidgetTester tester,
  SessionRepository repository, {
  AudioCaptureService? capture,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repository),
        if (capture != null)
          audioCaptureServiceProvider.overrideWithValue(capture),
      ],
      child: const LoquirisApp(),
    ),
  );
}

final class _PendingSessionRepository implements SessionRepository {
  final Completer<Result<SessionCollection, SessionRepositoryFailure>> _result =
      Completer();

  @override
  Future<Result<SessionCollection, SessionRepositoryFailure>> list() =>
      _result.future;

  @override
  Future<Result<SessionSummary, SessionRepositoryFailure>> save(
    SessionSummary session,
  ) async => Ok(session);

  @override
  Stream<Result<SessionLibraryPage, SessionRepositoryFailure>> watchLibrary(
    SessionLibraryQuery query,
  ) => const Stream.empty();

  @override
  Future<Result<SessionLibraryPage, SessionRepositoryFailure>> queryLibrary(
    SessionLibraryQuery query,
  ) => Completer<Result<SessionLibraryPage, SessionRepositoryFailure>>().future;

  @override
  Future<Result<SessionDetail, SessionRepositoryFailure>> loadDetail(
    String meetingId,
  ) => Completer<Result<SessionDetail, SessionRepositoryFailure>>().future;

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  ) async => Ok(meeting);

  @override
  Future<Result<Bookmark, SessionRepositoryFailure>> saveBookmark(
    Bookmark bookmark,
  ) async => Ok(bookmark);

  @override
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  loadRecordingDefaults() =>
      Completer<Result<RecordingDefaults, SessionRepositoryFailure>>().future;

  @override
  Future<Result<RecordingDefaults, SessionRepositoryFailure>>
  saveRecordingDefaults(
    RecordingDefaults defaults, {
    required int atUtcMs,
  }) => Completer<Result<RecordingDefaults, SessionRepositoryFailure>>().future;

  @override
  Future<Result<Meeting, SessionRepositoryFailure>>
  synchronizeRecordingProgress(
    String meetingId, {
    required MeetingLifecycle lifecycle,
    required Duration mediaDuration,
    required int atUtcMs,
  }) => Completer<Result<Meeting, SessionRepositoryFailure>>().future;

  @override
  Future<Result<void, SessionRepositoryFailure>> discardUnstartedMeeting(
    String meetingId,
  ) => Completer<Result<void, SessionRepositoryFailure>>().future;

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> renameMeeting(
    String meetingId,
    String title, {
    required int atUtcMs,
  }) => Completer<Result<Meeting, SessionRepositoryFailure>>().future;

  @override
  Future<Result<List<SessionSearchHit>, SessionRepositoryFailure>> search(
    String query,
  ) async => const Ok(<SessionSearchHit>[]);

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> moveToTrash(
    String meetingId, {
    required int atUtcMs,
  }) => Completer<Result<Meeting, SessionRepositoryFailure>>().future;

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> restoreFromTrash(
    String meetingId, {
    required int atUtcMs,
  }) => Completer<Result<Meeting, SessionRepositoryFailure>>().future;

  @override
  Future<Result<void, SessionRepositoryFailure>> permanentlyDelete(
    String meetingId,
  ) => Completer<Result<void, SessionRepositoryFailure>>().future;

  @override
  Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
  accountStorage() =>
      Completer<Result<SessionStorageAccounting, SessionRepositoryFailure>>()
          .future;

  @override
  Future<Result<SessionRecoveryDetails, SessionRepositoryFailure>>
  recoveryDetails(String meetingId) =>
      Completer<Result<SessionRecoveryDetails, SessionRepositoryFailure>>()
          .future;

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> resolveRecovery(
    String meetingId,
    RecoveryResolution resolution, {
    required int atUtcMs,
  }) => Completer<Result<Meeting, SessionRepositoryFailure>>().future;

  @override
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
    Set<String> liveMeetingIds = const <String>{},
    Set<String> invalidStorageKeys = const <String>{},
  }) => Completer<Result<SessionRecoveryReport, SessionRepositoryFailure>>()
      .future;
}
