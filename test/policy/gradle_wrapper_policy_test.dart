import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android Gradle wrapper is a tracked executable build entrypoint',
    () async {
      const wrapperFiles = <String>[
        'android/gradlew',
        'android/gradlew.bat',
        'android/gradle/wrapper/gradle-wrapper.jar',
        'android/gradle/wrapper/gradle-wrapper.properties',
      ];
      final tracked = await Process.run('git', <String>[
        'ls-files',
        '--stage',
        '--error-unmatch',
        ...wrapperFiles,
      ]);

      expect(tracked.exitCode, 0, reason: tracked.stderr as String?);
      expect(
        tracked.stdout,
        matches(
          RegExp(
            r'^100755 [0-9a-f]+ 0\tandroid/gradlew$',
            multiLine: true,
          ),
        ),
      );
    },
  );
}
