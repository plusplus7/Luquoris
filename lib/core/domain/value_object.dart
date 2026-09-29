import 'package:meta/meta.dart';

/// Immutable base for domain values with structural equality.
@immutable
abstract base class ValueObject {
  /// Creates an immutable value object.
  const ValueObject();

  /// Fields that define the value's identity, in stable order.
  @protected
  List<Object?> get equalityValues;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is ValueObject &&
          _listsEqual(equalityValues, other.equalityValues);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    runtimeType,
    ...equalityValues,
  ]);
}

bool _listsEqual(List<Object?> left, List<Object?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
