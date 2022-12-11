import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Mutable concatenation of vectors.
class ConcatVector<T> with Vector<T> {
  ConcatVector(this.dataType, this.vectors) : indexes = computeIndexes(vectors);

  final List<Vector<T>> vectors;
  final List<int> indexes;

  @override
  final DataType<T> dataType;

  @override
  int get count => indexes.last;

  @override
  Set<Storage> get storage => {...vectors};

  @override
  T getUnchecked(int index) {
    var vectorIndex = binarySearch<num>(indexes, 0, indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    return vectors[vectorIndex].getUnchecked(index - indexes[vectorIndex]);
  }

  @override
  void setUnchecked(int index, T value) {
    var vectorIndex = binarySearch<num>(indexes, 0, indexes.length, index);
    if (vectorIndex < 0) {
      vectorIndex = -vectorIndex - 2;
    }
    vectors[vectorIndex].setUnchecked(index - indexes[vectorIndex], value);
  }
}

List<int> computeIndexes<T>(List<Vector<T>> vectors) {
  final indexes = DataType.indexDataType.newList(vectors.length + 1);
  for (var i = 0; i < vectors.length; i++) {
    indexes[i + 1] = indexes[i] + vectors[i].count;
  }
  return indexes;
}
