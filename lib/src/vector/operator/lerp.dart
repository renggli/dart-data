import '../vector.dart';
import '../view/binary_operation_vector.dart';

extension LerpVectorExtension<T> on Vector<T> {
  /// Returns a view of the element-wise linear interpolation between this
  /// [Vector] and [other] with a factor of [t]. If [t] is equal to `0` the
  /// result is `this`, if [t] is equal to `1` the result is [other].
  Vector<T> lerp(Vector<T> other, num t) {
    final add = dataType.field.add, scale = dataType.field.scale;
    return binaryOperation(
        other, (a, b) => add(scale(a, 1.0 - t), scale(b, t)));
  }
}
