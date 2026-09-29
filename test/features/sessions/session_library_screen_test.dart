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
      ..listResult = const Err(
        SessionRepositoryUnavailable('database.internal.path'),
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
      ..listResult = Ok(
        SessionCollection(
          sessions: const [
            SessionSummary(
              id: 'recover-1',
              title: 'Interrupted interview',
              isRecoverable: true,
            ),
          ],
        ),
      );
    await _pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sessions-recovery')),
      findsOneWidget,
    );
    expect(find.text('Review recording'), findsOneWidget);
    expect(find.textContaining('Resume recording'), findsNothing);
  });

  testWidgets('every recoverable meeting remains explicitly identifiable', (
    tester,
  ) async {
    final repository = FakeSessionRepository()
      ..listResult = Ok(
        SessionCollection(
          sessions: const [
            SessionSummary(
              id: 'recover-1',
              title: 'Interrupted interview',
              isRecoverable: true,
            ),
            SessionSummary(
              id: 'recover-2',
              title: 'Interrupted lecture',
              isRecoverable: true,
            ),
          ],
        ),
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
}

Future<void> _pumpApp(
  WidgetTester tester,
  SessionRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
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
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  ) async => Ok(meeting);

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
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
  }) => Completer<Result<SessionRecoveryReport, SessionRepositoryFailure>>()
      .future;
}
