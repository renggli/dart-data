import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

// Sparse matrix in coordinate format.
class CoordinateListMatrix<T> with Matrix<T> {
  CoordinateListMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            DataType.indexDataType.newList(initialListLength),
            DataType.indexDataType.newList(initialListLength),
            dataType.newList(initialListLength),
            0);

  CoordinateListMatrix._(this.dataType, this.rowCount, this.columnCount,
      this._rows, this._cols, this._values, this._length);

  List<int> _rows;
  List<int> _cols;
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
    return index < 0 ? dataType.defaultValue : _values[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final index = _binarySearch(row, col);
    if (index < 0) {
      if (value != dataType.defaultValue) {
        _rows =
            insertAt(DataType.indexDataType, _rows, _length, -index - 1, row);
        _cols =
            insertAt(DataType.indexDataType, _cols, _length, -index - 1, col);
        _values = insertAt(dataType, _values, _length, -index - 1, value);
        _length++;
      }
    } else {
      if (value == dataType.defaultValue) {
        _rows = removeAt(DataType.indexDataType, _rows, _length, index);
        _cols = removeAt(DataType.indexDataType, _cols, _length, index);
        _values = removeAt(dataType, _values, _length, index);
        _length--;
      } else {
        _values[index] = value;
      }
    }
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (var i = 0; i < _length; i++) {
      callback(_rows[i], _cols[i], _values[i]);
    }
  }
}
