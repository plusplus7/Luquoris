import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_ids.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_processing_info.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Reconstructs only the full frozen refinement profile, never a catalog alias.
ProcessingModelProfile? refinementProfileForRun(
  ProcessingJob job,
  TranscriptRun run,
  TranscriptProcessingInfo info,
) {
  if (info.role != TranscriptProcessingRole.refinement ||
      run.meetingId != job.meetingId ||
      run.provenance.modelId != job.modelId ||
      info.audioInventorySha256 == null) {
    return null;
  }
  final parsed = ProcessingModelProfile.tryCreate(
    bundleManifestJson: info.bundleManifestJson,
    engineVersion: run.provenance.engineVersion,
    parametersJson: run.provenance.parametersJson,
  );
  if (parsed is! Ok<ProcessingModelProfile, InvalidProcessingSelection>) {
    return null;
  }
  final profile = parsed.value;
  return profile.manifest.engineId == run.provenance.engineId &&
          profile.manifest.version == run.provenance.modelVersion &&
          profile.manifest.sha256 == run.provenance.modelSha256 &&
          profile.parametersJson == run.provenance.parametersJson
      ? profile
      : null;
}

/// Validates complete, unformatted output and derives per-run stable segment IDs.
List<TranscriptSegment>? refinementSegments(
  String runId,
  TranscriptionOutput output,
  RefinementExecutionInput input,
) {
  if (output.engineVersion != input.profile.engineVersion ||
      output.warningCode != null) {
    return null;
  }
  final segments = <TranscriptSegment>[];
  var previous = Duration.zero;
  for (final chunk in output.chunks) {
    if (chunk.stability != TranscriptStability.stable ||
        chunk.start < previous ||
        chunk.end <= chunk.start ||
        chunk.end.inMicroseconds > (input.totalSamples ~/ 1024) * 64000 ||
        chunk.displayText != chunk.rawText) {
      return null;
    }
    segments.add(
      TranscriptSegment(
        id: transcriptionSegmentId(
          runId: runId,
          start: chunk.start,
          end: chunk.end,
        ),
        transcriptRunId: runId,
        start: chunk.start,
        end: chunk.end,
        rawModelText: chunk.rawText,
        displayedText: chunk.rawText,
        revisionState: TranscriptRevisionState.machine,
      ),
    );
    previous = chunk.end;
  }
  return segments;
}
