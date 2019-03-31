library data.vector.view.transformed;

import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Read-only transformed vector.
class TransformedVector<S, T> extends Vector<T> {
  final Vector<S> _vector;
  final T Function(int index, S value) _read;
  final S Function(int index, T value) _write;

  TransformedVector(this._vector, this._read, this._write, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Vector<T> copy() =>
      TransformedVector(_vector.copy(), _read, _write, dataType);

  @override
  T getUnchecked(int index) => _read(index, _vector.getUnchecked(index));

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(index, _write(index, value));
}
