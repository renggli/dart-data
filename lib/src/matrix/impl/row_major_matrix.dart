library data.matrix.impl.row_major_matrix;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/type.dart';

/// Row major matrix.
class RowMajorMatrix<T> extends Matrix<T> {
  final List<T> _values;

  RowMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  RowMajorMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => RowMajorMatrix.internal(
      dataType, rowCount, colCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row * colCount + col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row * colCount + col] = value;
}
