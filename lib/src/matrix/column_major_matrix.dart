library data.matrix.column_major_matrix;

import 'package:data/type.dart';

import 'matrix.dart';

class ColumnMajorMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> _data;

  ColumnMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : _data = dataType.newList(rowCount * colCount);

  @override
  T getUnchecked(int row, int col) => _data[row + col * rowCount];

  @override
  void setUnchecked(int row, int col, T value) => _data[row + col * rowCount] = value;
}
