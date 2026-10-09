import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';

/// Flutter asset key prefix containing the verified generated model tree.
const String modelAssetBundleRoot = 'build/generated/model_assets/';

/// Stable catalog-loading failure that never retains asset contents or paths.
@immutable
final class ModelCatalogFailure implements Failure {
  /// Creates a privacy-safe failure with [code].
  const ModelCatalogFailure(this.code);

  @override
  final String code;
}

/// Loads the generated model index and parses every manifest into domain data.
final class AssetBundleModelManifestCatalog {
  /// Creates a catalog backed by [bundle].
  const AssetBundleModelManifestCatalog({
    required this.bundle,
    this.assetRoot = modelAssetBundleRoot,
  });

  /// Flutter asset bundle containing the generated model tree.
  final AssetBundle bundle;

  /// Prefix prepended to generated-tree relative paths.
  final String assetRoot;

  /// Loads a strict immutable catalog without throwing for invalid assets.
  Future<Result<List<BundledModelManifest>, ModelCatalogFailure>> load() async {
    final indexResult = await _loadJson('model_manifests/index.json');
    if (indexResult case Err(:final failure)) return Err(failure);
    final index = (indexResult as Ok<Object?, ModelCatalogFailure>).value;
    final manifestPaths = _parseIndex(index);
    if (manifestPaths == null) {
      return const Err(ModelCatalogFailure('model_catalog_invalid'));
    }
    final manifests = <BundledModelManifest>[];
    for (final path in manifestPaths) {
      final manifestResult = await _loadJson(path.value);
      if (manifestResult case Err(:final failure)) return Err(failure);
      final parsed = BundledModelManifest.tryParse(
        (manifestResult as Ok<Object?, ModelCatalogFailure>).value,
      );
      if (parsed case Err()) {
        return const Err(ModelCatalogFailure('model_catalog_invalid'));
      }
      manifests.add(
        (parsed as Ok<BundledModelManifest, InvalidModelManifest>).value,
      );
    }
    return Ok(List<BundledModelManifest>.unmodifiable(manifests));
  }

  Future<Result<Object?, ModelCatalogFailure>> _loadJson(
    String relativePath,
  ) async {
    try {
      final data = await bundle.load('$assetRoot$relativePath');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return Ok(jsonDecode(utf8.decode(bytes)));
      // AssetBundle reports an absent key as FlutterError by contract.
      // ignore: avoid_catching_errors
    } on FlutterError {
      return const Err(ModelCatalogFailure('model_catalog_missing'));
    } on FormatException {
      return const Err(ModelCatalogFailure('model_catalog_invalid'));
    } on Object {
      return const Err(ModelCatalogFailure('model_catalog_unreadable'));
    }
  }
}

List<AppRelativePath>? _parseIndex(Object? candidate) {
  if (candidate is! Map<String, Object?> ||
      candidate.length != 2 ||
      candidate['schemaVersion'] != 1 ||
      candidate['manifests'] is! List<Object?>) {
    return null;
  }
  final paths = <AppRelativePath>[];
  final seen = <String>{};
  for (final entry in candidate['manifests']! as List<Object?>) {
    if (entry is! String ||
        !entry.startsWith('model_manifests/') ||
        !entry.endsWith('.json') ||
        !seen.add(entry)) {
      return null;
    }
    final result = AppRelativePath.tryParse(entry);
    if (result case Err()) return null;
    paths.add((result as Ok<AppRelativePath, InvalidAppRelativePath>).value);
  }
  return paths.isEmpty ? null : List<AppRelativePath>.unmodifiable(paths);
}

/// Reads a verified packaged model artifact through a Flutter [AssetBundle].
final class AssetBundleModelArtifactSource implements ModelArtifactSource {
  /// Creates a source backed by [bundle].
  const AssetBundleModelArtifactSource({
    required this.bundle,
    this.assetRoot = modelAssetBundleRoot,
  });

  /// Flutter asset bundle containing the generated model tree.
  final AssetBundle bundle;

  /// Prefix prepended to manifest-declared relative paths.
  final String assetRoot;

  @override
  Future<Result<ModelArtifact, ModelArtifactSourceFailure>> open(
    AppRelativePath artifactPath,
  ) async {
    try {
      final data = await bundle.load('$assetRoot${artifactPath.value}');
      return Ok(ModelArtifact(_boundedChunks(data)));
      // AssetBundle reports an absent key as FlutterError by contract.
      // ignore: avoid_catching_errors
    } on FlutterError {
      return const Err(
        ModelArtifactSourceFailure(ModelArtifactSourceFailureReason.missing),
      );
    } on Object {
      return const Err(
        ModelArtifactSourceFailure(
          ModelArtifactSourceFailureReason.unreadable,
        ),
      );
    }
  }
}

Stream<List<int>> _boundedChunks(ByteData data) async* {
  final bytes = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  const chunkBytes = 64 * 1024;
  for (var offset = 0; offset < bytes.length; offset += chunkBytes) {
    final candidateEnd = offset + chunkBytes;
    final end = candidateEnd < bytes.length ? candidateEnd : bytes.length;
    yield Uint8List.sublistView(bytes, offset, end);
  }
}
