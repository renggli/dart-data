library data.matrix.csc_sparse_matrix;

import 'package:data/src/type/type.dart';

import 'sparse_matrix.dart';
import 'utils.dart';

const int _initialSize = 4;
const DataType<int> _indexDataType = DataType.int32;

/// Compressed sparse column matrix.
class CompressedSparseColumnMatrix<T> extends SparseMatrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  List<int> _colExtends;
  List<int> _rowIndexes;
  List<T> _values;
  int _length;

  CompressedSparseColumnMatrix(this.dataType, this.rowCount, this.colCount)
      : _colExtends = _indexDataType.newList(colCount),
        _rowIndexes = _indexDataType.newList(_initialSize),
        _values = dataType.newList(_initialSize),
        _length = 0;

  @override
  T getUnchecked(int row, int col) {
    final start = col > 0 ? _colExtends[col - 1] : 0, stop = _colExtends[col];
    final index = binarySearch(_rowIndexes, start, stop, row);
    return index < 0 ? dataType.nullValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final start = col > 0 ? _colExtends[col - 1] : 0, stop = _colExtends[col];
    final index = binarySearch(_rowIndexes, start, stop, row);
    if (index < 0) {
      if (value != dataType.nullValue) {
        for (var c = col; c < colCount; c++) {
          _colExtends[c]++;
        }
        _rowIndexes =
            insertAt(_indexDataType, _rowIndexes, _length, -index - 1, row);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value != dataType.nullValue) {
        _values[index] = value;
      } else {
        for (var c = col; c < colCount; c++) {
          _colExtends[c]--;
        }
        _rowIndexes = removeAt(_indexDataType, _rowIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      }
    }
  }
}
