library data.matrix.matrix;

import 'package:data/type.dart';

import 'matrix_builder.dart';
import 'view/column_view.dart';
import 'view/row_view.dart';
import 'view/sub_matrix.dart';
import 'view/transposed_matrix.dart';

/// Abstract matrix type.
abstract class Matrix<T> {
  /// Default builder for new matrices.
  static MatrixBuilder<Object> get builder =>
      MatrixBuilder<Object>(MatrixType.rowMajor, DataType.object, 4, 4);

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

  /// Returns a mutable row of the matrix. Throws a [RangeError] if [row] is
  /// outside of bounds.
  RowView<T> row(int row) => RowView<T>(this, row);

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a mutable column of the matrix. Throws a [RangeError] if [col] is
  /// outside of bounds.
  ColumnView<T> col(int col) => ColumnView<T>(this, col);

  /// Returns a mutable view onto a sub-matrix.
  Matrix<T> subMatrix(
          int rowOffset, int rowCount, int colOffset, int colCount) =>
      SubMatrix<T>(this, rowOffset, rowCount, colOffset, colCount);

  /// Returns a mutable view onto the transposed matrix.
  Matrix<T> get transpose => TransposedMatrix<T>(this);

  /// Pretty prints the matrix.
  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    buffer.write('[$rowCount, $colCount]:');
    for (var r = 0; r < rowCount; r++) {
      buffer.writeln();
      for (var c = 0; c < colCount; c++) {
        buffer.write('  ${getUnchecked(r, c)}');
      }
    }
    return buffer.toString();
  }

  /// Helper to copy a matrix from [source].
  static Matrix<T> copy<T>(Matrix<T> source,
      {Matrix<T> target, MatrixBuilder<T> builder}) {
    if (target != null) {
      if (target.rowCount != source.rowCount ||
          target.colCount != source.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result =
        target ?? builder.withSize(source.rowCount, source.colCount).build();
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(r, c, source.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to add two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> add<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
      {Matrix<T> target, MatrixBuilder<T> builder}) {
    if (sourceA.rowCount != sourceB.rowCount ||
        sourceA.colCount != sourceB.colCount) {
      throw ArgumentError('Source matrices do not match in size.');
    }
    if (target != null) {
      if (target.rowCount != sourceA.rowCount ||
          target.colCount != sourceA.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result =
        target ?? builder.withSize(sourceA.rowCount, sourceA.colCount).build();
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(
            r, c, sourceA.getUnchecked(r, c) + sourceB.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to subtract two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> sub<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
      {Matrix<T> target, MatrixBuilder<T> builder}) {
    if (sourceA.rowCount != sourceB.rowCount ||
        sourceA.colCount != sourceB.colCount) {
      throw ArgumentError('Source matrices do not match in size.');
    }
    if (target != null) {
      if (target.rowCount != sourceA.rowCount ||
          target.colCount != sourceA.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result =
        target ?? builder.withSize(sourceA.rowCount, sourceA.colCount).build();
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(
            r, c, sourceA.getUnchecked(r, c) - sourceB.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to multiply two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> mul<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
      {Matrix<T> target, MatrixBuilder<T> builder}) {
    if (sourceA.colCount != sourceB.rowCount) {
      throw ArgumentError('Inner dimensions of source matrices do not match.');
    }
    if (target != null) {
      if (target.rowCount != sourceA.rowCount ||
          target.colCount != sourceB.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result =
        target ?? builder.withSize(sourceA.rowCount, sourceB.colCount).build();
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        var sum = result.dataType.nullValue;
        for (var j = 0; j < sourceA.colCount; j++) {
          sum += sourceA.getUnchecked(r, j) * sourceB.getUnchecked(j, c);
        }
        result.setUnchecked(r, c, sum);
      }
    }
    return result;
  }
}
