import '../../vector/vector.dart';
import '../../vector/view/column_matrix.dart';
import '../matrix.dart';
import '../view/matrix_matrix_multiplication_matrix.dart';
import '../view/matrix_vector_multiplication_vector.dart';
import '../view/unary_operation_matrix.dart';

extension MulMatrixExtension<T> on Matrix<T> {
  /// Returns a view of this [Matrix] multiplied with [other].
  Matrix<T> operator *(/* Matrix<T>|Vector<T>|T */ Object other) {
    if (other is Matrix<T>) {
      return mulMatrix(other);
    } else if (other is Vector<T>) {
      return mulVector(other).columnMatrix;
    } else if (other is T) {
      return mulScalar(other as T);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid scalar.');
    }
  }

  /// Returns a view of this [Matrix] multiplied with [other].
  Matrix<T> mulScalar(T other) {
    final mul = dataType.field.mul;
    return unaryOperation((value) => mul(value, other));
  }
}
