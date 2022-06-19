import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';
import 'utils.dart';

extension NegVectorExtension<T> on Vector<T> {
  /// Negates this [Vector].
  Vector<T> neg(
      {Vector<T>? target, DataType<T>? dataType, VectorFormat? format}) {
    final result = createVector<T>(this, target, dataType, format);
    unaryOperator<T>(result, this, result.dataType.field.neg);
    return result;
  }

  /// In-place negates this [Vector].
  Vector<T> negEq() => neg(target: this);

  /// Negate this [Vector].
  Vector<T> operator -() => neg();
}
