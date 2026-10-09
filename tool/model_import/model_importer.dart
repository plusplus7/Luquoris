import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

part 'model_importer_io.dart';

/// Stable reasons an offline model import cannot be published.
enum ModelImportFailureReason {
  /// A configured input directory is outside its fixed project location.
  invalidInputLayout,

  /// Generated assets would be written outside the ignored build tree.
  outputOutsideBuild,

  /// The manifest directory does not exist or cannot be read.
  manifestDirectoryUnavailable,

  /// No model manifest was available to import.
  noManifests,

  /// A manifest is malformed or violates the versioned domain contract.
  invalidManifest,

  /// Two manifest files declare the same stable model identifier.
  duplicateModelId,

  /// A model destination is outside the packaged `models/` namespace.
  invalidArtifactLayout,

  /// The ignored local model artifact is absent or not a regular file.
  artifactMissing,

  /// The local model byte length differs from its manifest.
  artifactBytesMismatch,

  /// The local model SHA-256 differs from its manifest.
  artifactSha256Mismatch,

  /// A license destination is outside committed `models/licenses/`.
  invalidLicenseLayout,

  /// The reviewed license snapshot is absent or not a regular file.
  licenseSnapshotMissing,

  /// The reviewed license snapshot contains no bytes.
  licenseSnapshotEmpty,

  /// A verified staging tree could not be assembled.
  stagingFailed,

  /// The completed staging tree could not replace generated output.
  publicationFailed,
}

/// A privacy-safe build failure that never includes model bytes or paths.
@immutable
final class ModelImportFailure extends ValueObject implements Failure {
  /// Creates a failure for an optional stable [modelId].
  const ModelImportFailure({required this.reason, this.modelId});

  /// Machine-actionable category for the failed build step.
  final ModelImportFailureReason reason;

  /// Stable manifest identifier when one manifest caused the failure.
  final String? modelId;

  @override
  String get code => 'model_import.${reason.name}';

  @override
  List<Object?> get equalityValues => <Object?>[reason, modelId];
}

/// Fixed filesystem roots for one offline model import run.
@immutable
final class ModelImportRequest {
  /// Creates an import request whose output must remain under `build/`.
  const ModelImportRequest({
    required this.projectRoot,
    required this.manifestDirectory,
    required this.artifactDirectory,
    required this.outputDirectory,
  });

  /// Repository root containing committed manifests and license snapshots.
  final Directory projectRoot;

  /// Committed `models/manifests/` directory scanned non-recursively.
  final Directory manifestDirectory;

  /// Ignored `models/local/` directory containing manually supplied weights.
  final Directory artifactDirectory;

  /// Generated asset directory replaced only after every input verifies.
  final Directory outputDirectory;
}

/// Deterministic summary of a successfully published model asset tree.
@immutable
final class ModelImportSummary extends ValueObject {
  /// Creates a summary with sorted [modelIds] and aggregate [totalBytes].
  ModelImportSummary({
    required List<String> modelIds,
    required this.totalBytes,
  }) : modelIds = List<String>.unmodifiable(modelIds);

  /// Imported stable identifiers in ascending order.
  final List<String> modelIds;

  /// Sum of verified model artifact lengths in bytes.
  final int totalBytes;

  @override
  List<Object?> get equalityValues => <Object?>[
    modelIds.length,
    ...modelIds,
    totalBytes,
  ];
}

/// Verifies all local model inputs and publishes one generated asset tree.
///
/// The function performs no network access. A failed run leaves any previously
/// published [ModelImportRequest.outputDirectory] unchanged.
Future<Result<ModelImportSummary, ModelImportFailure>> importModels(
  ModelImportRequest request,
) => _importModels(request);
