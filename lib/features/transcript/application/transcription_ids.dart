import 'package:loquiris/features/transcript/application/transcription_parameters.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();
const String _namespace = '5dc960ec-e560-5c45-b2fb-e5bf859d5c1d';

/// Deterministic durable job identity for one meeting/provenance tuple.
String transcriptionJobId({
  required String meetingId,
  required TranscriptionParameters parameters,
}) => _uuid.v5(_namespace, _identityName('job', meetingId, parameters));

/// Deterministic transcript-run identity for one meeting/provenance tuple.
String transcriptionRunId({
  required String meetingId,
  required TranscriptionParameters parameters,
}) => _uuid.v5(_namespace, _identityName('run', meetingId, parameters));

/// Deterministic segment identity independent of engine-provided labels/text.
String transcriptionSegmentId({
  required String runId,
  required Duration start,
  required Duration end,
}) => _uuid.v5(
  _namespace,
  'segment|$runId|${start.inMicroseconds}|${end.inMicroseconds}',
);

String _identityName(
  String kind,
  String meetingId,
  TranscriptionParameters parameters,
) =>
    '$kind|$meetingId|${parameters.requestedTiming.name}|'
    '${parameters.engineId}|${parameters.engineVersion}|'
    '${parameters.modelId}|${parameters.modelVersion}|'
    '${parameters.modelSha256}|${parameters.parameterVersion}|'
    '${parameters.canonicalJson}';
