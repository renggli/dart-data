import '../vector.dart';
import '../view/binary_operation_vector.dart';
import '../view/unary_operation_vector.dart';

extension DivVectorExtension<T> on Vector<T> {
  /// Returns a view of the element-wise division of this [Vector] by [other].
  Vector<T> operator /(/* Vector<T>|T */ Object other) {
    if (other is Vector<T>) {
      return divVector(other);
    } else if (other is T) {
      return divScalar(other as T);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid scalar.');
    }
  }

  /// Returns a view of the element-wise multiplication of this [Vector] and [other].
  Vector<T> divVector(Vector<T> other) =>
      binaryOperation(other, dataType.field.div);

  /// Returns a view of the multiplication of this [Vector] and a scalar.
  Vector<T> divScalar(T other) {
    final div = dataType.field.div;
    return unaryOperation((value) => div(value, other));
  }
}
