library data.matrix.matrix;

import 'package:data/type.dart' show DataType;
import 'package:data/vector.dart' show Vector;

import 'builder.dart';
import 'impl/row_major_matrix.dart';
import 'view/column_vector.dart';
import 'view/diagonal_vector.dart';
import 'view/row_vector.dart';
import 'view/sub_matrix.dart';
import 'view/transposed_matrix.dart';
import 'view/unmodifiable_matrix.dart';

/// Abstract matrix type.
abstract class Matrix<T> {
  /// Default builder for new matrices.
  static Builder<Object> get builder =>
      Builder<Object>(RowMajorMatrix, DataType.object);

  /// Unnamed default constructor.
  const Matrix();

  /// The data type of this matrix.
  DataType<T> get dataType;

  /// Returns the value at the provided [row] and [col] index. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  T get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return getUnchecked(row, col);
  }

  /// Returns the value at the provided [row] and [col] index. The behavior is
  /// undefined if [row] or [col] are outside of bounds.
  T getUnchecked(int row, int col);

  /// Sets the value at the provided [row] and [col] index to [value]. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Sets the value at the provided [row] and [col] index to [value]. The
  /// behavior is undefined if [row] or [col] are outside of bounds.
  void setUnchecked(int row, int col, T value);

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns a mutable row vector of the matrix. Throws a [RangeError], if
  /// [row] is out of bounds.
  Vector<T> row(int row) => RowVector<T>(this, row);

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a mutable column vector of the matrix. Throws a [RangeError], if
  /// [col] is out of bounds.
  Vector<T> column(int col) => ColumnVector<T>(this, col);

  /// Returns a mutable diagonal vector of the matrix. Throws a [RangeError], if
  /// [offset] is out of bounds.
  Vector<T> diagonal([int offset = 0]) => DiagonalVector<T>(this, offset);

  /// Returns a mutable view onto a sub-matrix. Throws a [RangeError], if
  /// any of the indexes are out of bounds.
  Matrix<T> subMatrix(int rowStart, int rowEnd, int colStart, int colEnd) {
    RangeError.checkValidRange(
        rowStart, rowEnd, rowCount, 'rowStart', 'rowEnd');
    RangeError.checkValidRange(
        colStart, colEnd, colCount, 'colStart', 'colEnd');
    if (rowStart == 0 &&
        rowEnd == rowCount &&
        colStart == 0 &&
        colEnd == colCount) {
      return this; // optimize the full sub-view
    } else {
      return subMatrixUnchecked(rowStart, rowEnd, colStart, colEnd);
    }
  }

  /// Returns a mutable view onto a sub-matrix. The behavior is undefined if
  /// any of the ranges are out of bounds.
  Matrix<T> subMatrixUnchecked(
          int rowStart, int rowEnd, int colStart, int colEnd) =>
      SubMatrix<T>(this, rowStart, rowEnd, colStart, colEnd);

  /// Returns a mutable view onto the transposed matrix.
  Matrix<T> get transpose => TransposedMatrix<T>(this);

  /// Returns a unmodifiable view of the matrix.
  Matrix<T> get unmodifiable => UnmodifiableMatrix<T>(this);

  /// Pretty prints the matrix.
  @override
  String toString() {
    final buffer = StringBuffer(runtimeType);
    buffer.write('[$rowCount, $colCount]:');
    for (var r = 0; r < rowCount; r++) {
      buffer.writeln();
      for (var c = 0; c < colCount; c++) {
        buffer.write('  ${getUnchecked(r, c)}');
      }
    }
    return buffer.toString();
  }
}
