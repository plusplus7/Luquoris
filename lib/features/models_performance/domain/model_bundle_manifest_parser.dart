part of 'model_manifest.dart';

const _bundleRootFields = <String>{
  'schemaVersion',
  'id',
  'version',
  'source',
  'sha256',
  'bytes',
  'runtime',
  'license',
  'artifacts',
  'capabilities',
  'enabledModes',
};
const _bundleRuntimeFields = <String>{
  'engineId',
  'modelFormat',
  'engineVersion',
};
const _bundleArtifactFields = <String>{
  'path',
  'role',
  'bytes',
  'sha256',
  'source',
  'license',
};
// Exact on both the native VM and JavaScript; also bounds checked summation.
const _maxBundleBytes = 9007199254740991;

Result<BundledModelManifest, InvalidModelManifest> _tryParseModelBundleManifest(
  Map<String, Object?> candidate,
) {
  final unknown = _firstUnknownField(candidate, _bundleRootFields);
  if (unknown != null) return _unknownField(unknown);
  final runtime = candidate['runtime'];
  final id = candidate['id'];
  final files = candidate['artifacts'];
  if (runtime is! Map<String, Object?> ||
      id is! String ||
      files is! List<Object?>) {
    return _invalidShape();
  }
  final unknownRuntime = _firstUnknownField(runtime, _bundleRuntimeFields);
  if (unknownRuntime != null) return _unknownField('runtime.$unknownRuntime');
  final engineVersion = runtime['engineVersion'];
  if (engineVersion is! String || !_isTrimmedNonEmpty(engineVersion)) {
    return _failure(
      'runtime.engineVersion',
      ModelManifestFailureReason.invalidValue,
    );
  }
  final parsed = _parseBundleArtifacts(files, id);
  if (parsed case Err(:final failure)) return Err(failure);
  final artifacts =
      (parsed as Ok<List<ModelArtifactManifest>, InvalidModelManifest>).value;
  final legacyShape = <String, Object?>{
    ...candidate,
    'schemaVersion': 1,
    'artifactPath': artifacts.first.path.value,
    'runtime': <String, Object?>{
      'engineId': runtime['engineId'],
      'modelFormat': runtime['modelFormat'],
    },
  }..remove('artifacts');
  final validated = _tryParseModelManifest(legacyShape);
  if (validated case Err(:final failure)) return Err(failure);
  final base =
      (validated as Ok<BundledModelManifest, InvalidModelManifest>).value;
  if (!base.licenseSnapshotPath.value.startsWith('models/licenses/') ||
      base.licenseSnapshotPath.value.contains('\u0000')) {
    return _failure(
      'license.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
  }
  if (!_isPinnedBundleSource(base.source)) {
    return _failure('source', ModelManifestFailureReason.invalidSource);
  }
  var totalBytes = 0;
  for (final artifact in artifacts) {
    if (totalBytes > _maxBundleBytes - artifact.bytes) {
      return _failure('bytes', ModelManifestFailureReason.invalidValue);
    }
    totalBytes += artifact.bytes;
  }
  if (base.bytes != totalBytes) {
    return _failure('bytes', ModelManifestFailureReason.invalidValue);
  }
  final inventory = jsonEncode(
    artifacts.map((artifact) => artifact.inventoryJson).toList(),
  );
  if (crypto.sha256.convert(utf8.encode(inventory)).toString() != base.sha256) {
    return _failure('sha256', ModelManifestFailureReason.invalidSha256);
  }
  return Ok(
    BundledModelManifest._(
      schemaVersion: 2,
      id: base.id,
      version: base.version,
      source: base.source,
      artifactPath: base.artifactPath,
      sha256: base.sha256,
      bytes: base.bytes,
      engineId: base.engineId,
      modelFormat: base.modelFormat,
      engineVersion: engineVersion,
      licenseId: base.licenseId,
      licenseSnapshotPath: base.licenseSnapshotPath,
      capabilities: base.capabilities,
      enabledModes: base.enabledModes,
      artifacts: artifacts,
    ),
  );
}

Result<List<ModelArtifactManifest>, InvalidModelManifest> _parseBundleArtifacts(
  List<Object?> files,
  String modelId,
) {
  if (files.isEmpty) {
    return _failure('artifacts', ModelManifestFailureReason.emptyCollection);
  }
  if (files.length > ModelArtifactRole.values.length) {
    return _failure('artifacts', ModelManifestFailureReason.invalidValue);
  }
  final artifacts = <ModelArtifactManifest>[];
  final paths = <String>{};
  final roles = <ModelArtifactRole>{};
  for (var index = 0; index < files.length; index += 1) {
    final parsed = _parseBundleArtifact(
      files[index],
      modelId,
      'artifacts[$index]',
    );
    if (parsed case Err(:final failure)) return Err(failure);
    final artifact =
        (parsed as Ok<ModelArtifactManifest, InvalidModelManifest>).value;
    if (!paths.add(artifact.path.value) || !roles.add(artifact.role)) {
      return _failure(
        'artifacts[$index]',
        ModelManifestFailureReason.duplicateValue,
      );
    }
    artifacts.add(artifact);
  }
  artifacts.sort((left, right) => left.path.value.compareTo(right.path.value));
  return Ok(List<ModelArtifactManifest>.unmodifiable(artifacts));
}

Result<ModelArtifactManifest, InvalidModelManifest> _parseBundleArtifact(
  Object? candidate,
  String modelId,
  String field,
) {
  if (candidate is! Map<String, Object?>) {
    return _failure(field, ModelManifestFailureReason.invalidShape);
  }
  final unknown = _firstUnknownField(candidate, _bundleArtifactFields);
  if (unknown != null) {
    return _failure('$field.$unknown', ModelManifestFailureReason.unknownField);
  }
  if (candidate case <String, Object?>{
    'path': final String artifactPath,
    'role': final String roleName,
    'bytes': final int bytes,
    'sha256': final String digest,
    'source': final String source,
    'license': final Map<String, Object?> license,
  }) {
    final path = AppRelativePath.tryParse(artifactPath);
    if (path is! Ok<AppRelativePath, InvalidAppRelativePath> ||
        artifactPath.contains('\u0000') ||
        !artifactPath.startsWith('models/$modelId/')) {
      return _failure('$field.path', ModelManifestFailureReason.unsafePath);
    }
    final role = ModelArtifactRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) {
      return _failure(
        '$field.role',
        ModelManifestFailureReason.unknownEnumValue,
      );
    }
    if (bytes <= 0 || bytes > _maxBundleBytes) {
      return _failure('$field.bytes', ModelManifestFailureReason.invalidValue);
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      return _failure(
        '$field.sha256',
        ModelManifestFailureReason.invalidSha256,
      );
    }
    if (!_isPinnedBundleSource(source)) {
      return _failure(
        '$field.source',
        ModelManifestFailureReason.invalidSource,
      );
    }
    final parsedLicense = _parseBundleArtifactLicense(
      license,
      '$field.license',
    );
    if (parsedLicense case Err(:final failure)) return Err(failure);
    final checkedLicense =
        (parsedLicense
                as Ok<
                  ({String id, AppRelativePath path}),
                  InvalidModelManifest
                >)
            .value;
    return Ok(
      ModelArtifactManifest._(
        path: path.value,
        role: role,
        bytes: bytes,
        sha256: digest,
        source: source,
        licenseId: checkedLicense.id,
        licenseSnapshotPath: checkedLicense.path,
      ),
    );
  }
  return _failure(field, ModelManifestFailureReason.invalidShape);
}

