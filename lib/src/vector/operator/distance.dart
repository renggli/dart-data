import '../vector.dart';

extension DistanceVectorExtension<T> on Vector<T> {
  /// Computes the distance between this [Vector] and [other].
  T distance(Vector<T> other) =>
      dataType.field.pow(distanceSquared(other), dataType.cast(0.5));

  /// Computes the squared distance between this [Vector] and [other].
  T distanceSquared(Vector<T> other) {
    assert(
      count == other.count,
      'Element count of this ($count) and other (${other.count}) operand '
      'must match.',
    );
    final add = dataType.field.add,
        sub = dataType.field.sub,
        mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var i = 0; i < count; i++) {
      final delta = sub(getUnchecked(i), other.getUnchecked(i));
      result = add(result, mul(delta, delta));
    }
    return result;
  }
}
