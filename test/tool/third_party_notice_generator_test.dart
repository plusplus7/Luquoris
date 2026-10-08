import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/third_party_notices/third_party_notice_generator.dart';

void main() {
  late _NoticeFixture fixture;

  setUp(() async {
    fixture = await _NoticeFixture.create();
  });

  tearDown(() => fixture.dispose());

  test(
    'collects transitive Dart packages in stable exact-version order',
    () async {
      await fixture.writeLock(<String>[
        _lockPackage('zeta', dependency: 'transitive', version: '2.0.0'),
        _lockPackage('alpha', dependency: 'direct main', version: '1.0.0'),
        _lockPackage('builder', dependency: 'direct dev', version: '9.0.0'),
      ]);
      await fixture.writePackageGraph(
        runtimeRoots: <String>['alpha'],
        devRoots: <String>['builder'],
        dependencies: <String, List<String>>{
          'alpha': <String>['zeta'],
          'zeta': <String>[],
          'builder': <String>[],
        },
        versions: <String, String>{
          'alpha': '1.0.0',
          'zeta': '2.0.0',
          'builder': '9.0.0',
        },
      );

      final inventory = await fixture.collect();
      final dartComponents = inventory.components
          .where(
            (component) => component.kind == NoticeComponentKind.dartPackage,
          )
          .toList();

      expect(
        dartComponents.map(
          (component) => '${component.name}@${component.version}',
        ),
        <String>['alpha@1.0.0', 'zeta@2.0.0'],
      );
      expect(dartComponents.first.artifactSha256, 'a' * 64);
    },
  );

  test('collects only Android release runtime artifacts', () async {
    await fixture.writeAndroidInventory(<Map<String, Object?>>[
      _androidArtifact('org.example:zeta:2.0.0', sha256: '2' * 64),
      _androidArtifact('org.example:alpha:1.0.0', sha256: '1' * 64),
    ]);

    final inventory = await fixture.collect();
    final androidComponents = inventory.components
        .where(
          (component) => component.kind == NoticeComponentKind.androidArtifact,
        )
        .toList();

    expect(
      androidComponents.map((component) => component.name),
      <String>['org.example:alpha', 'org.example:zeta'],
    );
    expect(
      androidComponents.every(
        (component) => component.source == 'releaseRuntimeClasspath',
      ),
      isTrue,
    );
  });

  test(
    'collects model and benchmark licenses independently from runtimes',
    () async {
      await fixture.writeModelManifest(
        id: 'speech-model',
        version: '2026.10',
        licenseId: 'Model-License-1.0',
        licensePath: 'models/licenses/model.txt',
      );

      final inventory = await fixture.collect();
      final model = inventory.components.singleWhere(
        (component) => component.kind == NoticeComponentKind.model,
      );
      final benchmark = inventory.components.singleWhere(
        (component) => component.kind == NoticeComponentKind.benchmarkAsset,
      );

      expect(model.licenseId, 'Model-License-1.0');
      expect(model.licenseSnapshotPath, 'models/licenses/model.txt');
      expect(benchmark.licenseId, 'CC0-1.0');
      expect(
        benchmark.licenseSnapshotPath,
        'assets/benchmarks/licenses/CC0-1.0.txt',
      );
      expect(model.licenseTextSha256, isNot(benchmark.licenseTextSha256));
    },
  );

  test(
    'rejects missing duplicate mutable and unsafe license metadata',
    () async {
      await fixture.writeModelManifest(
        id: 'mutable-model',
        version: 'latest',
        licenseId: 'Model-License-1.0',
        licensePath: '../outside.txt',
      );
      await expectLater(
        fixture.collect,
        throwsA(
          isA<NoticeInventoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            NoticeInventoryFailureReason.invalidMetadata,
          ),
        ),
      );

      await fixture.clearModels();
      await fixture.writeAndroidInventory(<Map<String, Object?>>[
        _androidArtifact('org.example:duplicate:1.0.0', sha256: '1' * 64),
        _androidArtifact('org.example:duplicate:1.0.0', sha256: '1' * 64),
      ]);
      await expectLater(
        fixture.collect,
        throwsA(
          isA<NoticeInventoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            NoticeInventoryFailureReason.duplicateComponent,
          ),
        ),
      );

      expect(
        () => NoticeApprovalCatalog.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'components': <Object?>[
            <String, Object?>{
              'kind': 'dartPackage',
              'name': 'unsafe',
              'version': '1.0.0',
              'artifactSha256': 'e' * 64,
              'licenseId': 'BSD-3-Clause\nInjected heading',
              'licensePath': 'tool/third_party_notices/licenses/unsafe.txt',
              'licenseTextSha256': 'f' * 64,
              'redistribution': 'Include the license.',
              'approvedBy': 'reviewer',
              'approvedAt': '2026-10-08',
            },
          ],
        }),
        throwsA(
          isA<NoticeInventoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            NoticeInventoryFailureReason.invalidMetadata,
          ),
        ),
      );
    },
  );

  test('detects stale approvals and changed license text hashes', () async {
    await fixture.writeLock(<String>[
      _lockPackage('alpha', dependency: 'direct main', version: '1.0.0'),
    ]);
    await fixture.writePackageGraph(
      runtimeRoots: <String>['alpha'],
      devRoots: const <String>[],
      dependencies: <String, List<String>>{'alpha': <String>[]},
    );
    await fixture.writeApprovalLicense('alpha.txt', 'reviewed license text');
    final inventory = await fixture.collect();
    final alpha = inventory.components.singleWhere(
      (component) => component.name == 'alpha',
    );
    final catalog = NoticeApprovalCatalog.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'components': <Object?>[
        fixture.approvalFor(
          alpha,
          licensePath: 'tool/third_party_notices/licenses/alpha.txt',
          licenseTextSha256: 'f' * 64,
        ),
        fixture.approvalFor(
          alpha.copyWith(version: '0.9.0'),
          licensePath: 'tool/third_party_notices/licenses/alpha.txt',
          licenseTextSha256: 'f' * 64,
        ),
      ],
    });

    final review = await NoticeReview.evaluate(
      inventory: inventory,
      approvals: catalog,
      projectRoot: fixture.root,
    );

    expect(
      review.issues.map((issue) => issue.reason),
      containsAll(<NoticeReviewIssueReason>[
        NoticeReviewIssueReason.staleApproval,
        NoticeReviewIssueReason.licenseTextHashMismatch,
      ]),
    );
    expect(review.isApproved, isFalse);
  });

  test(
    'development-only dependencies cannot masquerade as shipped entries',
    () async {
      await fixture.writeLock(<String>[
        _lockPackage('runtime', dependency: 'direct main', version: '1.0.0'),
        _lockPackage(
          'runtime_transitive',
          dependency: 'transitive',
          version: '1.0.0',
        ),
        _lockPackage('test_only', dependency: 'direct dev', version: '1.0.0'),
        _lockPackage(
          'dev_transitive',
          dependency: 'transitive',
          version: '1.0.0',
        ),
      ]);
      await fixture.writePackageGraph(
        runtimeRoots: <String>['runtime'],
        devRoots: <String>['test_only'],
        dependencies: <String, List<String>>{
          'runtime': <String>['runtime_transitive'],
          'runtime_transitive': <String>[],
          'test_only': <String>['dev_transitive'],
          'dev_transitive': <String>[],
        },
      );

      final inventory = await fixture.collect();

      expect(
        inventory.components.map((component) => component.name),
        isNot(contains('test_only')),
      );
      expect(
        inventory.components.map((component) => component.name),
        isNot(contains('dev_transitive')),
      );
      expect(
        inventory.components.map((component) => component.name),
        containsAll(<String>['runtime', 'runtime_transitive']),
      );
    },
  );
}

