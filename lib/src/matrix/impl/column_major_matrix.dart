import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Column major matrix.
class ColumnMajorMatrix<T> with Matrix<T> {
  ColumnMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : _values = dataType.newList(rowCount * colCount);

  ColumnMajorMatrix.fromList(
      this.dataType, this.rowCount, this.colCount, this._values)
      : assert(_values.length == rowCount * colCount);

  final List<T> _values;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => _values[row + col * rowCount];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row + col * rowCount] = value;
}
