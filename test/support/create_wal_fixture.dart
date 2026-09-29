import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) exit(64);
  final database = sqlite3.open(arguments[0])
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA wal_autocheckpoint = 0')
    ..execute(
      '''
      INSERT INTO meetings (
        id, created_at, updated_at, title, media_duration_us,
        lifecycle, language_mode
      ) VALUES (?, 1, 1, ?, 1234567, 'finalized', 'mixed')
      ''',
      <Object?>['meeting-hostile', arguments[1]],
    );
  final rowCount = database
      .select('SELECT count(*) FROM meetings')
      .single
      .values
      .single;
  if (rowCount != 1) exit(65);

  // Deliberately bypass sqlite3.dispose() to emulate process death with a
  // committed, uncheckpointed WAL bundle.
  exit(0);
}
