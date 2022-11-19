import '../vector.dart';
import '../view/unary_operation_vector.dart';

extension NegVectorExtension<T> on Vector<T> {
  /// Returns a view of this [Vector] negated.
  Vector<T> operator -() => unaryOperation(dataType.field.neg);
}
