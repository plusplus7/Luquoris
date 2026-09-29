import 'package:loquiris/core/failure.dart';

/// The typed outcome of an operation that can fail recoverably.
sealed class Result<T, F extends Failure> {
  const Result();

  /// Resolves this outcome by invoking exactly one branch.
  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) {
    return switch (this) {
      Ok<T, F>(:final value) => onOk(value),
      Err<T, F>(:final failure) => onErr(failure),
    };
  }

  /// Transforms a successful value and preserves a failure unchanged.
  Result<R, F> map<R>(R Function(T value) transform) {
    return switch (this) {
      Ok<T, F>(:final value) => Ok<R, F>(transform(value)),
      Err<T, F>(:final failure) => Err<R, F>(failure),
    };
  }

  /// Chains another typed operation after a successful value.
  Result<R, F> flatMap<R>(Result<R, F> Function(T value) transform) {
    return switch (this) {
      Ok<T, F>(:final value) => transform(value),
      Err<T, F>(:final failure) => Err<R, F>(failure),
    };
  }

  /// Whether this outcome contains a successful value.
  bool get isOk => this is Ok<T, F>;

  /// Whether this outcome contains a recoverable failure.
  bool get isErr => this is Err<T, F>;
}

/// A successful [Result].
final class Ok<T, F extends Failure> extends Result<T, F> {
  /// Creates a successful result containing [value].
  const Ok(this.value);

  /// The successful value.
  final T value;
}

/// A failed [Result] containing a typed recoverable failure.
final class Err<T, F extends Failure> extends Result<T, F> {
  /// Creates a failed result containing [failure].
  const Err(this.failure);

  /// The recoverable failure.
  final F failure;
}
