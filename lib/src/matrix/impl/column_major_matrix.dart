import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Column major matrix.
class ColumnMajorMatrix<T> with Matrix<T> {
  ColumnMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.fromList(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  ColumnMajorMatrix.fromList(
      this.dataType, this.rowCount, this.columnCount, this._values);

  final List<T> _values;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => ColumnMajorMatrix.fromList(
      dataType, rowCount, columnCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row + col * rowCount];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row + col * rowCount] = value;
}
