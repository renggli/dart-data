library data.matrix.impl.compressed_column_matrix;

import 'package:data/src/type/type.dart';

import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../matrix.dart';

/// Compressed sparse column matrix (CSC).
class CompressedColumnMatrix<T> extends Matrix<T> {
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

  CompressedColumnMatrix(this.dataType, this.rowCount, this.colCount)
      : _colExtends = indexDataType.newList(colCount),
        _rowIndexes = indexDataType.newList(initialListSize),
        _values = dataType.newList(initialListSize),
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
            insertAt(indexDataType, _rowIndexes, _length, -index - 1, row);
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
        _rowIndexes = removeAt(indexDataType, _rowIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      }
    }
  }
}
