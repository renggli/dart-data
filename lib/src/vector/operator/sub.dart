import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension SubVectorExtension<T> on Vector<T> {
  /// Subtracts [other] from this [Vector].
  Vector<T> sub(Vector<T> other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.sub);
    return result;
  }

  /// Subtracts [other] from this [Vector].
  Vector<T> operator -(Vector<T> other) => sub(other);
}