String _lockPackage(
  String name, {
  required String dependency,
  required String version,
}) => <String>[
  '  $name:',
  '    dependency: "$dependency"',
  '    description:',
  '      name: $name',
  '      sha256: ${name == 'alpha' ? 'a' * 64 : 'b' * 64}',
  '      url: "https://pub.dev"',
  '    source: hosted',
  '    version: "$version"',
].join('\n');

Map<String, Object?> _androidArtifact(
  String coordinate, {
  required String sha256,
}) {
  final segments = coordinate.split(':');
  return <String, Object?>{
    'coordinate': coordinate,
    'group': segments[0],
    'name': segments[1],
    'version': segments[2],
    'extension': 'aar',
    'classifier': null,
    'bytes': 100,
    'sha256': sha256,
  };
}

final class _NoticeFixture {
  _NoticeFixture._(this.root);

  final Directory root;

  static Future<_NoticeFixture> create() async {
    final root = await Directory.systemTemp.createTemp('loquiris-notices-');
    final fixture = _NoticeFixture._(root);
    await fixture._writeDefaults();
    return fixture;
  }

  Future<void> dispose() => root.delete(recursive: true);

  Future<void> _writeDefaults() async {
    await writeLock(const <String>[]);
    await writePackageGraph(
      runtimeRoots: const <String>[],
      devRoots: const <String>[],
      dependencies: const <String, List<String>>{},
    );
    await writeAndroidInventory(const <Map<String, Object?>>[]);
    await Directory('${root.path}/models/manifests').create(recursive: true);
    final benchmarkLicense = await _write(
      'assets/benchmarks/licenses/CC0-1.0.txt',
      'benchmark license text',
    );
    final licenseHash = sha256.convert(await benchmarkLicense.readAsBytes());
    await _writeJson('assets/benchmarks/audio/manifest.json', <String, Object?>{
      'schemaVersion': 1,
      'id': 'benchmark-audio',
      'annotationVersion': 1,
      'source': <String, Object?>{
        'kind': 'authorized-recording',
        'sourceId': 'recording-v1',
      },
      'audio': <String, Object?>{
        'path': 'assets/benchmarks/audio/benchmark.wav',
        'sha256': 'c' * 64,
        'bytes': 100,
      },
      'rights': <String, Object?>{
        'license': 'CC0-1.0',
        'licensePath': 'assets/benchmarks/licenses/CC0-1.0.txt',
        'licenseTextSha256': licenseHash.toString(),
        'rightsHolderAuthorized': true,
        'allIdentifiableSpeakersConsented': true,
      },
    });
  }

