import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable reverse view of a vector.
class ReversedVector<T> with Vector<T> {
  ReversedVector(this.vector);

  final Vector<T> vector;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int index) => vector.getUnchecked(vector.count - index - 1);

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(vector.count - index - 1, value);
}

extension ReversedVectorExtension<T> on Vector<T> {
  /// Returns a reversed view of this [Vector].
  Vector<T> get reversed => switch (this) {
    ReversedVector<T>(vector: final vector) => vector,
    _ => ReversedVector<T>(this),
  };
}
