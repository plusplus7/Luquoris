import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';

final _hash = RegExp(r'^[0-9a-f]{64}$');

/// Validates all bundle files and the exact owning runtime/model tuple.
bool matchesProcessingProvenance(
  InferenceProvenance provenance,
  TranscriptProcessingInfo info, {
  bool matchModelId = true,
}) {
  final hash = info.audioInventorySha256;
  if ((hash != null && !_hash.hasMatch(hash)) ||
      (info.role == TranscriptProcessingRole.refinement && hash == null) ||
      (info.role == TranscriptProcessingRole.liveDraft &&
          info.sourceRunId != null)) {
    return false;
  }
  try {
    final parsed = BundledModelManifest.tryParse(
      jsonDecode(info.bundleManifestJson),
    );
    return switch (parsed) {
      Ok(:final value) =>
        (!matchModelId || value.id == provenance.modelId) &&
            value.engineId == provenance.engineId &&
            (value.engineVersion == null ||
                value.engineVersion == provenance.engineVersion) &&
            value.version == provenance.modelVersion &&
            value.sha256 == provenance.modelSha256 &&
            value.capabilities.contains(ModelCapability.transcription),
      Err() => false,
    };
  } on FormatException {
    return false;
  }
}

/// Verifies new writes against a live catalog row, allowing verified restore IDs.
Future<bool> validProcessingModelBinding(
  db.AppDatabase database,
  InferenceProvenance provenance,
  TranscriptProcessingInfo info,
) async {
  if (!matchesProcessingProvenance(provenance, info, matchModelId: false)) {
    return false;
  }
  final parsed = BundledModelManifest.tryParse(
    jsonDecode(info.bundleManifestJson),
  );
  if (parsed is! Ok<BundledModelManifest, InvalidModelManifest>) return false;
  final manifest = parsed.value;
  final row = await (database.select(
    database.modelManifests,
  )..where((row) => row.id.equals(provenance.modelId))).getSingleOrNull();
  if (row == null ||
      row.isDeleted ||
      row.version != manifest.version ||
      row.source != manifest.source ||
      row.sha256 != manifest.sha256 ||
      row.bytes != manifest.bytes ||
      row.expectedEngineId != manifest.engineId ||
      row.licenseId != manifest.licenseId ||
      row.licenseSnapshotPath != manifest.licenseSnapshotPath.value) {
    return false;
  }
  final capabilities =
      await (database.select(database.modelCapabilityEntries)..where(
            (entry) =>
                entry.modelId.equals(row.id) & entry.isDeleted.equals(false),
          ))
          .get();
  final modes =
      await (database.select(database.modelModeEntries)..where(
            (entry) =>
                entry.modelId.equals(row.id) & entry.isDeleted.equals(false),
          ))
          .get();
  final expectedCapabilities = manifest.capabilities
      .map((value) => value.name)
      .toSet();
  final expectedModes = manifest.enabledModes
      .map((value) => value.name)
      .toSet();
  return capabilities.length == expectedCapabilities.length &&
      capabilities.every(
        (entry) => expectedCapabilities.contains(entry.capability),
      ) &&
      modes.length == expectedModes.length &&
      modes.every((entry) => expectedModes.contains(entry.mode));
}

/// Maps schema-checked enums without exposing Drift rows outside the data layer.
TranscriptProcessingInfo processingInfoFromRow(
  db.TranscriptProcessingMetadataData row,
) => TranscriptProcessingInfo(
  role: TranscriptProcessingRole.values.byName(row.processingRole),
  completeness: TranscriptCompleteness.values.byName(row.completeness),
  bundleManifestJson: row.bundleManifestJson,
  sourceRunId: row.sourceRunId,
  audioInventorySha256: row.audioInventorySha256,
);

InferenceProvenance _provenance(db.TranscriptRun run) => InferenceProvenance(
  engineId: run.engineId,
  engineVersion: run.engineVersion,
  modelId: run.modelId,
  modelVersion: run.modelVersion,
  modelSha256: run.modelSha256,
  parametersJson: run.parametersJson,
);

/// Checks stored provenance before completion can claim success or full coverage.
Future<bool> validStoredProcessing(
  db.AppDatabase database,
  db.TranscriptRun run,
  db.TranscriptProcessingMetadataData processing,
) async =>
    !run.isDeleted &&
    !processing.isDeleted &&
    processing.transcriptRunId == run.id &&
    processing.meetingId == run.meetingId &&
    matchesProcessingProvenance(
      _provenance(run),
      processingInfoFromRow(processing),
      matchModelId: false,
    ) &&
    await validProcessingSource(
      database,
      run.id,
      run.meetingId,
      processingInfoFromRow(processing),
    );

/// Rejects missing, legacy, foreign, deleted, or invalid-provenance source runs.
Future<bool> validProcessingSource(
  db.AppDatabase database,
  String runId,
  String meetingId,
  TranscriptProcessingInfo info,
) async {
  final sourceId = info.sourceRunId;
  if (sourceId == null) return true;
  if (sourceId == runId || info.role != TranscriptProcessingRole.refinement) {
    return false;
  }
  final source = await (database.select(
    database.transcriptProcessingMetadata,
  )..where((row) => row.transcriptRunId.equals(sourceId))).getSingleOrNull();
  final sourceRun = await (database.select(
    database.transcriptRuns,
  )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
  return source != null &&
      !source.isDeleted &&
      source.meetingId == meetingId &&
      source.processingRole == 'liveDraft' &&
      sourceRun != null &&
      !sourceRun.isDeleted &&
      sourceRun.meetingId == meetingId &&
      matchesProcessingProvenance(
        _provenance(sourceRun),
        processingInfoFromRow(source),
        matchModelId: false,
      );
}

/// Requires positive, ordered, nonoverlapping, uniquely identified machine spans.
bool validMachineTranscriptSegments(
  String runId,
  List<TranscriptSegment> segments,
) {
  final ids = <String>{};
  var previousEndUs = 0;
  for (final segment in segments) {
    final startUs = segment.start.inMicroseconds;
    final endUs = segment.end.inMicroseconds;
    if (segment.id.isEmpty ||
        segment.transcriptRunId != runId ||
        segment.revisionState != TranscriptRevisionState.machine ||
        startUs < previousEndUs ||
        endUs <= startUs ||
        !ids.add(segment.id)) {
      return false;
    }
    previousEndUs = endUs;
  }
  return true;
}
