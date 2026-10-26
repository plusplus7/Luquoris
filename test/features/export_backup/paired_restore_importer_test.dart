import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/features/export_backup/application/drift_restore_importer.dart';

import '../../support/model_bundle_fixture.dart';

void main() {
  late AppDatabase live;
  late AppDatabase source;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  setUp(() {
    live = AppDatabase(NativeDatabase.memory());
    source = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await live.close();
  });

  test(
    'an empty paired sidecar preserves legacy restored-copy identities',
    () async {
      for (final (database, title) in [
        (source, 'Old source'),
        (live, 'Local'),
      ]) {
        await database
            .into(database.meetings)
            .insert(
              MeetingsCompanion.insert(
                id: 'legacy',
                createdAt: 1,
                updatedAt: 1,
                title: title,
                lifecycle: 'finalized',
                languageMode: 'mixed',
              ),
            );
      }
      final result =
          await DriftRestoreImporter(
            liveDatabase: live,
            restoredCopyTitle: (title) => '$title — Restored copy',
          ).import(
            source,
            sourceAudioFingerprints: const {'legacy': _audioHash},
            liveAudioFingerprint: (_) async => _audioHash,
          );
      final receipt =
          (result as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
      // Frozen using independent Python stdlib canonical JSON/SHA-256/UUID-v5,
      // with the pre-v5 sidecar-free meeting aggregate and the literal fixture.
      expect(
        receipt.meetings.single.meetingId,
        '35e09874-ff49-516f-a898-db48caababa3',
        reason:
            'a newly added empty table must not change legacy content identity',
      );
    },
  );

  test('restores both processing roles with untouched v2 inventory', () async {
    await _seed(source);
    final receipt = await _restore(live, source);
    expect(receipt.importedCount, 1);
    final rows = await live.select(live.transcriptProcessingMetadata).get();
    expect(
      rows,
      hasLength(2),
      reason: 'backup restore must not drop paired provenance',
    );
    final refined = rows.singleWhere(
      (row) => row.processingRole == 'refinement',
    );
    expect(refined.sourceRunId, 'draft');
    expect(refined.audioInventorySha256, _audioHash);
    expect(refined.bundleManifestJson, jsonEncode(modelBundleFixture()));
  });

  test(
    'catalog ID remapping never rewrites the immutable bundle snapshot',
    () async {
      await _seed(source);
      await live
          .into(live.modelManifests)
          .insert(
            ModelManifestsCompanion.insert(
              id: 'test-bundle',
              createdAt: 1,
              updatedAt: 1,
              version: 'local-other',
              source: 'local-fixture',
              sha256: 'b' * 64,
              bytes: 1,
              expectedEngineId: 'test-streaming',
              licenseId: 'MIT',
              licenseSnapshotPath: 'models/licenses/test-bundle.txt',
            ),
          );
      final first = await _restore(live, source);
      expect(first.importedCount, 1);
      final runs = await live.select(live.transcriptRuns).get();
      expect(runs, hasLength(2));
      expect(runs.map((run) => run.modelId).toSet(), hasLength(1));
      expect(runs.first.modelId, isNot('test-bundle'));
      final metadata = await live
          .select(live.transcriptProcessingMetadata)
          .get();
      expect(metadata, hasLength(2));
      for (final row in metadata) {
        expect(row.bundleManifestJson, jsonEncode(modelBundleFixture()));
      }
      final repeated = await _restore(
        live,
        source,
        fingerprints: {'paired': _audioHash},
      );
      expect(repeated.skippedCount, 1);
      expect(await live.select(live.modelManifests).get(), hasLength(2));
      expect(
        await live.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'configuration-only changes restore both role profiles as a conflicting copy',
    () async {
      await _seed(source);
      await _seed(live);
      final snapshot = jsonEncode(modelBundleFixture());
      await source
          .into(source.meetingProcessingSelections)
          .insert(
            MeetingProcessingSelectionsCompanion.insert(
              id: 'paired',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'paired',
              processingMode: 'twoPass',
              liveBundleManifestJson: Value(snapshot),
              liveEngineVersion: const Value('1.0.0'),
              liveParametersJson: const Value('{"parameterVersion":1}'),
              refinementBundleManifestJson: Value(snapshot),
              refinementEngineVersion: const Value('1.0.0'),
              refinementParametersJson: const Value('{"parameterVersion":1}'),
            ),
          );
      final fingerprints = {'paired': _audioHash};
      final first = await _restore(live, source, fingerprints: fingerprints);
      expect(
        first.importedCount,
        1,
        reason: 'a new explicit selection is not identical to legacy absence',
      );
      final copyId = first.meetings.single.meetingId;
      expect(copyId, isNot('paired'));
      final selection = await (live.select(
        live.meetingProcessingSelections,
      )..where((row) => row.meetingId.equals(copyId))).getSingle();
      expect(selection.processingMode, 'twoPass');
      expect(selection.liveBundleManifestJson, snapshot);
      expect(selection.refinementBundleManifestJson, snapshot);
      expect(selection.liveParametersJson, '{"parameterVersion":1}');
      expect(
        selection.id,
        isNot(copyId),
        reason: 'selection and meeting IDs have separate table namespaces',
      );
      fingerprints[copyId] = _audioHash;
      final repeated = await _restore(live, source, fingerprints: fingerprints);
      expect(repeated.skippedCount, 1);
      expect(
        await live.select(live.meetingProcessingSelections).get(),
        hasLength(1),
      );
      expect(
        await live.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  for (final collision in ['paired', 'draft']) {
    test(
      'conflict restore scopes sidecar identity collision with $collision',
      () async {
        await _seed(source);
        await _seed(live, title: 'Local title');
        await source.customStatement(
          "UPDATE transcript_processing_metadata SET id = ? WHERE processing_role = 'liveDraft'",
          [collision],
        );
        final receipt = await _restore(
          live,
          source,
          fingerprints: {'paired': _audioHash},
        );
        final copyId = receipt.meetings.single.meetingId;
        final meeting = await (live.select(
          live.meetings,
        )..where((row) => row.id.equals(copyId))).getSingleOrNull();
        expect(
          meeting,
          isNotNull,
          reason:
              'receipt and file transfer must name the actual inserted meeting',
        );
        final metadata = await (live.select(
          live.transcriptProcessingMetadata,
        )..where((row) => row.meetingId.equals(copyId))).get();
        expect(metadata, hasLength(2));
        final draft = metadata.singleWhere(
          (row) => row.processingRole == 'liveDraft',
        );
        expect(
          draft.id,
          isNot(draft.transcriptRunId),
          reason:
              'equal source strings in different tables need independent identities',
        );
        final refined = metadata.singleWhere(
          (row) => row.processingRole == 'refinement',
        );
        expect(refined.sourceRunId, draft.transcriptRunId);
        expect(
          await live.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'metadata-only change makes a conflicting copy, not an identical skip',
    () async {
      await _seed(source);
      await _seed(live);
      await source.customStatement(
        "UPDATE transcript_processing_metadata SET completeness = 'complete' WHERE processing_role = 'liveDraft'",
      );
      final receipt = await _restore(
        live,
        source,
        fingerprints: {'paired': _audioHash},
      );
      expect(
        receipt.importedCount,
        1,
        reason: 'coverage changes belong to a distinct restored aggregate',
      );
      expect(receipt.meetings.single.wasConflictingCopy, isTrue);
      final old = await (live.select(
        live.transcriptProcessingMetadata,
      )..where((row) => row.id.equals('draft-metadata'))).getSingle();
      expect(
        old.completeness,
        'incomplete',
        reason: 'restore must never overwrite local coverage',
      );
      expect(
        await live.select(live.transcriptProcessingMetadata).get(),
        hasLength(4),
      );
    },
  );

  test(
    'conflict remaps draft links, keeps corrections/selection, and repeats idempotently',
    () async {
      await _seed(source);
      await _seed(live, title: 'Local title');
      final fingerprints = {'paired': _audioHash};
      final receipt = await _restore(live, source, fingerprints: fingerprints);
      final copyId = receipt.meetings.single.meetingId;
      expect(copyId, isNot('paired'));
      final metadata = await (live.select(
        live.transcriptProcessingMetadata,
      )..where((row) => row.meetingId.equals(copyId))).get();
      expect(metadata, hasLength(2));
      final draft = metadata.singleWhere(
        (row) => row.processingRole == 'liveDraft',
      );
      final refined = metadata.singleWhere(
        (row) => row.processingRole == 'refinement',
      );
      expect(draft.transcriptRunId, isNot('draft'));
      expect(refined.transcriptRunId, isNot('refined'));
      expect(
        refined.sourceRunId,
        draft.transcriptRunId,
        reason:
            'source link must point inside the restored meeting, not the original',
      );
      expect(refined.bundleManifestJson, jsonEncode(modelBundleFixture()));
      final selection = await (live.select(
        live.meetingTranscriptSelections,
      )..where((row) => row.meetingId.equals(copyId))).getSingle();
      expect(
        selection.transcriptRunId,
        draft.transcriptRunId,
        reason: 'refinement must not become current during restore',
      );
      final revision = await (live.select(
        live.revisions,
      )..where((row) => row.meetingId.equals(copyId))).getSingle();
      final corrected =
          await (live.select(live.transcriptSegments)
                ..where((row) => row.id.equals(revision.transcriptSegmentId!)))
              .getSingle();
      expect(corrected.transcriptRunId, draft.transcriptRunId);
      expect(corrected.rawModelText, _raw);
      expect(corrected.displayedText, _corrected);
      expect(
        revision.payloadJson,
        jsonEncode({'previousText': _raw, 'revisedText': _corrected}),
      );
      final bookmark = await (live.select(
        live.bookmarks,
      )..where((row) => row.meetingId.equals(copyId))).getSingle();
      expect(bookmark.mediaOffsetUs, 500000);
      fingerprints[copyId] = _audioHash;
      final repeated = await _restore(live, source, fingerprints: fingerprints);
      expect(
        repeated.skippedCount,
        1,
        reason:
            'draft run: ${draft.transcriptRunId}; refined run: ${refined.transcriptRunId}; metadata ids: ${metadata.map((row) => row.id).toList()}',
      );
      expect(repeated.meetings.single.meetingId, copyId);
      expect(
        await live.select(live.transcriptProcessingMetadata).get(),
        hasLength(4),
      );
      expect(
        await live.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}

const _audioHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _raw = '刘国梁 — O\'Brien 🎙️ "raw"\n  ';
const _corrected = '刘国良 — O\'Brien 🎙️ "corrected"\n  ';

Future<RestoreImportReceipt> _restore(
  AppDatabase live,
  AppDatabase source, {
  Map<String, String> fingerprints = const {},
}) async {
  final result =
      await DriftRestoreImporter(
        liveDatabase: live,
        restoredCopyTitle: (title) => '$title — Restored copy',
      ).import(
        source,
        sourceAudioFingerprints: const {'paired': _audioHash},
        liveAudioFingerprint: (id) async => fingerprints[id],
      );
  expect(result, isA<Ok<RestoreImportReceipt, RestoreImportFailure>>());
  return (result as Ok<RestoreImportReceipt, RestoreImportFailure>).value;
}

Future<void> _seed(AppDatabase database, {String title = '中英 paired'}) async {
  final bundle = modelBundleFixture();
  await database
      .into(database.meetings)
      .insert(
        MeetingsCompanion.insert(
          id: 'paired',
          createdAt: 1,
          updatedAt: 1,
          title: title,
          mediaDurationUs: const Value(2000000),
          lifecycle: 'finalized',
          languageMode: 'mixed',
        ),
      );
  await database
      .into(database.modelManifests)
      .insert(
        ModelManifestsCompanion.insert(
          id: 'test-bundle',
          createdAt: 1,
          updatedAt: 1,
          version: bundle['version']! as String,
          source: bundle['source']! as String,
          sha256: bundle['sha256']! as String,
          bytes: bundle['bytes']! as int,
          expectedEngineId: 'test-streaming',
          licenseId: 'MIT',
          licenseSnapshotPath: 'models/licenses/test-bundle.txt',
        ),
      );
  for (final run in ['draft', 'refined']) {
    await database
        .into(database.transcriptRuns)
        .insert(
          TranscriptRunsCompanion.insert(
            id: run,
            createdAt: 1,
            updatedAt: 1,
            meetingId: 'paired',
            engineId: 'test-streaming',
            engineVersion: '1.0.0',
            modelId: 'test-bundle',
            modelVersion: bundle['version']! as String,
            modelSha256: bundle['sha256']! as String,
            parametersJson: '{}',
            runState: 'completed',
            startedAtUtcMs: const Value(1),
            endedAtUtcMs: const Value(2),
            progress: const Value(1),
          ),
        );
    await database
        .into(database.transcriptProcessingMetadata)
        .insert(
          TranscriptProcessingMetadataCompanion.insert(
            id: '$run-metadata',
            createdAt: 1,
            updatedAt: 1,
            transcriptRunId: run,
            meetingId: 'paired',
            processingRole: run == 'draft' ? 'liveDraft' : 'refinement',
            sourceRunId: Value(run == 'refined' ? 'draft' : null),
            completeness: run == 'draft' ? 'incomplete' : 'complete',
            bundleManifestJson: jsonEncode(bundle),
            audioInventorySha256: Value(run == 'refined' ? _audioHash : null),
          ),
        );
  }
  await database
      .into(database.transcriptSegments)
      .insert(
        TranscriptSegmentsCompanion.insert(
          id: 'draft-segment',
          createdAt: 1,
          updatedAt: 1,
          meetingId: 'paired',
          transcriptRunId: 'draft',
          startUs: 0,
          endUs: 2000000,
          rawModelText: _raw,
          displayedText: _corrected,
          revisionState: 'corrected',
        ),
      );
  await database
      .into(database.revisions)
      .insert(
        RevisionsCompanion.insert(
          id: 'revision',
          createdAt: 2,
          updatedAt: 2,
          meetingId: 'paired',
          transcriptSegmentId: const Value('draft-segment'),
          revisionKind: 'transcriptText',
          payloadJson: jsonEncode({
            'previousText': _raw,
            'revisedText': _corrected,
          }),
        ),
      );
  await database
      .into(database.bookmarks)
      .insert(
        BookmarksCompanion.insert(
          id: 'bookmark',
          createdAt: 1,
          updatedAt: 1,
          meetingId: 'paired',
          mediaOffsetUs: 500000,
          kind: 'highlight',
        ),
      );
  await database
      .into(database.meetingTranscriptSelections)
      .insert(
        MeetingTranscriptSelectionsCompanion.insert(
          id: 'selection',
          createdAt: 1,
          updatedAt: 1,
          meetingId: 'paired',
          transcriptRunId: 'draft',
        ),
      );
}
