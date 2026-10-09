part of 'model_importer.dart';

final class _VerifiedModel {
  const _VerifiedModel({
    required this.manifest,
    required this.manifestFile,
    required this.artifactFile,
    required this.licenseFile,
  });

  final BundledModelManifest manifest;
  final File manifestFile;
  final File artifactFile;
  final File licenseFile;
}

Future<Result<ModelImportSummary, ModelImportFailure>> _importModels(
  ModelImportRequest request,
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
    return _stageAndPublish(request, verified);
  } on FileSystemException {
    return _failure(ModelImportFailureReason.stagingFailed);
  }
}

ModelImportFailure? _validateRequestLayout(ModelImportRequest request) {
  final root = path.normalize(path.absolute(request.projectRoot.path));
  final expectedManifests = path.join(root, 'models', 'manifests');
  final expectedArtifacts = path.join(root, 'models', 'local');
  final manifests = path.normalize(
    path.absolute(request.manifestDirectory.path),
  );
  final artifacts = path.normalize(
    path.absolute(request.artifactDirectory.path),
  );
  if (!path.equals(manifests, expectedManifests) ||
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
  for (final manifestFile in manifestFiles) {
    final decoded = await _decodeManifest(manifestFile);
    if (decoded case Err(:final failure)) {
      return Err<List<_VerifiedModel>, ModelImportFailure>(failure);
    }
    final manifest =
        (decoded as Ok<BundledModelManifest, ModelImportFailure>).value;
    if (!ids.add(manifest.id)) {
      return _failure(
        ModelImportFailureReason.duplicateModelId,
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
  final artifactPath = manifest.artifactPath.value;
  if (!path.posix.isWithin('models', artifactPath)) {
    return _failure(
      ModelImportFailureReason.invalidArtifactLayout,
      modelId: manifest.id,
    );
  }
  final licensePath = manifest.licenseSnapshotPath.value;
  if (!path.posix.isWithin('models/licenses', licensePath)) {
    return _failure(
      ModelImportFailureReason.invalidLicenseLayout,
      modelId: manifest.id,
    );
  }
  final artifactFile = File(
    path.join(
      request.artifactDirectory.path,
      manifest.id,
      path.posix.basename(artifactPath),
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
  if (artifactBytes != manifest.bytes) {
    return _failure(
      ModelImportFailureReason.artifactBytesMismatch,
      modelId: manifest.id,
    );
  }
  if (await _sha256Of(artifactFile) != manifest.sha256) {
    return _failure(
      ModelImportFailureReason.artifactSha256Mismatch,
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
  return Ok<_VerifiedModel, ModelImportFailure>(
    _VerifiedModel(
      manifest: manifest,
      manifestFile: manifestFile,
      artifactFile: artifactFile,
      licenseFile: licenseFile,
    ),
  );
}

Future<Result<ModelImportSummary, ModelImportFailure>> _stageAndPublish(
  ModelImportRequest request,
  List<_VerifiedModel> models,
) async {
  final outputParent = request.outputDirectory.parent;
  await outputParent.create(recursive: true);
  final staging = await outputParent.createTemp('.model-assets-staging-');
  try {
    for (final model in models) {
      await _copyFile(
        model.artifactFile,
        File(path.join(staging.path, model.manifest.artifactPath.value)),
      );
      final stagedArtifact = File(
        path.join(staging.path, model.manifest.artifactPath.value),
      );
      if (await stagedArtifact.length() != model.manifest.bytes ||
          await _sha256Of(stagedArtifact) != model.manifest.sha256) {
        return _failure(
          ModelImportFailureReason.stagingFailed,
          modelId: model.manifest.id,
        );
      }
      await _copyFile(
        model.licenseFile,
        File(
          path.join(staging.path, model.manifest.licenseSnapshotPath.value),
        ),
      );
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
    await _writeIndex(staging, models);
    final publishResult = await _publish(staging, request.outputDirectory);
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
) async {
  Directory? backup;
  try {
    if (output.existsSync()) {
      backup = await output.parent.createTemp('.model-assets-backup-');
      await backup.delete();
      await output.rename(backup.path);
    }
    await staging.rename(output.path);
    if (backup != null && backup.existsSync()) {
      await backup.delete(recursive: true);
    }
    return const Ok<void, ModelImportFailure>(null);
  } on FileSystemException {
    if (!output.existsSync() && backup != null && backup.existsSync()) {
      await backup.rename(output.path);
    }
    return _failure(ModelImportFailureReason.publicationFailed);
  }
}

Result<T, ModelImportFailure> _failure<T>(
  ModelImportFailureReason reason, {
  String? modelId,
}) => Err<T, ModelImportFailure>(
  ModelImportFailure(reason: reason, modelId: modelId),
);
