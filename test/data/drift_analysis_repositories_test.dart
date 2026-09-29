import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

void main() {
  late db.AppDatabase database;
  late DriftModelRepository repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftModelRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
  });

  tearDown(() => database.close());

  test('model manifests are complete, idempotent, and immutable', () async {
    final model = _model();

    expect(
      await repository.registerBundled(model, observedAtUtcMs: 10),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(
      await repository.registerBundled(model, observedAtUtcMs: 11),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(
      await repository.registerBundled(
        model.copyWith(
          capabilities: model.capabilities.reversed.toList(),
          enabledModes: model.enabledModes.reversed.toList(),
        ),
        observedAtUtcMs: 11,
      ),
      isA<Ok<InstalledModel, AnalysisRepositoryFailure>>(),
    );
    expect(await _ok(repository.listInstalled()), [model]);

    final conflict = await repository.registerBundled(
      model.copyWith(sha256: 'different-hash'),
      observedAtUtcMs: 12,
    );
    expect(
      (conflict as Err<InstalledModel, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    expect(await _ok(repository.listInstalled()), [model]);
  });

  test(
    'model child-write failure rolls back the manifest transaction',
    () async {
      await database.customStatement('''
      CREATE TRIGGER fail_model_capability
      BEFORE INSERT ON model_capability_entries
      BEGIN
        SELECT RAISE(ABORT, 'simulated capability failure');
      END
      ''');

      final result = await repository.registerBundled(
        _model(),
        observedAtUtcMs: 1,
      );

      expect(
        (result as Err<InstalledModel, AnalysisRepositoryFailure>).failure,
        isA<AnalysisStoreUnavailable>(),
      );
      expect(await _tableCount(database, 'model_manifests'), 0);
      expect(await _tableCount(database, 'model_capability_entries'), 0);
    },
  );

  test(
    'parallel transcript versions require explicit current selection',
    () async {
      await _insertMeeting(database, 'meeting-1');
      await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
      final transcripts = DriftTranscriptRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      );
      final firstRun = _run('run-1', createdAt: 2);
      final secondRun = _run('run-2', createdAt: 4);

      await _ok(
        transcripts.saveVersion(
          firstRun,
          [_segment('segment-1', 'run-1', 'first')],
          storedAtUtcMs: 2,
        ),
      );
      await _ok(
        transcripts.selectCurrent('meeting-1', 'run-1', selectedAtUtcMs: 3),
      );
      await _ok(
        transcripts.saveVersion(
          secondRun,
          [_segment('segment-2', 'run-2', 'second')],
          storedAtUtcMs: 4,
        ),
      );

      final retained = await _ok(transcripts.listVersions('meeting-1'));
      expect(retained.map((version) => version.run.id), ['run-2', 'run-1']);
      expect(
        retained.singleWhere((version) => version.isCurrent).run.id,
        'run-1',
      );
      expect(retained.last.segments.single.rawModelText, 'first');

      await _ok(
        transcripts.selectCurrent('meeting-1', 'run-2', selectedAtUtcMs: 5),
      );
      final selected = await _ok(transcripts.listVersions('meeting-1'));
      expect(
        selected.singleWhere((version) => version.isCurrent).run.id,
        'run-2',
      );
      expect(selected, hasLength(2));
    },
  );

  test('text and language corrections preserve machine evidence', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    final transcripts = DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _ok(
      transcripts.saveVersion(
        _run('run-1', createdAt: 2),
        [_segment('segment-1', 'run-1', 'machine text')],
        storedAtUtcMs: 2,
      ),
    );
    await _insertAutomaticLanguage(database);

    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-language',
          meetingId: 'meeting-1',
          targetId: 'segment-1',
          change: LanguageLabelChange(
            previous: LanguageTag.chinese,
            revised: LanguageTag.mixed,
          ),
          createdAtUtcMs: 4,
        ),
      ),
    );
    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-text',
          meetingId: 'meeting-1',
          targetId: 'segment-1',
          change: TranscriptTextChange(
            previousText: 'machine text',
            revisedText: 'human text',
          ),
          createdAtUtcMs: 3,
        ),
      ),
    );

    final version = (await _ok(transcripts.listVersions('meeting-1'))).single;
    final corrected = version.segments.single;
    expect(corrected.rawModelText, 'machine text');
    expect(corrected.displayedText, 'human text');
    expect(corrected.revisionState, TranscriptRevisionState.corrected);
    expect(corrected.languageDecisionId, 'revision-language:language');
    expect(await _tableCount(database, 'language_decisions'), 2);
    expect(await _ok(revisions.listMeeting('meeting-1')), hasLength(2));

    await _ok(
      transcripts.saveVersion(
        _run('run-2', createdAt: 5),
        [_segment('segment-2', 'run-2', 'new machine text')],
        storedAtUtcMs: 5,
      ),
    );
    final retained = await _ok(transcripts.listVersions('meeting-1'));
    expect(
      retained
          .singleWhere((version) => version.run.id == 'run-1')
          .segments
          .single
          .displayedText,
      'human text',
    );
  });

  test('speaker corrections project without mutating raw analysis', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    await _insertSpeakerAnalysis(database);
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    const rawSpeaker = Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-1',
      analysisRunId: 'diarization-1',
      label: 'Speaker 1',
    );
    const rawAssignment = SpeakerAssignment(
      id: 'assignment-1',
      analysisRunId: 'diarization-1',
      speakerId: 'speaker-1',
      start: Duration.zero,
      end: Duration(seconds: 1),
      confidence: 0.7,
      isOverlap: false,
      needsConfirmation: false,
    );

    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-speaker-label',
          meetingId: 'meeting-1',
          targetId: 'speaker-1',
          change: SpeakerLabelChange(
            previous: 'Speaker 1',
            revised: 'Alice',
          ),
          createdAtUtcMs: 3,
        ),
      ),
    );
    await _ok(
      revisions.apply(
        const Revision(
          id: 'revision-speaker-assignment',
          meetingId: 'meeting-1',
          targetId: 'assignment-1',
          change: SpeakerAssignmentChange(
            start: Duration.zero,
            end: Duration(seconds: 1),
            previousSpeakerId: 'speaker-1',
            revisedSpeakerId: null,
            needsConfirmation: true,
          ),
          createdAtUtcMs: 4,
        ),
      ),
    );

    expect(
      (await _ok(revisions.materializeSpeaker(rawSpeaker))).label,
      'Alice',
    );
    final projected = await _ok(
      revisions.materializeSpeakerAssignment(rawAssignment),
    );
    expect(projected.speakerId, isNull);
    expect(projected.needsConfirmation, isTrue);
    final rawSpeakerRow = await database
        .customSelect("SELECT label FROM speakers WHERE id = 'speaker-1'")
        .getSingle();
    final rawAssignmentRow = await database
        .customSelect(
          "SELECT speaker_id FROM speaker_assignments WHERE id = 'assignment-1'",
        )
        .getSingle();
    expect(rawSpeakerRow.read<String>('label'), 'Speaker 1');
    expect(rawAssignmentRow.read<String>('speaker_id'), 'speaker-1');

    final olderLabel = await revisions.apply(
      const Revision(
        id: 'revision-older-label',
        meetingId: 'meeting-1',
        targetId: 'speaker-1',
        change: SpeakerLabelChange(previous: 'Alice', revised: 'Bob'),
        createdAtUtcMs: 2,
      ),
    );
    expect(
      (olderLabel as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    final sameTimeEarlierLabelId = await revisions.apply(
      const Revision(
        id: 'a-label',
        meetingId: 'meeting-1',
        targetId: 'speaker-1',
        change: SpeakerLabelChange(previous: 'Alice', revised: 'Bob'),
        createdAtUtcMs: 3,
      ),
    );
    expect(
      (sameTimeEarlierLabelId as Err<Revision, AnalysisRepositoryFailure>)
          .failure,
      isA<AnalysisConflict>(),
    );
    final olderAssignment = await revisions.apply(
      const Revision(
        id: 'revision-older-assignment',
        meetingId: 'meeting-1',
        targetId: 'assignment-1',
        change: SpeakerAssignmentChange(
          start: Duration.zero,
          end: Duration(seconds: 1),
          previousSpeakerId: null,
          revisedSpeakerId: 'speaker-1',
          needsConfirmation: false,
        ),
        createdAtUtcMs: 3,
      ),
    );
    expect(
      (olderAssignment as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    final sameTimeEarlierId = await revisions.apply(
      const Revision(
        id: 'a',
        meetingId: 'meeting-1',
        targetId: 'assignment-1',
        change: SpeakerAssignmentChange(
          start: Duration.zero,
          end: Duration(seconds: 1),
          previousSpeakerId: null,
          revisedSpeakerId: 'speaker-1',
          needsConfirmation: false,
        ),
        createdAtUtcMs: 4,
      ),
    );
    expect(
      (sameTimeEarlierId as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisConflict>(),
    );
    expect(
      (await _ok(revisions.materializeSpeaker(rawSpeaker))).label,
      'Alice',
    );
    expect(
      (await _ok(
        revisions.materializeSpeakerAssignment(rawAssignment),
      )).speakerId,
      isNull,
    );
  });

  test('revision insert failure rolls back the corrected projection', () async {
    await _insertMeeting(database, 'meeting-1');
    await _ok(repository.registerBundled(_model(), observedAtUtcMs: 1));
    final transcripts = DriftTranscriptRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    final revisions = DriftRevisionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _ok(
      transcripts.saveVersion(
        _run('run-1', createdAt: 2),
        [_segment('segment-1', 'run-1', 'machine text')],
        storedAtUtcMs: 2,
      ),
    );
    await database.customStatement('''
      CREATE TRIGGER fail_revision_insert
      BEFORE INSERT ON revisions
      BEGIN
        SELECT RAISE(ABORT, 'simulated revision failure');
      END
      ''');

    final result = await revisions.apply(
      const Revision(
        id: 'revision-text',
        meetingId: 'meeting-1',
        targetId: 'segment-1',
        change: TranscriptTextChange(
          previousText: 'machine text',
          revisedText: 'must roll back',
        ),
        createdAtUtcMs: 3,
      ),
    );

    expect(
      (result as Err<Revision, AnalysisRepositoryFailure>).failure,
      isA<AnalysisStoreUnavailable>(),
    );
    final version = (await _ok(transcripts.listVersions('meeting-1'))).single;
    expect(version.segments.single.displayedText, 'machine text');
    expect(
      version.segments.single.revisionState,
      TranscriptRevisionState.machine,
    );
    expect(await _tableCount(database, 'revisions'), 0);
  });
}

InstalledModel _model() => InstalledModel(
  id: 'whisper-base-q5',
  version: '1',
  source: 'bundled-test-fixture',
  sha256: 'verified-hash',
  bytes: 42,
  capabilities: const <ModelCapability>[
    ModelCapability.transcription,
    ModelCapability.languageIdentification,
  ],
  expectedEngineId: 'whisper.cpp',
  licenseId: 'MIT',
  licenseSnapshotPath: _path('licenses/whisper.txt'),
  enabledModes: const <PerformanceMode>[
    PerformanceMode.balanced,
    PerformanceMode.postSession,
  ],
);

AppRelativePath _path(String value) =>
    switch (AppRelativePath.tryParse(value)) {
      Ok(:final value) => value,
      Err() => throw TestFailure('invalid test path'),
    };

TranscriptRun _run(String id, {required int createdAt}) => TranscriptRun(
  id: id,
  meetingId: 'meeting-1',
  provenance: const InferenceProvenance(
    engineId: 'whisper.cpp',
    engineVersion: '1',
    modelId: 'whisper-base-q5',
    modelVersion: '1',
    modelSha256: 'verified-hash',
    parametersJson: '{}',
  ),
  createdAtUtcMs: createdAt,
  state: const AnalysisQueued(),
);

TranscriptSegment _segment(String id, String runId, String text) =>
    TranscriptSegment(
      id: id,
      transcriptRunId: runId,
      start: Duration.zero,
      end: const Duration(seconds: 1),
      rawModelText: text,
      displayedText: text,
      revisionState: TranscriptRevisionState.machine,
    );

Future<void> _insertMeeting(db.AppDatabase database, String id) =>
    database.customStatement(
      '''
      INSERT INTO meetings (
        id, created_at, updated_at, title, media_duration_us,
        lifecycle, language_mode
      ) VALUES (?, 1, 1, ?, 0, 'finalized', 'mixed')
      ''',
      <Object>[id, id],
    );

Future<void> _insertAutomaticLanguage(db.AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO language_decisions (
      id, created_at, updated_at, transcript_segment_id, tag, source, confidence
    ) VALUES ('language-auto', 2, 2, 'segment-1', 'chinese', 'automatic', 0.9)
    ''');
  await database.customStatement('''
    INSERT INTO transcript_language_selections (
      id, created_at, updated_at, transcript_segment_id, language_decision_id
    ) VALUES ('language-selection', 2, 2, 'segment-1', 'language-auto')
    ''');
}

Future<int> _tableCount(db.AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<void> _insertSpeakerAnalysis(db.AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO diarization_runs (
      id, created_at, updated_at, meeting_id, engine_id, engine_version,
      model_id, model_version, model_sha256, parameters_json, run_state
    ) VALUES (
      'diarization-1', 2, 2, 'meeting-1', 'whisper.cpp', '1',
      'whisper-base-q5', '1', 'verified-hash', '{}', 'queued'
    )
    ''');
  await database.customStatement('''
    INSERT INTO speakers (
      id, created_at, updated_at, meeting_id, analysis_run_id, label
    ) VALUES ('speaker-1', 2, 2, 'meeting-1', 'diarization-1', 'Speaker 1')
    ''');
  await database.customStatement('''
    INSERT INTO speaker_assignments (
      id, created_at, updated_at, meeting_id, analysis_run_id,
      speaker_id, speaker_analysis_run_id, start_us, end_us,
      confidence, is_overlap, needs_confirmation
    ) VALUES (
      'assignment-1', 2, 2, 'meeting-1', 'diarization-1',
      'speaker-1', 'diarization-1', 0, 1000000, 0.7, 0, 0
    )
    ''');
}

Future<T> _ok<T>(Future<Result<T, AnalysisRepositoryFailure>> result) async {
  return switch (await result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('Unexpected ${failure.code}'),
  };
}
