import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/services/service_contracts.dart';

import '../../../support/model_bundle_fixture.dart';

void main() {
  test(
    'runtime verifies every bundle artifact instead of aggregate as a file',
    () async {
      final source = _Source();
      final result = await _manager(source).verify('test-bundle');
      expect(result, isA<Ok<ModelDescriptor, ModelFailure>>());
      expect(source.opened.toSet(), modelBundleFiles.keys.toSet());
    },
  );

  for (final filename in modelBundleFiles.keys) {
    test('runtime rejects absent $filename', () async {
      final result = await _manager(
        _Source()..missing = filename,
      ).verify('test-bundle');
      _failure(result, 'model_artifact_missing');
    });
    test('runtime rejects corrupt $filename', () async {
      final result = await _manager(
        _Source()..corrupt = filename,
      ).verify('test-bundle');
      _failure(result, 'model_sha256_mismatch');
    });
  }
}

RuntimeModelManager _manager(_Source source) {
  final manifest =
      (BundledModelManifest.tryParse(modelBundleFixture())
              as Ok<BundledModelManifest, InvalidModelManifest>)
          .value;
  return RuntimeModelManager(
    manifests: <BundledModelManifest>[manifest],
    artifactSource: source,
  );
}

void _failure(Result<ModelDescriptor, ModelFailure> result, String reason) {
  expect(result, isA<Err<ModelDescriptor, ModelFailure>>());
  expect((result as Err<ModelDescriptor, ModelFailure>).failure.code, reason);
}

final class _Source implements ModelArtifactSource {
  String? missing;
  String? corrupt;
  final opened = <String>[];

  @override
  Future<Result<ModelArtifact, ModelArtifactSourceFailure>> open(
    AppRelativePath artifactPath,
  ) async {
    final filename = artifactPath.value.split('/').last;
    opened.add(filename);
    if (filename == missing) {
      return const Err(
        ModelArtifactSourceFailure(ModelArtifactSourceFailureReason.missing),
      );
    }
    final bytes = modelBundleFiles[filename]!;
    return Ok(
      ModelArtifact(
        Stream.value(
          filename == corrupt ? List<int>.filled(bytes.length, 99) : bytes,
        ),
      ),
    );
  }
}
