library data.vector.view.cast;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable cast vector.
class CastVector<S, T> with Vector<T> {
  final Vector<S> vector;

  CastVector(this.vector, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Vector<T> copy() => CastVector<S, T>(vector.copy(), dataType);

  @override
  T getUnchecked(int index) => dataType.cast(vector.getUnchecked(index));

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(index, vector.dataType.cast(value));
}

extension CastVectorExtension<T> on Vector<T> {
  /// Returns a [Vector] with the elements cast to `dataType`.
  Vector<S> cast<S>(DataType<S> dataType) => CastVector<T, S>(this, dataType);
}