Result<({String id, AppRelativePath path}), InvalidModelManifest>
_parseBundleArtifactLicense(
  Map<String, Object?> license,
  String field,
) {
  final unknown = _firstUnknownField(license, _licenseFields);
  if (unknown != null) {
    return _failure('$field.$unknown', ModelManifestFailureReason.unknownField);
  }
  final id = license['id'];
  final snapshot = license['snapshotPath'];
  if (id is! String || !_isTrimmedNonEmpty(id) || snapshot is! String) {
    return _failure(field, ModelManifestFailureReason.invalidValue);
  }
  final path = AppRelativePath.tryParse(snapshot);
  if (path is! Ok<AppRelativePath, InvalidAppRelativePath> ||
      snapshot.contains('\u0000') ||
      !snapshot.startsWith('models/licenses/')) {
    return _failure(
      '$field.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
  }
  return Ok((id: id, path: path.value));
}

bool _isPinnedBundleSource(String source) {
  final uri = Uri.tryParse(source);
  if (source.trim() != source ||
      uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  final segments = uri.pathSegments;
  if (segments.any((segment) => segment == '.' || segment == '..')) {
    return false;
  }
  final revision = RegExp(r'^[0-9a-f]{40}([0-9a-f]{24})?$');
  if (uri.host == 'raw.githubusercontent.com' && segments.length >= 4) {
    return revision.hasMatch(segments[2]);
  }
  for (var index = 0; index < segments.length - 2; index += 1) {
    if ((segments[index] == 'resolve' || segments[index] == 'blob') &&
        revision.hasMatch(segments[index + 1])) {
      return true;
    }
  }
  return false;
}
