import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Sparse compressed vector.
class CompressedVector<T> with Vector<T> {
  CompressedVector(this.dataType, this.count)
      : _indexes = DataType.indexDataType.newList(initialListLength),
        _values = dataType.newList(initialListLength),
        _length = 0;

  List<int> _indexes;
  List<T> _values;
  int _length;

  @override
  final DataType<T> dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int index) {
    final pos = binarySearch<num>(_indexes, 0, _length, index);
    return pos < 0 ? dataType.defaultValue : _values[pos];
  }

  @override
  void setUnchecked(int index, T value) {
    final pos = binarySearch<num>(_indexes, 0, _length, index);
    if (pos < 0) {
      if (value != dataType.defaultValue) {
        _indexes = insertAt(
            DataType.indexDataType, _indexes, _length, -pos - 1, index);
        _values = insertAt(dataType, _values, _length, -pos - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        _indexes = removeAt(DataType.indexDataType, _indexes, _length, pos);
        _values = removeAt(dataType, _values, _length, pos);
        _length--;
      } else {
        _values[pos] = value;
      }
    }
  }

  @override
  void forEach(void Function(int index, T value) callback) {
    for (var i = 0; i < _length; i++) {
      callback(_indexes[i], _values[i]);
    }
  }
}
