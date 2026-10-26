part of 'model_manifest.dart';

const _rootFields = <String>{
  'schemaVersion',
  'id',
  'version',
  'source',
  'artifactPath',
  'sha256',
  'bytes',
  'runtime',
  'license',
  'capabilities',
  'enabledModes',
};
const _runtimeFields = <String>{'engineId', 'modelFormat'};
const _licenseFields = <String>{'id', 'snapshotPath'};

Result<BundledModelManifest, InvalidModelManifest> _tryParseModelManifest(
  Object? candidate,
) {
  if (candidate is! Map<String, Object?>) return _invalidShape();
  final declaredSchemaVersion = candidate['schemaVersion'];
  if (declaredSchemaVersion is int && declaredSchemaVersion == 2) {
    return _tryParseModelBundleManifest(candidate);
  }
  if (declaredSchemaVersion is int && declaredSchemaVersion != 1) {
    return _failure(
      'schemaVersion',
      ModelManifestFailureReason.unsupportedSchemaVersion,
    );
  }
  final unknownRoot = _firstUnknownField(candidate, _rootFields);
  if (unknownRoot != null) return _unknownField(unknownRoot);
  final runtime = candidate['runtime'];
  if (runtime is Map<String, Object?>) {
    final unknownRuntime = _firstUnknownField(runtime, _runtimeFields);
    if (unknownRuntime != null) {
      return _unknownField('runtime.$unknownRuntime');
    }
  }
  final license = candidate['license'];
  if (license is Map<String, Object?>) {
    final unknownLicense = _firstUnknownField(license, _licenseFields);
    if (unknownLicense != null) {
      return _unknownField('license.$unknownLicense');
    }
  }
  if (candidate case <String, Object?>{
    'schemaVersion': final int schemaVersion,
    'id': final String id,
    'version': final String version,
    'source': final String source,
    'artifactPath': final String artifactPath,
    'sha256': final String sha256,
    'bytes': final int bytes,
    'runtime': <String, Object?>{
      'engineId': final String engineId,
      'modelFormat': final String modelFormat,
    },
    'license': <String, Object?>{
      'id': final String licenseId,
      'snapshotPath': final String licenseSnapshotPath,
    },
    'capabilities': final List<Object?> capabilityNames,
    'enabledModes': final List<Object?> modeNames,
  }) {
    return _validateManifest(
      schemaVersion: schemaVersion,
      id: id,
      version: version,
      source: source,
      artifactPath: artifactPath,
      sha256: sha256,
      bytes: bytes,
      engineId: engineId,
      modelFormat: modelFormat,
      licenseId: licenseId,
      licenseSnapshotPath: licenseSnapshotPath,
      capabilityNames: capabilityNames,
      modeNames: modeNames,
    );
  }
  return _invalidShape();
}

Result<BundledModelManifest, InvalidModelManifest> _validateManifest({
  required int schemaVersion,
  required String id,
  required String version,
  required String source,
  required String artifactPath,
  required String sha256,
  required int bytes,
  required String engineId,
  required String modelFormat,
  required String licenseId,
  required String licenseSnapshotPath,
  required List<Object?> capabilityNames,
  required List<Object?> modeNames,
}) {
  if (schemaVersion != 1) {
    return _failure(
      'schemaVersion',
      ModelManifestFailureReason.unsupportedSchemaVersion,
    );
  }
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(id)) {
    return _failure('id', ModelManifestFailureReason.invalidValue);
  }
  if (!_isTrimmedNonEmpty(version)) {
    return _failure('version', ModelManifestFailureReason.invalidValue);
  }
  final sourceUri = Uri.tryParse(source);
  if (sourceUri == null ||
      sourceUri.scheme != 'https' ||
      !sourceUri.hasAuthority ||
      sourceUri.host.isEmpty) {
    return _failure('source', ModelManifestFailureReason.invalidSource);
  }
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
    return _failure('sha256', ModelManifestFailureReason.invalidSha256);
  }
  if (bytes <= 0) {
    return _failure('bytes', ModelManifestFailureReason.invalidValue);
  }
  if (!_isTrimmedNonEmpty(engineId)) {
    return _failure(
      'runtime.engineId',
      ModelManifestFailureReason.invalidValue,
    );
  }
  if (!_isTrimmedNonEmpty(modelFormat)) {
    return _failure(
      'runtime.modelFormat',
      ModelManifestFailureReason.invalidValue,
    );
  }
  if (!_isTrimmedNonEmpty(licenseId)) {
    return _failure('license.id', ModelManifestFailureReason.invalidValue);
  }
  return _validatePathsAndEnums(
    schemaVersion: schemaVersion,
    id: id,
    version: version,
    source: source,
    artifactPath: artifactPath,
    sha256: sha256,
    bytes: bytes,
    engineId: engineId,
    modelFormat: modelFormat,
    licenseId: licenseId,
    licenseSnapshotPath: licenseSnapshotPath,
    capabilityNames: capabilityNames,
    modeNames: modeNames,
  );
}

