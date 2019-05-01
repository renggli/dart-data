library data.matrix.view.range;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable range of the rows and columns of a matrix.
class RangeMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;
  final int _rowStart;
  final int _colStart;

  RangeMatrix(
      Matrix<T> matrix, int rowStart, int rowEnd, int colStart, int colEnd)
      : this._(
            matrix, rowStart, rowEnd - rowStart, colStart, colEnd - colStart);

  RangeMatrix._(this._matrix, this._rowStart, this.rowCount, this._colStart,
      this.colCount);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() =>
      RangeMatrix._(_matrix.copy(), _rowStart, rowCount, _colStart, colCount);

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(_rowStart + row, _colStart + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(_rowStart + row, _colStart + col, value);

  @override
  Matrix<T> rangeUnchecked(
          int rowStart, int rowEnd, int colStart, int colEnd) =>
      RangeMatrix<T>(_matrix, _rowStart + rowStart, _rowStart + rowEnd,
          _colStart + colStart, _colStart + colEnd);
}
