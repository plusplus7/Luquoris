import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release_footprint.dart' as cli;
import '../../tool/release_size/release_footprint_policy.dart';

void main() {
  late Directory projectRoot;
  late File apk;
  late File aab;
  late File measurement;
  late File report;
  late List<String> output;
  late List<String> errors;

  setUp(() async {
    projectRoot = await Directory.systemTemp.createTemp(
      'loquiris-release-footprint-',
    );
    final build = await Directory(
      '${projectRoot.path}/build/app/outputs',
    ).create(recursive: true);
    apk = File('${build.path}/app-release.apk');
    aab = File('${build.path}/app-release.aab');
    await apk.writeAsBytes(<int>[1, 2, 3], flush: true);
    await aab.writeAsBytes(<int>[4, 5, 6, 7], flush: true);
    measurement = File('${projectRoot.path}/build/installed.json');
    report = File('${projectRoot.path}/build/footprint.json');
    await _writeInstalledMeasurement(
      measurement,
      installedApkSha256: sha256.convert(await apk.readAsBytes()).toString(),
    );
    output = <String>[];
    errors = <String>[];
  });

  tearDown(() => projectRoot.delete(recursive: true));

  test(
    'CLI measures regular artifacts and writes canonical privacy-safe JSON',
    () async {
      final code = await _run(
        projectRoot,
        apk: apk,
        aab: aab,
        measurement: measurement,
        report: report,
        output: output,
        errors: errors,
      );

      expect(code, 0);
      expect(errors, isEmpty);
      expect(output, hasLength(1));
      expect(await report.readAsString(), '${output.single}\n');
      expect(output.single, isNot(contains(projectRoot.path)));
      final decoded = jsonDecode(output.single) as Map<String, Object?>;
      expect(
        (decoded['decision']! as Map<String, Object?>)['status'],
        'passed',
      );
      expect(
        (decoded['artifacts']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map((artifact) => artifact['bytes']),
        <int>[4, 3],
      );
      expect(
        (decoded['artifacts']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map((artifact) => artifact['sha256']),
        <String>[
          sha256.convert(<int>[4, 5, 6, 7]).toString(),
          sha256.convert(<int>[1, 2, 3]).toString(),
        ],
      );
    },
  );

  test(
    'CLI rejects missing symlink duplicate and changed artifact inputs',
    () async {
      final missingCode = await _run(
        projectRoot,
        apk: File('${projectRoot.path}/build/missing.apk'),
        aab: aab,
        measurement: measurement,
        report: report,
        output: output,
        errors: errors,
      );
      expect(missingCode, 64);
      expect(errors.last, 'release_footprint.artifact_not_regular');

      output.clear();
      errors.clear();
      final linkedApk = Link('${projectRoot.path}/build/linked.apk');
      await linkedApk.create(apk.path);
      final symlinkCode = await _run(
        projectRoot,
        apk: File(linkedApk.path),
        aab: aab,
        measurement: measurement,
        report: report,
        output: output,
        errors: errors,
      );
      expect(symlinkCode, 64);
      expect(errors, <String>['release_footprint.artifact_not_regular']);

      output.clear();
      errors.clear();
      final duplicateCode = await cli.runReleaseFootprintCommand(
        <String>[
          '--apk',
          'universal=${_relative(projectRoot, apk)}',
          '--apk',
          'arm64-v8a=${_relative(projectRoot, apk)}',
          '--aab',
          _relative(projectRoot, aab),
          '--installed-measurement',
          _relative(projectRoot, measurement),
          '--output',
          _relative(projectRoot, report),
        ],
        projectRoot: projectRoot,
        writeOutput: output.add,
        writeError: errors.add,
      );
      expect(duplicateCode, 64);
      expect(errors, <String>['release_footprint.artifact_duplicated']);

      output.clear();
      errors.clear();
      await apk.writeAsBytes(<int>[9, 9, 9], flush: true);
      final changedCode = await _run(
        projectRoot,
        apk: apk,
        aab: aab,
        measurement: measurement,
        report: report,
        output: output,
        errors: errors,
      );
      expect(changedCode, 1);
      expect(errors, <String>['release_footprint.gate_failed']);
      final changed = jsonDecode(output.single) as Map<String, Object?>;
      expect(
        ((changed['decision']! as Map<String, Object?>)['violations']!
                as List<Object?>)
            .cast<Map<String, Object?>>()
            .map((violation) => violation['code']),
        contains('installedApkMismatch'),
      );
    },
  );

  test('CLI exits nonzero for artifact or installed budget failure', () async {
    await apk.writeAsBytes(<int>[1, 2, 3], flush: true);
    await _writeInstalledMeasurement(
      measurement,
      installedApkSha256: sha256.convert(await apk.readAsBytes()).toString(),
      appBytes: maxInstalledFootprintBytes,
      dataBytes: 1,
    );

    final code = await _run(
      projectRoot,
      apk: apk,
      aab: aab,
      measurement: measurement,
      report: report,
      output: output,
      errors: errors,
    );

    expect(code, 1);
    expect(errors, <String>['release_footprint.gate_failed']);
    final decoded = jsonDecode(output.single) as Map<String, Object?>;
    expect(
      ((decoded['decision']! as Map<String, Object?>)['violations']!
              as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((violation) => violation['code']),
      contains('installedBudgetExceeded'),
    );
  });

  test(
    'CLI never reports a pass without device measurement provenance',
    () async {
      final code = await cli.runReleaseFootprintCommand(
        <String>[
          '--apk',
          'universal=${_relative(projectRoot, apk)}',
          '--aab',
          _relative(projectRoot, aab),
          '--output',
          _relative(projectRoot, report),
        ],
        projectRoot: projectRoot,
        writeOutput: output.add,
        writeError: errors.add,
      );

      expect(code, 1);
      expect(errors, <String>['release_footprint.gate_incomplete']);
      final decoded = jsonDecode(output.single) as Map<String, Object?>;
      expect(
        (decoded['decision']! as Map<String, Object?>)['status'],
        'incomplete',
      );
      expect(decoded['installedMeasurement'], isNull);
    },
  );
}

Future<int> _run(
  Directory projectRoot, {
  required File apk,
  required File aab,
  required File measurement,
  required File report,
  required List<String> output,
  required List<String> errors,
}) => cli.runReleaseFootprintCommand(
  <String>[
    '--apk',
    'universal=${_relative(projectRoot, apk)}',
    '--aab',
    _relative(projectRoot, aab),
    '--installed-measurement',
    _relative(projectRoot, measurement),
    '--output',
    _relative(projectRoot, report),
  ],
  projectRoot: projectRoot,
  writeOutput: output.add,
  writeError: errors.add,
);

Future<void> _writeInstalledMeasurement(
  File file, {
  required String installedApkSha256,
  int appBytes = 200,
  int dataBytes = 50,
}) => file.writeAsString(
  '${jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'buildId': 'release-2026-10-08',
    'packageName': 'com.loquiris',
    'versionCode': 1,
    'deviceSerial': 'device-serial',
    'deviceModel': 'M2104K10AC',
    'buildFingerprint': 'redmi/chopin/build:fingerprint',
    'observedAtUtc': '2026-10-08T00:00:00Z',
    'cleanInstall': true,
    'installedApkSha256': installedApkSha256,
    'appBytes': appBytes,
    'dataBytes': dataBytes,
    'cacheBytes': 25,
  })}\n',
  flush: true,
);

String _relative(Directory projectRoot, File file) => file.path
    .substring(projectRoot.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');
