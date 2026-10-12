import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:meta/meta.dart';

/// Closed state of one explicit local backup attempt.
@immutable
sealed class BackupState extends ValueObject {
  /// Creates a backup state.
  const BackupState();
}

/// Backup creation is in progress.
final class BackupPending extends BackupState {
  /// Creates a pending backup state.
  const BackupPending();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// A complete checksummed archive exists in app-private storage.
final class BackupCompleted extends BackupState {
  /// Creates a completed backup state.
  const BackupCompleted({
    required this.relativePath,
    required this.sha256,
    required this.bytes,
  }) : assert(bytes >= 0, 'bytes must be non-negative'),
       assert(
         sha256.length == 64,
         'sha256 must contain 64 lowercase hex digits',
       );

  /// Validated app-private archive path.
  final AppRelativePath relativePath;

  /// SHA-256 of the complete archive.
  final String sha256;

  /// Complete archive byte length.
  final int bytes;

  @override
  List<Object?> get equalityValues => <Object?>[relativePath, sha256, bytes];
}

/// Backup creation terminated with a stable privacy-safe reason.
final class BackupFailed extends BackupState {
  /// Creates a failed backup state.
  const BackupFailed({required this.failureCode});

  /// Stable machine-readable reason.
  final String failureCode;

  @override
  List<Object?> get equalityValues => <Object?>[failureCode];
}

/// Durable metadata for one explicit local backup attempt.
@immutable
final class BackupRecord extends ValueObject {
  /// Creates a durable backup record.
  const BackupRecord({
    required this.id,
    required this.createdAtUtcMs,
    required this.state,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable operation identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Current closed backup state.
  final BackupState state;

  /// Returns a copy with a changed [state].
  BackupRecord copyWith({BackupState? state}) => BackupRecord(
    id: id,
    createdAtUtcMs: createdAtUtcMs,
    state: state ?? this.state,
  );

  @override
  List<Object?> get equalityValues => <Object?>[id, createdAtUtcMs, state];
}
