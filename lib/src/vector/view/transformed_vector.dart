library data.vector.view.transformed;

import 'package:data/src/vector/mixins/unmodifiable_vector.dart';
import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Read-only transformed vector.
class TransformedVector<S, T> extends Vector<T>
    with UnmodifiableVectorMixin<T> {
  final Vector<S> _vector;
  final T Function(int index, S value) _callback;

  TransformedVector(this._vector, this._callback, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get count => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Vector<T> copy() => TransformedVector(_vector.copy(), _callback, dataType);

  @override
  T getUnchecked(int index) => _callback(index, _vector.getUnchecked(index));
}
