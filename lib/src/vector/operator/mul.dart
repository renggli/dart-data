import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension MulVectorExtension<T> on Vector<T> {
  /// Multiplies this [Vector] element-wise with [other].
  Vector<T> mul(/* Matrix<T>|Vector<T>|T */ Object other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    if (other is Vector<T>) {
      binaryOperator<T>(result, this, other, result.dataType.field.mul);
    } else {
      final mul = result.dataType.field.mul;
      final factor = result.dataType.cast(other);
      unaryOperator<T>(result, this, (value) => mul(value, factor));
    }
    return result;
  }

  /// In-place multiplies this by [other].
  Vector<T> mulEq(/* Vector<T>|T */ Object other) => mul(other, target: this);

  /// Multiplies this with [other].
  Vector<T> operator *(/* Vector<T>|T */ Object other) => mul(other);
}
