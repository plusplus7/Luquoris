import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/release_privacy_policy.dart';

void main() {
  test('release supports authorized LAN HTTP and keeps backup isolation', () {
    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      validateMainManifest(
        main.replaceFirst(
          'android:usesCleartextTraffic="false"',
          'android:usesCleartextTraffic="true"',
        ),
      ),
      isEmpty,
    );
    expect(validateBackupManifest(main), isEmpty);
  });
  test('a release overlay cannot silently disable configured LAN transport', () {
    expect(
      validateReleaseManifest(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:usesCleartextTraffic="false"/></manifest>',
      ),
      isNotEmpty,
    );
  });
}
