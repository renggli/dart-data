library data.vector.view.cast;

import '../../../tensor.dart';
import '../../../type.dart';
import '../vector.dart';

/// Mutable cast vector.
class CastVector<S, T> extends Vector<T> {
  final Vector<S> _vector;

  CastVector(this._vector, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Vector<T> copy() => CastVector(_vector.copy(), dataType);

  @override
  T getUnchecked(int index) => dataType.cast(_vector.getUnchecked(index));

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(index, _vector.dataType.cast(value));
}
