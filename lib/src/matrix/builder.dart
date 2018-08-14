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

enum FormatType {
  rowMajor,
  columnMajor,
  compressedRow,
  compressedColumn,
  coordinateList,
  keyed,
  diagonal,
}

/// Builds a matrix of a custom type.
class Builder<T> {
  Builder(this.format, this.type);

  final FormatType format;

  final DataType<T> type;

  Builder<T> get rowMajor => withFormat(FormatType.rowMajor);

  Builder<T> get columnMajor => withFormat(FormatType.columnMajor);

  Builder<T> get compressedRow => withFormat(FormatType.compressedRow);

  Builder<T> get compressedColumn => withFormat(FormatType.compressedColumn);

  Builder<T> get coordinateList => withFormat(FormatType.coordinateList);

  Builder<T> get keyed => withFormat(FormatType.keyed);

  Builder<T> get diagonal => withFormat(FormatType.diagonal);

  Builder<T> withFormat(FormatType format) =>
      this.format == format ? this : Builder<T>(format, type);

  Builder<S> withType<S>(DataType<S> type) =>
      this.type == type ? this : Builder<S>(format, type);

  /// Builds a matrix of the configured format.
  Matrix<T> call(int rowCount, int colCount) {
    RangeError.checkNotNegative(rowCount, 'rowCount');
    RangeError.checkNotNegative(colCount, 'colCount');
    // The reason for this enum to exist is purely to be able to instantiate
    // the matrix with the right generic type. Constructor tear-offs are current
    // not supported and wrapping the constructor in a closure yields a matrix
    // of type `Matrix<dynamic>`, which we don't want either.
    switch (format) {
      case FormatType.rowMajor:
        return RowMajorMatrix<T>(type, rowCount, colCount);
      case FormatType.columnMajor:
        return ColumnMajorMatrix<T>(type, rowCount, colCount);
      case FormatType.compressedRow:
        return CompressedRowMatrix<T>(type, rowCount, colCount);
      case FormatType.compressedColumn:
        return CompressedColumnMatrix<T>(type, rowCount, colCount);
      case FormatType.coordinateList:
        return CoordinateListMatrix<T>(type, rowCount, colCount);
      case FormatType.keyed:
        return KeyedMatrix<T>(type, rowCount, colCount);
      case FormatType.diagonal:
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
