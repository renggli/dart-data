import '../matrix.dart';
import '../view/unary_operation_matrix.dart';

extension NegMatrixExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] negated.
  Matrix<T> operator -() => unaryOperation(dataType.field.neg);
}
