import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_privacy_policy.dart';

void main() {
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
