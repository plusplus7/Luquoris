import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';

import '../../tool/model_import/model_importer.dart';
import '../support/model_bundle_fixture.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('loquiris-bundle-import-');
    for (final dir in <String>[
      'models/manifests',
      'models/licenses',
      'models/local/test-bundle',
    ]) {
      await Directory('${root.path}/$dir').create(recursive: true);
    }
    await File(
      '${root.path}/models/manifests/test-bundle.json',
    ).writeAsString(jsonEncode(modelBundleFixture()));
    await File(
      '${root.path}/models/licenses/test-bundle.txt',
    ).writeAsString('MIT test license');
    for (final entry in modelBundleFiles.entries) {
      await File(
        '${root.path}/models/local/test-bundle/${entry.key}',
      ).writeAsBytes(entry.value);
    }
  });
  tearDown(() => root.delete(recursive: true));

  test('publishes all verified files as one bundle', () async {
    final result = await importModels(_request(root));
    expect(result, isA<Ok<ModelImportSummary, ModelImportFailure>>());
    for (final entry in modelBundleFiles.entries) {
      expect(
        await File(
          '${root.path}/build/generated/model_assets/models/test-bundle/${entry.key}',
        ).readAsBytes(),
        entry.value,
      );
    }
  });
  for (final filename in modelBundleFiles.keys) {
    test('missing $filename preserves the previous published bundle', () async {
      await File('${root.path}/models/local/test-bundle/$filename').delete();
      final sentinel = File(
        '${root.path}/build/generated/model_assets/previous.txt',
      );
      await sentinel.create(recursive: true);
      await sentinel.writeAsString('preserve');
      final result = await importModels(_request(root));
      expect(result, isA<Err<ModelImportSummary, ModelImportFailure>>());
      expect(
        (result as Err<ModelImportSummary, ModelImportFailure>).failure.reason,
        ModelImportFailureReason.artifactMissing,
      );
      expect(await sentinel.readAsString(), 'preserve');
    });
  }

  test('rejects an artifact colliding with a license destination', () async {
    final manifest = modelBundleFixture()..['id'] = 'licenses';
    final artifacts = (manifest['artifacts']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final artifact in artifacts) {
      artifact['path'] = (artifact['path']! as String).replaceFirst(
        'test-bundle/',
        'licenses/',
      );
    }
    final encoder = artifacts.firstWhere((file) => file['role'] == 'encoder');
    encoder['path'] = 'models/licenses/test-bundle.txt';
    artifacts.sort(
      (a, b) => (a['path']! as String).compareTo(b['path']! as String),
    );
    manifest['sha256'] = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              for (final artifact in artifacts)
                {
                  for (final key in <String>['path', 'role', 'bytes', 'sha256'])
                    key: artifact[key],
                },
            ]),
          ),
        )
        .toString();
    await File(
      '${root.path}/models/manifests/test-bundle.json',
    ).writeAsString(jsonEncode(manifest));
    final local = Directory('${root.path}/models/local/licenses');
    await local.create();
    for (final entry in modelBundleFiles.entries) {
      await File(
        '${local.path}/${entry.key == 'encoder.onnx' ? 'test-bundle.txt' : entry.key}',
      ).writeAsBytes(entry.value);
    }
    final result = await importModels(_request(root));
    expect(result, isA<Err<ModelImportSummary, ModelImportFailure>>());
  });

  test(
    'failed replacement restores old output before returning failure',
    () async {
      final previous = File(
        '${root.path}/build/generated/model_assets/previous.txt',
      );
      await previous.create(recursive: true);
      await previous.writeAsString('keep');
      final result = await importModels(
        _request(root),
        publication: _FailPublication(),
      );
      expect(result, isA<Err<ModelImportSummary, ModelImportFailure>>());
      expect(await previous.readAsString(), 'keep');
    },
  );

  test(
    'reserved index ID cannot overwrite the catalog or prior output',
    () async {
      final manifest = modelBundleFixture()
        ..['schemaVersion'] = 1
        ..['id'] = 'index'
        ..['artifactPath'] = 'models/index/model.bin'
        ..['bytes'] = 1
        ..['sha256'] = sha256.convert(<int>[1]).toString()
        ..remove('artifacts');
      (manifest['runtime']! as Map<String, Object?>).remove('engineVersion');
      await File(
        '${root.path}/models/manifests/test-bundle.json',
      ).writeAsString(jsonEncode(manifest));
      final artifact = File('${root.path}/models/local/index/model.bin');
      await artifact.create(recursive: true);
      await artifact.writeAsBytes(<int>[1]);
      final previous = File(
        '${root.path}/build/generated/model_assets/previous.txt',
      );
      await previous.create(recursive: true);
      await previous.writeAsString('keep');
      final result = await importModels(_request(root));
      expect(result, isA<Err<ModelImportSummary, ModelImportFailure>>());
      expect(await previous.readAsString(), 'keep');
    },
  );

  test('backup cleanup failure after commit does not claim rollback', () async {
    final previous = File(
      '${root.path}/build/generated/model_assets/previous.txt',
    );
    await previous.create(recursive: true);
    await previous.writeAsString('keep');
    final result = await importModels(
      _request(root),
      publication: _FailPublication(cleanup: true),
    );
    expect(result, isA<Ok<ModelImportSummary, ModelImportFailure>>());
    expect(
      File(
        '${root.path}/build/generated/model_assets/models/test-bundle/tokens.txt',
      ).existsSync(),
      isTrue,
    );
    expect(previous.existsSync(), isFalse);
  });
}

final class _FailPublication implements ModelImportPublication {
  _FailPublication({this.cleanup = false});
  final bool cleanup;
  @override
  Future<Directory> rename(Directory directory, String destination) {
    if (!cleanup &&
        directory.path.split('/').last.startsWith('.model-assets-staging-')) {
      throw const FileSystemException('injected replacement failure');
    }
    return directory.rename(destination);
  }

  @override
  Future<void> removeBackup(Directory directory) async {
    if (cleanup) throw const FileSystemException('injected cleanup failure');
    await directory.delete(recursive: true);
  }
}

ModelImportRequest _request(Directory root) => ModelImportRequest(
  projectRoot: root,
  manifestDirectory: Directory('${root.path}/models/manifests'),
  artifactDirectory: Directory('${root.path}/models/local'),
  outputDirectory: Directory('${root.path}/build/generated/model_assets'),
);
