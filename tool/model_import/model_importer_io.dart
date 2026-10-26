part of 'model_importer.dart';

final class _VerifiedModel {
  const _VerifiedModel({
    required this.manifest,
    required this.manifestFile,
    required this.artifactFiles,
    required this.licenseFiles,
  });

  final BundledModelManifest manifest;
  final File manifestFile;
  final Map<String, File> artifactFiles;
  final Map<String, File> licenseFiles;
}

Future<Result<ModelImportSummary, ModelImportFailure>> _importModels(
  ModelImportRequest request,
  ModelImportPublication publication,
) async {
  final layoutFailure = _validateRequestLayout(request);
  if (layoutFailure != null) {
    return Err<ModelImportSummary, ModelImportFailure>(layoutFailure);
  }
  try {
    if (!request.manifestDirectory.existsSync()) {
      return _failure(ModelImportFailureReason.manifestDirectoryUnavailable);
    }
    final manifestFiles = await _manifestFiles(request.manifestDirectory);
    if (manifestFiles.isEmpty) {
      return _failure(ModelImportFailureReason.noManifests);
    }
    final verifiedResult = await _verifyModels(request, manifestFiles);
    if (verifiedResult case Err(:final failure)) {
      return Err<ModelImportSummary, ModelImportFailure>(failure);
    }
    final verified =
        (verifiedResult as Ok<List<_VerifiedModel>, ModelImportFailure>).value;
    return _stageAndPublish(request, verified, publication);
  } on FileSystemException {
    return _failure(ModelImportFailureReason.stagingFailed);
  }
}

ModelImportFailure? _validateRequestLayout(ModelImportRequest request) {
  final root = path.normalize(path.absolute(request.projectRoot.path));
  final expectedManifests = path.join(root, 'models', 'manifests');
  final experimentalManifests = path.join(
    expectedManifests,
    'experimental-small',
  );
  final expectedArtifacts = path.join(root, 'models', 'local');
  final manifests = path.normalize(
    path.absolute(request.manifestDirectory.path),
  );
  final artifacts = path.normalize(
    path.absolute(request.artifactDirectory.path),
  );
  if ((!path.equals(manifests, expectedManifests) &&
          !path.equals(manifests, experimentalManifests)) ||
      !path.equals(artifacts, expectedArtifacts)) {
    return const ModelImportFailure(
      reason: ModelImportFailureReason.invalidInputLayout,
    );
  }
  final buildRoot = path.join(root, 'build');
  final output = path.normalize(path.absolute(request.outputDirectory.path));
  if (!path.isWithin(buildRoot, output)) {
    return const ModelImportFailure(
      reason: ModelImportFailureReason.outputOutsideBuild,
    );
  }
  return null;
}

