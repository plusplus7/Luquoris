import 'package:drift/drift.dart';
import 'package:loquiris/data/database/schema_versions.dart';
import 'package:loquiris/data/database/tables/meeting_processing_selection_tables.dart';
import 'package:loquiris/data/database/tables/meeting_tables.dart';
import 'package:loquiris/data/database/tables/model_export_tables.dart';
import 'package:loquiris/data/database/tables/remote_transcription_tables.dart';
import 'package:loquiris/data/database/tables/revision_job_tables.dart';
import 'package:loquiris/data/database/tables/speaker_tables.dart';
import 'package:loquiris/data/database/tables/transcript_processing_tables.dart';
import 'package:loquiris/data/database/tables/transcription_tables.dart';

part 'app_database.g.dart';

/// Single local source of truth for durable meeting and analysis metadata.
@DriftDatabase(
  tables: <Type>[
    Meetings,
    RecordingPreferences,
    MeetingProcessingSelections,
    RemoteTranscriptionTasks,
    RemoteTranscriptVersions,
    AudioSegments,
    RecoveryFindings,
    SessionEvents,
    Bookmarks,
    TranscriptRuns,
    TranscriptProcessingMetadata,
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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: stepByStep(
      from1To2: (migrator, schema) async {
        await migrator.createTable(schema.recoveryFindings);
        await migrator.createIndex(schema.idxRecoveryFindingsMeetingSequence);
      },
      from2To3: (migrator, schema) async {
        await migrator.addColumn(
          schema.meetings,
          schema.meetings.transcriptionMode,
        );
        await migrator.addColumn(
          schema.meetings,
          schema.meetings.expectedSpeakerCount,
        );
        await migrator.createTable(schema.recordingPreferences);
      },
      from3To4: (migrator, schema) async {
        await migrator.alterTable(
          TableMigration(
            schema.exportRecords,
            columnTransformer: {
              schema.exportRecords.format: const CustomExpression<String>(
                "CASE format WHEN 'audio' THEN 'audioM4a' "
                "WHEN 'plainText' THEN 'text' "
                "WHEN 'structuredJson' THEN 'json' ELSE format END",
              ),
            },
          ),
        );
      },
      from4To5: (migrator, schema) async {
        await migrator.createTable(schema.transcriptProcessingMetadata);
        await migrator.createIndex(schema.uxTranscriptProcessingRun);
      },
      from5To6: (migrator, schema) async {
        await migrator.createTable(schema.meetingProcessingSelections);
        await migrator.createIndex(schema.uxMeetingProcessingSelection);
      },
      from6To7: (migrator, schema) async {
        await migrator.createTable(schema.remoteTranscriptionTasks);
        await migrator.createTable(schema.remoteTranscriptVersions);
      },
    ),
    beforeOpen: (details) async {
      for (final pragma in connectionPragmas) {
        await customStatement(pragma);
      }
    },
  );
}
