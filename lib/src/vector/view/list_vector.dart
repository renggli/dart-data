import '../../../type.dart';
import '../impl/standard_vector.dart';
import '../vector.dart';
import '../vector_format.dart';

extension ListVectorExtension<T> on List<T> {
  /// Converts this list to a corresponding vector.
  ///
  /// If [format] is provided the list data will be copied into a native format,
  /// otherwise a view onto the (possibly mutable) underlying list will be
  /// returned.
  Vector<T> toVector({DataType<T>? dataType, VectorFormat? format}) {
    dataType ??= DataType.fromType<T>();
    return format == null
        ? StandardVector<T>.fromList(dataType, this)
        : Vector.fromList(dataType, this, format: format);
  }
}
