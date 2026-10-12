import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

part 'model_manifest_parser.dart';

/// Reasons an external bundled-model manifest cannot enter the domain.
enum ModelManifestFailureReason {
  /// The decoded JSON shape or a required field type is invalid.
  invalidShape,

  /// The manifest declares a schema version this application cannot read.
  unsupportedSchemaVersion,

  /// A field is not defined by the selected schema revision.
  unknownField,

  /// A scalar field violates its documented format or range.
  invalidValue,

  /// The source is not an absolute HTTPS artifact reference.
  invalidSource,

  /// The digest is not exactly 64 lowercase hexadecimal characters.
  invalidSha256,

  /// A bundled file path is absolute, empty, or traverses directories.
  unsafePath,

  /// A capability or performance-mode name is not part of the app contract.
  unknownEnumValue,

  /// A required capability or mode set is empty.
  emptyCollection,

  /// A set-like manifest array contains the same value more than once.
  duplicateValue,
}

/// A privacy-safe explanation of a rejected bundled-model manifest.
@immutable
final class InvalidModelManifest extends ValueObject implements Failure {
  /// Creates a failure for [field] without retaining the rejected value.
  const InvalidModelManifest({required this.field, required this.reason});

  /// JSON field whose contract was violated.
  final String field;

  /// Stable category callers can handle without parsing text.
  final ModelManifestFailureReason reason;

  @override
  String get code => 'model_manifest.${reason.name}';

  @override
  List<Object?> get equalityValues => <Object?>[field, reason];
}

/// Immutable supply-chain contract for one bundled model artifact.
@immutable
final class BundledModelManifest extends ValueObject {
  BundledModelManifest._({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.source,
    required this.artifactPath,
    required this.sha256,
    required this.bytes,
    required this.engineId,
    required this.modelFormat,
    required this.licenseId,
    required this.licenseSnapshotPath,
    required List<ModelCapability> capabilities,
    required List<PerformanceMode> enabledModes,
  }) : capabilities = List<ModelCapability>.unmodifiable(capabilities),
       enabledModes = List<PerformanceMode>.unmodifiable(enabledModes);

  /// Parses decoded JSON without throwing for malformed input.
  static Result<BundledModelManifest, InvalidModelManifest> tryParse(
    Object? candidate,
  ) => _tryParseModelManifest(candidate);

  /// Schema revision interpreted by [tryParse].
  final int schemaVersion;

  /// Stable model identifier shared with analysis provenance.
  final String id;

  /// Exact upstream model release identifier.
  final String version;

  /// Immutable HTTPS reference from which the artifact was reviewed.
  final String source;

  /// Safe application-relative path of the bundled model bytes.
  final AppRelativePath artifactPath;

  /// Expected lowercase SHA-256 of the exact artifact bytes.
  final String sha256;

  /// Expected artifact length in bytes; always positive.
  final int bytes;

  /// Stable identifier of the only engine adapter allowed to load the model.
  final String engineId;

  /// Model container or tensor format understood by [engineId].
  final String modelFormat;

  /// SPDX identifier or fixed reviewed license key.
  final String licenseId;

  /// Safe bundled path to the exact license text reviewed for this artifact.
  final AppRelativePath licenseSnapshotPath;

  /// AI capabilities that depend on this artifact.
  final List<ModelCapability> capabilities;

  /// User-selectable modes for which this exact artifact passed release gates.
  final List<PerformanceMode> enabledModes;

  /// Returns the durable provenance representation used by analysis records.
  InstalledModel toInstalledModel() => InstalledModel(
    id: id,
    version: version,
    source: source,
    sha256: sha256,
    bytes: bytes,
    capabilities: capabilities,
    expectedEngineId: engineId,
    licenseId: licenseId,
    licenseSnapshotPath: licenseSnapshotPath,
    enabledModes: enabledModes,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    schemaVersion,
    id,
    version,
    source,
    artifactPath,
    sha256,
    bytes,
    engineId,
    modelFormat,
    licenseId,
    licenseSnapshotPath,
    capabilities.length,
    ...capabilities,
    enabledModes.length,
    ...enabledModes,
  ];
}
