import '../vector.dart';
import '../view/binary_operation_vector.dart';

extension AddVectorExtension<T> on Vector<T> {
  /// Returns a view of this [Vector] added to [other].
  Vector<T> operator +(Vector<T> other) =>
      binaryOperation(other, dataType.field.add);
}
