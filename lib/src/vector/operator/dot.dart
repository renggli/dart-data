import '../vector.dart';

extension DotVectorExtension<T> on Vector<T> {
  /// Computes the dot product of this [Vector] and [other].
  T dot(Vector<T> other) {
    assert(count == other.count,
        'Element count of this ($count) and other (${other.count}) must match.');
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      result = add(result, mul(getUnchecked(i), other.getUnchecked(i)));
    }
    return result;
  }
}
