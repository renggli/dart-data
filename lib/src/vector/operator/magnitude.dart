import '../vector.dart';

extension MagnitudeVectorExtension<T> on Vector<T> {
  /// Computes the magnitude (Euclidean norm, length) of this [Vector].
  T get magnitude => dataType.field.pow(magnitudeSquared, dataType.cast(0.5));

  /// Computes the squared magnitude (Euclidean norm, length) of this [Vector].
  T get magnitudeSquared {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      final value = getUnchecked(i);
      result = add(result, mul(value, value));
    }
    return result;
  }

  @Deprecated('Use `magnitudeSquared` instead.')
  T get magnitude2 => magnitudeSquared;
}
