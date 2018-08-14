library data.matrix.builder;

import 'package:data/type.dart';

import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'matrix.dart';

/// Builds a matrix of a custom type.
class Builder<T> {
  /// Constructors a builder with the provided storage [format] and data [type].
  Builder(this.format, this.type);

  /// Returns the storage format of the builder.
  final Type format;

  /// Returns the data type of the builder.
  final DataType<T> type;

  /// Returns a builder for row major matrices.
  Builder<T> get rowMajor => withFormat(RowMajorMatrix);

  /// Returns a builder for column major matrices.
  Builder<T> get columnMajor => withFormat(ColumnMajorMatrix);

  /// Returns a builder for compressed row matrices.
  Builder<T> get compressedRow => withFormat(CompressedRowMatrix);

  /// Returns a builder for compressed column matrices.
  Builder<T> get compressedColumn => withFormat(CompressedColumnMatrix);

  /// Returns a builder for coordinate list matrices.
  Builder<T> get coordinateList => withFormat(CoordinateListMatrix);

  /// Returns a builder for keyed matrices.
  Builder<T> get keyed => withFormat(KeyedMatrix);

  /// Returns a builder for diagonal matrices.
  Builder<T> get diagonal => withFormat(DiagonalMatrix);

  /// Returns a builder with the provided storage [format].
  Builder<T> withFormat(Type format) =>
      this.format == format ? this : Builder<T>(format, type);

  /// Returns a builder with the provided data [type].
  Builder<S> withType<S>(DataType<S> type) =>
      this.type == type ? this : Builder<S>(format, type);

  /// Builds a new matrix of the configured format.
  Matrix<T> call(int rowCount, int colCount) {
    RangeError.checkNotNegative(rowCount, 'rowCount');
    RangeError.checkNotNegative(colCount, 'colCount');
    switch (format) {
      case RowMajorMatrix:
        return RowMajorMatrix<T>(type, rowCount, colCount);
      case ColumnMajorMatrix:
        return ColumnMajorMatrix<T>(type, rowCount, colCount);
      case CompressedRowMatrix:
        return CompressedRowMatrix<T>(type, rowCount, colCount);
      case CompressedColumnMatrix:
        return CompressedColumnMatrix<T>(type, rowCount, colCount);
      case CoordinateListMatrix:
        return CoordinateListMatrix<T>(type, rowCount, colCount);
      case KeyedMatrix:
        return KeyedMatrix<T>(type, rowCount, colCount);
      case DiagonalMatrix:
        return DiagonalMatrix<T>(type, rowCount, colCount);
    }
    throw ArgumentError.value(format, 'format');
  }

  /// Builds a matrix with a constant [value].
  Matrix<T> constant(int rowCount, int colCount, T value) {
    final result = this(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, value);
      }
    }
    return result;
  }

  /// Builds an identity matrix with a constant [value].
  Matrix<T> identity(int count, T value) {
    final result = this(count, count);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, i, value);
    }
    return result;
  }

  /// Builds a matrix from calling a [callback] on every value.
  Matrix<T> generate(int rowCount, int colCount, T callback(int row, int col)) {
    final result = this(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, callback(row, col));
      }
    }
    return result;
  }

  /// Builds a matrix from another matrix.
  Matrix<T> from(Matrix<T> source) {
    final result = this(source.rowCount, source.colCount);
    for (var row = 0; row < result.rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(row, col, source.getUnchecked(row, col));
      }
    }
    return result;
  }

  /// Builds a sub-matrix from the row range [rowStart] to [rowEnd] (exclusive)
  /// and the column range [colStart] to [colEnd] (exclusive).
  Matrix<T> fromRanges(
      Matrix<T> source, int rowStart, int rowEnd, int colStart, int colEnd) {
    RangeError.checkValidRange(
        rowStart, rowEnd, source.rowCount, 'rowStart', 'rowEnd');
    RangeError.checkValidRange(
        colStart, colEnd, source.colCount, 'colStart', 'colEnd');
    final result = this(rowEnd - rowStart, colEnd - colStart);
    for (var r = rowStart; r < rowEnd; r++) {
      for (var c = colStart; c < colEnd; c++) {
        result.setUnchecked(
            r - rowStart, c - colStart, source.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Builds a sub-matrix from the row range [rowStart] to [rowEnd] (exclusive)
  /// and a list of column [colIndices].
  Matrix<T> fromRangeAndIndices(
      Matrix<T> source, int rowStart, int rowEnd, List<int> colIndices) {
    RangeError.checkValidRange(
        rowStart, rowEnd, source.rowCount, 'rowStart', 'rowEnd');
    final result = this(rowEnd - rowStart, colIndices.length);
    for (var c = 0; c < colIndices.length; c++) {
      RangeError.checkValueInInterval(c, 0, source.colCount, 'colIndices');
      for (var r = rowStart; r < rowEnd; r++) {
        result.setUnchecked(
            r - rowStart, c, source.getUnchecked(r, colIndices[c]));
      }
    }
    return result;
  }

  /// Builds a sub-matrix from a list of [rowIndices] and the column range
  /// [colStart] to [colEnd] (exclusive).
  Matrix<T> fromIndicesAndRange(
      Matrix<T> source, List<int> rowIndices, int colStart, int colEnd) {
    RangeError.checkValidRange(
        colStart, colEnd, source.colCount, 'colStart', 'colEnd');
    final result = this(rowIndices.length, colEnd - colStart);
    for (var r = 0; r < rowIndices.length; r++) {
      RangeError.checkValueInInterval(r, 0, source.rowCount, 'rowIndices');
      for (var c = colStart; c < colEnd; c++) {
        result.setUnchecked(
            r, c - colStart, source.getUnchecked(rowIndices[r], c));
      }
    }
    return result;
  }

  /// Builds a sub-matrix from a list of row [rowIndices] and column
  /// [colIndices].
  Matrix<T> fromIndices(
      Matrix<T> source, List<int> rowIndices, List<int> colIndices) {
    final result = this(rowIndices.length, colIndices.length);
    for (var r = 0; r < rowIndices.length; r++) {
      RangeError.checkValueInInterval(r, 0, source.rowCount, 'rowIndices');
      for (var c = 0; c < colIndices.length; c++) {
        RangeError.checkValueInInterval(c, 0, source.colCount, 'colIndices');
        result.setUnchecked(
            r, c, source.getUnchecked(rowIndices[r], colIndices[c]));
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of rows.
  Matrix<T> fromRows(List<List<T>> source) {
    if (source.isEmpty) {
      ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = this(source.length, source[0].length);
    for (var row = 0; row < result.rowCount; row++) {
      final sourceRow = source[row];
      if (sourceRow.length != result.colCount) {
        ArgumentError.value(source, 'source', 'Must be equally sized');
      }
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(row, col, sourceRow[col]);
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of columns.
  Matrix<T> fromCols(List<List<T>> source) {
    if (source.isEmpty) {
      ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = this(source[0].length, source.length);
    for (var col = 0; col < result.colCount; col++) {
      final sourceCol = source[col];
      if (sourceCol.length != result.rowCount) {
        ArgumentError.value(source, 'source', 'Must be equally sized');
      }
      for (var row = 0; row < result.rowCount; row++) {
        result.setUnchecked(row, col, sourceCol[row]);
      }
    }
    return result;
  }
}
