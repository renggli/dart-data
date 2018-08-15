library data.matrix.builder;

import 'package:data/type.dart';
import 'package:data/vector.dart' show Vector;

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

  /// Builds a matrix by transforming another matrix with [callback].
  Matrix<T> transform<S>(
      Matrix<S> source, T callback(int row, int col, S value)) {
    final result = this(source.rowCount, source.colCount);
    for (var row = 0; row < result.rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(
            row, col, callback(row, col, source.getUnchecked(row, col)));
      }
    }
    return result;
  }

  /// Builds a matrix from another matrix.
  Matrix<T> fromMatrix(Matrix<T> source) {
    final result = this(source.rowCount, source.colCount);
    for (var row = 0; row < result.rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(row, col, source.getUnchecked(row, col));
      }
    }
    return result;
  }

  /// Builds a matrix from a row vector.
  Matrix<T> fromVectorRow(Vector<T> source) {
    final result = this(1, source.count);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(0, index, source.getUnchecked(index));
    }
    return result;
  }

  /// Builds a matrix from a column vector.
  Matrix<T> fromVectorColumn(Vector<T> source) {
    final result = this(source.count, 1);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(index, 0, source.getUnchecked(index));
    }
    return result;
  }

  /// Builds a matrix from a diagonal vector.
  Matrix<T> fromVectorDiagonal(Vector<T> source) {
    final result = this(source.count, source.count);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(index, index, source.getUnchecked(index));
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
    for (var row = rowStart; row < rowEnd; row++) {
      for (var col = colStart; col < colEnd; col++) {
        result.setUnchecked(
            row - rowStart, col - colStart, source.getUnchecked(row, col));
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
    for (var col = 0; col < colIndices.length; col++) {
      RangeError.checkValueInInterval(col, 0, source.colCount, 'colIndices');
      for (var row = rowStart; row < rowEnd; row++) {
        result.setUnchecked(
            row - rowStart, col, source.getUnchecked(row, colIndices[col]));
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
    for (var row = 0; row < rowIndices.length; row++) {
      RangeError.checkValueInInterval(row, 0, source.rowCount, 'rowIndices');
      for (var col = colStart; col < colEnd; col++) {
        result.setUnchecked(
            row, col - colStart, source.getUnchecked(rowIndices[row], col));
      }
    }
    return result;
  }

  /// Builds a sub-matrix from a list of row [rowIndices] and column
  /// [colIndices].
  Matrix<T> fromIndices(
      Matrix<T> source, List<int> rowIndices, List<int> colIndices) {
    final result = this(rowIndices.length, colIndices.length);
    for (var row = 0; row < rowIndices.length; row++) {
      RangeError.checkValueInInterval(row, 0, source.rowCount, 'rowIndices');
      for (var col = 0; col < colIndices.length; col++) {
        RangeError.checkValueInInterval(col, 0, source.colCount, 'colIndices');
        result.setUnchecked(
            row, col, source.getUnchecked(rowIndices[row], colIndices[col]));
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of rows.
  Matrix<T> fromRows(List<List<T>> source) {
    if (source.isEmpty) {
      throw ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = this(source.length, source[0].length);
    for (var row = 0; row < result.rowCount; row++) {
      final sourceRow = source[row];
      if (sourceRow.length != result.colCount) {
        throw ArgumentError.value(source, 'source', 'Must be equally sized');
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
      throw ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = this(source[0].length, source.length);
    for (var col = 0; col < result.colCount; col++) {
      final sourceCol = source[col];
      if (sourceCol.length != result.rowCount) {
        throw ArgumentError.value(source, 'source', 'Must be equally sized');
      }
      for (var row = 0; row < result.rowCount; row++) {
        result.setUnchecked(row, col, sourceCol[row]);
      }
    }
    return result;
  }
}
