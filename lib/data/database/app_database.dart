import 'package:drift/drift.dart';
import 'package:loquiris/data/database/schema_versions.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/model_export_tables.dart';
import 'package:loquiris/data/database/tables/revision_job_tables.dart';
import 'package:loquiris/data/database/tables/speaker_tables.dart';
import 'package:loquiris/data/database/tables/transcription_tables.dart';

part 'app_database.g.dart';

/// Single local source of truth for durable meeting and analysis metadata.
@DriftDatabase(
  tables: <Type>[
    Meetings,
    AudioSegments,
    SessionEvents,
    Bookmarks,
    TranscriptRuns,
    MeetingTranscriptSelections,
    TranscriptSegments,
    LanguageDecisions,
    TranscriptLanguageSelections,
    DiarizationRuns,
    Speakers,
    SpeakerAssignments,
    Revisions,
    ProcessingJobs,
    ModelManifests,
    ModelCapabilityEntries,
    ModelModeEntries,
    ExportRecords,
    BackupRecords,
  ],
)
final class AppDatabase extends _$AppDatabase {
  /// Opens the database over an injected executor.
  AppDatabase(super.e);

  /// Per-connection durability and referential-integrity settings.
  static const List<String> connectionPragmas = <String>[
    'PRAGMA foreign_keys = ON',
    'PRAGMA journal_mode = WAL',
    'PRAGMA synchronous = FULL',
    'PRAGMA busy_timeout = 5000',
  ];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: stepByStep(),
    beforeOpen: (details) async {
      for (final pragma in connectionPragmas) {
        await customStatement(pragma);
      }
    },
  );
}
