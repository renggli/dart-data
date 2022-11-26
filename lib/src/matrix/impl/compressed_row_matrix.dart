import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Sparse compressed row matrix.
class CompressedRowMatrix<T> with Matrix<T> {
  CompressedRowMatrix(this.dataType, this.rowCount, this.columnCount)
      : _rowExtends = DataType.indexDataType.newList(rowCount),
        _columnIndexes = DataType.indexDataType.newList(initialListLength),
        _values = dataType.newList(initialListLength),
        _length = 0;

  final List<int> _rowExtends;
  List<int> _columnIndexes;
  List<T> _values;
  int _length;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) {
    final start = row > 0 ? _rowExtends[row - 1] : 0, stop = _rowExtends[row];
    final index = binarySearch<num>(_columnIndexes, start, stop, col);
    return index < 0 ? dataType.defaultValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final start = row > 0 ? _rowExtends[row - 1] : 0, stop = _rowExtends[row];
    final index = binarySearch<num>(_columnIndexes, start, stop, col);
    if (index < 0) {
      if (value != dataType.defaultValue) {
        for (var r = row; r < rowCount; r++) {
          _rowExtends[r]++;
        }
        _columnIndexes = insertAt(
            DataType.indexDataType, _columnIndexes, _length, -index - 1, col);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        for (var r = row; r < rowCount; r++) {
          _rowExtends[r]--;
        }
        _columnIndexes =
            removeAt(DataType.indexDataType, _columnIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      } else {
        _values[index] = value;
      }
    }
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (var i = 0, rowIndex = 0; i < _length; i++) {
      if (_rowExtends[rowIndex] <= i) {
        rowIndex++;
      }
      callback(rowIndex, _columnIndexes[i], _values[i]);
    }
  }
}
