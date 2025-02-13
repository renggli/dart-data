import '../matrix.dart';
import '../view/binary_operation_matrix.dart';

extension LerpMatrixExtension<T> on Matrix<T> {
  /// Returns a view of the element-wise linear interpolation between this
  /// [Matrix] and [other] with a factor of [t]. If [t] is equal to `0` the
  /// result is `this`, if [t] is equal to `1` the result is [other].
  Matrix<T> lerp(Matrix<T> other, num t) {
    final add = dataType.field.add, scale = dataType.field.scale;
    return binaryOperation(
      other,
      (a, b) => add(scale(a, 1.0 - t), scale(b, t)),
    );
  }
}
