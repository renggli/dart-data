library data.vector.operator.neg;

import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension NegExtension<T> on Vector<T> {
  /// Negates this [Vector].
  Vector<T> neg({Vector<T> target, DataType<T> dataType, VectorFormat format}) {
    final result = createVector<T>(this, target, dataType, format);
    unaryOperator<T>(result, this, result.dataType.field.neg);
    return result;
  }

  /// Convenience method to negate this [Vector].
  Vector<T> operator -() => neg();
}
