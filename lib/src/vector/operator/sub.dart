import '../vector.dart';
import '../view/binary_operation_vector.dart';

extension SubVectorExtension<T> on Vector<T> {
  /// Returns a view of this [Vector] subtracted by [other].
  Vector<T> operator -(Vector<T> other) =>
      binaryOperation(other, dataType.field.sub);
}
