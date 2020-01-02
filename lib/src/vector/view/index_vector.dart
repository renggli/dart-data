library data.vector.view.index;

import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/storage.dart';
import '../vector.dart';

// A mutable indexed view of a vector.
class IndexVector<T> with Vector<T> {
  final Vector<T> vector;
  final List<int> indexes;

  IndexVector(Vector<T> vector, Iterable<int> indexes)
      : this._(vector, indexDataType.copyList(indexes));

  IndexVector._(this.vector, this.indexes);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get count => indexes.length;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Vector<T> copy() => IndexVector._(vector.copy(), indexes);

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
  Vector<T> indexUnchecked(Iterable<int> indexes) =>
      _indexUnchecked(this, indexes);

  // TODO(renggli): workaround, https://github.com/dart-lang/sdk/issues/39959.
  Vector<T> _indexUnchecked<T>(Vector<T> self, Iterable<int> indexes) => self
          is IndexVector<T>
      ? IndexVector<T>(self.vector, indexes.map((index) => self.indexes[index]))
      : IndexVector<T>(self, indexes);
}
