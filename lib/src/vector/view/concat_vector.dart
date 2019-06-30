library data.vector.view.concat;

import 'package:data/src/shared/config.dart';
import 'package:data/src/shared/lists.dart';
import 'package:data/src/vector/vector.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart';

/// Mutable concatenation of vectors.
class ConcatVector<T> extends Vector<T> {
  final List<Vector<T>> _vectors;
  final List<int> _indexes;

  ConcatVector(DataType<T> dataType, Iterable<Vector<T>> vectors)
      : this._withList(dataType, vectors.toList(growable: false));

  ConcatVector._withList(DataType<T> dataType, List<Vector<T>> vectors)
      : this._withListAndIndexes(dataType, vectors, computeIndexes(vectors));

  ConcatVector._withListAndIndexes(this.dataType, this._vectors, this._indexes);

  @override
  final DataType<T> dataType;

  @override
  int get count => _indexes.last;

  @override
  Set<Tensor> get storage => {..._vectors};

  @override
  Vector<T> copy() => ConcatVector._withListAndIndexes(
      dataType,
      _vectors.map((vector) => vector.copy()).toList(growable: false),
      _indexes);

  @override
  T getUnchecked(int index) {
    var vectorIndex = binarySearch(_indexes, 0, _indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    return _vectors[vectorIndex].getUnchecked(index - _indexes[vectorIndex]);
  }

  @override
  void setUnchecked(int index, T value) {
    var vectorIndex = binarySearch(_indexes, 0, _indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    _vectors[vectorIndex].setUnchecked(index - _indexes[vectorIndex], value);
  }
}

List<int> computeIndexes(List<Vector> vectors) {
  final indexes = indexDataType.newList(vectors.length + 1);
  for (var i = 0; i < vectors.length; i++) {
    indexes[i + 1] = indexes[i] + vectors[i].count;
  }
  return indexes;
}
