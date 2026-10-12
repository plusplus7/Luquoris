import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';

/// User-confirmed local backup boundary; bootstrap installs production I/O.
final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError('BackupService is not installed'),
);
