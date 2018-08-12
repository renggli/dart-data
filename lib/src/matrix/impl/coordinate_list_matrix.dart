library data.matrix.impl.coordinate_list_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';
import '../utils.dart';

// A sparse matrix in coordinate format (COO).
class CoordinateListMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  List<int> _rows;
  List<int> _cols;
  List<T> _values;
  int _length;

  CoordinateListMatrix(this.dataType, this.rowCount, this.colCount)
      : _rows = indexDataType.newList(initialListSize),
        _cols = indexDataType.newList(initialListSize),
        _values = dataType.newList(initialListSize),
        _length = 0;

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
      if (value != dataType.nullValue) {
        _values[index] = value;
      } else {
        _rows = removeAt(indexDataType, _rows, _length, index);
        _cols = removeAt(indexDataType, _cols, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      }
    }
  }
}
