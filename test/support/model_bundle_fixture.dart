import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Small deterministic bundle used by publication and runtime tests.
Map<String, Object?> modelBundleFixture() {
  final artifacts = <Map<String, Object?>>[
    for (final entry in modelBundleFiles.entries)
      <String, Object?>{
        'path': 'models/test-bundle/${entry.key}',
        'role': switch (entry.key) {
          'encoder.onnx' => 'encoder',
          'tokens.txt' => 'tokenizer',
          _ => 'configuration',
        },
        'bytes': entry.value.length,
        'sha256': sha256.convert(entry.value).toString(),
        'source': 'https://example.test/resolve/$_revision/${entry.key}',
        'license': _license,
      },
  ]..sort((a, b) => (a['path']! as String).compareTo(b['path']! as String));
  final inventory = <Map<String, Object?>>[
    for (final artifact in artifacts)
      <String, Object?>{
        for (final key in <String>['path', 'role', 'bytes', 'sha256'])
          key: artifact[key],
      },
  ];
  return <String, Object?>{
    'schemaVersion': 2,
    'id': 'test-bundle',
    'version': _revision,
    'source': 'https://example.test/resolve/$_revision/manifest.json',
    'sha256': sha256.convert(utf8.encode(jsonEncode(inventory))).toString(),
    'bytes': modelBundleFiles.values.fold<int>(0, (a, b) => a + b.length),
    'runtime': <String, Object?>{
      'engineId': 'test-streaming',
      'engineVersion': '1.0.0',
      'modelFormat': 'onnx',
    },
    'license': _license,
    'artifacts': artifacts,
    'capabilities': <Object?>['transcription'],
    'enabledModes': <Object?>['balanced'],
  };
}

/// Independently verifiable encoder, tokenizer, and configuration bytes.
const modelBundleFiles = <String, List<int>>{
  'encoder.onnx': <int>[1, 2, 3],
  'tokens.txt': <int>[4, 5],
  'configuration.json': <int>[6],
};

const _revision = '0123456789abcdef0123456789abcdef01234567';
const _license = <String, Object?>{
  'id': 'MIT',
  'snapshotPath': 'models/licenses/test-bundle.txt',
};
