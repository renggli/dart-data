library data.vector.operator.mul;

import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension MulExtension<T> on Vector<T> {
  /// Multiplies this [Vector] with [other].
  ///
  /// If [other] is a [Vector], then element-wise multiplication is performed.
  /// If [other] is a scalar, then the vector is scaled.
  Vector<T> mul(/* Matrix<T>|Vector<T>|T */ Object other,
      {Vector<T> target, DataType<T> dataType, VectorFormat format}) {
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

  /// Multiplies this [Vector] with [other].
  Vector<T> operator *(/* Vector<T>|T */ Object other) => mul(other);
}
