import 'dart:convert';

import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:meta/meta.dart';

/// Stable identifier of the bundled multilingual base model.
const String transcriptionModelId = 'whisper-base-q5_1';

/// Exact native engine release used to derive durable run identity.
const String transcriptionEngineVersion = '1.9.4';

/// Canonical parameter schema interpreted by the current native adapter.
const int transcriptionParameterVersion = 1;

/// Canonical immutable inputs for one complete post-session pass.
@immutable
final class TranscriptionParameters {
  const TranscriptionParameters._({
    required this.requestedTiming,
    required this.languageHint,
    required this.executionMode,
    required this.modelId,
    required this.modelVersion,
    required this.modelSha256,
    required this.engineId,
    required this.engineVersion,
    required this.parameterVersion,
  });

  /// Builds parameters from durable meeting selection and typed model data.
  factory TranscriptionParameters.forMeeting({
    required Meeting meeting,
    required BundledModelManifest manifest,
    PerformanceMode executionMode = PerformanceMode.postSession,
  }) => TranscriptionParameters._(
    requestedTiming: meeting.transcriptionMode,
    languageHint: meeting.languageMode,
    executionMode: executionMode,
    modelId: manifest.id,
    modelVersion: manifest.version,
    modelSha256: manifest.sha256,
    engineId: manifest.engineId,
    engineVersion: transcriptionEngineVersion,
    parameterVersion: transcriptionParameterVersion,
  );

  /// Rebuilds only exact, currently supported parameters from durable provenance.
  static TranscriptionParameters? tryFromProvenance({
    required InferenceProvenance provenance,
    required BundledModelManifest manifest,
  }) {
    if (!isSupportedTranscriptionManifest(manifest) ||
        provenance.engineId != manifest.engineId ||
        provenance.engineVersion != transcriptionEngineVersion ||
        provenance.modelId != manifest.id ||
        provenance.modelVersion != manifest.version ||
        provenance.modelSha256 != manifest.sha256) {
      return null;
    }
    try {
      final decoded = jsonDecode(provenance.parametersJson);
      if (decoded is! Map<String, Object?> ||
          decoded.keys.toSet().difference(_canonicalKeys).isNotEmpty ||
          _canonicalKeys.difference(decoded.keys.toSet()).isNotEmpty) {
        return null;
      }
      final requestedTiming = MeetingTranscriptionMode.values
          .where((value) => value.name == decoded['requestedTiming'])
          .firstOrNull;
      final languageHint = MeetingLanguageMode.values
          .where((value) => value.name == decoded['languageHint'])
          .firstOrNull;
      final executionMode = PerformanceMode.values
          .where((value) => value.name == decoded['executionMode'])
          .firstOrNull;
      final parameterVersion = decoded['parameterVersion'];
      if (requestedTiming == null ||
          languageHint == null ||
          executionMode == null ||
          parameterVersion is! int ||
          parameterVersion != transcriptionParameterVersion) {
        return null;
      }
      final parameters = TranscriptionParameters._(
        requestedTiming: requestedTiming,
        languageHint: languageHint,
        executionMode: executionMode,
        modelId: provenance.modelId,
        modelVersion: provenance.modelVersion,
        modelSha256: provenance.modelSha256,
        engineId: provenance.engineId,
        engineVersion: provenance.engineVersion,
        parameterVersion: parameterVersion,
      );
      return parameters.canonicalJson == provenance.parametersJson
          ? parameters
          : null;
    } on FormatException {
      return null;
    }
  }

  /// User-selected meeting timing retained even when live work falls back.
  final MeetingTranscriptionMode requestedTiming;

  /// Recognition-language hint sent unchanged to the native engine.
  final MeetingLanguageMode languageHint;

  /// Effective execution policy for this complete pass.
  final PerformanceMode executionMode;

  /// Exact bundled model identifier.
  final String modelId;

  /// Exact model revision.
  final String modelVersion;

  /// Exact model artifact digest.
  final String modelSha256;

  /// Stable native engine identifier.
  final String engineId;

  /// Exact native engine release expected in the result.
  final String engineVersion;

  /// Canonical inference parameter schema.
  final int parameterVersion;

  /// Whether this policy permits any transcription work.
  bool get isTranscriptionEnabled =>
      executionMode != PerformanceMode.recordingOnly;

  /// Canonical JSON persisted with durable run provenance.
  String get canonicalJson => jsonEncode(<String, Object>{
    'executionMode': executionMode.name,
    'languageHint': languageHint.name,
    'parameterVersion': parameterVersion,
    'requestedTiming': requestedTiming.name,
  });

  /// Exact provenance stored before native inference starts.
  InferenceProvenance get provenance => InferenceProvenance(
    engineId: engineId,
    engineVersion: engineVersion,
    modelId: modelId,
    modelVersion: modelVersion,
    modelSha256: modelSha256,
    parametersJson: canonicalJson,
  );
}

/// Whether [manifest] may back this coordinator's production request.
bool isSupportedTranscriptionManifest(BundledModelManifest manifest) =>
    manifest.id == transcriptionModelId &&
    manifest.engineId == 'whisper_cpp' &&
    manifest.modelFormat == 'ggml' &&
    manifest.capabilities.contains(ModelCapability.transcription) &&
    manifest.enabledModes.contains(PerformanceMode.postSession);

const Set<String> _canonicalKeys = <String>{
  'executionMode',
  'languageHint',
  'parameterVersion',
  'requestedTiming',
};
