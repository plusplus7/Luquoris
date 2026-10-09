import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';

import '../../tool/model_import/model_importer.dart';

void main() {
  test('repository pins the reviewed multilingual base q5 model', () async {
    final manifestFile = File(
      'models/manifests/whisper-base-q5_1.json',
    );
    expect(manifestFile.existsSync(), isTrue);

    final parsed = BundledModelManifest.tryParse(
      jsonDecode(await manifestFile.readAsString()),
    );

    expect(parsed, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
    final manifest =
        (parsed as Ok<BundledModelManifest, InvalidModelManifest>).value;
    expect(manifest.schemaVersion, 1);
    expect(manifest.id, 'whisper-base-q5_1');
    expect(manifest.version, 'f281eb45af861ab5e5297d23694b7d46e090c02c');
    expect(
      manifest.source,
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/'
      'f281eb45af861ab5e5297d23694b7d46e090c02c/'
      'ggml-base-q5_1.bin',
    );
    expect(
      manifest.artifactPath.value,
      'models/whisper-base-q5_1/ggml-base-q5_1.bin',
    );
    expect(
      manifest.sha256,
      '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898',
    );
    expect(manifest.bytes, 59707625);
    expect(manifest.engineId, 'whisper_cpp');
    expect(manifest.modelFormat, 'ggml');
    expect(manifest.licenseId, 'MIT');
    expect(
      manifest.licenseSnapshotPath.value,
      'models/licenses/openai-whisper-model-MIT.txt',
    );
    expect(manifest.capabilities, <ModelCapability>[
      ModelCapability.transcription,
    ]);
    expect(manifest.enabledModes, <PerformanceMode>[
      PerformanceMode.postSession,
    ]);
    expect(File(manifest.licenseSnapshotPath.value).lengthSync(), greaterThan(0));
  });

  late Directory projectRoot;

  setUp(() async {
    projectRoot = await Directory.systemTemp.createTemp(
      'loquiris-model-import-',
    );
    await Directory(
      '${projectRoot.path}/models/manifests',
    ).create(recursive: true);
    await Directory(
      '${projectRoot.path}/models/licenses',
    ).create(recursive: true);
    await Directory(
      '${projectRoot.path}/models/local',
    ).create(recursive: true);
  });

  tearDown(() => projectRoot.delete(recursive: true));

  test('imports verified models and writes a deterministic index', () async {
    await _writeModel(projectRoot, id: 'zeta-model', bytes: <int>[4, 5, 6]);
    await _writeModel(projectRoot, id: 'alpha-model', bytes: <int>[1, 2, 3]);

    final result = await importModels(_request(projectRoot));

    expect(result, isA<Ok<ModelImportSummary, ModelImportFailure>>());
    final summary =
        (result as Ok<ModelImportSummary, ModelImportFailure>).value;
    expect(summary.modelIds, <String>['alpha-model', 'zeta-model']);
    expect(summary.totalBytes, 6);
    final output = '${projectRoot.path}/build/generated/model_assets';
    expect(
      await File('$output/models/alpha-model/model.bin').readAsBytes(),
      <int>[1, 2, 3],
    );
    expect(
      await File('$output/models/licenses/alpha-model.txt').readAsString(),
      'MIT license for alpha-model\n',
    );
    expect(
      File('$output/model_manifests/alpha-model.json').existsSync(),
      isTrue,
    );
    expect(
      jsonDecode(
        await File('$output/model_manifests/index.json').readAsString(),
      ),
      <String, Object?>{
        'schemaVersion': 1,
        'manifests': <Object?>[
          'model_manifests/alpha-model.json',
          'model_manifests/zeta-model.json',
        ],
      },
    );
  });

  test('rejects a hash mismatch without replacing prior output', () async {
    await _writeModel(
      projectRoot,
      id: 'broken-model',
      bytes: <int>[1, 2, 3],
      declaredSha256: 'a' * 64,
    );
    final sentinel = File(
      '${projectRoot.path}/build/generated/model_assets/prior.txt',
    );
    await sentinel.create(recursive: true);
    await sentinel.writeAsString('keep');

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.artifactSha256Mismatch);
    expect(await sentinel.readAsString(), 'keep');
    expect(
      File(
        '${projectRoot.path}/build/generated/model_assets/'
        'model_manifests/index.json',
      ).existsSync(),
      isFalse,
    );
  });

  test('rejects an artifact byte-length mismatch', () async {
    await _writeModel(
      projectRoot,
      id: 'broken-model',
      bytes: <int>[1, 2, 3],
      declaredBytes: 4,
    );

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.artifactBytesMismatch);
  });

  test('rejects an invalid manifest before staging', () async {
    await File(
      '${projectRoot.path}/models/manifests/broken.json',
    ).writeAsString('{"schemaVersion":2}');

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.invalidManifest);
  });

  test('rejects a missing license snapshot', () async {
    await _writeModel(projectRoot, id: 'missing-license', bytes: <int>[1]);
    await File(
      '${projectRoot.path}/models/licenses/missing-license.txt',
    ).delete();

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.licenseSnapshotMissing);
  });

  test('rejects duplicate model identifiers', () async {
    await _writeModel(projectRoot, id: 'duplicate', bytes: <int>[1]);
    final original = File(
      '${projectRoot.path}/models/manifests/duplicate.json',
    );
    await original.copy(
      '${projectRoot.path}/models/manifests/duplicate-copy.json',
    );

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.duplicateModelId);
  });

  test('rejects model and license destinations outside fixed roots', () async {
    await _writeModel(
      projectRoot,
      id: 'wrong-layout',
      bytes: <int>[1],
      artifactPath: 'weights/wrong-layout.bin',
    );

    final result = await importModels(_request(projectRoot));

    _expectFailure(result, ModelImportFailureReason.invalidArtifactLayout);
  });

  test('rejects generated output outside the ignored build tree', () async {
    await _writeModel(projectRoot, id: 'valid-model', bytes: <int>[1]);
    final request = ModelImportRequest(
      projectRoot: projectRoot,
      manifestDirectory: Directory(
        '${projectRoot.path}/models/manifests',
      ),
      artifactDirectory: Directory('${projectRoot.path}/models/local'),
      outputDirectory: Directory('${projectRoot.path}/assets/models'),
    );

    final result = await importModels(request);

    _expectFailure(result, ModelImportFailureReason.outputOutsideBuild);
  });
}

