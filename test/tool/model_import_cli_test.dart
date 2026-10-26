import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_models.dart' as cli;

void main() {
  late Directory projectRoot;
  late List<String> output;
  late List<String> errors;

  setUp(() async {
    projectRoot = await Directory.systemTemp.createTemp(
      'loquiris-model-import-cli-',
    );
    output = <String>[];
    errors = <String>[];
  });

  tearDown(() => projectRoot.delete(recursive: true));

  test('imports the fixed project layout and reports a safe summary', () async {
    await _writeModel(projectRoot);

    final code = await cli.runModelImportCommand(
      const <String>[],
      projectRoot: projectRoot,
      writeOutput: output.add,
      writeError: errors.add,
    );

    expect(code, 0);
    expect(output, <String>['Imported 1 model (3 bytes).']);
    expect(errors, isEmpty);
  });

  test(
    'experimental import requires explicit opt-in and uses its own catalog',
    () async {
      await _writeModel(projectRoot, experimental: true);
      final defaultCode = await cli.runModelImportCommand(
        const <String>[],
        projectRoot: projectRoot,
        writeOutput: output.add,
        writeError: errors.add,
      );
      expect(defaultCode, 1);
      expect(output, isEmpty);
      errors.clear();

      final experimentalCode = await cli.runModelImportCommand(
        const <String>['--experimental-small'],
        projectRoot: projectRoot,
        writeOutput: output.add,
        writeError: errors.add,
      );
      expect(experimentalCode, 0);
      expect(output, <String>['Imported 1 model (3 bytes).']);
      expect(errors, isEmpty);
    },
  );

  test('reports a stable failure code without exposing paths', () async {
    final code = await cli.runModelImportCommand(
      const <String>[],
      projectRoot: projectRoot,
      writeOutput: output.add,
      writeError: errors.add,
    );

    expect(code, 1);
    expect(
      errors,
      <String>[
        'Model import failed: model_import.manifestDirectoryUnavailable',
      ],
    );
    expect(errors.single, isNot(contains(projectRoot.path)));
  });

  test('rejects arguments with a usage error', () async {
    final code = await cli.runModelImportCommand(
      const <String>['--project-root', '/tmp/example'],
      projectRoot: projectRoot,
      writeOutput: output.add,
      writeError: errors.add,
    );

    expect(code, 64);
    expect(output, isEmpty);
    expect(errors, <String>[
      'Usage: dart run tool/import_models.dart [--experimental-small]',
    ]);
  });
}

Future<void> _writeModel(
  Directory projectRoot, {
  bool experimental = false,
}) async {
  const id = 'test-model';
  const bytes = <int>[1, 2, 3];
  final manifestDirectory = experimental
      ? '${projectRoot.path}/models/manifests/experimental-small'
      : '${projectRoot.path}/models/manifests';
  await Directory(
    manifestDirectory,
  ).create(recursive: true);
  await Directory(
    '${projectRoot.path}/models/licenses',
  ).create(recursive: true);
  final artifact = File(
    '${projectRoot.path}/models/local/$id/model.bin',
  );
  await artifact.create(recursive: true);
  await artifact.writeAsBytes(bytes);
  await File(
    '${projectRoot.path}/models/licenses/$id.txt',
  ).writeAsString('MIT license\n');
  await File(
    '$manifestDirectory/$id.json',
  ).writeAsString(
    '${jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'version': '1.0.0',
      'source': 'https://example.test/model.bin',
      'artifactPath': 'models/$id/model.bin',
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
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
    })}\n',
  );
}
