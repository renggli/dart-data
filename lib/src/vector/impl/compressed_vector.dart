import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../vector.dart';

/// Sparse compressed vector.
class CompressedVector<T> with Vector<T> {
  CompressedVector(DataType<T> dataType, int count)
      : this._(dataType, count, indexDataType.newList(initialListLength),
            dataType.newList(initialListLength), 0);

  CompressedVector._(
      this.dataType, this.count, this._indexes, this._values, this._length);

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
  Vector<T> copy() => CompressedVector._(dataType, count,
      indexDataType.copyList(_indexes), dataType.copyList(_values), _length);

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
        _indexes = insertAt(indexDataType, _indexes, _length, -pos - 1, index);
        _values = insertAt(dataType, _values, _length, -pos - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        _indexes = removeAt(indexDataType, _indexes, _length, pos);
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
