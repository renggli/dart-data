library data.vector.view.index_vector;

import 'package:data/type.dart';

import '../../shared/config.dart';
import '../vector.dart';

// A mutable indexed view of a vector.
class IndexVector<T> extends Vector<T> {
  final Vector<T> _vector;
  final List<int> _indexes;

  IndexVector(this._vector, Iterable<int> indexes)
      : _indexes = indexDataType.copyList(indexes);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get count => _indexes.length;

  @override
  T getUnchecked(int index) => _vector.getUnchecked(_indexes[index]);

  @override
  void setUnchecked(int index, T value) =>
      _vector.setUnchecked(_indexes[index], value);

  @override
  Vector<T> indexUnchecked(Iterable<int> indexes) =>
      IndexVector<T>(_vector, indexes.map((index) => _indexes[index]));
}
