import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/app_database.dart';

void main() {
  test(
    'pause keeps wall time while media time excludes the paused interval',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final fixedClock = Clock.fixed(DateTime.utc(2026, 9, 28, 12));
      final startedAtUtcMs = fixedClock.now().millisecondsSinceEpoch;

      await database
          .into(database.meetings)
          .insert(
            MeetingsCompanion.insert(
              id: 'meeting-paused',
              createdAt: startedAtUtcMs,
              updatedAt: startedAtUtcMs,
              title: 'Pause mapping',
              mediaDurationUs: const Value(30000000),
              lifecycle: 'finalized',
              languageMode: 'mixed',
            ),
          );
      await database.batch((batch) {
        batch.insertAll(database.sessionEvents, <SessionEventsCompanion>[
          _event(
            id: 'event-start',
            sequence: 0,
            type: 'started',
            wallClockUtcMs: startedAtUtcMs,
            monotonicElapsed: Duration.zero,
            mediaOffset: Duration.zero,
          ),
          _event(
            id: 'event-pause',
            sequence: 1,
            type: 'pausedByUser',
            wallClockUtcMs: startedAtUtcMs + 10000,
            monotonicElapsed: const Duration(seconds: 10),
            mediaOffset: const Duration(seconds: 10),
          ),
          _event(
            id: 'event-resume',
            sequence: 2,
            type: 'resumedByUser',
            wallClockUtcMs: startedAtUtcMs + 70000,
            monotonicElapsed: const Duration(seconds: 70),
            mediaOffset: const Duration(seconds: 10),
          ),
          _event(
            id: 'event-stop',
            sequence: 3,
            type: 'stopped',
            wallClockUtcMs: startedAtUtcMs + 90000,
            monotonicElapsed: const Duration(seconds: 90),
            mediaOffset: const Duration(seconds: 30),
          ),
        ]);
      });

      final events =
          await (database.select(database.sessionEvents)..orderBy([
                (event) => OrderingTerm.asc(event.sequence),
              ]))
              .get();
      final meeting = await (database.select(
        database.meetings,
      )..where((row) => row.id.equals('meeting-paused'))).getSingle();

      expect(events.map((event) => event.type), <String>[
        'started',
        'pausedByUser',
        'resumedByUser',
        'stopped',
      ]);
      expect(
        events[2].wallClockUtcMs - events[1].wallClockUtcMs,
        const Duration(minutes: 1).inMilliseconds,
        reason: 'the real pause interval must remain visible on wall time',
      );
      expect(
        events[2].monotonicElapsedUs - events[1].monotonicElapsedUs,
        const Duration(minutes: 1).inMicroseconds,
        reason: 'monotonic ordering continues while capture is paused',
      );
      expect(
        events[2].mediaOffsetUs,
        events[1].mediaOffsetUs,
        reason: 'paused wall time must not advance the media timeline',
      );
      expect(events.last.monotonicElapsedUs, 90000000);
      expect(events.last.mediaOffsetUs, 30000000);
      expect(meeting.mediaDurationUs, events.last.mediaOffsetUs);
    },
  );
}

SessionEventsCompanion _event({
  required String id,
  required int sequence,
  required String type,
  required int wallClockUtcMs,
  required Duration monotonicElapsed,
  required Duration mediaOffset,
}) => SessionEventsCompanion.insert(
  id: id,
  createdAt: wallClockUtcMs,
  updatedAt: wallClockUtcMs,
  meetingId: 'meeting-paused',
  sequence: sequence,
  type: type,
  wallClockUtcMs: wallClockUtcMs,
  monotonicElapsedUs: monotonicElapsed.inMicroseconds,
  mediaOffsetUs: mediaOffset.inMicroseconds,
);
