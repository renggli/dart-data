library data.matrix.sparse.compressed_row_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';
import '../utils.dart';

/// Compressed sparse row matrix (CSR).
class CompressedSparseRowMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  List<int> _rowExtends;
  List<int> _colIndexes;
  List<T> _values;
  int _length;

  CompressedSparseRowMatrix(this.dataType, this.rowCount, this.colCount)
      : _rowExtends = indexDataType.newList(rowCount),
        _colIndexes = indexDataType.newList(initialListSize),
        _values = dataType.newList(initialListSize),
        _length = 0;

  @override
  T getUnchecked(int row, int col) {
    final start = row > 0 ? _rowExtends[row - 1] : 0, stop = _rowExtends[row];
    final index = binarySearch(_colIndexes, start, stop, col);
    return index < 0 ? dataType.nullValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final start = row > 0 ? _rowExtends[row - 1] : 0, stop = _rowExtends[row];
    final index = binarySearch(_colIndexes, start, stop, col);
    if (index < 0) {
      if (value != dataType.nullValue) {
        for (var r = row; r < rowCount; r++) {
          _rowExtends[r]++;
        }
        _colIndexes =
            insertAt(indexDataType, _colIndexes, _length, -index - 1, col);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value != dataType.nullValue) {
        _values[index] = value;
      } else {
        for (var r = row; r < rowCount; r++) {
          _rowExtends[r]--;
        }
        _colIndexes = removeAt(indexDataType, _colIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      }
    }
  }
}
