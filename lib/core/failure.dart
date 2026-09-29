/// Stable, non-localized information about a recoverable boundary failure.
abstract interface class Failure {
  /// A stable code that presentation code can map to localized copy.
  String get code;
}