Future<List<File>> _manifestFiles(Directory directory) async {
  final files = <File>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File && path.extension(entity.path) == '.json') {
      files.add(entity);
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

Future<Result<List<_VerifiedModel>, ModelImportFailure>> _verifyModels(
  ModelImportRequest request,
  List<File> manifestFiles,
) async {
  final verified = <_VerifiedModel>[];
  final ids = <String>{};
  final artifactPaths = <String>{};
  final licensePaths = <String>{};
  for (final manifestFile in manifestFiles) {
    final decoded = await _decodeManifest(manifestFile);
    if (decoded case Err(:final failure)) {
      return Err<List<_VerifiedModel>, ModelImportFailure>(failure);
    }
    final manifest =
        (decoded as Ok<BundledModelManifest, ModelImportFailure>).value;
    if (manifest.id == 'index') {
      return _failure(
        ModelImportFailureReason.invalidArtifactLayout,
        modelId: manifest.id,
      );
    }
    if (!ids.add(manifest.id)) {
      return _failure(
        ModelImportFailureReason.duplicateModelId,
        modelId: manifest.id,
      );
    }
    for (final artifact in manifest.artifacts) {
      if (!artifactPaths.add(artifact.path.value)) {
        return _failure(
          ModelImportFailureReason.invalidArtifactLayout,
          modelId: manifest.id,
        );
      }
      licensePaths.add(artifact.licenseSnapshotPath.value);
    }
    licensePaths.add(manifest.licenseSnapshotPath.value);
    if (artifactPaths.intersection(licensePaths).isNotEmpty) {
      return _failure(
        ModelImportFailureReason.invalidArtifactLayout,
        modelId: manifest.id,
      );
    }
    final modelResult = await _verifyOne(request, manifestFile, manifest);
    if (modelResult case Err(:final failure)) {
      return Err<List<_VerifiedModel>, ModelImportFailure>(failure);
    }
    verified.add((modelResult as Ok<_VerifiedModel, ModelImportFailure>).value);
  }
  verified.sort((left, right) => left.manifest.id.compareTo(right.manifest.id));
  return Ok<List<_VerifiedModel>, ModelImportFailure>(verified);
}

Future<Result<BundledModelManifest, ModelImportFailure>> _decodeManifest(
  File file,
) async {
  try {
    final decoded = jsonDecode(await file.readAsString());
    return switch (BundledModelManifest.tryParse(decoded)) {
      Ok(:final value) => Ok<BundledModelManifest, ModelImportFailure>(value),
      Err() => _failure(ModelImportFailureReason.invalidManifest),
    };
  } on FormatException {
    return _failure(ModelImportFailureReason.invalidManifest);
  }
}

Future<Result<_VerifiedModel, ModelImportFailure>> _verifyOne(
  ModelImportRequest request,
  File manifestFile,
  BundledModelManifest manifest,
) async {
  final artifactFiles = <String, File>{};
  for (final artifact in manifest.artifacts) {
    final artifactPath = artifact.path.value;
    if (!path.posix.isWithin('models', artifactPath)) {
      return _failure(
        ModelImportFailureReason.invalidArtifactLayout,
        modelId: manifest.id,
      );
    }
    final artifactFile = File(
      path.join(
        request.artifactDirectory.path,
        manifest.id,
        manifest.schemaVersion == 1
            ? path.posix.basename(artifactPath)
            : path.posix.relative(artifactPath, from: 'models/${manifest.id}'),
      ),
    );
    if (FileSystemEntity.typeSync(artifactFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return _failure(
        ModelImportFailureReason.artifactMissing,
        modelId: manifest.id,
      );
    }
    final artifactBytes = await artifactFile.length();
    if (artifactBytes != artifact.bytes) {
      return _failure(
        ModelImportFailureReason.artifactBytesMismatch,
        modelId: manifest.id,
      );
    }
    if (await _sha256Of(artifactFile) != artifact.sha256) {
      return _failure(
        ModelImportFailureReason.artifactSha256Mismatch,
        modelId: manifest.id,
      );
    }
    artifactFiles[artifactPath] = artifactFile;
  }
  final licenseFiles = <String, File>{};
  final licensePaths = <String>{
    manifest.licenseSnapshotPath.value,
    for (final artifact in manifest.artifacts)
      artifact.licenseSnapshotPath.value,
  };
  for (final licensePath in licensePaths) {
    if (!path.posix.isWithin('models/licenses', licensePath)) {
      return _failure(
        ModelImportFailureReason.invalidLicenseLayout,
        modelId: manifest.id,
      );
    }
    final licenseFile = File(
      path.joinAll(<String>[
        request.projectRoot.path,
        ...path.posix.split(licensePath),
      ]),
    );
    if (FileSystemEntity.typeSync(licenseFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return _failure(
        ModelImportFailureReason.licenseSnapshotMissing,
        modelId: manifest.id,
      );
    }
    if (await licenseFile.length() == 0) {
      return _failure(
        ModelImportFailureReason.licenseSnapshotEmpty,
        modelId: manifest.id,
      );
    }
    licenseFiles[licensePath] = licenseFile;
  }
  return Ok<_VerifiedModel, ModelImportFailure>(
    _VerifiedModel(
      manifest: manifest,
      manifestFile: manifestFile,
      artifactFiles: artifactFiles,
      licenseFiles: licenseFiles,
    ),
  );
}

Future<Result<ModelImportSummary, ModelImportFailure>> _stageAndPublish(
  ModelImportRequest request,
  List<_VerifiedModel> models,
  ModelImportPublication publication,
) async {
  final outputParent = request.outputDirectory.parent;
  await outputParent.create(recursive: true);
  final staging = await outputParent.createTemp('.model-assets-staging-');
  try {
    for (final model in models) {
      for (final artifact in model.manifest.artifacts) {
        await _copyFile(
          model.artifactFiles[artifact.path.value]!,
          File(path.join(staging.path, artifact.path.value)),
        );
        final stagedArtifact = File(
          path.join(staging.path, artifact.path.value),
        );
        if (await stagedArtifact.length() != artifact.bytes ||
            await _sha256Of(stagedArtifact) != artifact.sha256) {
          return _failure(
            ModelImportFailureReason.stagingFailed,
            modelId: model.manifest.id,
          );
        }
      }
      for (final license in model.licenseFiles.entries) {
        await _copyFile(
          license.value,
          File(
            path.join(staging.path, license.key),
          ),
        );
      }
      await _copyFile(
        model.manifestFile,
        File(
          path.join(
            staging.path,
            'model_manifests',
            '${model.manifest.id}.json',
          ),
        ),
      );
    }
    // Copying later inputs must not invalidate any earlier verification.
    for (final model in models) {
      for (final artifact in model.manifest.artifacts) {
        final staged = File(path.join(staging.path, artifact.path.value));
        if (await staged.length() != artifact.bytes ||
            await _sha256Of(staged) != artifact.sha256) {
          return _failure(
            ModelImportFailureReason.stagingFailed,
            modelId: model.manifest.id,
          );
        }
      }
      final stagedManifest = await _decodeManifest(
        File(
          path.join(
            staging.path,
            'model_manifests',
            '${model.manifest.id}.json',
          ),
        ),
      );
      if (stagedManifest is! Ok<BundledModelManifest, ModelImportFailure> ||
          stagedManifest.value != model.manifest) {
        return _failure(
          ModelImportFailureReason.stagingFailed,
          modelId: model.manifest.id,
        );
      }
    }
    await _writeIndex(staging, models);
    final publishResult = await _publish(
      staging,
      request.outputDirectory,
      publication,
    );
    if (publishResult case Err(:final failure)) {
      return Err<ModelImportSummary, ModelImportFailure>(failure);
    }
    return Ok<ModelImportSummary, ModelImportFailure>(
      ModelImportSummary(
        modelIds: models.map((model) => model.manifest.id).toList(),
        totalBytes: models.fold<int>(
          0,
          (total, model) => total + model.manifest.bytes,
        ),
      ),
    );
  } on FileSystemException {
    return _failure(ModelImportFailureReason.stagingFailed);
  } finally {
    if (staging.existsSync()) await staging.delete(recursive: true);
  }
}

Future<void> _copyFile(File source, File destination) async {
  await destination.parent.create(recursive: true);
  await source.openRead().pipe(destination.openWrite());
}

Future<String> _sha256Of(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<void> _writeIndex(
  Directory staging,
  List<_VerifiedModel> models,
) async {
  final index = <String, Object?>{
    'schemaVersion': 1,
    'manifests': models
        .map((model) => 'model_manifests/${model.manifest.id}.json')
        .toList(growable: false),
  };
  final file = File(path.join(staging.path, 'model_manifests', 'index.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(index)}\n',
    flush: true,
  );
}

Future<Result<void, ModelImportFailure>> _publish(
  Directory staging,
  Directory output,
  ModelImportPublication publication,
) async {
  Directory? backup;
  try {
    if (output.existsSync()) {
      backup = await output.parent.createTemp('.model-assets-backup-');
      await backup.delete();
      await publication.rename(output, backup.path);
    }
    await publication.rename(staging, output.path);
  } on FileSystemException {
    if (!output.existsSync() && backup != null && backup.existsSync()) {
      await publication.rename(backup, output.path);
    }
    return _failure(ModelImportFailureReason.publicationFailed);
  }
  // Publication has committed. A cleanup failure must not misreport rollback.
  if (backup != null && backup.existsSync()) {
    try {
      await publication.removeBackup(backup);
    } on FileSystemException {
      // Keep the recoverable backup; the new verified output is authoritative.
    }
  }
  return const Ok<void, ModelImportFailure>(null);
}

Result<T, ModelImportFailure> _failure<T>(
  ModelImportFailureReason reason, {
  String? modelId,
}) => Err<T, ModelImportFailure>(
  ModelImportFailure(reason: reason, modelId: modelId),
);
