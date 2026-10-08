import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fakeTools;
  late File fakeAdb;

  setUp(() async {
    fakeTools = await Directory.systemTemp.createTemp(
      'loquiris-footprint-script-',
    );
    fakeAdb = File('${fakeTools.path}/adb');
  });

  tearDown(() => fakeTools.delete(recursive: true));

  test('host preflight rejects zero and multiple connected devices', () async {
    await _writeFakeAdb(fakeAdb, deviceLines: const <String>[]);
    final noDevice = await _runDeviceCheck(fakeAdb);
    expect(noDevice.exitCode, 65);
    expect(noDevice.stderr, contains('release_footprint.device_count_invalid'));

    await _writeFakeAdb(
      fakeAdb,
      deviceLines: const <String>[
        'serial-one device product:chopin model:M2104K10AC',
        'serial-two device product:chopin model:M2104K10AC',
      ],
    );
    final multipleDevices = await _runDeviceCheck(fakeAdb);
    expect(multipleDevices.exitCode, 65);
    expect(
      multipleDevices.stderr,
      contains('release_footprint.device_count_invalid'),
    );
  });

  test('host preflight accepts only the selected target identity', () async {
    await _writeFakeAdb(
      fakeAdb,
      deviceLines: const <String>[
        'target-serial device product:chopin model:M2104K10AC',
      ],
      model: 'M2104K10AC',
      device: 'chopin',
      fingerprint: 'Redmi/chopin/chopin:13/build/test-keys',
    );

    final result = await _runDeviceCheck(fakeAdb);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('release_footprint.device_ready'));
    expect(result.stdout, isNot(contains('Redmi/chopin')));
    expect(result.stderr, isEmpty);
  });

  test('host rejects an AAB without required native symbol metadata', () async {
    final validRoot = await Directory('${fakeTools.path}/valid').create();
    final symbolRoot = await Directory(
      '${validRoot.path}/BUNDLE-METADATA/'
      'com.android.tools.build.debugsymbols/arm64-v8a',
    ).create(recursive: true);
    await File('${symbolRoot.path}/libflutter.so.sym').writeAsBytes(<int>[1]);
    await File('${symbolRoot.path}/libapp.so.sym').writeAsBytes(<int>[2]);
    final validAab = File('${fakeTools.path}/valid.aab');
    final zipResult = await Process.run(
      '/usr/bin/zip',
      <String>['-q', '-r', validAab.path, 'BUNDLE-METADATA'],
      workingDirectory: validRoot.path,
    );
    expect(zipResult.exitCode, 0);

    final valid = await Process.run(
      'bash',
      <String>[
        'tool/measure_release_footprint.sh',
        '--check-aab-only',
        validAab.path,
      ],
      workingDirectory: Directory.current.path,
      environment: Platform.environment,
    );
    expect(valid.exitCode, 0);
    expect(valid.stdout, contains('release_footprint.aab_symbols_ready'));

    final invalidAab = File('${fakeTools.path}/invalid.aab');
    await invalidAab.writeAsBytes(<int>[1, 2, 3]);
    final invalid = await Process.run(
      'bash',
      <String>[
        'tool/measure_release_footprint.sh',
        '--check-aab-only',
        invalidAab.path,
      ],
      workingDirectory: Directory.current.path,
      environment: Platform.environment,
    );
    expect(invalid.exitCode, 66);
    expect(invalid.stderr, contains('release_footprint.aab_symbols_missing'));
  });

  test('host signs and verifies the measurement APK before install', () async {
    final apk = File('${fakeTools.path}/app-release.apk');
    await apk.writeAsBytes(<int>[1, 2, 3]);
    final log = File('${fakeTools.path}/signing.log');
    final fakeKeytool = File('${fakeTools.path}/keytool');
    final fakeApksigner = File('${fakeTools.path}/apksigner');
    await _writeFakeSigningTools(
      keytool: fakeKeytool,
      apksigner: fakeApksigner,
    );

    final result = await Process.run(
      'bash',
      <String>[
        'tool/measure_release_footprint.sh',
        '--sign-apk-only',
        apk.path,
      ],
      workingDirectory: Directory.current.path,
      environment: <String, String>{
        ...Platform.environment,
        'KEYTOOL_BIN': fakeKeytool.path,
        'APKSIGNER_BIN': fakeApksigner.path,
        'MEASUREMENT_SIGNING_LOG': log.path,
      },
    );

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('release_footprint.apk_signed'));
    expect(
      await log.readAsLines(),
      containsAllInOrder(<String>[
        'keytool',
        'apksigner sign',
        'apksigner verify',
      ]),
    );
  });
}

Future<ProcessResult> _runDeviceCheck(File fakeAdb) => Process.run(
  'bash',
  <String>['tool/measure_release_footprint.sh', '--check-device-only'],
  workingDirectory: Directory.current.path,
  environment: <String, String>{
    ...Platform.environment,
    'ADB_BIN': fakeAdb.path,
  },
);

Future<void> _writeFakeAdb(
  File file, {
  required List<String> deviceLines,
  String model = '',
  String device = '',
  String fingerprint = '',
}) async {
  final devices = deviceLines.join(r'\n');
  final deviceOutput = devices.isEmpty ? '' : '$devices\\n';
  await file.writeAsString(
    <String>[
      '#!/usr/bin/env bash',
      'set -eu',
      r'if [[ "${1:-}" == "devices" ]]; then',
      "  printf 'List of devices attached\\n$deviceOutput'",
      '  exit 0',
      'fi',
      r'if [[ "${1:-}" == "-s" && "${3:-}" == "shell" && "${4:-}" == "getprop" ]]; then',
      r'  case "${5:-}" in',
      "    ro.product.model) printf '%s\\n' '$model' ;;",
      "    ro.product.device) printf '%s\\n' '$device' ;;",
      "    ro.build.fingerprint) printf '%s\\n' '$fingerprint' ;;",
      '    *) exit 2 ;;',
      '  esac',
      '  exit 0',
      'fi',
      'exit 2',
      '',
    ].join('\n'),
  );
  await Process.run('chmod', <String>['+x', file.path]);
}

Future<void> _writeFakeSigningTools({
  required File keytool,
  required File apksigner,
}) async {
  await keytool.writeAsString(
    <String>[
      '#!/usr/bin/env bash',
      'set -eu',
      r'''printf '%s\n' 'keytool' >>"$MEASUREMENT_SIGNING_LOG"''',
      r'''while [[ "$#" -gt 0 ]]; do''',
      r'''  if [[ "$1" == "-keystore" ]]; then''',
      '    shift',
      r'''    : >"$1"''',
      '    exit 0',
      '  fi',
      '  shift',
      'done',
      'exit 2',
      '',
    ].join('\n'),
  );
  await apksigner.writeAsString(
    <String>[
      '#!/usr/bin/env bash',
      'set -eu',
      r'''action="${1:-}"''',
      r'''printf 'apksigner %s\n' "$action" >>"$MEASUREMENT_SIGNING_LOG"''',
      r'''apk="${!#}"''',
      r'''case "$action" in''',
      r'''  sign) : >"$apk.signed" ;;''',
      r'''  verify) [[ -f "$apk.signed" ]] ;;''',
      '  *) exit 2 ;;',
      'esac',
      '',
    ].join('\n'),
  );
  await Process.run(
    'chmod',
    <String>['+x', keytool.path, apksigner.path],
  );
}
