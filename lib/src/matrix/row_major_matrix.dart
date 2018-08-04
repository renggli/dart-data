library data.matrix.row_major_matrix;

import 'package:data/type.dart';

import 'matrix.dart';

class RowMajorMatrix<T extends num> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> data;

  RowMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : data = dataType.newList(rowCount * colCount);

  @override
  T get(int row, int col) => data[row * rowCount + col];

  @override
  T set(int row, int col, T value) => data[row * rowCount + col] = value;
}
