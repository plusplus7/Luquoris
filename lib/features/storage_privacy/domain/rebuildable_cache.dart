import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:meta/meta.dart';

/// Counts only allowlisted derived artifacts removed from app cache storage.
@immutable
final class RebuildableCacheCleanupReceipt {
  /// Creates an immutable cleanup receipt.
  const RebuildableCacheCleanupReceipt({
    required this.filesDeleted,
    required this.bytesDeleted,
  }) : assert(filesDeleted >= 0, 'filesDeleted must be non-negative'),
       assert(bytesDeleted >= 0, 'bytesDeleted must be non-negative');

  /// Number of regular derived files removed.
  final int filesDeleted;

  /// Sum of regular derived-file bytes removed.
  final int bytesDeleted;
}

/// Recoverable cleanup failure, including work completed before failure.
final class RebuildableCacheFailure implements Failure {
  /// Creates a privacy-safe cleanup failure.
  const RebuildableCacheFailure({
    required this.code,
    required this.filesDeleted,
    required this.bytesDeleted,
  });

  @override
  final String code;

  /// Number of derived files removed before the failure.
  final int filesDeleted;

  /// Derived-file bytes removed before the failure.
  final int bytesDeleted;
}

/// Native boundary for deleting only explicitly rebuildable cache artifacts.
// The interface is intentional: destructive filesystem work must be injectable.
// ignore: one_member_abstracts
abstract interface class RebuildableCacheService {
  /// Clears allowlisted derived cache and never accepts paths from Dart.
  Future<Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>>
  clear();
}
