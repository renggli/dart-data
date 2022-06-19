import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension LerpVectorExtension<T> on Vector<T> {
  /// Interpolates linearly between this [Vector] and [other] with a factor of
  /// [t]. If [t] is equal to `0` the result is `this`, if [t] is equal to `1`
  /// the result is [other].
  Vector<T> lerp(Vector<T> other, num t,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    final add = result.dataType.field.add, scale = result.dataType.field.scale;
    binaryOperator<T>(
        result, this, other, (a, b) => add(scale(a, 1.0 - t), scale(b, t)));
    return result;
  }

  /// In-place linear interpolation between this [Vector] and [other].
  Vector<T> lerpEq(Vector<T> other, num t) => lerp(other, t, target: this);
}
