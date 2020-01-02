library data.vector.view.concat;

import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable concatenation of vectors.
class ConcatVector<T> with Vector<T> {
  final List<Vector<T>> vectors;
  final List<int> indexes;

  ConcatVector(DataType<T> dataType, Iterable<Vector<T>> vectors)
      : this._withList(dataType, vectors.toList(growable: false));

  ConcatVector._withList(DataType<T> dataType, List<Vector<T>> vectors)
      : this._withListAndIndexes(dataType, vectors, computeIndexes(vectors));

  ConcatVector._withListAndIndexes(this.dataType, this.vectors, this.indexes);

  @override
  final DataType<T> dataType;

  @override
  int get count => indexes.last;

  @override
  Set<Storage> get storage => {...vectors};

  @override
  Vector<T> copy() => ConcatVector._withListAndIndexes(dataType,
      vectors.map((vector) => vector.copy()).toList(growable: false), indexes);

  @override
  T getUnchecked(int index) {
    var vectorIndex = binarySearch(indexes, 0, indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    return vectors[vectorIndex].getUnchecked(index - indexes[vectorIndex]);
  }

  @override
  void setUnchecked(int index, T value) {
    var vectorIndex = binarySearch(indexes, 0, indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    vectors[vectorIndex].setUnchecked(index - indexes[vectorIndex], value);
  }
}

List<int> computeIndexes(List<Vector> vectors) {
  final indexes = indexDataType.newList(vectors.length + 1);
  for (var i = 0; i < vectors.length; i++) {
    indexes[i + 1] = indexes[i] + vectors[i].count;
  }
  return indexes;
}
