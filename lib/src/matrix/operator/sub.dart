import '../matrix.dart';
import '../view/binary_operation_matrix.dart';

extension SubMatrixExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] subtracted by [other].
  Matrix<T> operator -(Matrix<T> other) =>
      binaryOperation(other, dataType.field.sub);
}
