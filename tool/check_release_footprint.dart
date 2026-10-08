import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'release_size/release_footprint_policy.dart';

const _usageFailure = 'release_footprint.usage';

/// Measures release artifacts and evaluates the exact-byte production gate.
Future<int> runReleaseFootprintCommand(
  List<String> arguments, {
  required Directory projectRoot,
  required void Function(String) writeOutput,
  required void Function(String) writeError,
}) async {
  try {
    final request = _parseArguments(arguments);
    final rootPath = projectRoot.resolveSymbolicLinksSync();
    final seenLabels = <String>{};
    final seenPaths = <String>{};
    final artifactRequests = <_ArtifactRequest>[
      _ArtifactRequest(
        kind: ReleaseArtifactKind.aab,
        label: 'release-bundle',
        inputPath: request.aabPath,
      ),
      ...request.apks,
    ];
    for (final artifact in artifactRequests) {
      if (!seenLabels.add(artifact.label) ||
          !seenPaths.add(path.normalize(artifact.inputPath))) {
        throw const _CliFailure('release_footprint.artifact_duplicated');
      }
    }

    final artifacts = <ReleaseArtifactMeasurement>[];
    for (final artifact in artifactRequests) {
      artifacts.add(
        await _measureArtifact(
          rootPath: rootPath,
          request: artifact,
        ),
      );
    }

    final installed = request.installedMeasurementPath == null
        ? null
        : await _readInstalledMeasurement(
            rootPath,
            request.installedMeasurementPath!,
          );
    final report = ReleaseFootprintReport(
      schemaVersion: 1,
      buildId: installed?.buildId ?? 'unverified',
      artifacts: artifacts,
      installedMeasurement: installed?.measurement,
    );
    final decision = evaluateReleaseFootprint(report);
    final document = <String, Object?>{
      ...report.toCanonicalJson(),
      'decision': decision.toCanonicalJson(),
    };
    final encoded = jsonEncode(document);
    final outputFile = _resolveOutputFile(rootPath, request.outputPath);
    await _writeAtomically(outputFile, '$encoded\n');
    writeOutput(encoded);

    return switch (decision.status) {
      ReleaseFootprintStatus.passed => 0,
      ReleaseFootprintStatus.failed => _reportGateError(
        writeError,
        'release_footprint.gate_failed',
      ),
      ReleaseFootprintStatus.incomplete => _reportGateError(
        writeError,
        'release_footprint.gate_incomplete',
      ),
    };
  } on _CliFailure catch (failure) {
    writeError(failure.code);
    return 64;
  } on FileSystemException {
    writeError('release_footprint.io_failed');
    return 74;
  } on FormatException {
    writeError('release_footprint.installed_measurement_invalid');
    return 64;
  }
}

int _reportGateError(
  void Function(String) writeError,
  String code,
) {
  writeError(code);
  return 1;
}

_CliRequest _parseArguments(List<String> arguments) {
  final apks = <_ArtifactRequest>[];
  String? aabPath;
  String? installedMeasurementPath;
  String? outputPath;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw const _CliFailure(_usageFailure);
    }
    final flag = arguments[index];
    final value = arguments[index + 1];
    if (value.isEmpty) throw const _CliFailure(_usageFailure);
    switch (flag) {
      case '--apk':
        final separator = value.indexOf('=');
        if (separator <= 0 || separator == value.length - 1) {
          throw const _CliFailure(_usageFailure);
        }
        final label = value.substring(0, separator);
        if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(label)) {
          throw const _CliFailure(_usageFailure);
        }
        apks.add(
          _ArtifactRequest(
            kind: ReleaseArtifactKind.apk,
            label: label,
            inputPath: value.substring(separator + 1),
          ),
        );
      case '--aab':
        if (aabPath != null) {
          throw const _CliFailure('release_footprint.artifact_duplicated');
        }
        aabPath = value;
      case '--installed-measurement':
        if (installedMeasurementPath != null) {
          throw const _CliFailure(_usageFailure);
        }
        installedMeasurementPath = value;
      case '--output':
        if (outputPath != null) throw const _CliFailure(_usageFailure);
        outputPath = value;
      default:
        throw const _CliFailure(_usageFailure);
    }
  }
  if (apks.isEmpty || aabPath == null || outputPath == null) {
    throw const _CliFailure(_usageFailure);
  }
  return _CliRequest(
    apks: apks,
    aabPath: aabPath,
    installedMeasurementPath: installedMeasurementPath,
    outputPath: outputPath,
  );
}