  Future<void> writeLock(List<String> packages) => _write(
    'pubspec.lock',
    <String>[
      '# Generated by pub',
      '# See https://dart.dev/tools/pub/glossary#lockfile',
      'packages:',
      ...packages,
      '',
    ].join('\n'),
  );

  Future<void> writePackageGraph({
    required List<String> runtimeRoots,
    required List<String> devRoots,
    required Map<String, List<String>> dependencies,
    Map<String, String> versions = const <String, String>{},
  }) => _writeJson('.dart_tool/package_graph.json', <String, Object?>{
    'roots': <String>['fixture'],
    'packages': <Object?>[
      <String, Object?>{
        'name': 'fixture',
        'version': '1.0.0',
        'dependencies': runtimeRoots,
        'devDependencies': devRoots,
      },
      for (final entry in dependencies.entries)
        <String, Object?>{
          'name': entry.key,
          'version': versions[entry.key] ?? '1.0.0',
          'dependencies': entry.value,
        },
    ],
  });

  Future<void> writeAndroidInventory(
    List<Map<String, Object?>> artifacts,
  ) => _writeJson(
    'build/third_party_notices/android_release_dependencies.json',
    <String, Object?>{
      'schemaVersion': 1,
      'configuration': 'releaseRuntimeClasspath',
      'artifacts': artifacts,
    },
  );

  Future<void> writeModelManifest({
    required String id,
    required String version,
    required String licenseId,
    required String licensePath,
  }) async {
    if (!licensePath.startsWith('../')) {
      await _write(licensePath, 'model license text');
    }
    await _writeJson('models/manifests/$id.json', <String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'version': version,
      'source': 'https://example.invalid/models/$id/$version.bin',
      'artifactPath': 'models/$id.bin',
      'sha256': 'd' * 64,
      'bytes': 100,
      'runtime': <String, Object?>{
        'engineId': 'engine',
        'modelFormat': 'binary',
      },
      'license': <String, Object?>{
        'id': licenseId,
        'snapshotPath': licensePath,
      },
      'capabilities': <String>['transcription'],
      'enabledModes': <String>['balanced'],
    });
  }

  Future<void> clearModels() async {
    final directory = Directory('${root.path}/models/manifests');
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }

  Future<File> writeApprovalLicense(String name, String contents) =>
      _write('tool/third_party_notices/licenses/$name', contents);

  Future<NoticeInventory> collect() => NoticeInventory.collect(
    NoticeInventoryRequest.fromProjectRoot(root),
  );

  Map<String, Object?> approvalFor(
    NoticeComponent component, {
    required String licensePath,
    required String licenseTextSha256,
  }) => <String, Object?>{
    'kind': component.kind.name,
    'name': component.name,
    'version': component.version,
    'artifactSha256': component.artifactSha256,
    'licenseId': 'BSD-3-Clause',
    'licensePath': licensePath,
    'licenseTextSha256': licenseTextSha256,
    'redistribution': 'Include the reviewed license text.',
    'approvedBy': 'release-reviewer',
    'approvedAt': '2026-10-08',
  };

  Future<File> _write(String relativePath, String contents) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
    return file;
  }

  Future<File> _writeJson(
    String relativePath,
    Map<String, Object?> contents,
  ) => _write(relativePath, '${jsonEncode(contents)}\n');
}
