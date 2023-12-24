import '../../type/type.dart';
import '../vector.dart';
import '../view/cross_operation_vector.dart';

extension CrossVectorExtension<T> on Vector<T> {
  /// Computes the cross product of this [Vector] and [other].
  Vector<T> cross(Vector<T> other, {DataType<T>? dataType}) =>
      CrossOperationVector<T>(dataType ?? this.dataType, this, other);
}
