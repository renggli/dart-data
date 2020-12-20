import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension DivVectorExtension<T> on Vector<T> {
  /// Divides this [Vector] element-wise by [other].
  Vector<T> div(/* Vector<T>|T */ Object other,
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    if (other is Vector<T>) {
      binaryOperator<T>(result, this, other, result.dataType.field.div);
    } else {
      final div = result.dataType.field.div;
      final factor = result.dataType.cast(other);
      unaryOperator<T>(result, this, (value) => div(value, factor));
    }
    return result;
  }

  /// Divides this [Vector] by [other].
  Vector<T> operator /(/* Vector<T>|T */ Object other) => div(other);
}
