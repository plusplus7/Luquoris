import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';

/// Preserves exact new-meeting role profiles without changing legacy records.
final class DriftMeetingProcessingSelectionRepository
    implements MeetingProcessingSelectionRepository {
  /// Shares the app's one local transaction boundary.
  const DriftMeetingProcessingSelectionRepository(
    this.database, {
    required this.diagnosticSink,
  });

  /// Local durable meeting and optional selection storage.
  final db.AppDatabase database;

  /// Structured, content-free local diagnostic destination.
  final DiagnosticLogSink diagnosticSink;

  @override
  Future<Result<MeetingProcessingSelection, AnalysisRepositoryFailure>> save(
    String meetingId,
    MeetingProcessingSelection selection, {
    required int storedAtUtcMs,
  }) => _transaction(() async {
    final meeting = await _meeting(meetingId);
    final existing = await _selection(meetingId);
    if (existing != null && _read(existing) == selection) return selection;
    final run =
        await (database.select(database.transcriptRuns)
              ..where((row) => row.meetingId.equals(meetingId))
              ..limit(1))
            .getSingleOrNull();
    if (meeting.lifecycle != 'draft' || run != null || storedAtUtcMs < 0) {
      throw const _SelectionAbort(AnalysisConflict());
    }
    final values = _values(selection, storedAtUtcMs);
    if (existing == null) {
      await database
          .into(database.meetingProcessingSelections)
          .insert(
            values.copyWith(
              id: Value(meetingId),
              meetingId: Value(meetingId),
              createdAt: Value(storedAtUtcMs),
            ),
          );
    } else {
      await (database.update(
        database.meetingProcessingSelections,
      )..where((row) => row.id.equals(existing.id))).write(
        values.copyWith(
          rowRevision: Value(existing.rowRevision + 1),
        ),
      );
    }
    return selection;
  });

  @override
  Future<Result<MeetingProcessingSelection?, AnalysisRepositoryFailure>> load(
    String meetingId,
  ) => _transaction(() async {
    await _meeting(meetingId);
    final row = await _selection(meetingId);
    return row == null ? null : _read(row);
  });

  @override
  Future<Result<List<String>, AnalysisRepositoryFailure>> listFinalized() =>
      _transaction(() async {
        final rows = await database.customSelect('''
          SELECT m.id FROM meetings AS m
          INNER JOIN meeting_processing_selections AS s ON s.meeting_id = m.id
          WHERE m.lifecycle = 'finalized' AND m.is_deleted = 0 AND s.is_deleted = 0
            AND s.processing_mode <> 'recordingOnly'
          ORDER BY m.created_at, m.id
        ''').get();
        return List<String>.unmodifiable(
          rows.map((row) => row.read<String>('id')),
        );
      });

  Future<db.Meeting> _meeting(String id) async {
    final row = await (database.select(
      database.meetings,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null || row.isDeleted) {
      throw const _SelectionAbort(AnalysisNotFound());
    }
    return row;
  }

  Future<db.MeetingProcessingSelection?> _selection(String id) =>
      (database.select(
        database.meetingProcessingSelections,
      )..where((row) => row.meetingId.equals(id))).getSingleOrNull();

  MeetingProcessingSelection _read(db.MeetingProcessingSelection row) {
    if (row.isDeleted) throw const _SelectionAbort(AnalysisConflict());
    return switch (MeetingProcessingMode.values.byName(row.processingMode)) {
      MeetingProcessingMode.recordingOnly =>
        const MeetingProcessingSelection.recordingOnly(),
      MeetingProcessingMode.postSession =>
        MeetingProcessingSelection.postSession(
          refinement: _profile(
            row.refinementBundleManifestJson,
            row.refinementEngineVersion,
            row.refinementParametersJson,
          ),
        ),
      MeetingProcessingMode.twoPass => MeetingProcessingSelection.twoPass(
        live: _profile(
          row.liveBundleManifestJson,
          row.liveEngineVersion,
          row.liveParametersJson,
        ),
        refinement: _profile(
          row.refinementBundleManifestJson,
          row.refinementEngineVersion,
          row.refinementParametersJson,
        ),
      ),
    };
  }

  ProcessingModelProfile _profile(
    String? snapshot,
    String? runtime,
    String? parameters,
  ) {
    if (snapshot == null || runtime == null || parameters == null) {
      throw const _SelectionAbort(AnalysisConflict());
    }
    return switch (ProcessingModelProfile.tryCreate(
      bundleManifestJson: snapshot,
      engineVersion: runtime,
      parametersJson: parameters,
    )) {
      Ok(:final value) => value,
      Err() => throw const _SelectionAbort(AnalysisConflict()),
    };
  }

  db.MeetingProcessingSelectionsCompanion _values(
    MeetingProcessingSelection selection,
    int storedAtUtcMs,
  ) => db.MeetingProcessingSelectionsCompanion(
    updatedAt: Value(storedAtUtcMs),
    processingMode: Value(selection.mode.name),
    liveBundleManifestJson: Value(selection.live?.bundleManifestJson),
    liveEngineVersion: Value(selection.live?.engineVersion),
    liveParametersJson: Value(selection.live?.parametersJson),
    refinementBundleManifestJson: Value(
      selection.refinement?.bundleManifestJson,
    ),
    refinementEngineVersion: Value(selection.refinement?.engineVersion),
    refinementParametersJson: Value(selection.refinement?.parametersJson),
  );

  Future<Result<T, AnalysisRepositoryFailure>> _transaction<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await database.transaction(operation));
    } on _SelectionAbort catch (abort) {
      return Err(abort.failure);
    } on SqliteException catch (error, stackTrace) {
      diagnosticSink.record(
        DiagnosticEvent(
          code: DiagnosticCode.analysisRepositoryOperationFailed,
          errorType: error.runtimeType,
          stackFingerprint: diagnosticStackFingerprint(stackTrace),
        ),
      );
      return const Err(
        AnalysisStoreUnavailable('meeting_processing_selection_store_failed'),
      );
    }
  }
}

final class _SelectionAbort implements Exception {
  const _SelectionAbort(this.failure);
  final AnalysisRepositoryFailure failure;
}
