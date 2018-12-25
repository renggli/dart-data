library data.matrix.impl.compressed_row_matrix;

import 'package:data/type.dart';

import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../matrix.dart';

/// Sparse compressed row matrix.
class CompressedRowMatrix<T> extends Matrix<T> {
  List<int> _rowExtends;
  List<int> _colIndexes;
  List<T> _values;
  int _length;

  CompressedRowMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(
            dataType,
            rowCount,
            colCount,
            indexDataType.newList(rowCount),
            indexDataType.newList(initialListSize),
            dataType.newList(initialListSize),
            0);

  CompressedRowMatrix.internal(this.dataType, this.rowCount, this.colCount,
      this._rowExtends, this._colIndexes, this._values, this._length);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => CompressedRowMatrix.internal(
      dataType,
      rowCount,
      colCount,
      indexDataType.copyList(_rowExtends),
      indexDataType.copyList(_colIndexes),
      dataType.copyList(_values),
      _length);

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
