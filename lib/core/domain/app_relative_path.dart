import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:meta/meta.dart';

/// A validated path rooted beneath an application-owned base directory.
@immutable
final class AppRelativePath extends ValueObject {
  const AppRelativePath._(this.value);

  /// Parses [candidate] without accepting absolute or traversing paths.
  static Result<AppRelativePath, InvalidAppRelativePath> tryParse(
    String candidate,
  ) {
    final parts = candidate.split('/');
    final hasInvalidSegment = parts.any(
      (part) => part.isEmpty || part == '.' || part == '..',
    );
    final isWindowsAbsolute = RegExp('^[A-Za-z]:').hasMatch(candidate);
    if (candidate.isEmpty ||
        candidate.startsWith('/') ||
        candidate.codeUnits.contains(0x5c) ||
        candidate.contains('\u0000') ||
        isWindowsAbsolute ||
        hasInvalidSegment) {
      return const Err<AppRelativePath, InvalidAppRelativePath>(
        InvalidAppRelativePath(),
      );
    }
    return Ok<AppRelativePath, InvalidAppRelativePath>(
      AppRelativePath._(candidate),
    );
  }

  /// Portable path text using forward-slash separators.
  final String value;

  @override
  List<Object?> get equalityValues => <Object?>[value];

  @override
  String toString() => value;
}

/// Failure returned when a path can escape its application-owned base.
@immutable
final class InvalidAppRelativePath implements Failure {
  /// Creates a privacy-safe invalid-path failure.
  const InvalidAppRelativePath();

  @override
  String get code => 'invalid_app_relative_path';
}
