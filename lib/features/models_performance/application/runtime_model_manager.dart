import 'package:crypto/crypto.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:meta/meta.dart';

/// Reasons an immutable bundled artifact cannot be opened for verification.
enum ModelArtifactSourceFailureReason {
  /// No regular artifact exists at the declared bundled path.
  missing,

  /// The artifact exists but its bytes cannot be read safely.
  unreadable,
}

/// Privacy-safe failure returned by a bundled [ModelArtifactSource].
@immutable
final class ModelArtifactSourceFailure implements Failure {
  /// Creates a source failure without retaining a private path or exception.
  const ModelArtifactSourceFailure(this.reason);

  /// Stable machine-actionable failure category.
  final ModelArtifactSourceFailureReason reason;

  @override
  String get code => 'model_artifact_source.${reason.name}';
}

/// One freshly opened, single-subscription stream of immutable model bytes.
final class ModelArtifact {
  /// Creates an artifact backed by [bytes].
  const ModelArtifact(this.bytes);

  /// Exact artifact bytes, emitted in bounded chunks.
  final Stream<List<int>> bytes;
}

/// Supplies immutable bundled artifacts without exposing filesystem paths.
///
/// Implementations must return a fresh [ModelArtifact] for each call. The
/// artifact associated with a path must not change during this source's
/// lifetime, which permits successful and failed verification to be cached.
// The interface keeps packaged-asset and test sources replaceable.
// ignore: one_member_abstracts
abstract interface class ModelArtifactSource {
  /// Opens the artifact declared at [artifactPath].
  Future<Result<ModelArtifact, ModelArtifactSourceFailure>> open(
    AppRelativePath artifactPath,
  );
}

/// Verifies bundled models independently before an AI engine may load them.
///
/// A failure is scoped to the requested model. Canonical audio capture does
/// not depend on this service and therefore remains available when AI assets
/// are absent or corrupt.
final class RuntimeModelManager implements ModelManager {
  /// Creates a manager for typed [manifests] and one immutable artifact source.
  factory RuntimeModelManager({
    required List<BundledModelManifest> manifests,
    required ModelArtifactSource artifactSource,
  }) => RuntimeModelManager._(manifests, artifactSource);

  RuntimeModelManager._(
    List<BundledModelManifest> manifests,
    this._artifactSource,
  ) {
    final byId = <String, BundledModelManifest>{};
    final duplicates = <String>{};
    for (final manifest in manifests) {
      if (byId.containsKey(manifest.id)) duplicates.add(manifest.id);
      byId[manifest.id] = manifest;
    }
    _manifests = Map<String, BundledModelManifest>.unmodifiable(byId);
    _duplicateIds = Set<String>.unmodifiable(duplicates);
  }

  final ModelArtifactSource _artifactSource;
  late final Map<String, BundledModelManifest> _manifests;
  late final Set<String> _duplicateIds;
  final Map<String, Future<Result<ModelDescriptor, ModelFailure>>>
  _verifications = <String, Future<Result<ModelDescriptor, ModelFailure>>>{};

  @override
  Future<Result<ModelInventory, ModelFailure>> listInstalled() async {
    if (_duplicateIds.isNotEmpty) {
      return const Err<ModelInventory, ModelFailure>(
        ModelUnavailable('model_manifest_duplicate'),
      );
    }
    final descriptors = _manifests.values.map(_descriptor).toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return Ok<ModelInventory, ModelFailure>(
      ModelInventory(models: descriptors),
    );
  }

  @override
  Future<Result<ModelDescriptor, ModelFailure>> verify(String modelId) {
    if (_duplicateIds.contains(modelId)) {
      return Future<Result<ModelDescriptor, ModelFailure>>.value(
        const Err<ModelDescriptor, ModelFailure>(
          ModelUnavailable('model_manifest_duplicate'),
        ),
      );
    }
    final manifest = _manifests[modelId];
    if (manifest == null) {
      return Future<Result<ModelDescriptor, ModelFailure>>.value(
        const Err<ModelDescriptor, ModelFailure>(
          ModelUnavailable('model_not_declared'),
        ),
      );
    }
    return _verifications.putIfAbsent(
      modelId,
      () => _verifyManifest(manifest),
    );
  }

  Future<Result<ModelDescriptor, ModelFailure>> _verifyManifest(
    BundledModelManifest manifest,
  ) async {
    Result<ModelArtifact, ModelArtifactSourceFailure> opened;
    try {
      opened = await _artifactSource.open(manifest.artifactPath);
    } on Object {
      return _unavailable('model_artifact_unreadable');
    }
    if (opened case Err(:final failure)) {
      return _unavailable(
        switch (failure.reason) {
          ModelArtifactSourceFailureReason.missing => 'model_artifact_missing',
          ModelArtifactSourceFailureReason.unreadable =>
            'model_artifact_unreadable',
        },
      );
    }
    final artifact =
        (opened as Ok<ModelArtifact, ModelArtifactSourceFailure>).value;
    var observedBytes = 0;
    try {
      final digest = await sha256
          .bind(
            artifact.bytes.map((chunk) {
              observedBytes += chunk.length;
              return chunk;
            }),
          )
          .first;
      if (observedBytes != manifest.bytes) {
        return _unavailable('model_bytes_mismatch');
      }
      if (digest.toString() != manifest.sha256) {
        return _unavailable('model_sha256_mismatch');
      }
    } on Object {
      return _unavailable('model_artifact_unreadable');
    }
    return Ok<ModelDescriptor, ModelFailure>(_descriptor(manifest));
  }
}

ModelDescriptor _descriptor(BundledModelManifest manifest) => ModelDescriptor(
  id: manifest.id,
  version: manifest.version,
  bytes: manifest.bytes,
);

Result<ModelDescriptor, ModelFailure> _unavailable(String code) =>
    Err<ModelDescriptor, ModelFailure>(ModelUnavailable(code));
