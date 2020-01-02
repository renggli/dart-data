library data.matrix.impl.coordinate_list;

import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

// Sparse matrix in coordinate format.
class CoordinateListMatrix<T> with Matrix<T> {
  List<int> _rows;
  List<int> _cols;
  List<T> _values;
  int _length;

  CoordinateListMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            indexDataType.newList(initialListLength),
            indexDataType.newList(initialListLength),
            dataType.newList(initialListLength),
            0);

  CoordinateListMatrix._(this.dataType, this.rowCount, this.columnCount,
      this._rows, this._cols, this._values, this._length);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => CoordinateListMatrix._(
      dataType,
      rowCount,
      columnCount,
      indexDataType.copyList(_rows),
      indexDataType.copyList(_cols),
      dataType.copyList(_values),
      _length);

  int _binarySearch(int row, int col) {
    var min = 0;
    var max = _length;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      final rowAtMid = _rows[mid], colAtMid = _cols[mid];
      if (rowAtMid == row && colAtMid == col) {
        return mid;
      } else if (rowAtMid < row || (rowAtMid == row && colAtMid < col)) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return -min - 1;
  }

  @override
  T getUnchecked(int row, int col) {
    final index = _binarySearch(row, col);
    return index < 0 ? dataType.nullValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final index = _binarySearch(row, col);
    if (index < 0) {
      if (value != dataType.nullValue) {
        _rows = insertAt(indexDataType, _rows, _length, -index - 1, row);
        _cols = insertAt(indexDataType, _cols, _length, -index - 1, col);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.nullValue) {
        _rows = removeAt(indexDataType, _rows, _length, index);
        _cols = removeAt(indexDataType, _cols, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      } else {
        _values[index] = value;
      }
    }
  }
}
