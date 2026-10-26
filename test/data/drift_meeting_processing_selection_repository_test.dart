import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/repositories/drift_meeting_processing_selection_repository.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

import '../support/model_bundle_fixture.dart';

void main() {
  late db.AppDatabase database;
  late DriftMeetingProcessingSelectionRepository selections;
  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    selections = DriftMeetingProcessingSelectionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    await _meeting(database);
  });
  tearDown(() => database.close());

  test('legacy absence is not interpreted as an opt-in', () async {
    expect(_ok(await selections.load('meeting')), isNull);
    expect(_ok(await selections.listFinalized()), isEmpty);
  });

  test(
    'independent complete profiles persist and repeat idempotently',
    () async {
      final choice = _choice();
      expect(
        _ok(await selections.save('meeting', choice, storedAtUtcMs: 2)),
        choice,
      );
      expect(
        _ok(await selections.save('meeting', choice, storedAtUtcMs: 3)),
        choice,
      );
      expect(_ok(await selections.load('meeting')), choice);
      final row = await database
          .select(database.meetingProcessingSelections)
          .getSingle();
      expect(
        row.rowRevision,
        0,
        reason: 'duplicate configuration notification is not a new user choice',
      );
      expect(row.liveBundleManifestJson, choice.live!.bundleManifestJson);
      expect(
        row.refinementBundleManifestJson,
        choice.refinement!.bundleManifestJson,
      );
    },
  );

  test(
    'choice can change before capture but freezes once recording begins',
    () async {
      _ok(await selections.save('meeting', _choice(), storedAtUtcMs: 2));
      const captureOnly = MeetingProcessingSelection.recordingOnly();
      _ok(await selections.save('meeting', captureOnly, storedAtUtcMs: 3));
      await database.customStatement(
        "UPDATE meetings SET lifecycle='recording' WHERE id='meeting'",
      );
      expect(
        _ok(await selections.save('meeting', captureOnly, storedAtUtcMs: 4)),
        captureOnly,
      );
      expect(
        await selections.save('meeting', _choice(), storedAtUtcMs: 4),
        isA<Err<MeetingProcessingSelection, AnalysisRepositoryFailure>>(),
      );
      expect(_ok(await selections.load('meeting')), captureOnly);
      final row = await database
          .select(database.meetingProcessingSelections)
          .getSingle();
      expect(row.rowRevision, 1);
    },
  );

  test(
    'startup scan contains only explicit finalized inference selections',
    () async {
      _ok(await selections.save('meeting', _choice(), storedAtUtcMs: 2));
      await _meeting(database, id: 'capture-only');
      _ok(
        await selections.save(
          'capture-only',
          const MeetingProcessingSelection.recordingOnly(),
          storedAtUtcMs: 2,
        ),
      );
      await _meeting(database, id: 'legacy');
      expect(_ok(await selections.listFinalized()), isEmpty);
      await database.customStatement(
        "UPDATE meetings SET lifecycle='finalized'",
      );
      expect(_ok(await selections.listFinalized()), ['meeting']);
    },
  );

  test(
    'stored malformed profile fails closed rather than falling back to defaults',
    () async {
      _ok(await selections.save('meeting', _choice(), storedAtUtcMs: 2));
      await database.customStatement(
        "UPDATE meeting_processing_selections SET refinement_bundle_manifest_json='{\"schemaVersion\":2}'",
      );
      expect(
        await selections.load('meeting'),
        isA<Err<MeetingProcessingSelection?, AnalysisRepositoryFailure>>(),
      );
    },
  );

  test('initial write after capture startup is rejected', () async {
    await database.customStatement(
      "UPDATE meetings SET lifecycle='preparing' WHERE id='meeting'",
    );
    expect(
      await selections.save('meeting', _choice(), storedAtUtcMs: 2),
      isA<Err<MeetingProcessingSelection, AnalysisRepositoryFailure>>(),
    );
    expect(_ok(await selections.load('meeting')), isNull);
  });

  test('selection survives a genuine file close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loquiris-processing-choice-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/database.sqlite');
    await database.close();
    database = db.AppDatabase(NativeDatabase(file));
    await _meeting(database);
    final choice = _choice();
    _ok(
      await DriftMeetingProcessingSelectionRepository(
        database,
        diagnosticSink: const DisabledDiagnosticLogSink(),
      ).save('meeting', choice, storedAtUtcMs: 2),
    );
    await database.close();
    database = db.AppDatabase(NativeDatabase(file));
    expect(
      _ok(
        await DriftMeetingProcessingSelectionRepository(
          database,
          diagnosticSink: const DisabledDiagnosticLogSink(),
        ).load('meeting'),
      ),
      choice,
    );
  });
}

T _ok<T>(Result<T, AnalysisRepositoryFailure> result) {
  expect(result, isA<Ok<T, AnalysisRepositoryFailure>>());
  return (result as Ok<T, AnalysisRepositoryFailure>).value;
}

MeetingProcessingSelection _choice() => MeetingProcessingSelection.twoPass(
  live: _profile(jsonEncode(modelBundleFixture()), '1.0.0'),
  refinement: _profile(
    File('models/manifests/whisper-base-q5_1.json').readAsStringSync(),
    '1.9.4',
  ),
);

ProcessingModelProfile _profile(String snapshot, String runtime) =>
    (ProcessingModelProfile.tryCreate(
              bundleManifestJson: snapshot,
              engineVersion: runtime,
              parametersJson: '{"parameterVersion":1}',
            )
            as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
        .value;

Future<void> _meeting(db.AppDatabase database, {String id = 'meeting'}) =>
    database
        .into(database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: id,
            createdAt: 1,
            updatedAt: 1,
            title: 'meeting',
            lifecycle: 'draft',
            languageMode: 'mixed',
          ),
        )
        .then<void>((_) {});
