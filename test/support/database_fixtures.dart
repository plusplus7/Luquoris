import 'package:drift/drift.dart';

import '../drift/generated/schema_v1.dart' as v1;
import '../drift/generated/schema_v2.dart' as v2;

/// Hostile, deterministic rows used by schema and migration tests.
abstract final class DatabaseFixtures {
  /// Text designed to expose lossy quoting, escaping, Unicode, and whitespace.
  static const hostileMeetingTitle =
      '  O\'Brien — 中英会议 🎙️ "quoted" \\ path\n  ';

  /// A complete meeting row authored through the v1-era companion.
  static v1.MeetingsCompanion meetingV1({String id = 'meeting-hostile'}) =>
      v1.MeetingsCompanion.insert(
        id: id,
        createdAt: 1,
        updatedAt: 1,
        title: hostileMeetingTitle,
        mediaDurationUs: const Value(1234567),
        lifecycle: 'finalized',
        languageMode: 'mixed',
      );

  /// A complete meeting row authored through the v2-era companion.
  static v2.MeetingsCompanion meetingV2({String id = 'meeting-hostile'}) =>
      v2.MeetingsCompanion.insert(
        id: id,
        createdAt: 1,
        updatedAt: 1,
        title: hostileMeetingTitle,
        mediaDurationUs: const Value(1234567),
        lifecycle: 'finalized',
        languageMode: 'mixed',
      );
}
