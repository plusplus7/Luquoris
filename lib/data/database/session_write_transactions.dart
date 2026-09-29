import 'package:loquiris/data/database/app_database.dart';

/// Cross-table atomic write boundaries used by session repositories.
final class SessionWriteTransactions {
  /// Creates transaction boundaries over [database].
  const SessionWriteTransactions(this.database);

  /// Database that owns the transaction and all affected tables.
  final AppDatabase database;

  /// Creates a meeting and its first persisted state event atomically.
  Future<void> createMeetingWithInitialEvent(
    MeetingsCompanion meeting,
    SessionEventsCompanion initialEvent,
  ) async {
    if (!meeting.id.present ||
        !initialEvent.meetingId.present ||
        meeting.id.value != initialEvent.meetingId.value) {
      throw ArgumentError.value(
        initialEvent.meetingId.value,
        'initialEvent.meetingId',
        'must equal the new meeting id',
      );
    }

    await database.transaction(() async {
      await database.into(database.meetings).insert(meeting);
      await database.into(database.sessionEvents).insert(initialEvent);
    });
  }
}
