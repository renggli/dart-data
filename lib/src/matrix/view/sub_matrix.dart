library data.matrix.view.sub_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto a region of a matrix.
class SubMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;
  final int _rowOffset;
  final int _colOffset;

  SubMatrix(this._matrix, this._rowOffset, this.rowCount, this._colOffset,
      this.colCount);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(_rowOffset + row, _colOffset + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(_rowOffset + row, _colOffset + col, value);

  @override
  Matrix<T> subMatrix(
          int rowOffset, int rowCount, int colOffset, int colCount) =>
      SubMatrix<T>(_matrix, rowOffset, rowCount, colOffset, colCount);
}
