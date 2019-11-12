library data.matrix.impl.compressed_column;

import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../matrix.dart';

/// Sparse compressed column matrix.
class CompressedColumnMatrix<T> extends Matrix<T> {
  List<int> _colExtends;
  List<int> _rowIndexes;
  List<T> _values;
  int _length;

  CompressedColumnMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            indexDataType.newList(colCount),
            indexDataType.newList(initialListLength),
            dataType.newList(initialListLength),
            0);

  CompressedColumnMatrix._(this.dataType, this.rowCount, this.colCount,
      this._colExtends, this._rowIndexes, this._values, this._length);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => CompressedColumnMatrix._(
      dataType,
      rowCount,
      colCount,
      indexDataType.copyList(_colExtends),
      indexDataType.copyList(_rowIndexes),
      dataType.copyList(_values),
      _length);

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
      if (value == dataType.nullValue) {
        for (var c = col; c < colCount; c++) {
          _colExtends[c]--;
        }
        _rowIndexes = removeAt(indexDataType, _rowIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      } else {
        _values[index] = value;
      }
    }
  }
}
