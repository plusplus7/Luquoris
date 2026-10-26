import 'dart:io';

import 'package:drift/native.dart';
import 'package:loquiris/data/database/app_database.dart';

/// Exports the real Drift schema for Android repository integration tests.
Future<void> main() async {
  final file = File('build/remote_native_test/remote-v7.sqlite');
  await file.parent.create(recursive: true);
  if (file.existsSync()) await file.delete();
  final database = AppDatabase(NativeDatabase(file));
  try {
    await database.customSelect('PRAGMA user_version').getSingle();
  } finally {
    await database.close();
  }
}
