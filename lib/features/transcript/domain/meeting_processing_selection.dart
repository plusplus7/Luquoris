import 'dart:convert';

import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

/// Explicit new-meeting processing choice; legacy absence is not a new opt-in.
enum MeetingProcessingMode {
  /// Authoritative capture without optional inference.
  recordingOnly,

  /// Complete pass after durable recording finalization, without live work.
  postSession,

  /// Separate streaming draft followed by an independently configured full pass.
  twoPass,
}

/// A role profile is unreadable or does not pin a compatible runtime/settings.
final class InvalidProcessingSelection implements Failure {
  /// Creates a stable content-free rejection.
  const InvalidProcessingSelection();

  @override
  String get code => 'processing_selection_invalid';
}

/// Frozen role-specific bundle/runtime/settings, independent of other roles.
@immutable
final class ProcessingModelProfile extends ValueObject {
  const ProcessingModelProfile._({
    required this.manifest,
    required this.bundleManifestJson,
    required this.engineVersion,
    required this.parametersJson,
    required this.parameterVersion,
  });

  /// Parses full inventory and canonicalizes parameters, without model loading.
  ///
  /// Each JSON input is bounded to 131072 UTF-16 code units; nesting to 16 levels.
  /// No normalization changes string values, language, or numeric settings.
  static Result<ProcessingModelProfile, InvalidProcessingSelection> tryCreate({
    required String bundleManifestJson,
    required String engineVersion,
    required String parametersJson,
  }) {
    if (bundleManifestJson.length > _maximumJsonCharacters ||
        parametersJson.length > _maximumJsonCharacters ||
        !_runtime.hasMatch(engineVersion) ||
        const [
          'latest',
          'main',
          'master',
        ].contains(engineVersion.toLowerCase())) {
      return const Err(InvalidProcessingSelection());
    }
    try {
      final parsed = BundledModelManifest.tryParse(
        jsonDecode(bundleManifestJson),
      );
      final parameters = jsonDecode(parametersJson);
      if (parsed is! Ok<BundledModelManifest, InvalidModelManifest> ||
          parameters is! Map<String, Object?> ||
          parameters['parameterVersion'] is! int ||
          (parameters['parameterVersion']! as int) <= 0) {
        return const Err(InvalidProcessingSelection());
      }
      final manifest = parsed.value;
      if (!manifest.capabilities.contains(ModelCapability.transcription) ||
          (manifest.engineVersion != null &&
              manifest.engineVersion != engineVersion)) {
        return const Err(InvalidProcessingSelection());
      }
      return Ok(
        ProcessingModelProfile._(
          manifest: manifest,
          bundleManifestJson: bundleManifestJson,
          engineVersion: engineVersion,
          parametersJson: jsonEncode(_canonical(parameters, 0)),
          parameterVersion: parameters['parameterVersion']! as int,
        ),
      );
    } on FormatException {
      return const Err(InvalidProcessingSelection());
    }
  }

  /// Full typed v1/v2 bundle, including per-file source and license snapshots.
  final BundledModelManifest manifest;

  /// Original manifest bytes retained independently of catalog ID remapping.
  final String bundleManifestJson;

  /// Exact runtime version used by this role.
  final String engineVersion;

  /// Recursively key-sorted compact JSON of the actual decoding configuration.
  final String parametersJson;

  /// Positive integer schema interpreted by this role's native adapter.
  final int parameterVersion;

  /// Complete immutable inputs for a new run, before allocation or inference.
  InferenceProvenance get provenance => InferenceProvenance(
    engineId: manifest.engineId,
    engineVersion: engineVersion,
    modelId: manifest.id,
    modelVersion: manifest.version,
    modelSha256: manifest.sha256,
    parametersJson: parametersJson,
  );

  /// Binds only a semantically identical local catalog row after ID remapping.
  ///
  /// This does not verify asset availability, integrity, or release qualification.
  Result<InferenceProvenance, InvalidProcessingSelection> bindToInstalledModel(
    InstalledModel model,
  ) {
    if (model.id.isEmpty ||
        model.version != manifest.version ||
        model.source != manifest.source ||
        model.sha256 != manifest.sha256 ||
        model.bytes != manifest.bytes ||
        model.expectedEngineId != manifest.engineId ||
        model.licenseId != manifest.licenseId ||
        model.licenseSnapshotPath != manifest.licenseSnapshotPath ||
        model.capabilities.length != manifest.capabilities.length ||
        !model.capabilities.toSet().containsAll(manifest.capabilities) ||
        model.enabledModes.length != manifest.enabledModes.length ||
        !model.enabledModes.toSet().containsAll(manifest.enabledModes)) {
      return const Err(InvalidProcessingSelection());
    }
    return Ok(
      InferenceProvenance(
        engineId: manifest.engineId,
        engineVersion: engineVersion,
        modelId: model.id,
        modelVersion: manifest.version,
        modelSha256: manifest.sha256,
        parametersJson: parametersJson,
      ),
    );
  }

  @override
  List<Object?> get equalityValues => [
    bundleManifestJson,
    engineVersion,
    parametersJson,
  ];
}

/// One valid complete role assignment, selected before capture starts.
@immutable
final class MeetingProcessingSelection extends ValueObject {
  /// Explicit capture-only mode; neither engine is implicitly enabled.
  const MeetingProcessingSelection.recordingOnly()
    : mode = MeetingProcessingMode.recordingOnly,
      live = null,
      refinement = null;

  /// Complete-pass-only mode retains one independent role profile.
  const MeetingProcessingSelection.postSession({
    required ProcessingModelProfile this.refinement,
  }) : mode = MeetingProcessingMode.postSession,
       live = null;

  /// Paired mode never substitutes the complete-pass profile for live work.
  const MeetingProcessingSelection.twoPass({
    required ProcessingModelProfile this.live,
    required ProcessingModelProfile this.refinement,
  }) : mode = MeetingProcessingMode.twoPass;

  /// Explicit user timing/processing intent.
  final MeetingProcessingMode mode;

  /// Streaming-only profile, present exactly for two-pass mode.
  final ProcessingModelProfile? live;

  /// Complete-pass profile, absent exactly for capture-only mode.
  final ProcessingModelProfile? refinement;

  @override
  List<Object?> get equalityValues => [mode, live, refinement];
}

const int _maximumJsonCharacters = 128 * 1024;
final _runtime = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+\-]{0,127}$');

Object? _canonical(Object? value, int depth) {
  if (depth > 16) throw const FormatException('parameter_nesting_invalid');
  return switch (value) {
    Map<String, Object?>() => {
      for (final key in value.keys.toList()..sort())
        key: _canonical(value[key], depth + 1),
    },
    List<Object?>() =>
      value.map((item) => _canonical(item, depth + 1)).toList(growable: false),
    double() when !value.isFinite => throw const FormatException(
      'parameter_number_invalid',
    ),
    _ => value,
  };
}
