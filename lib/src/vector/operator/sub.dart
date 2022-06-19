import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension SubVectorExtension<T> on Vector<T> {
  /// Returns a [Vector] with the element-wise subtraction of [other] from this.
  Vector<T> sub(Vector<T> other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.sub);
    return result;
  }

  /// In-place subtracts [other] from this one.
  Vector<T> subEq(Vector<T> other) => sub(other, target: this);

  /// Subtracts [other] from this one.
  Vector<T> operator -(Vector<T> other) => sub(other);
}
