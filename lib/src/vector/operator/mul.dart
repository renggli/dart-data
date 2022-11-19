import '../vector.dart';
import '../view/binary_operation_vector.dart';
import '../view/unary_operation_vector.dart';

extension MulVectorExtension<T> on Vector<T> {
  /// Returns a view of the element-wise multiplication of this [Vector] and [other].
  Vector<T> operator *(/* Vector<T>|T */ Object other) {
    if (other is Vector<T>) {
      return mulVector(other);
    } else if (other is T) {
      return mulScalar(other as T);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid scalar.');
    }
  }

  /// Returns a view of the element-wise multiplication of this [Vector] and [other].
  Vector<T> mulVector(Vector<T> other) =>
      binaryOperation(other, dataType.field.mul);

  /// Returns a view of the multiplication of this [Vector] and a scalar.
  Vector<T> mulScalar(T other) {
    final mul = dataType.field.mul;
    return unaryOperation((value) => mul(value, other));
  }
}
