import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/asset_bundle_model_artifact_source.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';

void main() {
  group('AssetBundleModelManifestCatalog', () {
    test('loads a strict typed manifest catalog in index order', () async {
      final bundle = _MemoryAssetBundle({
        '${modelAssetBundleRoot}model_manifests/index.json': _jsonBytes({
          'schemaVersion': 1,
          'manifests': <Object?>[
            'model_manifests/whisper-base-q5_1.json',
          ],
        }),
        '${modelAssetBundleRoot}model_manifests/whisper-base-q5_1.json':
            _jsonBytes(_manifestJson()),
      });

      final result = await AssetBundleModelManifestCatalog(
        bundle: bundle,
      ).load();

      expect(
        result,
        isA<Ok<List<BundledModelManifest>, ModelCatalogFailure>>(),
      );
      final manifests =
          (result as Ok<List<BundledModelManifest>, ModelCatalogFailure>).value;
      expect(manifests, hasLength(1));
      expect(manifests.single.id, 'whisper-base-q5_1');
      expect(manifests.single.engineId, 'whisper_cpp');
      expect(bundle.loadedKeys, <String>[
        '${modelAssetBundleRoot}model_manifests/index.json',
        '${modelAssetBundleRoot}model_manifests/whisper-base-q5_1.json',
      ]);
    });

    test(
      'rejects traversal and duplicate entries before loading them',
      () async {
        for (final entries in <List<Object?>>[
          <Object?>['../private.json'],
          <Object?>[
            'model_manifests/model.json',
            'model_manifests/model.json',
          ],
        ]) {
          final bundle = _MemoryAssetBundle({
            '${modelAssetBundleRoot}model_manifests/index.json': _jsonBytes({
              'schemaVersion': 1,
              'manifests': entries,
            }),
          });

          final result = await AssetBundleModelManifestCatalog(
            bundle: bundle,
          ).load();

          expect(
            result,
            isA<Err<List<BundledModelManifest>, ModelCatalogFailure>>().having(
              (failure) => failure.failure.code,
              'code',
              'model_catalog_invalid',
            ),
          );
        }
      },
    );

    test('maps missing and malformed assets to stable failures', () async {
      final missing = await AssetBundleModelManifestCatalog(
        bundle: _MemoryAssetBundle({}),
      ).load();
      final malformed = await AssetBundleModelManifestCatalog(
        bundle: _MemoryAssetBundle({
          '${modelAssetBundleRoot}model_manifests/index.json':
              Uint8List.fromList(utf8.encode('{not-json')),
        }),
      ).load();

      expect(
        (missing as Err<List<BundledModelManifest>, ModelCatalogFailure>)
            .failure
            .code,
        'model_catalog_missing',
      );
      expect(
        (malformed as Err<List<BundledModelManifest>, ModelCatalogFailure>)
            .failure
            .code,
        'model_catalog_invalid',
      );
    });
  });

  group('AssetBundleModelArtifactSource', () {
    test('opens exact sliced bytes as a fresh stream each time', () async {
      final backing = Uint8List.fromList(<int>[9, 1, 2, 3, 9]);
      final bundle = _MemoryAssetBundle(
        {
          '${modelAssetBundleRoot}models/test/model.bin': backing,
        },
        slices: {
          '${modelAssetBundleRoot}models/test/model.bin': const (1, 3),
        },
      );
      final source = AssetBundleModelArtifactSource(bundle: bundle);
      final path = _path('models/test/model.bin');

      final first = await source.open(path);
      final second = await source.open(path);

      expect(await _bytes(first), <int>[1, 2, 3]);
      expect(await _bytes(second), <int>[1, 2, 3]);
      expect(bundle.loadedKeys, hasLength(2));
    });

    test('emits large artifacts in bounded verification chunks', () async {
      final bundle = _MemoryAssetBundle({
        '${modelAssetBundleRoot}models/test/model.bin': Uint8List(
          64 * 1024 + 1,
        ),
      });
      final source = AssetBundleModelArtifactSource(bundle: bundle);

      final result = await source.open(_path('models/test/model.bin'));
      final artifact =
          (result as Ok<ModelArtifact, ModelArtifactSourceFailure>).value;
      final chunks = await artifact.bytes.toList();

      expect(chunks.map((chunk) => chunk.length), <int>[64 * 1024, 1]);
    });

    test('contains bundle failures without exposing paths', () async {
      final missing = await AssetBundleModelArtifactSource(
        bundle: _MemoryAssetBundle({}),
      ).open(_path('models/private/model.bin'));
      final unreadable = await AssetBundleModelArtifactSource(
        bundle: _MemoryAssetBundle(
          {},
          failure: Exception('/private/files/model.bin'),
        ),
      ).open(_path('models/private/model.bin'));

      expect(
        (missing as Err<ModelArtifact, ModelArtifactSourceFailure>)
            .failure
            .reason,
        ModelArtifactSourceFailureReason.missing,
      );
      expect(
        (unreadable as Err<ModelArtifact, ModelArtifactSourceFailure>)
            .failure
            .reason,
        ModelArtifactSourceFailureReason.unreadable,
      );
      expect(unreadable.toString(), isNot(contains('/private/files')));
    });
  });
}

Future<List<int>> _bytes(
  Result<ModelArtifact, ModelArtifactSourceFailure> result,
) async {
  final artifact =
      (result as Ok<ModelArtifact, ModelArtifactSourceFailure>).value;
  return artifact.bytes.expand((chunk) => chunk).toList();
}

AppRelativePath _path(String value) =>
    (AppRelativePath.tryParse(value)
            as Ok<AppRelativePath, InvalidAppRelativePath>)
        .value;

Uint8List _jsonBytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Map<String, Object?> _manifestJson() => <String, Object?>{
  'schemaVersion': 1,
  'id': 'whisper-base-q5_1',
  'version': 'model-commit',
  'source': 'https://example.test/model.bin',
  'artifactPath': 'models/whisper-base-q5_1/model.bin',
  'sha256': '0000000000000000000000000000000000000000000000000000000000000000',
  'bytes': 3,
  'runtime': <String, Object?>{
    'engineId': 'whisper_cpp',
    'modelFormat': 'ggml',
  },
  'license': <String, Object?>{
    'id': 'MIT',
    'snapshotPath': 'models/licenses/model.txt',
  },
  'capabilities': <Object?>['transcription'],
  'enabledModes': <Object?>['postSession'],
};

final class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(
    this.assets, {
    this.slices = const {},
    this.failure,
  });

  final Map<String, Uint8List> assets;
  final Map<String, (int, int)> slices;
  final Exception? failure;
  final List<String> loadedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    loadedKeys.add(key);
    final configuredFailure = failure;
    if (configuredFailure != null) throw configuredFailure;
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('asset missing');
    final slice = slices[key];
    if (slice == null) return ByteData.sublistView(bytes);
    return ByteData.sublistView(bytes, slice.$1, slice.$1 + slice.$2);
  }
}
