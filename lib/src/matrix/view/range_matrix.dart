import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable range of the rows and columns of a matrix.
class RangeMatrix<T> with Matrix<T> {
  RangeMatrix(
      this.matrix, this.rowStart, this.rowEnd, this.columnStart, this.columnEnd)
      : rowCount = rowEnd - rowStart,
        colCount = columnEnd - columnStart;

  final Matrix<T> matrix;
  final int rowStart, rowEnd;
  final int columnStart, columnEnd;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(rowStart + row, columnStart + col);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(rowStart + row, columnStart + col, value);
}

extension RangeMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRange(int rowStart, [int? rowEnd]) {
    rowEnd = RangeError.checkValidRange(
        rowStart, rowEnd, rowCount, 'rowStart', 'rowEnd');
    return rowRangeUnchecked(rowStart, rowEnd);
  }

  /// Returns a mutable view onto the row range. The behavior is undefined, if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRangeUnchecked(int rowStart, int rowEnd) =>
      rangeUnchecked(rowStart, rowEnd, 0, colCount);

  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [columnStart] or [columnEnd] are out of bounds.
  Matrix<T> colRange(int columnStart, [int? columnEnd]) {
    columnEnd = RangeError.checkValidRange(
        columnStart, columnEnd, colCount, 'columnStart', 'columnEnd');
    return colRangeUnchecked(columnStart, columnEnd);
  }

  /// Returns a mutable view onto the row range. The behavior is undefined, if
  /// [columnStart] or [columnEnd] are out of bounds.
  Matrix<T> colRangeUnchecked(int columnStart, int columnEnd) =>
      rangeUnchecked(0, rowCount, columnStart, columnEnd);

  /// Returns a mutable view onto the row and column ranges. Throws a
  /// [RangeError], if any of the ranges are out of bounds.
  Matrix<T> range(int rowStart, int rowEnd, int columnStart, int columnEnd) {
    rowEnd = RangeError.checkValidRange(
        rowStart, rowEnd, rowCount, 'rowStart', 'rowEnd');
    columnEnd = RangeError.checkValidRange(
        columnStart, columnEnd, colCount, 'columnStart', 'columnEnd');
    return rangeUnchecked(rowStart, rowEnd, columnStart, columnEnd);
  }

  /// Returns a mutable view onto the row and column ranges. The behavior is
  /// undefined if any of the ranges are out of bounds.
  Matrix<T> rangeUnchecked(
      int rowStart, int rowEnd, int columnStart, int columnEnd) {
    if (rowStart == 0 &&
        rowEnd == rowCount &&
        columnStart == 0 &&
        columnEnd == colCount) return this;
    return switch (this) {
      RangeMatrix<T>(
        matrix: final thisMatrix,
        rowStart: final thisRowStart,
        columnStart: final thisColumnStart
      ) =>
        RangeMatrix<T>(
            thisMatrix,
            thisRowStart + rowStart,
            thisRowStart + rowEnd,
            thisColumnStart + columnStart,
            thisColumnStart + columnEnd),
      _ => RangeMatrix<T>(this, rowStart, rowEnd, columnStart, columnEnd),
    };
  }
}
