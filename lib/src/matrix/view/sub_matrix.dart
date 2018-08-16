library data.matrix.view.sub_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto a region of a matrix.
class SubMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;
  final int _rowStart;
  final int _colStart;

  SubMatrix(
      this._matrix, this._rowStart, int rowEnd, this._colStart, int colEnd)
      : rowCount = rowEnd - _rowStart,
        colCount = colEnd - _colStart;

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(_rowStart + row, _colStart + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(_rowStart + row, _colStart + col, value);

  @override
  Matrix<T> subMatrixUnchecked(
          int rowStart, int rowEnd, int colStart, int colEnd) =>
      SubMatrix<T>(_matrix, _rowStart + rowStart, _rowStart + rowEnd,
          _colStart + colStart, _colStart + colEnd);
}
