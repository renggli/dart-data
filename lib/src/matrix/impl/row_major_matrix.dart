library data.matrix.impl.row_major;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/type.dart';

/// Row major matrix.
class RowMajorMatrix<T> extends Matrix<T> {
  final List<T> _values;

  RowMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.fromList(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  RowMajorMatrix.fromList(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => RowMajorMatrix.fromList(
      dataType, rowCount, colCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row * colCount + col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row * colCount + col] = value;
}
