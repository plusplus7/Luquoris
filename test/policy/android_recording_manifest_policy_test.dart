import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production keeps recording independent and declares explicit remote access',
    () {
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
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.ACCESS_NETWORK_STATE'));
      expect(manifest, contains('android:usesCleartextTraffic="true"'));
      expect(manifest, contains('android.permission.BIND_JOB_SERVICE'));
    },
  );
}
