import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';

/// User-authorized restore boundary; bootstrap must override this provider.
final restoreServiceProvider = Provider<RestoreService>(
  (ref) => throw UnimplementedError('RestoreService is not installed'),
);
