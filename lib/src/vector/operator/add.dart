import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension AddVectorExtension<T> on Vector<T> {
  /// Returns a [Vector] with the element-wise addition of this and [other].
  Vector<T> add(Vector<T> other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.add);
    return result;
  }

  /// In-place adds [other] to this one.
  Vector<T> addEq(Vector<T> other) => add(other, target: this);

  /// Adds [other] to this one.
  Vector<T> operator +(Vector<T> other) => add(other);
}
