import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production manifest declares only offline recording capabilities', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final permission in <String>[
      'android.permission.RECORD_AUDIO',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MICROPHONE',
      'android.permission.WAKE_LOCK',
      'android.permission.POST_NOTIFICATIONS',
    ]) {
      expect(
        manifest,
        contains(permission),
        reason: '$permission must be declared',
      );
    }
    expect(
      manifest,
      contains('android:name=".recording.RecordingForegroundService"'),
    );
    expect(manifest, contains('android:foregroundServiceType="microphone"'));
    expect(manifest, contains('android:stopWithTask="false"'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });
}
