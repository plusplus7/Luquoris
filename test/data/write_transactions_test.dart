import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/data/database/analysis_write_transactions.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/model_write_transactions.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('model manifest and compatibility rows roll back together', () async {
    final writes = ModelWriteTransactions(database);

    await expectLater(
      writes.installManifest(
        ModelManifestsCompanion.insert(
          id: 'model-1',
          createdAt: 1,
          updatedAt: 1,
          version: '1',
          source: 'source',
          sha256: 'hash',
          bytes: 1,
          expectedEngineId: 'engine',
          licenseId: 'MIT',
          licenseSnapshotPath: 'licenses/model.txt',
        ),
        capabilities: <ModelCapabilityEntriesCompanion>[
          ModelCapabilityEntriesCompanion.insert(
            id: 'capability-1',
            createdAt: 1,
            updatedAt: 1,
            modelId: 'model-1',
            capability: 'transcription',
          ),
          ModelCapabilityEntriesCompanion.insert(
            id: 'capability-2',
            createdAt: 1,
            updatedAt: 1,
            modelId: 'model-1',
            capability: 'transcription',
          ),
        ],
        modes: const <ModelModeEntriesCompanion>[],
      ),
      throwsA(isA<SqliteException>()),
    );

    expect(await _count(database, 'model_manifests'), 0);
    expect(await _count(database, 'model_capability_entries'), 0);
  });

  test('transcript run and derived rows roll back together', () async {
    await _insertMeetingAndModel(database);
    final writes = AnalysisWriteTransactions(database);

    await expectLater(
      writes.createTranscriptVersion(
        TranscriptRunsCompanion.insert(
          id: 'transcript-1',
          createdAt: 1,
          updatedAt: 1,
          meetingId: 'meeting-1',
          engineId: 'engine',
          engineVersion: '1',
          modelId: 'model-1',
          modelVersion: '1',
          modelSha256: 'hash',
          parametersJson: '{}',
          runState: 'queued',
        ),
        segments: <TranscriptSegmentsCompanion>[
          TranscriptSegmentsCompanion.insert(
            id: 'segment-invalid',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'meeting-1',
            transcriptRunId: 'transcript-1',
            startUs: 2,
            endUs: 1,
            rawModelText: 'raw',
            displayedText: 'raw',
            revisionState: 'machine',
          ),
        ],
        languageDecisions: const <LanguageDecisionsCompanion>[],
      ),
      throwsA(isA<SqliteException>()),
    );

    expect(await _count(database, 'transcript_runs'), 0);
    expect(await _count(database, 'transcript_segments'), 0);
  });

  test(
    'transcript write rejects language selection outside its aggregate',
    () async {
      await _insertMeetingAndModel(database);
      await database.customStatement('''
        INSERT INTO transcript_runs (
          id, created_at, updated_at, meeting_id, engine_id, engine_version,
          model_id, model_version, model_sha256, parameters_json, run_state
        ) VALUES ('existing-run', 1, 1, 'meeting-1', 'engine', '1',
          'model-1', '1', 'hash', '{}', 'queued')
        ''');
      await database.customStatement('''
        INSERT INTO transcript_segments (
          id, created_at, updated_at, meeting_id, transcript_run_id,
          start_us, end_us, raw_model_text, displayed_text, revision_state
        ) VALUES ('existing-segment', 1, 1, 'meeting-1', 'existing-run',
          0, 1, 'raw', 'raw', 'machine')
        ''');
      await database.customStatement('''
        INSERT INTO language_decisions (
          id, created_at, updated_at, transcript_segment_id,
          tag, source, confidence
        ) VALUES ('existing-language', 1, 1, 'existing-segment',
          'english', 'automatic', 0.9)
        ''');

      final writes = AnalysisWriteTransactions(database);
      await expectLater(
        writes.createTranscriptVersion(
          TranscriptRunsCompanion.insert(
            id: 'new-run',
            createdAt: 2,
            updatedAt: 2,
            meetingId: 'meeting-1',
            engineId: 'engine',
            engineVersion: '1',
            modelId: 'model-1',
            modelVersion: '1',
            modelSha256: 'hash',
            parametersJson: '{}',
            runState: 'queued',
          ),
          segments: const <TranscriptSegmentsCompanion>[],
          languageDecisions: const <LanguageDecisionsCompanion>[],
          languageSelections: <TranscriptLanguageSelectionsCompanion>[
            TranscriptLanguageSelectionsCompanion.insert(
              id: 'selection-invalid',
              createdAt: 2,
              updatedAt: 2,
              transcriptSegmentId: 'existing-segment',
              languageDecisionId: 'existing-language',
            ),
          ],
        ),
        throwsArgumentError,
      );

      expect(await _count(database, 'transcript_runs'), 1);
      expect(await _count(database, 'transcript_language_selections'), 0);
    },
  );

  test(
    'diarization run, clusters, and assignments roll back together',
    () async {
      await _insertMeetingAndModel(database);
      final writes = AnalysisWriteTransactions(database);

      await expectLater(
        writes.createDiarizationVersion(
          DiarizationRunsCompanion.insert(
            id: 'diarization-1',
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'meeting-1',
            engineId: 'engine',
            engineVersion: '1',
            modelId: 'model-1',
            modelVersion: '1',
            modelSha256: 'hash',
            parametersJson: '{}',
            runState: 'queued',
          ),
          speakers: <SpeakersCompanion>[
            SpeakersCompanion.insert(
              id: 'speaker-1',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'meeting-1',
              analysisRunId: 'diarization-1',
              label: 'Speaker 1',
            ),
          ],
          assignments: <SpeakerAssignmentsCompanion>[
            SpeakerAssignmentsCompanion.insert(
              id: 'assignment-invalid',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'meeting-1',
              analysisRunId: 'diarization-1',
              startUs: 2,
              endUs: 1,
              isOverlap: false,
              needsConfirmation: false,
            ),
          ],
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(await _count(database, 'diarization_runs'), 0);
      expect(await _count(database, 'speakers'), 0);
    },
  );
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM $table',
      )
      .getSingle();
  return row.read<int>('count');
}

Future<void> _insertMeetingAndModel(AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO meetings (
      id, created_at, updated_at, title, media_duration_us,
      lifecycle, language_mode
    ) VALUES ('meeting-1', 1, 1, 'Meeting', 0, 'draft', 'mixed')
    ''');
  await database.customStatement('''
    INSERT INTO model_manifests (
      id, created_at, updated_at, version, source, sha256, bytes,
      expected_engine_id, license_id, license_snapshot_path
    ) VALUES ('model-1', 1, 1, '1', 'source', 'hash', 1,
      'engine', 'MIT', 'licenses/model.txt')
    ''');
}
