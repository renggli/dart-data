import '../../../type.dart';
import '../../shared/storage.dart';
import '../vector.dart';

// A mutable indexed view of a vector.
class IndexVector<T> with Vector<T> {
  IndexVector(this.vector, Iterable<int> indexes)
      : indexes = DataType.index.copyList(indexes);

  final Vector<T> vector;
  final List<int> indexes;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => indexes.length;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int index) => vector.getUnchecked(indexes[index]);

  @override
  void setUnchecked(int index, T value) =>
      vector.setUnchecked(indexes[index], value);
}

extension IndexVectorExtension<T> on Vector<T> {
  /// Returns a mutable view onto indexes of a [Vector]. Throws a [RangeError],
  /// if any of the indexes index is out of bounds.
  Vector<T> index(Iterable<int> indexes) {
    for (final index in indexes) {
      RangeError.checkValueInInterval(index, 0, count - 1, 'indexes');
    }
    return indexUnchecked(indexes);
  }

  /// Returns a mutable view onto indexes of a [Vector]. The behavior is
  /// undefined, if any of the indexes are out of bounds.
  Vector<T> indexUnchecked(Iterable<int> indexes) => switch (this) {
        IndexVector<T>(vector: final vector, indexes: final thisIndexes) =>
          IndexVector<T>(vector, indexes.map((index) => thisIndexes[index])),
        _ => IndexVector<T>(this, indexes),
      };
}
