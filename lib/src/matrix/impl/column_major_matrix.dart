library data.matrix.impl.column_major;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/type.dart';

/// Column major matrix.
class ColumnMajorMatrix<T> extends Matrix<T> {
  final List<T> _values;

  ColumnMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  ColumnMajorMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => ColumnMajorMatrix.internal(
      dataType, rowCount, colCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row + col * rowCount];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row + col * rowCount] = value;
}
