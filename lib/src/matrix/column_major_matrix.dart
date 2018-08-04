library data.matrix.column_major_matrix;

import 'package:data/type.dart';

import 'matrix.dart';

class ColumnMajorMatrix<T extends num> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> data;

  ColumnMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : data = dataType.newList(rowCount * colCount);

  @override
  T get(int row, int col) => data[row + col * colCount];

  @override
  T set(int row, int col, T value) => data[row + col * colCount] = value;
}
