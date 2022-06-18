import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Sparse compressed column matrix.
class CompressedColumnMatrix<T> with Matrix<T> {
  CompressedColumnMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            DataType.indexDataType.newList(colCount),
            DataType.indexDataType.newList(initialListLength),
            dataType.newList(initialListLength),
            0);

  CompressedColumnMatrix._(this.dataType, this.rowCount, this.columnCount,
      this._colExtends, this._rowIndexes, this._values, this._length);

  List<int> _colExtends;
  List<int> _rowIndexes;
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
  Matrix<T> copy() => CompressedColumnMatrix._(
      dataType,
      rowCount,
      columnCount,
      DataType.indexDataType.copyList(_colExtends),
      DataType.indexDataType.copyList(_rowIndexes),
      dataType.copyList(_values),
      _length);

  @override
  T getUnchecked(int row, int col) {
    final start = col > 0 ? _colExtends[col - 1] : 0, stop = _colExtends[col];
    final index = binarySearch<num>(_rowIndexes, start, stop, row);
    return index < 0 ? dataType.defaultValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final start = col > 0 ? _colExtends[col - 1] : 0, stop = _colExtends[col];
    final index = binarySearch<num>(_rowIndexes, start, stop, row);
    if (index < 0) {
      if (value != dataType.defaultValue) {
        for (var c = col; c < columnCount; c++) {
          _colExtends[c]++;
        }
        _rowIndexes = insertAt(
            DataType.indexDataType, _rowIndexes, _length, -index - 1, row);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        for (var c = col; c < columnCount; c++) {
          _colExtends[c]--;
        }
        _rowIndexes =
            removeAt(DataType.indexDataType, _rowIndexes, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      } else {
        _values[index] = value;
      }
    }
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (var i = 0, colIndex = 0; i < _length; i++) {
      if (_colExtends[colIndex] <= i) {
        colIndex++;
      }
      callback(_rowIndexes[i], colIndex, _values[i]);
    }
  }
}
