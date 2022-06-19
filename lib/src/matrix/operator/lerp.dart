import '../../../type.dart';
import '../matrix.dart';
import '../matrix_format.dart';
import 'utils.dart';

extension LerpMatrixExtension<T> on Matrix<T> {
  /// Interpolates linearly between this [Matrix] and [other] with a factor of
  /// [t]. If [t] is equal to `0` the result is `this`, if [t] is equal to `1`
  /// the result is [other].
  Matrix<T> lerp(Matrix<T> other, num t,
      {Matrix<T>? target, DataType<T>? dataType, MatrixFormat? format}) {
    final result = createMatrix<T>(this, target, dataType, format);
    final add = result.dataType.field.add, scale = result.dataType.field.scale;
    binaryOperator<T>(
        result, this, other, (a, b) => add(scale(a, 1.0 - t), scale(b, t)));
    return result;
  }

  /// In-place interpolates linearly between this [Matrix] and [other].
  Matrix<T> lerpEq(Matrix<T> other, num t) => lerp(other, t, target: this);
}
