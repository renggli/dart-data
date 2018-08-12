library data.matrix.view.sub_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto a region of a matrix.
class SubMatrix<T> extends Matrix<T> {
  final Matrix<T> matrix;

  final int rowOffset;

  @override
  final int rowCount;

  final int colOffset;

  @override
  final int colCount;

  SubMatrix(this.matrix, this.rowOffset, this.rowCount, this.colOffset,
      this.colCount);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(rowOffset + row, colOffset + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(rowOffset + row, colOffset + col, value);

  @override
  Matrix<T> subMatrix(
          int rowOffset, int rowCount, int colOffset, int colCount) =>
      SubMatrix<T>(matrix, rowOffset, rowCount, colOffset, colCount);
}
