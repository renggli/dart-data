library data.vector.view.reversed;

import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable reverse view of a vector.
class ReversedVector<T> extends Vector<T> {
  final Vector<T> _vector;

  ReversedVector(this._vector);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get count => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Vector<T> get reversed => _vector;

  @override
  Vector<T> copy() => ReversedVector(_vector.copy());

  @override
  T getUnchecked(int index) => _vector.getUnchecked(_vector.count - index - 1);

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(_vector.count - index - 1, value);
}
