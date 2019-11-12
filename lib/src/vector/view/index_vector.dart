library data.vector.view.index;

import '../../../tensor.dart';
import '../../../type.dart';
import '../../shared/config.dart';
import '../vector.dart';

// A mutable indexed view of a vector.
class IndexVector<T> extends Vector<T> {
  final Vector<T> _vector;
  final List<int> _indexes;

  IndexVector(Vector<T> vector, Iterable<int> indexes)
      : this._(vector, indexDataType.copyList(indexes));

  IndexVector._(this._vector, this._indexes);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get count => _indexes.length;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Vector<T> copy() => IndexVector._(_vector.copy(), _indexes);

  @override
  T getUnchecked(int index) => _vector.getUnchecked(_indexes[index]);

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(_indexes[index], value);

  @override
  Vector<T> indexUnchecked(Iterable<int> indexes) =>
      IndexVector<T>(_vector, indexes.map((index) => _indexes[index]));
}
