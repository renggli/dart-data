library data.matrix.csr_sparse_matrix;

import 'package:data/src/type/type.dart';

import 'sparse_matrix.dart';
import 'utils.dart';

const int _initialSize = 4;
const DataType<int> _indexDataType = DataType.int32;

class CompressedSparseRowMatrix<T> extends SparseMatrix<T> {
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
      : _rowExtends = _indexDataType.newList(rowCount),
        _colIndexes = _indexDataType.newList(_initialSize),
        _values = dataType.newList(_initialSize),
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
            insertAt(_indexDataType, _colIndexes, _length, -index - 1, col);
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
        _colIndexes = removeAt(_indexDataType, _colIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      }
    }
  }
}
