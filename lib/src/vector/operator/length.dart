import '../vector.dart';

extension LengthExtension<T> on Vector<T> {
  /// Computes the squared length of this [Vector].
  T get length2 {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      final value = getUnchecked(i);
      result = add(result, mul(value, value));
    }
    return result;
  }

  /// Computes the length of this [Vector].
  T get length => dataType.field.pow(length2, dataType.cast(0.5));
}
