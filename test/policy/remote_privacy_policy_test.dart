import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/release_privacy_policy.dart';

void main() {
  test('release retains explicit remote access with bounded LAN cleartext', () {
    expect(
      validateReleaseManifest(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"/>',
      ),
      isEmpty,
    );
    const removed =
        '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"><uses-permission android:name="android.permission.INTERNET" tools:node="remove"/></manifest>''';
    expect(validateReleaseManifest(removed), isNotEmpty);
    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(validateMainManifest(main), isEmpty);
    expect(
      validateMainManifest(
        main.replaceFirst(
          'android:usesCleartextTraffic="true"',
          'android:usesCleartextTraffic="false"',
        ),
      ),
      isNotEmpty,
    );
  });
}
