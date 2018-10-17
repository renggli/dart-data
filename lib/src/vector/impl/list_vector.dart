library data.vector.impl.list;

import 'package:data/type.dart';

import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../vector.dart';

/// Sparse compressed vector.
class ListVector<T> extends Vector<T> {
  List<int> _indexes;
  List<T> _values;
  int _length;

  ListVector(DataType<T> dataType, int count)
      : this.internal(dataType, count, indexDataType.newList(initialListSize),
            dataType.newList(initialListSize), 0);

  ListVector.internal(
      this.dataType, this.count, this._indexes, this._values, this._length);

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Vector<T> get base => this;

  @override
  Vector<T> copy() => ListVector.internal(dataType, count,
      indexDataType.copyList(_indexes), dataType.copyList(_values), _length);

  @override
  T getUnchecked(int index) {
    final pos = binarySearch(_indexes, 0, _length, index);
    return pos < 0 ? dataType.nullValue : _values[pos];
  }

  @override
  void setUnchecked(int index, T value) {
    final pos = binarySearch(_indexes, 0, _length, index);
    if (pos < 0) {
      if (value != dataType.nullValue) {
        _indexes = insertAt(indexDataType, _indexes, _length, -pos - 1, index);
        _values = insertAt(dataType, _values, _length, -pos - 1, value);
        _length++;
      }
    } else {
      if (value != dataType.nullValue) {
        _values[pos] = value;
      } else {
        _indexes = removeAt(indexDataType, _indexes, _length, pos);
        _values = removeAt(dataType, _values, _length, pos);
        _length--;
      }
    }
  }
}
