import '../../../type.dart';
import '../vector.dart';
import '../vector_format.dart';

extension IterableVectorExtension<T> on Iterable<T> {
  /// Copies this iterable into a new [Vector].
  Vector<T> toVector({DataType<T>? dataType, VectorFormat? format}) =>
      Vector<T>.fromIterable(
        dataType ?? DataType.fromType<T>(),
        this,
        format: format,
      );
}
