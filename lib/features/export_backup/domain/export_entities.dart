import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:meta/meta.dart';

/// User-authorized local export representation.
enum LocalExportFormat {
  /// Audio media.
  audio,

  /// Plain transcript text.
  plainText,

  /// Timestamped subtitles.
  subtitles,

  /// Structured meeting JSON.
  structuredJson,

  /// Checksummed portable archive.
  archive,
}

/// Closed state of one export attempt.
@immutable
sealed class ExportState extends ValueObject {
  /// Creates an export state.
  const ExportState();
}

/// Export has not completed yet.
final class ExportPending extends ExportState {
  /// Creates a pending export state.
  const ExportPending();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// Export completed to an app-relative file.
final class ExportCompleted extends ExportState {
  /// Creates a completed export result.
  const ExportCompleted({required this.relativePath, required this.bytes})
    : assert(bytes >= 0, 'bytes must be non-negative');

  /// Path relative to the export base directory.
  final AppRelativePath relativePath;

  /// Final file size.
  final int bytes;

  @override
  List<Object?> get equalityValues => <Object?>[relativePath, bytes];
}

/// Export failed with a stable structured code.
final class ExportFailed extends ExportState {
  /// Creates a failed export result.
  const ExportFailed({required this.failureCode});

  /// Stable failure code without user data.
  final String failureCode;

  @override
  List<Object?> get equalityValues => <Object?>[failureCode];
}

/// Durable record of one user-authorized export attempt.
@immutable
final class ExportRecord extends ValueObject {
  /// Creates an export record.
  const ExportRecord({
    required this.id,
    required this.meetingId,
    required this.format,
    required this.createdAtUtcMs,
    required this.state,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable export identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Requested representation.
  final LocalExportFormat format;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Current closed export state.
  final ExportState state;

  /// Returns a copy with a changed [state].
  ExportRecord copyWith({ExportState? state}) => ExportRecord(
    id: id,
    meetingId: meetingId,
    format: format,
    createdAtUtcMs: createdAtUtcMs,
    state: state ?? this.state,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    format,
    createdAtUtcMs,
    state,
  ];
}
