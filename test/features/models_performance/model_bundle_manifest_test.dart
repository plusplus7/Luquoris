import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';

void main() {
  test('serializes full v2 provenance into a durable processing profile', () {
    final input = _bundle();
    final tokenizer = _files(input).last;
    tokenizer['source'] =
        'https://other.test/resolve/$_revision/vocabulary.txt';
    tokenizer['license'] = <String, Object?>{
      'id': 'Apache-2.0',
      'snapshotPath': 'models/licenses/tokenizer-Apache-2.0.txt',
    };
    final manifest =
        (BundledModelManifest.tryParse(input)
                as Ok<BundledModelManifest, InvalidModelManifest>)
            .value;

    final snapshot = manifest.toJson();

    expect(snapshot, input);
    expect(snapshot.containsKey('artifactPath'), isFalse);
    expect(
      (snapshot['runtime']! as Map<String, Object?>)['engineVersion'],
      '1.0.0',
    );
    expect(manifest.artifacts.last.toJson(), tokenizer);
    final frozen = jsonEncode(snapshot);
    final profile = ProcessingModelProfile.tryCreate(
      bundleManifestJson: frozen,
      engineVersion: '1.0.0',
      parametersJson: '{"parameterVersion":1,"language":"zh"}',
    );
    expect(
      profile,
      isA<Ok<ProcessingModelProfile, InvalidProcessingSelection>>(),
    );
    final restored =
        (profile as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
            .value;
    expect(restored.manifest, manifest);
    expect(
      restored.manifest.artifacts.last.source,
      'https://other.test/resolve/$_revision/vocabulary.txt',
    );
    expect(restored.manifest.artifacts.last.licenseId, 'Apache-2.0');
    expect(restored.manifest.sha256, _bundleDigest);

    _files(snapshot).clear();
    (snapshot['runtime']! as Map<String, Object?>)['engineVersion'] = 'changed';
    tokenizer['source'] = 'changed';
    expect(jsonEncode(manifest.toJson()), frozen);
    expect(restored.bundleManifestJson, frozen);
  });

  test(
    'accepts a pinned two-file bundle and preserves its durable identity',
    () {
      final result = BundledModelManifest.tryParse(_bundle());
      expect(result, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
      final manifest =
          (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
      expect(manifest.schemaVersion, 2);
      expect(manifest.bytes, 24);
      expect(manifest.sha256, _bundleDigest);
      expect(manifest.toInstalledModel().sha256, _bundleDigest);
    },
  );

  test('canonical identity does not depend on inventory input order', () {
    final candidate = _bundle();
    candidate['artifacts'] = (candidate['artifacts']! as List<Object?>).reversed
        .toList();
    final result = BundledModelManifest.tryParse(candidate);
    expect(result, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
    final manifest =
        (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
    expect(
      manifest.canonicalInventoryJson,
      '[{"path":"models/test-bundle/encoder.onnx","role":"encoder",'
      '"bytes":16,"sha256":"${'0' * 64}"},'
      '{"path":"models/test-bundle/tokens.txt","role":"tokenizer",'
      '"bytes":8,"sha256":"${'1' * 64}"}]',
    );
    expect(manifest.artifacts.map((file) => file.role), <ModelArtifactRole>[
      ModelArtifactRole.encoder,
      ModelArtifactRole.tokenizer,
    ]);
    expect(manifest.engineVersion, '1.0.0');
  });

  test('rejects a bundle whose aggregate digest omits its tokenizer', () {
    final candidate = _bundle()..['sha256'] = '0' * 64;
    _reject(candidate, 'sha256', ModelManifestFailureReason.invalidSha256);
  });

  test('rejects byte totals that do not cover every required artifact', () {
    _reject(
      _bundle()..['bytes'] = 16,
      'bytes',
      ModelManifestFailureReason.invalidValue,
    );
  });

  test('rejects duplicate artifact paths before allocating a model', () {
    final candidate = _bundle();
    final artifacts = candidate['artifacts']! as List<Object?>;
    artifacts[1] = artifacts[0];
    _reject(
      candidate,
      'artifacts[1]',
      ModelManifestFailureReason.duplicateValue,
    );
  });

  test('rejects an artifact escaping the model bundle namespace', () {
    final candidate = _bundle();
    final artifacts = candidate['artifacts']! as List<Object?>;
    (artifacts[0]! as Map<String, Object?>)['path'] =
        'models/another-model/encoder.onnx';
    _reject(
      candidate,
      'artifacts[0].path',
      ModelManifestFailureReason.unsafePath,
    );
  });

  test('rejects mutable source branches and missing runtime compatibility', () {
    final mutable = _bundle()
      ..['source'] = 'https://example.test/resolve/main/m.json';
    _reject(mutable, 'source', ModelManifestFailureReason.invalidSource);
    final incompatible = _bundle();
    (incompatible['runtime']! as Map<String, Object?>).remove('engineVersion');
    _reject(
      incompatible,
      'runtime.engineVersion',
      ModelManifestFailureReason.invalidValue,
    );
  });

  test('rejects a bundle-level license outside committed model licenses', () {
    final candidate = _bundle();
    (candidate['license']! as Map<String, Object?>)['snapshotPath'] =
        'private/license.txt';
    _reject(
      candidate,
      'license.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
  });

  test('rejects arbitrary branches, unversioned URLs, and query revisions', () {
    for (final source in <String>[
      'https://example.test/resolve/dev/model.onnx',
      'https://example.test/model.onnx',
      'https://example.test/resolve/$_revision/model.onnx?ref=main',
      'https://example.test/resolve/$_revision/../../resolve/main/model.onnx',
      'https://example.test/resolve/$_revision/%2e%2e/model.onnx',
    ]) {
      _reject(
        _bundle()..['source'] = source,
        'source',
        ModelManifestFailureReason.invalidSource,
      );
      final artifact = _bundle();
      _files(artifact).first['source'] = source;
      _reject(
        artifact,
        'artifacts[0].source',
        ModelManifestFailureReason.invalidSource,
      );
    }
  });

  test('rejects actual NUL characters in artifact and license paths', () {
    final artifact = _bundle();
    _files(artifact).first['path'] = 'models/test-bundle/encoder\u0000.onnx';
    _reject(
      artifact,
      'artifacts[0].path',
      ModelManifestFailureReason.unsafePath,
    );
    final license = _bundle();
    (license['license']! as Map<String, Object?>)['snapshotPath'] =
        'models/licenses/test\u0000.txt';
    _reject(
      license,
      'license.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
    final fileLicense = _bundle();
    (_files(fileLicense).first['license']!
            as Map<String, Object?>)['snapshotPath'] =
        'models/licenses/test\u0000.txt';
    _reject(
      fileLicense,
      'artifacts[0].license.snapshotPath',
      ModelManifestFailureReason.unsafePath,
    );
  });

  test('rejects noninteger schema revisions', () {
    expect(
      BundledModelManifest.tryParse(_bundle()..['schemaVersion'] = 2.0),
      isA<Err<BundledModelManifest, InvalidModelManifest>>(),
    );
  });

  test('rejects byte counts outside the portable integer range', () {
    final candidate = _bundle();
    _files(candidate).first['bytes'] = 9223372036854775807;
    _reject(
      candidate,
      'artifacts[0].bytes',
      ModelManifestFailureReason.invalidValue,
    );
  });

  test('canonical digest uses unescaped UTF-8 and lexical path ordering', () {
    final candidate = _bundle()
      ..['sha256'] =
          '3ccbc6215c91484d88ff4a88ccfd5962bc63a142dd7c83e8219f6b0e4551d059';
    _files(candidate).first['path'] = 'models/test-bundle/编码器.onnx';
    final result = BundledModelManifest.tryParse(candidate);
    expect(result, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
    final manifest =
        (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
    expect(manifest.canonicalInventoryJson, contains('编码器.onnx'));
    expect(manifest.artifacts.first.role, ModelArtifactRole.tokenizer);
  });

  test(
    'parsed inventory is independent of mutable input and cannot mutate',
    () {
      final candidate = _bundle();
      final result = BundledModelManifest.tryParse(candidate);
      final manifest =
          (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
      _files(candidate).first['bytes'] = 999;
      _files(candidate).clear();
      expect(manifest.artifacts.first.bytes, 16);
      expect(manifest.artifacts, hasLength(2));
      expect(manifest.artifacts.clear, throwsUnsupportedError);
    },
  );

  test('rejects duplicate roles even at distinct safe paths', () {
    final candidate = _bundle();
    _files(candidate).last['role'] = 'encoder';
    _reject(
      candidate,
      'artifacts[1]',
      ModelManifestFailureReason.duplicateValue,
    );
  });

  test('rejects empty inventory and unknown artifact/license fields', () {
    _reject(
      _bundle()..['artifacts'] = <Object?>[],
      'artifacts',
      ModelManifestFailureReason.emptyCollection,
    );
    final unknown = _bundle();
    _files(unknown).first['download'] = true;
    _reject(
      unknown,
      'artifacts[0].download',
      ModelManifestFailureReason.unknownField,
    );
    final license = _bundle();
    (_files(license).first['license']! as Map<String, Object?>)['extra'] = true;
    _reject(
      license,
      'artifacts[0].license.extra',
      ModelManifestFailureReason.unknownField,
    );
  });

  test('rejects malformed artifacts and invalid individual digests', () {
    final malformed = _bundle();
    (malformed['artifacts']! as List<Object?>)[0] = 'encoder.onnx';
    _reject(malformed, 'artifacts[0]', ModelManifestFailureReason.invalidShape);
    final digest = _bundle();
    _files(digest).first['sha256'] = 'A' * 64;
    _reject(
      digest,
      'artifacts[0].sha256',
      ModelManifestFailureReason.invalidSha256,
    );
    final bytes = _bundle();
    _files(bytes).first['bytes'] = 0;
    _reject(
      bytes,
      'artifacts[0].bytes',
      ModelManifestFailureReason.invalidValue,
    );
  });

  test('checked byte sum rejects a portable-range overflow', () {
    final candidate = _bundle();
    _files(candidate).first['bytes'] = 9007199254740991;
    _reject(candidate, 'bytes', ModelManifestFailureReason.invalidValue);
  });

  test('v1 remains a singleton artifact with its original durable digest', () {
    final candidate = _bundle()
      ..['schemaVersion'] = 1
      ..['artifactPath'] = 'models/test-bundle/legacy.bin'
      ..remove('artifacts');
    (candidate['runtime']! as Map<String, Object?>).remove('engineVersion');
    final result = BundledModelManifest.tryParse(candidate);
    final manifest =
        (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
    expect(manifest.artifacts.single.role, ModelArtifactRole.model);
    expect(manifest.artifacts.single.sha256, _bundleDigest);
    expect(manifest.sha256, _bundleDigest);
    expect(manifest.engineVersion, isNull);
  });
}

const _revision = '0123456789abcdef0123456789abcdef01234567';

List<Map<String, Object?>> _files(Map<String, Object?> bundle) =>
    (bundle['artifacts']! as List<Object?>).cast<Map<String, Object?>>();

void _reject(
  Map<String, Object?> candidate,
  String field,
  ModelManifestFailureReason reason,
) {
  final result = BundledModelManifest.tryParse(candidate);
  expect(result, isA<Err<BundledModelManifest, InvalidModelManifest>>());
  final failure =
      (result as Err<BundledModelManifest, InvalidModelManifest>).failure;
  expect(failure, InvalidModelManifest(field: field, reason: reason));
}

const _bundleDigest =
    'd2531478b5050f8ca5375c97cb2e94aff565e057f4ef4ae4c2c79a5c9b41a1c8';

Map<String, Object?> _bundle() => <String, Object?>{
  'schemaVersion': 2,
  'id': 'test-bundle',
  'version': '0123456789abcdef0123456789abcdef01234567',
  'source':
      'https://example.test/resolve/'
      '0123456789abcdef0123456789abcdef01234567/manifest.json',
  'sha256': _bundleDigest,
  'bytes': 24,
  'runtime': <String, Object?>{
    'engineId': 'sherpa_onnx',
    'engineVersion': '1.0.0',
    'modelFormat': 'onnx',
  },
  'license': _license(),
  'artifacts': <Object?>[
    _artifact('encoder.onnx', 'encoder', 16, '0' * 64),
    _artifact('tokens.txt', 'tokenizer', 8, '1' * 64),
  ],
  'capabilities': <Object?>['transcription'],
  'enabledModes': <Object?>['balanced', 'postSession'],
};

Map<String, Object?> _artifact(
  String filename,
  String role,
  int bytes,
  String digest,
) => <String, Object?>{
  'path': 'models/test-bundle/$filename',
  'role': role,
  'bytes': bytes,
  'sha256': digest,
  'source':
      'https://example.test/resolve/'
      '0123456789abcdef0123456789abcdef01234567/$filename',
  'license': _license(),
};

Map<String, Object?> _license() => <String, Object?>{
  'id': 'MIT',
  'snapshotPath': 'models/licenses/test-MIT.txt',
};