ModelImportRequest _request(Directory projectRoot) => ModelImportRequest(
  projectRoot: projectRoot,
  manifestDirectory: Directory('${projectRoot.path}/models/manifests'),
  artifactDirectory: Directory('${projectRoot.path}/models/local'),
  outputDirectory: Directory(
    '${projectRoot.path}/build/generated/model_assets',
  ),
);

Future<void> _writeModel(
  Directory projectRoot, {
  required String id,
  required List<int> bytes,
  String? declaredSha256,
  int? declaredBytes,
  String? artifactPath,
}) async {
  final resolvedArtifactPath = artifactPath ?? 'models/$id/model.bin';
  final artifact = File(
    '${projectRoot.path}/models/local/$id/model.bin',
  );
  await artifact.create(recursive: true);
  await artifact.writeAsBytes(bytes, flush: true);
  final license = File('${projectRoot.path}/models/licenses/$id.txt');
  await license.writeAsString('MIT license for $id\n', flush: true);
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'version': '1.0.0',
    'source': 'https://example.test/models/$id/1.0.0/model.bin',
    'artifactPath': resolvedArtifactPath,
    'sha256': declaredSha256 ?? sha256.convert(bytes).toString(),
    'bytes': declaredBytes ?? bytes.length,
    'runtime': <String, Object?>{
      'engineId': 'test-engine',
      'modelFormat': 'test-format',
    },
    'license': <String, Object?>{
      'id': 'MIT',
      'snapshotPath': 'models/licenses/$id.txt',
    },
    'capabilities': <Object?>['transcription'],
    'enabledModes': <Object?>['postSession'],
  };
  await File(
    '${projectRoot.path}/models/manifests/$id.json',
  ).writeAsString('${jsonEncode(manifest)}\n', flush: true);
}

void _expectFailure(
  Result<ModelImportSummary, ModelImportFailure> result,
  ModelImportFailureReason reason,
) {
  expect(result, isA<Err<ModelImportSummary, ModelImportFailure>>());
  expect(
    (result as Err<ModelImportSummary, ModelImportFailure>).failure.reason,
    reason,
  );
}
