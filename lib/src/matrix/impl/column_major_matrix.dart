library data.matrix.impl.column_major_matrix;

import 'package:data/type.dart';

import '../matrix.dart';

class ColumnMajorMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> _values;

  ColumnMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  ColumnMajorMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  Matrix<T> copy() => ColumnMajorMatrix.internal(
      dataType, rowCount, colCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row + col * rowCount];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row + col * rowCount] = value;
}
