library data.vector.impl.list;

import 'package:data/type.dart';

import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../vector.dart';

class ListVector<T> extends Vector<T> {
  @override
  final DataType<T> dataType;

  @override
  final int count;

  List<int> _indexes;
  List<T> _values;
  int _length;

  ListVector(this.dataType, this.count)
      : _indexes = indexDataType.newList(initialListSize),
        _values = dataType.newList(initialListSize),
        _length = 0;

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
