import '../vector.dart';

extension MagnitudeVectorExtension<T> on Vector<T> {
  /// Computes the squared magnitude (Euclidean norm, length) of this [Vector].
  T get magnitude2 {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      final value = getUnchecked(i);
      result = add(result, mul(value, value));
    }
    return result;
  }

  /// Computes the magnitude (Euclidean norm, length) of this [Vector].
  T get magnitude => dataType.field.pow(magnitude2, dataType.cast(0.5));
}
