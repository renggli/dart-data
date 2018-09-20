library data.matrix.view.mapped_matrix;

import 'package:data/src/type/type.dart';

import '../vector.dart';

typedef T VectorTransformation<S, T>(int index, S value);

/// A lazy transformed vector.
class MappedVector<S, T> extends Vector<T> {
  final Vector<S> _vector;
  final VectorTransformation<S, T> _callback;

  MappedVector(this._vector, this._callback, this.dataType);

  @override
  Vector<T> copy() => MappedVector(_vector.copy(), _callback, dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => _vector.count;

  @override
  T getUnchecked(int index) => _callback(index, _vector.getUnchecked(index));

  @override
  void setUnchecked(int index, T value) =>
      throw UnsupportedError('Vector is not mutable.');
}
