library data.matrix.impl.row_major_matrix;

import 'package:data/type.dart';

import '../matrix.dart';

class RowMajorMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> _values;

  RowMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  RowMajorMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  Matrix<T> copy() => RowMajorMatrix.internal(
      dataType, rowCount, colCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row * colCount + col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row * colCount + col] = value;
}
