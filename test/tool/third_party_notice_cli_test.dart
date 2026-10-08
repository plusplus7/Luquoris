import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_third_party_notices.dart';
import '../../tool/third_party_notices/third_party_notice_generator.dart';

void main() {
  late _CliFixture fixture;
  late List<String> output;
  late List<String> errors;

  setUp(() async {
    fixture = await _CliFixture.create();
    output = <String>[];
    errors = <String>[];
  });

  tearDown(() => fixture.dispose());

  Future<int> run(List<String> arguments) => runThirdPartyNoticeCli(
    <String>['--project-root', fixture.root.path, ...arguments],
    currentDirectory: fixture.root,
    writeOutput: output.add,
    writeError: errors.add,
  );

  test(
    'candidate mode writes canonical Markdown and machine-readable JSON',
    () async {
      final exitCode = await run(<String>['--candidate', 'candidate.json']);

      expect(exitCode, 0);
      expect(errors, isEmpty);
      expect(output, <String>[
        'third_party_notices.candidate_ready components=2',
      ]);
      final decoded =
          jsonDecode(
                await File(
                  '${fixture.root.path}/candidate.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['status'], 'reviewRequired');
      expect(
        (decoded['components']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map((component) => component['kind']),
        <String>['benchmarkAsset', 'dartPackage'],
      );
      expect(
        await File('${fixture.root.path}/candidate.md').readAsString(),
        allOf(
          startsWith('# Third-Party Notice Review Candidate\n'),
          contains('## benchmarkAsset: benchmark-audio @ annotation-1'),
          contains('Approval: missing'),
        ),
      );
    },
  );

  test(
    'CLI reports missing inputs without exposing filesystem paths',
    () async {
      await File('${fixture.root.path}/pubspec.lock').delete();

      final exitCode = await run(<String>['--candidate', 'candidate.json']);

      expect(exitCode, 66);
      expect(errors, <String>['third_party_notices.inventory.inputMissing']);
      expect(errors.single, isNot(contains(fixture.root.path)));
      expect(File('${fixture.root.path}/candidate.json').existsSync(), isFalse);
    },
  );

  test('output mode rejects approval drift without publishing', () async {
    final exitCode = await run(<String>[
      '--output',
      'THIRD_PARTY_NOTICES.md',
    ]);

    expect(exitCode, 65);
    expect(errors, <String>['third_party_notices.review_required issues=2']);
    expect(
      File('${fixture.root.path}/THIRD_PARTY_NOTICES.md').existsSync(),
      isFalse,
    );
  });

  test('check mode rejects notice drift byte-for-byte', () async {
    await fixture.approveCurrentInventory();
    await File(
      '${fixture.root.path}/THIRD_PARTY_NOTICES.md',
    ).writeAsString('# stale notice\n');

    final exitCode = await run(<String>[
      '--check',
      'THIRD_PARTY_NOTICES.md',
    ]);

    expect(exitCode, 65);
    expect(errors, <String>['third_party_notices.notice_drift']);
  });

  test('output mode leaves an unchanged reviewed notice untouched', () async {
    await fixture.approveCurrentInventory();
    expect(
      await run(<String>['--output', 'THIRD_PARTY_NOTICES.md']),
      0,
    );
    final notice = File('${fixture.root.path}/THIRD_PARTY_NOTICES.md');
    final firstModified = notice.lastModifiedSync();
    final firstBytes = await notice.readAsBytes();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    output.clear();

    expect(
      await run(<String>['--output', 'THIRD_PARTY_NOTICES.md']),
      0,
    );

    expect(await notice.readAsBytes(), firstBytes);
    expect(notice.lastModifiedSync(), firstModified);
    expect(output, <String>['third_party_notices.unchanged components=2']);
  });
}

final class _CliFixture {
  _CliFixture._(this.root);

  final Directory root;

  static Future<_CliFixture> create() async {
    final root = await Directory.systemTemp.createTemp('loquiris-notice-cli-');
    final fixture = _CliFixture._(root);
    await fixture._writeDefaults();
    return fixture;
  }

  Future<void> dispose() => root.delete(recursive: true);

  Future<void> _writeDefaults() async {
    await _write(
      'pubspec.lock',
      <String>[
        'packages:',
        '  runtime:',
        '    dependency: "direct main"',
        '    description:',
        '      name: runtime',
        '      sha256: ${'a' * 64}',
        '      url: "https://pub.dev"',
        '    source: hosted',
        '    version: "1.0.0"',
        '',
      ].join('\n'),
    );
    await _writeJson('.dart_tool/package_graph.json', <String, Object?>{
      'roots': <String>['fixture'],
      'packages': <Object?>[
        <String, Object?>{
          'name': 'fixture',
          'version': '1.0.0',
          'dependencies': <String>['runtime'],
          'devDependencies': <String>[],
        },
        <String, Object?>{
          'name': 'runtime',
          'version': '1.0.0',
          'dependencies': <String>[],
        },
      ],
    });
    await _writeJson(
      'build/third_party_notices/android_release_dependencies.json',
      <String, Object?>{
        'schemaVersion': 1,
        'configuration': 'releaseRuntimeClasspath',
        'artifacts': <Object?>[],
      },
    );
    await Directory('${root.path}/models/manifests').create(recursive: true);
    final benchmarkLicense = await _write(
      'assets/benchmarks/licenses/CC0-1.0.txt',
      'benchmark license text',
    );
    final benchmarkHash = sha256
        .convert(await benchmarkLicense.readAsBytes())
        .toString();
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
        'sha256': 'b' * 64,
        'bytes': 100,
      },
      'rights': <String, Object?>{
        'license': 'CC0-1.0',
        'licensePath': 'assets/benchmarks/licenses/CC0-1.0.txt',
        'licenseTextSha256': benchmarkHash,
        'rightsHolderAuthorized': true,
        'allIdentifiableSpeakersConsented': true,
      },
    });
    await _writeJson(
      'tool/third_party_notices/approved_components.json',
      <String, Object?>{'schemaVersion': 1, 'components': <Object?>[]},
    );
  }

  Future<void> approveCurrentInventory() async {
    final inventory = await NoticeInventory.collect(
      NoticeInventoryRequest.fromProjectRoot(root),
    );
    final entries = <Map<String, Object?>>[];
    for (final component in inventory.components) {
      final fileName = '${component.kind.name}-${component.name}.txt';
      final safeFileName = fileName.replaceAll(RegExp('[^a-zA-Z0-9_.-]'), '-');
      final contents = component.licenseTextSha256 == null
          ? 'runtime reviewed license text'
          : 'benchmark license text';
      final license = await _write(
        'tool/third_party_notices/licenses/$safeFileName',
        contents,
      );
      final licenseHash = sha256
          .convert(await license.readAsBytes())
          .toString();
      entries.add(<String, Object?>{
        'kind': component.kind.name,
        'name': component.name,
        'version': component.version,
        'artifactSha256': component.artifactSha256,
        'licenseId': component.licenseId ?? 'BSD-3-Clause',
        'licensePath': 'tool/third_party_notices/licenses/$safeFileName',
        'licenseTextSha256': licenseHash,
        'redistribution': 'Include this exact reviewed license text.',
        'approvedBy': 'release-reviewer',
        'approvedAt': '2026-10-08',
      });
    }
    await _writeJson(
      'tool/third_party_notices/approved_components.json',
      <String, Object?>{'schemaVersion': 1, 'components': entries},
    );
  }

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
