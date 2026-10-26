import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';

void main() {
  test('serializes a lossless v1 snapshot without v2-only fields', () {
    final input = _validManifest();
    final manifest =
        (BundledModelManifest.tryParse(input)
                as Ok<BundledModelManifest, InvalidModelManifest>)
            .value;

    final snapshot = manifest.toJson();

    expect(snapshot, _validManifest());
    expect(snapshot.containsKey('artifacts'), isFalse);
    expect(
      (snapshot['runtime']! as Map<String, Object?>).containsKey(
        'engineVersion',
      ),
      isFalse,
    );
    final reparsed = BundledModelManifest.tryParse(snapshot);
    expect(reparsed, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
    expect(
      (reparsed as Ok<BundledModelManifest, InvalidModelManifest>).value,
      manifest,
    );
    (snapshot['license']! as Map<String, Object?>)['id'] = 'changed';
    expect(manifest.toJson(), _validManifest());
  });

  test('parses a complete version-one bundled-model manifest', () {
    final result = BundledModelManifest.tryParse(_validManifest());

    expect(result, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
    final manifest =
        (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
    expect(manifest.schemaVersion, 1);
    expect(manifest.id, 'whisper-base-q5');
    expect(manifest.version, '1.0.0');
    expect(
      manifest.source,
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/'
      '0123456789abcdef0123456789abcdef01234567/ggml-base-q5_0.bin',
    );
    expect(manifest.artifactPath.value, 'models/whisper/ggml-base-q5_0.bin');
    expect(manifest.sha256, 'a' * 64);
    expect(manifest.bytes, 147951465);
    expect(manifest.engineId, 'whisper.cpp');
    expect(manifest.modelFormat, 'ggml');
    expect(manifest.licenseId, 'MIT');
    expect(
      manifest.licenseSnapshotPath.value,
      'licenses/whisper.cpp.MIT.txt',
    );
    expect(
      manifest.capabilities,
      const <ModelCapability>[
        ModelCapability.transcription,
        ModelCapability.languageIdentification,
      ],
    );
    expect(
      manifest.enabledModes,
      const <PerformanceMode>[
        PerformanceMode.balanced,
        PerformanceMode.postSession,
      ],
    );

    final installed = manifest.toInstalledModel();
    expect(installed.id, manifest.id);
    expect(installed.source, manifest.source);
    expect(installed.expectedEngineId, manifest.engineId);
    expect(installed.licenseSnapshotPath, manifest.licenseSnapshotPath);
  });

  test('rejects fields outside the version-one contract', () {
    final root = _validManifest()..['downloadAtRuntime'] = true;
    final nested = _validManifest();
    _nestedMap(nested, 'runtime')['threads'] = 4;

    _expectFailure(
      root,
      field: 'downloadAtRuntime',
      reason: ModelManifestFailureReason.unknownField,
    );
    _expectFailure(
      nested,
      field: 'runtime.threads',
      reason: ModelManifestFailureReason.unknownField,
    );
  });

  test('rejects unsupported schema revisions', () {
    final futureManifest = _validManifest()
      ..['schemaVersion'] = 3
      ..['futureField'] = true;

    _expectFailure(
      futureManifest,
      field: 'schemaVersion',
      reason: ModelManifestFailureReason.unsupportedSchemaVersion,
    );
  });

  test('rejects malformed identity and compatibility fields', () {
    for (final testCase in <({String field, Object? value})>[
      (field: 'id', value: 'Whisper Base'),
      (field: 'version', value: ' 1.0.0'),
      (field: 'runtime.engineId', value: ''),
      (field: 'runtime.modelFormat', value: ' ggml'),
      (field: 'license.id', value: ''),
    ]) {
      final manifest = _validManifest();
      _replaceField(manifest, testCase.field, testCase.value);
      _expectFailure(
        manifest,
        field: testCase.field,
        reason: ModelManifestFailureReason.invalidValue,
      );
    }
  });

  test('requires an absolute HTTPS source reference', () {
    _expectFailure(
      _validManifest()..['source'] = 'http://example.test/model.bin',
      field: 'source',
      reason: ModelManifestFailureReason.invalidSource,
    );
    _expectFailure(
      _validManifest()..['source'] = 'models/model.bin',
      field: 'source',
      reason: ModelManifestFailureReason.invalidSource,
    );
  });

  test('requires a lowercase 64-character SHA-256 and positive bytes', () {
    _expectFailure(
      _validManifest()..['sha256'] = 'A' * 64,
      field: 'sha256',
      reason: ModelManifestFailureReason.invalidSha256,
    );
    _expectFailure(
      _validManifest()..['sha256'] = 'abc123',
      field: 'sha256',
      reason: ModelManifestFailureReason.invalidSha256,
    );
    _expectFailure(
      _validManifest()..['bytes'] = 0,
      field: 'bytes',
      reason: ModelManifestFailureReason.invalidValue,
    );
  });

  test('rejects unsafe artifact and license snapshot paths', () {
    _expectFailure(
      _validManifest()..['artifactPath'] = '../model.bin',
      field: 'artifactPath',
      reason: ModelManifestFailureReason.unsafePath,
    );
    final manifest = _validManifest();
    _nestedMap(manifest, 'license')['snapshotPath'] = '/licenses/model.txt';
    _expectFailure(
      manifest,
      field: 'license.snapshotPath',
      reason: ModelManifestFailureReason.unsafePath,
    );
  });

  test('requires non-empty unique capability and mode sets', () {
    _expectFailure(
      _validManifest()..['capabilities'] = <Object?>[],
      field: 'capabilities',
      reason: ModelManifestFailureReason.emptyCollection,
    );
    _expectFailure(
      _validManifest()..['enabledModes'] = <Object?>['balanced', 'balanced'],
      field: 'enabledModes',
      reason: ModelManifestFailureReason.duplicateValue,
    );
  });

  test('rejects unknown capability and mode names', () {
    _expectFailure(
      _validManifest()..['capabilities'] = <Object?>['translation'],
      field: 'capabilities',
      reason: ModelManifestFailureReason.unknownEnumValue,
    );
    _expectFailure(
      _validManifest()..['enabledModes'] = <Object?>['turbo'],
      field: 'enabledModes',
      reason: ModelManifestFailureReason.unknownEnumValue,
    );
  });
}

void _expectFailure(
  Map<String, Object?> manifest, {
  required String field,
  required ModelManifestFailureReason reason,
}) {
  final result = BundledModelManifest.tryParse(manifest);

  expect(result, isA<Err<BundledModelManifest, InvalidModelManifest>>());
  expect(
    (result as Err<BundledModelManifest, InvalidModelManifest>).failure,
    InvalidModelManifest(field: field, reason: reason),
  );
}

void _replaceField(
  Map<String, Object?> manifest,
  String field,
  Object? value,
) {
  final parts = field.split('.');
  if (parts.length == 1) {
    manifest[field] = value;
    return;
  }
  _nestedMap(manifest, parts.first)[parts.last] = value;
}

Map<String, Object?> _nestedMap(
  Map<String, Object?> manifest,
  String field,
) => switch (manifest[field]) {
  final Map<String, Object?> value => value,
  _ => throw TestFailure('$field is not an object'),
};

Map<String, Object?> _validManifest() => <String, Object?>{
  'schemaVersion': 1,
  'id': 'whisper-base-q5',
  'version': '1.0.0',
  'source':
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/'
      '0123456789abcdef0123456789abcdef01234567/ggml-base-q5_0.bin',
  'artifactPath': 'models/whisper/ggml-base-q5_0.bin',
  'sha256': 'a' * 64,
  'bytes': 147951465,
  'runtime': <String, Object?>{
    'engineId': 'whisper.cpp',
    'modelFormat': 'ggml',
  },
  'license': <String, Object?>{
    'id': 'MIT',
    'snapshotPath': 'licenses/whisper.cpp.MIT.txt',
  },
  'capabilities': <Object?>['transcription', 'languageIdentification'],
  'enabledModes': <Object?>['balanced', 'postSession'],
};