Result<BundledModelManifest, InvalidModelManifest> _validatePathsAndEnums({
  required int schemaVersion,
  required String id,
  required String version,
  required String source,
  required String artifactPath,
  required String sha256,
  required int bytes,
  required String engineId,
  required String modelFormat,
  required String licenseId,
  required String licenseSnapshotPath,
  required List<Object?> capabilityNames,
  required List<Object?> modeNames,
}) {
  final artifactResult = AppRelativePath.tryParse(artifactPath);
  if (artifactResult case Err()) {
    return _failure('artifactPath', ModelManifestFailureReason.unsafePath);
  }
  final licenseResult = AppRelativePath.tryParse(licenseSnapshotPath);
  if (licenseResult case Err()) {
    return _failure(
      'license.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
  }
  final capabilityResult = _parseCapabilities(capabilityNames);
  if (capabilityResult case Err(:final failure)) {
    return Err<BundledModelManifest, InvalidModelManifest>(failure);
  }
  final modeResult = _parseModes(modeNames);
  if (modeResult case Err(:final failure)) {
    return Err<BundledModelManifest, InvalidModelManifest>(failure);
  }
  final artifact = artifactResult.fold<AppRelativePath?>(
    (value) => value,
    (_) => null,
  );
  final license = licenseResult.fold<AppRelativePath?>(
    (value) => value,
    (_) => null,
  );
  final capabilities = capabilityResult.fold<List<ModelCapability>?>(
    (value) => value,
    (_) => null,
  );
  final modes = modeResult.fold<List<PerformanceMode>?>(
    (value) => value,
    (_) => null,
  );
  if (artifact == null ||
      license == null ||
      capabilities == null ||
      modes == null) {
    return _invalidShape();
  }
  return Ok<BundledModelManifest, InvalidModelManifest>(
    BundledModelManifest._(
      schemaVersion: schemaVersion,
      id: id,
      version: version,
      source: source,
      artifactPath: artifact,
      sha256: sha256,
      bytes: bytes,
      engineId: engineId,
      modelFormat: modelFormat,
      licenseId: licenseId,
      licenseSnapshotPath: license,
      capabilities: capabilities,
      enabledModes: modes,
    ),
  );
}

String? _firstUnknownField(Map<String, Object?> map, Set<String> allowed) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) return key;
  }
  return null;
}

bool _isTrimmedNonEmpty(String value) =>
    value.isNotEmpty && value.trim() == value;

Result<BundledModelManifest, InvalidModelManifest> _invalidShape() => _failure(
  r'$manifest',
  ModelManifestFailureReason.invalidShape,
);

Result<BundledModelManifest, InvalidModelManifest> _unknownField(
  String field,
) => _failure(field, ModelManifestFailureReason.unknownField);

Result<T, InvalidModelManifest> _failure<T>(
  String field,
  ModelManifestFailureReason reason,
) => Err<T, InvalidModelManifest>(
  InvalidModelManifest(field: field, reason: reason),
);

Result<List<ModelCapability>, InvalidModelManifest> _parseCapabilities(
  List<Object?> names,
) => _parseEnumValues<ModelCapability>(
  names: names,
  values: ModelCapability.values,
  field: 'capabilities',
  nameOf: (value) => value.name,
);

Result<List<PerformanceMode>, InvalidModelManifest> _parseModes(
  List<Object?> names,
) => _parseEnumValues<PerformanceMode>(
  names: names,
  values: PerformanceMode.values,
  field: 'enabledModes',
  nameOf: (value) => value.name,
);

Result<List<T>, InvalidModelManifest> _parseEnumValues<T>({
  required List<Object?> names,
  required List<T> values,
  required String field,
  required String Function(T value) nameOf,
}) {
  if (names.isEmpty) {
    return _failure(field, ModelManifestFailureReason.emptyCollection);
  }
  final parsed = <T>[];
  final seen = <String>{};
  for (final name in names) {
    if (name is! String) {
      return _failure(field, ModelManifestFailureReason.unknownEnumValue);
    }
    if (!seen.add(name)) {
      return _failure(field, ModelManifestFailureReason.duplicateValue);
    }
    T? match;
    for (final value in values) {
      if (nameOf(value) == name) match = value;
    }
    if (match == null) {
      return _failure(field, ModelManifestFailureReason.unknownEnumValue);
    }
    parsed.add(match);
  }
  return Ok<List<T>, InvalidModelManifest>(List<T>.unmodifiable(parsed));
}
