import '../vector.dart';
import 'utils.dart';

extension DotExtension<T> on Vector<T> {
  /// Computes the dot product of this [Vector] and [other].
  T dot(Vector<T> other) {
    checkDimensions<T>(this, other);
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      result = add(result, mul(getUnchecked(i), other.getUnchecked(i)));
    }
    return result;
  }
}
