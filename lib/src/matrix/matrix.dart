library data.matrix.matrix;

import 'package:data/type.dart';

import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'view/column_view.dart';
import 'view/row_view.dart';
import 'view/sub_matrix.dart';
import 'view/transposed_matrix.dart';

/// Generic function type for all matrix constructors.
typedef Matrix<T> MatrixConstructor<T>(
  DataType<T> dataType,
  int rowCount,
  int colCount,
);

/// Abstract matrix type.
abstract class Matrix<T> {
  /// Constructor function for a row-major matrix.
  static Matrix<T> rowMajor<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      RowMajorMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a column-major matrix.
  static Matrix<T> columnMajor<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      ColumnMajorMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a compressed-row sparse matrix.
  static Matrix<T> compressedRow<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      CompressedRowMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a compressed-column sparse matrix.
  static Matrix<T> compressedColumn<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      CompressedColumnMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a coordinate-list sparse matrix.
  static Matrix<T> coordinateList<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      CoordinateListMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a diagonal sparse matrix.
  static Matrix<T> diagonal<T>(
          DataType<T> dataType, int rowCount, int colCount) =>
      DiagonalMatrix<T>(dataType, rowCount, colCount);

  /// Constructor function for a keyed sparse matrix.
  static Matrix<T> keyed<T>(DataType<T> dataType, int rowCount, int colCount) =>
      KeyedMatrix<T>(dataType, rowCount, colCount);

  /// Constructs a matrix with all values on their default.
  factory Matrix.zero(MatrixConstructor<T> constructor, DataType<T> dataType,
          int rowCount, int colCount) =>
      constructor(dataType, rowCount, colCount);

  /// Constructs a matrix with a constant [value].
  factory Matrix.constant(MatrixConstructor<T> constructor,
      DataType<T> dataType, int rowCount, int colCount, T value) {
    final result = constructor(dataType, rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, value);
      }
    }
    return result;
  }

  /// Constructs an identity matrix.
  factory Matrix.identity(MatrixConstructor<T> constructor,
      DataType<T> dataType, int count, T value) {
    final result = constructor(dataType, count, count);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, i, value);
    }
    return result;
  }

  /// Constructs a matrix from a callback.
  factory Matrix.generate(
      MatrixConstructor<T> constructor,
      DataType<T> dataType,
      int rowCount,
      int colCount,
      T callback(int row, int col)) {
    final result = constructor(dataType, rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, callback(row, col));
      }
    }
    return result;
  }

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
    buffer.write('[$rowCount * $colCount]');
    for (var r = 0; r < rowCount; r++) {
      buffer.writeln();
      for (var c = 0; c < colCount; c++) {
        buffer.write('  ${getUnchecked(r, c)}');
      }
    }
    return buffer.toString();
  }

  /// Helper to copy a matrix from [source].
  static Matrix<T> copy<T>(
    Matrix<T> source, {
    Matrix<T> target,
    MatrixConstructor<T> constructor,
    DataType<T> dataType,
  }) {
    if (target != null) {
      if (target.rowCount != source.rowCount ||
          target.colCount != source.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result = target ??
        constructor(
          dataType ?? source.dataType,
          source.rowCount,
          source.colCount,
        );
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(r, c, source.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to add two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> add<T extends num>(
    Matrix<T> sourceA,
    Matrix<T> sourceB, {
    Matrix<T> target,
    MatrixConstructor<T> constructor,
    DataType<T> dataType,
  }) {
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
    final result = target ??
        constructor(
          dataType ?? sourceA.dataType,
          sourceA.rowCount,
          sourceA.colCount,
        );
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(
            r, c, sourceA.getUnchecked(r, c) + sourceB.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to subtract two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> sub<T extends num>(
    Matrix<T> sourceA,
    Matrix<T> sourceB, {
    Matrix<T> target,
    MatrixConstructor<T> constructor,
    DataType<T> dataType,
  }) {
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
    final result = target ??
        constructor(
          dataType ?? sourceA.dataType,
          sourceA.rowCount,
          sourceA.colCount,
        );
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(
            r, c, sourceA.getUnchecked(r, c) - sourceB.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Helper to multiply two numeric matrices [sourceA] and [sourceB].
  static Matrix<T> mul<T extends num>(
    Matrix<T> sourceA,
    Matrix<T> sourceB, {
    Matrix<T> target,
    MatrixConstructor<T> constructor,
    DataType<T> dataType,
  }) {
    if (sourceA.colCount != sourceB.rowCount) {
      throw ArgumentError('Inner dimensions of source matrices do not match.');
    }
    if (target != null) {
      if (target.rowCount != sourceA.rowCount ||
          target.colCount != sourceB.colCount) {
        throw ArgumentError('Target matrix does not match in size.');
      }
    }
    final result = target ??
        constructor(
          dataType ?? sourceA.dataType,
          sourceA.rowCount,
          sourceB.colCount,
        );
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
