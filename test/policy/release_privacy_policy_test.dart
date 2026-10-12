import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_privacy_policy.dart';

void main() {
  test('Android build accepts only verified generated model assets', () {
    final buildScript = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(
      buildScript,
      contains('buildDirectory.dir("generated/model_assets")'),
    );
    expect(buildScript, contains('model_assets_not_imported'));
    expect(buildScript, contains('model_manifests/index.json'));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains(
        'build/generated/model_assets/models/whisper-base-q5_1/',
      ),
    );
    expect(buildScript, isNot(contains('assets.srcDir(')));
    expect(
      File(
        'android/app/src/main/kotlin/com/loquiris/transcription/'
        'WhisperModelStore.kt',
      ).readAsStringSync(),
      contains('flutter_assets/build/generated/model_assets/'),
    );
    expect(buildScript, contains('noCompress += "bin"'));
    expect(buildScript, contains('dependsOn(verifyImportedModels)'));
  });

  test('release manifest explicitly removes network permissions', () {
    final manifest = File(
      'android/app/src/release/AndroidManifest.xml',
    ).readAsStringSync();

    expect(validateReleaseManifest(manifest), isEmpty);
  });

  test(
    'manifest validation cannot be satisfied by comments or adjacent nodes',
    () {
      const malformed = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
  <!-- android.permission.INTERNET tools:node="remove" -->
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  <application tools:node="remove" />
</manifest>
''';

      expect(validateReleaseManifest(malformed), hasLength(2));
    },
  );

  test('main manifest rejects Android backup and restore opt-ins', () {
    const manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
      android:allowBackup="true"
      android:fullBackupContent="@xml/backup_rules"
      android:dataExtractionRules="@xml/data_extraction_rules"
      android:backupAgent=".BackupAgent"
      android:backupInForeground="true"
      android:restoreAnyVersion="true" />
</manifest>
''';

    expect(
      validateMainManifest(manifest),
      containsAll(<String>[
        'application must set android:allowBackup="false"',
        'application must set android:fullBackupContent="false"',
        'application must not declare android:backupAgent',
        'application must not enable android:backupInForeground',
        'application must not enable android:restoreAnyVersion',
      ]),
    );
  });

  test('privacy gate rejects incomplete Android 12 extraction rules', () async {
    final fixtureDirectory = await Directory.systemTemp.createTemp(
      'loquiris-backup-policy-',
    );
    addTearDown(() => fixtureDirectory.delete(recursive: true));
    final manifest = File('${fixtureDirectory.path}/AndroidManifest.xml')
      ..writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
      android:allowBackup="false"
      android:fullBackupContent="false"
      android:dataExtractionRules="@xml/data_extraction_rules" />
</manifest>
''');
    final rules = File('${fixtureDirectory.path}/data_extraction_rules.xml')
      ..writeAsStringSync('''
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="root" path="." />
  </cloud-backup>
</data-extraction-rules>
''');

    final result = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/release_privacy_policy.dart',
        '--manifest',
        manifest.path,
        '--data-extraction-rules',
        rules.path,
        '--skip-dependencies',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(
      result.stderr,
      contains('rules must contain exactly one device-transfer section'),
    );
  });

  test('backup-only mode accepts a valid merged debug manifest', () async {
    final fixtureDirectory = await Directory.systemTemp.createTemp(
      'loquiris-merged-backup-policy-',
    );
    addTearDown(() => fixtureDirectory.delete(recursive: true));
    final manifest = File('${fixtureDirectory.path}/AndroidManifest.xml')
      ..writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <application
      android:allowBackup="false"
      android:fullBackupContent="false"
      android:dataExtractionRules="@xml/data_extraction_rules" />
</manifest>
''');
    final rules = File('${fixtureDirectory.path}/data_extraction_rules.xml')
      ..writeAsStringSync(_completeDataExtractionRules);

    final result = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/release_privacy_policy.dart',
        '--backup-manifest',
        manifest.path,
        '--data-extraction-rules',
        rules.path,
        '--skip-dependencies',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('source dependency privacy gate passes', () async {
    final result = await Process.run(
      'bash',
      ['tool/check_release_privacy.sh', '--source-only'],
      workingDirectory: Directory.current.path,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}

const _completeDataExtractionRules = '''
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </cloud-backup>
  <device-transfer>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </device-transfer>
</data-extraction-rules>
''';
