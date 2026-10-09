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
