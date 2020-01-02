library data.matrix.view.range;

import '../../../tensor.dart';
import '../../../type.dart';
import '../matrix.dart';

/// Mutable range of the rows and columns of a matrix.
class RangeMatrix<T> extends Matrix<T> {
  final Matrix<T> matrix;
  final int rowStart;
  final int colStart;

  RangeMatrix(
      Matrix<T> matrix, int rowStart, int rowEnd, int colStart, int colEnd)
      : this._(
            matrix, rowStart, rowEnd - rowStart, colStart, colEnd - colStart);

  RangeMatrix._(
      this.matrix, this.rowStart, this.rowCount, this.colStart, this.colCount);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Tensor> get storage => matrix.storage;

  @override
  Matrix<T> copy() =>
      RangeMatrix._(matrix.copy(), rowStart, rowCount, colStart, colCount);

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(rowStart + row, colStart + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(rowStart + row, colStart + col, value);
}

extension RangeMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRange(int rowStart, [int rowEnd]) =>
      range(rowStart, rowEnd, 0, colCount);

  /// Returns a mutable view onto the row range. The behavior is undefined, if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRangeUnchecked(int rowStart, int rowEnd) =>
      rangeUnchecked(rowStart, rowEnd, 0, colCount);

  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [colStart] or [colEnd] are out of bounds.
  Matrix<T> colRange(int colStart, [int colEnd]) =>
      range(0, rowCount, colStart, colEnd);

  /// Returns a mutable view onto the row range. The behavior is undefed, if
  /// [colStart] or [colEnd] are out of bounds.
  Matrix<T> colRangeUnchecked(int colStart, int colEnd) =>
      rangeUnchecked(0, rowCount, colStart, colEnd);

  /// Returns a mutable view onto the row and column ranges. Throws a
  /// [RangeError], if any of the ranges are out of bounds.
  Matrix<T> range(int rowStart, int rowEnd, int colStart, int colEnd) {
    rowEnd = RangeError.checkValidRange(
        rowStart, rowEnd, rowCount, 'rowStart', 'rowEnd');
    colEnd = RangeError.checkValidRange(
        colStart, colEnd, colCount, 'colStart', 'colEnd');
    if (rowStart == 0 &&
        rowEnd == rowCount &&
        colStart == 0 &&
        colEnd == colCount) {
      return this;
    } else {
      return rangeUnchecked(rowStart, rowEnd, colStart, colEnd);
    }
  }

  /// Returns a mutable view onto the row and column ranges. The behavior is
  /// undefined if any of the ranges are out of bounds.
  Matrix<T> rangeUnchecked(
          int rowStart, int rowEnd, int colStart, int colEnd) =>
      _rangeUnchecked(this, rowStart, rowEnd, colStart, colEnd);

  // TODO(renggli): workaround, https://github.com/dart-lang/sdk/issues/39959.
  Matrix<T> _rangeUnchecked(
          Matrix<T> self, int rowStart, int rowEnd, int colStart, int colEnd) =>
      self is RangeMatrix<T>
          ? RangeMatrix<T>(
              self.matrix,
              self.rowStart + rowStart,
              self.rowStart + rowEnd,
              self.colStart + colStart,
              self.colStart + colEnd)
          : RangeMatrix<T>(self, rowStart, rowEnd, colStart, colEnd);
}
