import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/sessions/presentation/sessions_controller.dart';
import 'package:loquiris/services/service_contracts.dart';

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
    expect(SessionsLoaded(first), SessionsLoaded(second));
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
}