Future<ReleaseArtifactMeasurement> _measureArtifact({
  required String rootPath,
  required _ArtifactRequest request,
}) async {
  final file = _resolveRegularFile(rootPath, request.inputPath);
  final before = file.statSync();
  final digest = await sha256.bind(file.openRead()).first;
  final after = file.statSync();
  if (!_sameFileState(before, after)) {
    throw const _CliFailure('release_footprint.artifact_changed');
  }
  return ReleaseArtifactMeasurement(
    kind: request.kind,
    label: request.label,
    relativePath: path.posix.joinAll(
      path.relative(file.path, from: rootPath).split(Platform.pathSeparator),
    ),
    bytes: after.size,
    sha256: digest.toString(),
  );
}

bool _sameFileState(FileStat before, FileStat after) =>
    before.type == FileSystemEntityType.file &&
    after.type == FileSystemEntityType.file &&
    before.size == after.size &&
    before.modified == after.modified &&
    before.changed == after.changed;

Future<_InstalledInput> _readInstalledMeasurement(
  String rootPath,
  String inputPath,
) async {
  final file = _resolveRegularFile(rootPath, inputPath);
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?> || decoded['schemaVersion'] != 1) {
    throw const FormatException('invalid installed measurement');
  }
  return _InstalledInput(
    buildId: _requiredString(decoded, 'buildId'),
    measurement: InstalledFootprintMeasurement(
      packageName: _requiredString(decoded, 'packageName'),
      versionCode: _requiredInt(decoded, 'versionCode'),
      deviceSerial: _requiredString(decoded, 'deviceSerial'),
      deviceModel: _requiredString(decoded, 'deviceModel'),
      buildFingerprint: _requiredString(decoded, 'buildFingerprint'),
      observedAtUtc: _requiredString(decoded, 'observedAtUtc'),
      cleanInstall: _requiredBool(decoded, 'cleanInstall'),
      installedApkSha256: _requiredString(decoded, 'installedApkSha256'),
      appBytes: _requiredInt(decoded, 'appBytes'),
      dataBytes: _requiredInt(decoded, 'dataBytes'),
      cacheBytes: _requiredInt(decoded, 'cacheBytes'),
    ),
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('invalid string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw const FormatException('invalid integer');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw const FormatException('invalid boolean');
  return value;
}

File _resolveRegularFile(String rootPath, String inputPath) {
  final candidate = File(
    path.normalize(
      path.isAbsolute(inputPath) ? inputPath : path.join(rootPath, inputPath),
    ),
  );
  if (FileSystemEntity.typeSync(candidate.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const _CliFailure('release_footprint.artifact_not_regular');
  }
  final resolved = candidate.resolveSymbolicLinksSync();
  if (!_isWithinRoot(rootPath, resolved)) {
    throw const _CliFailure('release_footprint.path_outside_project');
  }
  return File(resolved);
}

File _resolveOutputFile(String rootPath, String outputPath) {
  final absolute = path.normalize(
    path.isAbsolute(outputPath) ? outputPath : path.join(rootPath, outputPath),
  );
  if (!_isWithinRoot(rootPath, absolute)) {
    throw const _CliFailure('release_footprint.path_outside_project');
  }
  final type = FileSystemEntity.typeSync(absolute, followLinks: false);
  if (type == FileSystemEntityType.link ||
      (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file)) {
    throw const _CliFailure('release_footprint.output_not_regular');
  }
  return File(absolute);
}

bool _isWithinRoot(String rootPath, String candidate) =>
    path.equals(rootPath, candidate) || path.isWithin(rootPath, candidate);

Future<void> _writeAtomically(File output, String contents) async {
  await output.parent.create(recursive: true);
  final temporary = File('${output.path}.tmp');
  if (FileSystemEntity.typeSync(temporary.path, followLinks: false) !=
          FileSystemEntityType.notFound &&
      FileSystemEntity.typeSync(temporary.path, followLinks: false) !=
          FileSystemEntityType.file) {
    throw const _CliFailure('release_footprint.output_not_regular');
  }
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(output.path);
}

final class _CliRequest {
  const _CliRequest({
    required this.apks,
    required this.aabPath,
    required this.installedMeasurementPath,
    required this.outputPath,
  });

  final List<_ArtifactRequest> apks;
  final String aabPath;
  final String? installedMeasurementPath;
  final String outputPath;
}

final class _ArtifactRequest {
  const _ArtifactRequest({
    required this.kind,
    required this.label,
    required this.inputPath,
  });

  final ReleaseArtifactKind kind;
  final String label;
  final String inputPath;
}

final class _InstalledInput {
  const _InstalledInput({required this.buildId, required this.measurement});

  final String buildId;
  final InstalledFootprintMeasurement measurement;
}

final class _CliFailure implements Exception {
  const _CliFailure(this.code);

  final String code;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runReleaseFootprintCommand(
    arguments,
    projectRoot: Directory.current,
    writeOutput: stdout.writeln,
    writeError: stderr.writeln,
  );
}
