import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';

extension ListVectorExtension<T> on List<T> {
  /// Converts this list to a corresponding vector.
  ///
  /// If [format] is specified, the list is copied into a mutable vector of the
  /// selected format; otherwise a view onto this list is provided.
  Vector<T> toVector({DataType<T>? dataType, VectorFormat? format}) =>
      Vector.fromList(dataType ?? DataType.fromType<T>(), this, format: format);
}
