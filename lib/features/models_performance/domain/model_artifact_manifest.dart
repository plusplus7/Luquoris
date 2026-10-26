part of 'model_manifest.dart';

/// File roles understood by offline model adapters.
enum ModelArtifactRole {
  /// Legacy single-file model weights.
  model,

  /// Streaming acoustic encoder weights.
  encoder,

  /// Recognition decoder weights.
  decoder,

  /// Transducer joiner weights.
  joiner,

  /// Token vocabulary or tokenizer data.
  tokenizer,

  /// Immutable runtime configuration data.
  configuration,
}

/// One individually pinned artifact within an atomic model bundle.
@immutable
final class ModelArtifactManifest extends ValueObject {
  const ModelArtifactManifest._({
    required this.path,
    required this.role,
    required this.bytes,
    required this.sha256,
    required this.source,
    required this.licenseId,
    required this.licenseSnapshotPath,
  });

  /// Safe application-relative destination, never an absolute filesystem path.
  final AppRelativePath path;

  /// Adapter-visible purpose of this artifact.
  final ModelArtifactRole role;

  /// Exact positive byte length of the reviewed file.
  final int bytes;

  /// Expected lowercase SHA-256 of the file bytes.
  final String sha256;

  /// Pinned HTTPS source for this file, separate from its runtime dependency.
  final String source;

  /// Reviewed fixed weight/tokenizer/configuration license identifier.
  final String licenseId;

  /// Committed immutable license snapshot for this individual artifact.
  final AppRelativePath licenseSnapshotPath;

  /// Copies all file provenance, including source and reviewed license identity.
  Map<String, Object?> toJson() => <String, Object?>{
    ...inventoryJson,
    'source': source,
    'license': <String, Object?>{
      'id': licenseId,
      'snapshotPath': licenseSnapshotPath.value,
    },
  };

  /// Ordered digest inventory entry; source and license remain separately pinned.
  Map<String, Object> get inventoryJson => <String, Object>{
    'path': path.value,
    'role': role.name,
    'bytes': bytes,
    'sha256': sha256,
  };

  @override
  List<Object?> get equalityValues => <Object?>[
    path,
    role,
    bytes,
    sha256,
    source,
    licenseId,
    licenseSnapshotPath,
  ];
}
