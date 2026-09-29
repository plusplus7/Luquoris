import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';

/// Drift-backed parallel transcript-version repository.
final class DriftTranscriptRepository implements TranscriptRepository {
  /// Creates a transcript repository over the shared local database.
  const DriftTranscriptRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  }) async {
    if (segments.any((segment) => segment.transcriptRunId != run.id)) {
      return const Err(AnalysisConflict());
    }
    try {
      await database.transaction(() async {
        final existing = await (database.select(
          database.transcriptRuns,
        )..where((row) => row.id.equals(run.id))).getSingleOrNull();
        if (existing != null) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        final state = _storedAnalysisState(run.state);
        await database
            .into(database.transcriptRuns)
            .insert(
              db.TranscriptRunsCompanion.insert(
                id: run.id,
                createdAt: run.createdAtUtcMs,
                updatedAt: storedAtUtcMs,
                meetingId: run.meetingId,
                engineId: run.provenance.engineId,
                engineVersion: run.provenance.engineVersion,
                modelId: run.provenance.modelId,
                modelVersion: run.provenance.modelVersion,
                modelSha256: run.provenance.modelSha256,
                parametersJson: run.provenance.parametersJson,
                runState: state.name,
                startedAtUtcMs: Value(state.startedAtUtcMs),
                endedAtUtcMs: Value(state.endedAtUtcMs),
                progress: Value(state.progress),
                failureCode: Value(state.failureCode),
              ),
            );
        for (final segment in segments) {
          await database
              .into(database.transcriptSegments)
              .insert(
                db.TranscriptSegmentsCompanion.insert(
                  id: segment.id,
                  createdAt: storedAtUtcMs,
                  updatedAt: storedAtUtcMs,
                  meetingId: run.meetingId,
                  transcriptRunId: run.id,
                  startUs: segment.start.inMicroseconds,
                  endUs: segment.end.inMicroseconds,
                  rawModelText: segment.rawModelText,
                  displayedText: segment.displayedText,
                  revisionState: segment.revisionState.name,
                  speakerId: Value(segment.speakerId),
                  speakerMeetingId: Value(
                    segment.speakerId == null ? null : run.meetingId,
                  ),
                ),
              );
        }
      });
      return Ok(
        TranscriptVersion(run: run, segments: segments, isCurrent: false),
      );
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_version_save_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async {
    try {
      final runRows =
          await (database.select(database.transcriptRuns)
                ..where(
                  (row) =>
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                )
                ..orderBy([
                  (row) => OrderingTerm.desc(row.createdAt),
                  (row) => OrderingTerm.desc(row.id),
                ]))
              .get();
      final selection =
          await (database.select(
                database.meetingTranscriptSelections,
              )..where(
                (row) =>
                    row.meetingId.equals(meetingId) &
                    row.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      final versions = <TranscriptVersion>[];
      for (final runRow in runRows) {
        final segmentRows = await database
            .customSelect(
              '''
              SELECT ts.*, tls.language_decision_id
              FROM transcript_segments AS ts
              LEFT JOIN transcript_language_selections AS tls
                ON tls.transcript_segment_id = ts.id AND tls.is_deleted = 0
              WHERE ts.transcript_run_id = ? AND ts.is_deleted = 0
              ORDER BY ts.start_us, ts.id
              ''',
              variables: <Variable<Object>>[Variable<String>(runRow.id)],
            )
            .get();
        versions.add(
          TranscriptVersion(
            run: _readTranscriptRun(runRow),
            segments: segmentRows.map(_readTranscriptSegment).toList(),
            isCurrent: selection?.transcriptRunId == runRow.id,
          ),
        );
      }
      return Ok(List<TranscriptVersion>.unmodifiable(versions));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_version_list_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  }) async {
    try {
      await database.transaction(() async {
        final run =
            await (database.select(database.transcriptRuns)..where(
                  (row) =>
                      row.id.equals(runId) &
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (run == null) {
          throw const _AnalysisStateError('analysis_not_found');
        }
        final existing = await (database.select(
          database.meetingTranscriptSelections,
        )..where((row) => row.meetingId.equals(meetingId))).getSingleOrNull();
        if (existing == null) {
          await database
              .into(database.meetingTranscriptSelections)
              .insert(
                db.MeetingTranscriptSelectionsCompanion.insert(
                  id: '$meetingId:current-transcript',
                  createdAt: selectedAtUtcMs,
                  updatedAt: selectedAtUtcMs,
                  meetingId: meetingId,
                  transcriptRunId: runId,
                ),
              );
        } else {
          await (database.update(
            database.meetingTranscriptSelections,
          )..where((row) => row.id.equals(existing.id))).write(
            db.MeetingTranscriptSelectionsCompanion(
              updatedAt: Value(selectedAtUtcMs),
              rowRevision: Value(existing.rowRevision + 1),
              isDeleted: const Value(false),
              deletedAt: const Value(null),
              transcriptRunId: Value(runId),
            ),
          );
        }
      });
      return const Ok<void, AnalysisRepositoryFailure>(null);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'transcript_selection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }
}

/// Drift-backed immutable revision history and corrected-view repository.
final class DriftRevisionRepository implements RevisionRepository {
  /// Creates a revision repository over the shared local database.
  const DriftRevisionRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<Revision, AnalysisRepositoryFailure>> apply(
    Revision revision,
  ) async {
    try {
      await database.transaction(() async {
        final duplicate = await (database.select(
          database.revisions,
        )..where((row) => row.id.equals(revision.id))).getSingleOrNull();
        if (duplicate != null) {
          throw const _AnalysisStateError('analysis_conflict');
        }
        await _ensureRevisionOrder(revision);
        switch (revision.change) {
          case final TranscriptTextChange change:
            await _applyText(revision, change);
          case final LanguageLabelChange change:
            await _applyLanguage(revision, change);
          case final SpeakerAssignmentChange change:
            await _applySpeakerAssignment(revision, change);
          case final SpeakerLabelChange change:
            await _applySpeakerLabel(revision, change);
        }
        await _insertRevision(revision);
      });
      return Ok(revision);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_apply_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<Revision>, AnalysisRepositoryFailure>> listMeeting(
    String meetingId,
  ) async {
    try {
      final rows =
          await (database.select(database.revisions)
                ..where(
                  (row) =>
                      row.meetingId.equals(meetingId) &
                      row.isDeleted.equals(false),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      return Ok(
        List<Revision>.unmodifiable(rows.map(_readRevision)),
      );
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_list_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<SpeakerAssignment, AnalysisRepositoryFailure>>
  materializeSpeakerAssignment(SpeakerAssignment rawAssignment) async {
    try {
      return Ok(await _materializedAssignment(rawAssignment));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_assignment_projection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Speaker, AnalysisRepositoryFailure>> materializeSpeaker(
    Speaker rawSpeaker,
  ) async {
    try {
      return Ok(await _materializedSpeaker(rawSpeaker));
    } on SqliteException catch (error, stackTrace) {
      return Err(
        _storeFailure(
          diagnosticSink,
          'revision_speaker_projection_failed',
          error,
          stackTrace,
        ),
      );
    }
  }

  Future<void> _applyText(
    Revision revision,
    TranscriptTextChange change,
  ) async {
    final segment = await _ownedSegment(revision);
    if (segment.displayedText != change.previousText) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    await (database.update(
      database.transcriptSegments,
    )..where((row) => row.id.equals(segment.id))).write(
      db.TranscriptSegmentsCompanion(
        updatedAt: Value(revision.createdAtUtcMs),
        rowRevision: Value(segment.rowRevision + 1),
        displayedText: Value(change.revisedText),
        revisionState: Value(TranscriptRevisionState.corrected.name),
      ),
    );
  }

  Future<void> _ensureRevisionOrder(Revision revision) async {
    if (revision.change is TranscriptTextChange ||
        revision.change is LanguageLabelChange) {
      return;
    }
    final query = database.select(database.revisions)
      ..where(
        switch (revision.change) {
          SpeakerAssignmentChange() =>
            (row) =>
                row.speakerAssignmentId.equals(revision.targetId) &
                row.isDeleted.equals(false),
          SpeakerLabelChange() =>
            (row) =>
                row.speakerId.equals(revision.targetId) &
                row.isDeleted.equals(false),
          TranscriptTextChange() || LanguageLabelChange() => throw StateError(
            'unreachable transcript revision ordering',
          ),
        },
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ])
      ..limit(1);
    final latest = await query.getSingleOrNull();
    if (latest != null &&
        (revision.createdAtUtcMs < latest.createdAt ||
            (revision.createdAtUtcMs == latest.createdAt &&
                revision.id.compareTo(latest.id) <= 0))) {
      throw const _AnalysisStateError('analysis_conflict');
    }
  }

  Future<void> _applyLanguage(
    Revision revision,
    LanguageLabelChange change,
  ) async {
    final segment = await _ownedSegment(revision);
    final selection =
        await (database.select(
              database.transcriptLanguageSelections,
            )..where(
              (row) =>
                  row.transcriptSegmentId.equals(segment.id) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (selection == null) {
      throw const _AnalysisStateError('analysis_invalid_revision');
    }
    final current =
        await (database.select(database.languageDecisions)..where(
              (row) =>
                  row.id.equals(selection.languageDecisionId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (current == null || current.tag != change.previous.name) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    final decisionId = '${revision.id}:language';
    await database
        .into(database.languageDecisions)
        .insert(
          db.LanguageDecisionsCompanion.insert(
            id: decisionId,
            createdAt: revision.createdAtUtcMs,
            updatedAt: revision.createdAtUtcMs,
            transcriptSegmentId: segment.id,
            tag: change.revised.name,
            source: LanguageDecisionSource.manual.name,
            confidence: const Value(null),
          ),
        );
    await (database.update(
      database.transcriptLanguageSelections,
    )..where((row) => row.id.equals(selection.id))).write(
      db.TranscriptLanguageSelectionsCompanion(
        updatedAt: Value(revision.createdAtUtcMs),
        rowRevision: Value(selection.rowRevision + 1),
        languageDecisionId: Value(decisionId),
      ),
    );
  }

  Future<void> _applySpeakerAssignment(
    Revision revision,
    SpeakerAssignmentChange change,
  ) async {
    final row =
        await (database.select(database.speakerAssignments)..where(
              (candidate) =>
                  candidate.id.equals(revision.targetId) &
                  candidate.meetingId.equals(revision.meetingId) &
                  candidate.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final raw = _readSpeakerAssignment(row);
    final current = await _materializedAssignment(raw);
    if (current.speakerId != change.previousSpeakerId ||
        raw.start != change.start ||
        raw.end != change.end) {
      throw const _AnalysisStateError('analysis_conflict');
    }
    if (change.revisedSpeakerId case final speakerId?) {
      final speaker =
          await (database.select(database.speakers)..where(
                (candidate) =>
                    candidate.id.equals(speakerId) &
                    candidate.analysisRunId.equals(row.analysisRunId) &
                    candidate.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (speaker == null) {
        throw const _AnalysisStateError('analysis_invalid_revision');
      }
    }
  }

  Future<void> _applySpeakerLabel(
    Revision revision,
    SpeakerLabelChange change,
  ) async {
    final row =
        await (database.select(database.speakers)..where(
              (candidate) =>
                  candidate.id.equals(revision.targetId) &
                  candidate.meetingId.equals(revision.meetingId) &
                  candidate.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    final speaker = await _materializedSpeaker(_readSpeaker(row));
    if (speaker.label != change.previous) {
      throw const _AnalysisStateError('analysis_conflict');
    }
  }

  Future<db.TranscriptSegment> _ownedSegment(Revision revision) async {
    final segment =
        await (database.select(database.transcriptSegments)..where(
              (row) =>
                  row.id.equals(revision.targetId) &
                  row.meetingId.equals(revision.meetingId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (segment == null) {
      throw const _AnalysisStateError('analysis_not_found');
    }
    return segment;
  }

  Future<void> _insertRevision(Revision revision) async {
    final encoded = _encodedRevision(revision.change);
    await database
        .into(database.revisions)
        .insert(
          db.RevisionsCompanion.insert(
            id: revision.id,
            createdAt: revision.createdAtUtcMs,
            updatedAt: revision.createdAtUtcMs,
            meetingId: revision.meetingId,
            transcriptSegmentId: Value(
              encoded.kind == 'transcriptText' ||
                      encoded.kind == 'languageLabel'
                  ? revision.targetId
                  : null,
            ),
            speakerAssignmentId: Value(
              encoded.kind == 'speakerAssignment' ? revision.targetId : null,
            ),
            speakerId: Value(
              encoded.kind == 'speakerLabel' ? revision.targetId : null,
            ),
            revisionKind: encoded.kind,
            payloadJson: encoded.payload,
          ),
        );
  }

  Future<SpeakerAssignment> _materializedAssignment(
    SpeakerAssignment raw,
  ) async {
    var projected = raw;
    final rows =
        await (database.select(database.revisions)
              ..where(
                (row) =>
                    row.speakerAssignmentId.equals(raw.id) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    for (final row in rows) {
      final revision = _readRevision(row);
      if (revision.change case final SpeakerAssignmentChange change) {
        projected = projected.copyWith(
          speakerId: change.revisedSpeakerId,
          needsConfirmation: change.needsConfirmation,
        );
      }
    }
    return projected;
  }

  Future<List<db.Revision>> _revisionRowsForSpeaker(String speakerId) =>
      (database.select(database.revisions)
            ..where(
              (row) =>
                  row.speakerId.equals(speakerId) & row.isDeleted.equals(false),
            )
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();

  Future<Speaker> _materializedSpeaker(Speaker raw) async {
    var projected = raw;
    final rows = await _revisionRowsForSpeaker(raw.id);
    for (final row in rows) {
      final revision = _readRevision(row);
      if (revision.change case final SpeakerLabelChange change) {
        projected = projected.copyWith(label: change.revised);
      }
    }
    return projected;
  }
}

/// Drift-backed immutable bundled-model manifest repository.
final class DriftModelRepository implements ModelRepository {
  /// Creates a model repository over the shared local database.
  const DriftModelRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Shared local database.
  final db.AppDatabase database;

  /// Privacy-safe local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<InstalledModel, AnalysisRepositoryFailure>> registerBundled(
    InstalledModel model, {
    required int observedAtUtcMs,
  }) async {
    try {
      late InstalledModel stored;
      await database.transaction(() async {
        final existing = await _findModel(model.id);
        if (existing != null) {
          if (!_sameModelManifest(existing, model)) {
            throw const _AnalysisStateError('analysis_conflict');
          }
          stored = existing;
          return;
        }
        await database
            .into(database.modelManifests)
            .insert(
              db.ModelManifestsCompanion.insert(
                id: model.id,
                createdAt: observedAtUtcMs,
                updatedAt: observedAtUtcMs,
                version: model.version,
                source: model.source,
                sha256: model.sha256,
                bytes: model.bytes,
                expectedEngineId: model.expectedEngineId,
                licenseId: model.licenseId,
                licenseSnapshotPath: model.licenseSnapshotPath.value,
              ),
            );
        for (final capability in model.capabilities) {
          await database
              .into(database.modelCapabilityEntries)
              .insert(
                db.ModelCapabilityEntriesCompanion.insert(
                  id: '${model.id}:capability:${capability.name}',
                  createdAt: observedAtUtcMs,
                  updatedAt: observedAtUtcMs,
                  modelId: model.id,
                  capability: capability.name,
                ),
              );
        }
        for (final mode in model.enabledModes) {
          await database
              .into(database.modelModeEntries)
              .insert(
                db.ModelModeEntriesCompanion.insert(
                  id: '${model.id}:mode:${mode.name}',
                  createdAt: observedAtUtcMs,
                  updatedAt: observedAtUtcMs,
                  modelId: model.id,
                  mode: mode.name,
                ),
              );
        }
        stored = model;
      });
      return Ok(stored);
    } on _AnalysisStateError catch (error) {
      return Err(_stateFailure(error));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('model_register_failed', error, stackTrace));
    }
  }

  @override
  Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
  listInstalled() async {
    try {
      final rows = await (database.select(
        database.modelManifests,
      )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
      final models = <InstalledModel>[];
      for (final row in rows) {
        models.add((await _findModel(row.id))!);
      }
      return Ok(List<InstalledModel>.unmodifiable(models));
    } on SqliteException catch (error, stackTrace) {
      return Err(_storeFailure('model_list_failed', error, stackTrace));
    }
  }

  Future<InstalledModel?> _findModel(String modelId) async {
    final row = await (database.select(
      database.modelManifests,
    )..where((candidate) => candidate.id.equals(modelId))).getSingleOrNull();
    if (row == null) return null;
    final capabilityRows = await (database.select(
      database.modelCapabilityEntries,
    )..where((entry) => entry.modelId.equals(modelId))).get();
    final modeRows = await (database.select(
      database.modelModeEntries,
    )..where((entry) => entry.modelId.equals(modelId))).get();
    final licensePath = switch (AppRelativePath.tryParse(
      row.licenseSnapshotPath,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('database path invariant violated'),
    };
    final capabilities =
        capabilityRows
            .map((entry) => ModelCapability.values.byName(entry.capability))
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));
    final modes =
        modeRows
            .map((entry) => PerformanceMode.values.byName(entry.mode))
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));
    return InstalledModel(
      id: row.id,
      version: row.version,
      source: row.source,
      sha256: row.sha256,
      bytes: row.bytes,
      capabilities: capabilities,
      expectedEngineId: row.expectedEngineId,
      licenseId: row.licenseId,
      licenseSnapshotPath: licensePath,
      enabledModes: modes,
    );
  }

  AnalysisStoreUnavailable _storeFailure(
    String code,
    Object error,
    StackTrace stackTrace,
  ) {
    diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.analysisRepositoryOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
    return AnalysisStoreUnavailable(code);
  }
}

final class _AnalysisStateError implements Exception {
  const _AnalysisStateError(this.code);

  final String code;
}

AnalysisRepositoryFailure _stateFailure(_AnalysisStateError error) =>
    switch (error.code) {
      'analysis_not_found' => const AnalysisNotFound(),
      'analysis_conflict' => const AnalysisConflict(),
      'analysis_invalid_revision' => const AnalysisInvalidRevision(),
      _ => throw StateError('unknown analysis repository state failure'),
    };

({
  String name,
  int? startedAtUtcMs,
  int? endedAtUtcMs,
  double progress,
  String? failureCode,
})
_storedAnalysisState(AnalysisState state) => switch (state) {
  AnalysisQueued() => (
    name: 'queued',
    startedAtUtcMs: null,
    endedAtUtcMs: null,
    progress: 0,
    failureCode: null,
  ),
  AnalysisRunning(:final startedAtUtcMs, :final progress) => (
    name: 'running',
    startedAtUtcMs: startedAtUtcMs,
    endedAtUtcMs: null,
    progress: progress,
    failureCode: null,
  ),
  AnalysisCompleted(:final startedAtUtcMs, :final endedAtUtcMs) => (
    name: 'completed',
    startedAtUtcMs: startedAtUtcMs,
    endedAtUtcMs: endedAtUtcMs,
    progress: 1,
    failureCode: null,
  ),
  AnalysisFailed(
    :final startedAtUtcMs,
    :final endedAtUtcMs,
    :final progress,
    :final failureCode,
  ) =>
    (
      name: 'failed',
      startedAtUtcMs: startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs,
      progress: progress,
      failureCode: failureCode,
    ),
};

TranscriptRun _readTranscriptRun(db.TranscriptRun row) => TranscriptRun(
  id: row.id,
  meetingId: row.meetingId,
  provenance: InferenceProvenance(
    engineId: row.engineId,
    engineVersion: row.engineVersion,
    modelId: row.modelId,
    modelVersion: row.modelVersion,
    modelSha256: row.modelSha256,
    parametersJson: row.parametersJson,
  ),
  createdAtUtcMs: row.createdAt,
  state: switch (row.runState) {
    'queued' => const AnalysisQueued(),
    'running' => AnalysisRunning(
      startedAtUtcMs: row.startedAtUtcMs!,
      progress: row.progress,
    ),
    'completed' => AnalysisCompleted(
      startedAtUtcMs: row.startedAtUtcMs!,
      endedAtUtcMs: row.endedAtUtcMs!,
    ),
    'failed' => AnalysisFailed(
      startedAtUtcMs: row.startedAtUtcMs!,
      endedAtUtcMs: row.endedAtUtcMs!,
      progress: row.progress,
      failureCode: row.failureCode!,
    ),
    _ => throw StateError('database analysis state invariant violated'),
  },
);

TranscriptSegment _readTranscriptSegment(QueryRow row) => TranscriptSegment(
  id: row.read<String>('id'),
  transcriptRunId: row.read<String>('transcript_run_id'),
  start: Duration(microseconds: row.read<int>('start_us')),
  end: Duration(microseconds: row.read<int>('end_us')),
  rawModelText: row.read<String>('raw_model_text'),
  displayedText: row.read<String>('displayed_text'),
  revisionState: TranscriptRevisionState.values.byName(
    row.read<String>('revision_state'),
  ),
  languageDecisionId: row.readNullable<String>('language_decision_id'),
  speakerId: row.readNullable<String>('speaker_id'),
);

({String kind, String payload}) _encodedRevision(RevisionChange change) =>
    switch (change) {
      TranscriptTextChange(:final previousText, :final revisedText) => (
        kind: 'transcriptText',
        payload: jsonEncode(<String, Object>{
          'previousText': previousText,
          'revisedText': revisedText,
        }),
      ),
      LanguageLabelChange(:final previous, :final revised) => (
        kind: 'languageLabel',
        payload: jsonEncode(<String, Object>{
          'previous': previous.name,
          'revised': revised.name,
        }),
      ),
      SpeakerAssignmentChange(
        :final start,
        :final end,
        :final previousSpeakerId,
        :final revisedSpeakerId,
        :final needsConfirmation,
      ) =>
        (
          kind: 'speakerAssignment',
          payload: jsonEncode(<String, Object?>{
            'startUs': start.inMicroseconds,
            'endUs': end.inMicroseconds,
            'previousSpeakerId': previousSpeakerId,
            'revisedSpeakerId': revisedSpeakerId,
            'needsConfirmation': needsConfirmation,
          }),
        ),
      SpeakerLabelChange(:final previous, :final revised) => (
        kind: 'speakerLabel',
        payload: jsonEncode(<String, Object>{
          'previous': previous,
          'revised': revised,
        }),
      ),
    };

Revision _readRevision(db.Revision row) {
  final payload = jsonDecode(row.payloadJson) as Map<String, Object?>;
  final targetId = switch (row.revisionKind) {
    'transcriptText' || 'languageLabel' => row.transcriptSegmentId!,
    'speakerAssignment' => row.speakerAssignmentId!,
    'speakerLabel' => row.speakerId!,
    _ => throw StateError('database revision kind invariant violated'),
  };
  final change = switch (row.revisionKind) {
    'transcriptText' => TranscriptTextChange(
      previousText: payload['previousText']! as String,
      revisedText: payload['revisedText']! as String,
    ),
    'languageLabel' => LanguageLabelChange(
      previous: LanguageTag.values.byName(payload['previous']! as String),
      revised: LanguageTag.values.byName(payload['revised']! as String),
    ),
    'speakerAssignment' => SpeakerAssignmentChange(
      start: Duration(microseconds: payload['startUs']! as int),
      end: Duration(microseconds: payload['endUs']! as int),
      previousSpeakerId: payload['previousSpeakerId'] as String?,
      revisedSpeakerId: payload['revisedSpeakerId'] as String?,
      needsConfirmation: payload['needsConfirmation']! as bool,
    ),
    'speakerLabel' => SpeakerLabelChange(
      previous: payload['previous']! as String,
      revised: payload['revised']! as String,
    ),
    _ => throw StateError('database revision kind invariant violated'),
  };
  return Revision(
    id: row.id,
    meetingId: row.meetingId,
    targetId: targetId,
    change: change,
    createdAtUtcMs: row.createdAt,
  );
}

Speaker _readSpeaker(db.Speaker row) => Speaker(
  id: row.id,
  meetingId: row.meetingId,
  analysisRunId: row.analysisRunId,
  label: row.label,
);

SpeakerAssignment _readSpeakerAssignment(db.SpeakerAssignment row) =>
    SpeakerAssignment(
      id: row.id,
      analysisRunId: row.analysisRunId,
      speakerId: row.speakerId,
      start: Duration(microseconds: row.startUs),
      end: Duration(microseconds: row.endUs),
      confidence: row.confidence,
      isOverlap: row.isOverlap,
      needsConfirmation: row.needsConfirmation,
    );

bool _sameModelManifest(InstalledModel left, InstalledModel right) =>
    left.id == right.id &&
    left.version == right.version &&
    left.source == right.source &&
    left.sha256 == right.sha256 &&
    left.bytes == right.bytes &&
    left.expectedEngineId == right.expectedEngineId &&
    left.licenseId == right.licenseId &&
    left.licenseSnapshotPath == right.licenseSnapshotPath &&
    left.capabilities.length == right.capabilities.length &&
    left.capabilities.every(right.capabilities.contains) &&
    left.enabledModes.length == right.enabledModes.length &&
    left.enabledModes.every(right.enabledModes.contains);

AnalysisStoreUnavailable _storeFailure(
  DiagnosticLogSink diagnosticSink,
  String code,
  Object error,
  StackTrace stackTrace,
) {
  diagnosticSink.record(
    DiagnosticEvent(
      code: DiagnosticCode.analysisRepositoryOperationFailed,
      errorType: error.runtimeType,
      stackFingerprint: diagnosticStackFingerprint(stackTrace),
    ),
  );
  return AnalysisStoreUnavailable(code);
}
