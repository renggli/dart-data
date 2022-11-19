import '../matrix.dart';
import '../view/binary_operation_matrix.dart';

extension AddMatrixExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] added to [other].
  Matrix<T> operator +(Matrix<T> other) =>
      binaryOperation(other, dataType.field.add);
}
