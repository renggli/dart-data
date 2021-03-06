import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension AddVectorExtension<T> on Vector<T> {
  /// Adds this [Vector] element-wise to [other].
  Vector<T> add(Vector<T> other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.add);
    return result;
  }

  /// Adds [other] to this [Vector].
  Vector<T> operator +(Vector<T> other) => add(other);
}
