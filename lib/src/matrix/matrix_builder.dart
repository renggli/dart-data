library data.matrix.matrix_builder;

import 'package:data/type.dart';

import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'matrix.dart';

enum MatrixFormat {
  rowMajor,
  columnMajor,
  compressedRow,
  compressedColumn,
  coordinateList,
  keyed,
  diagonal,
}

/// Builds a matrix of a custom type.
class MatrixBuilder<T> {
  MatrixBuilder(this.format, this.type);

  final MatrixFormat format;

  final DataType<T> type;

  MatrixBuilder<T> withFormat(MatrixFormat format) =>
      MatrixBuilder<T>(format, type);

  MatrixBuilder<S> withType<S>(DataType<S> type) =>
      MatrixBuilder<S>(format, type);

  /// Builds a matrix of the configured format.
  Matrix<T> build(int rowCount, int colCount) {
    // The reason for this enum to exist is purely to be able to instantiate
    // the matrix with the right generic type. Constructor tear-offs are current
    // not supported and wrapping the constructor in a closure yields a matrix
    // of type `Matrix<dynamic>`, which we don't want either.
    switch (format) {
      case MatrixFormat.rowMajor:
        return RowMajorMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.columnMajor:
        return ColumnMajorMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.compressedRow:
        return CompressedRowMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.compressedColumn:
        return CompressedColumnMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.coordinateList:
        return CoordinateListMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.keyed:
        return KeyedMatrix<T>(type, rowCount, colCount);
      case MatrixFormat.diagonal:
        return DiagonalMatrix<T>(type, rowCount, colCount);
    }
    throw ArgumentError.value(format, 'format');
  }

  /// Builds a matrix with a constant [value].
  Matrix<T> buildConstant(int rowCount, int colCount, T value) {
    final result = build(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, value);
      }
    }
    return result;
  }

  /// Builds an identity matrix with a constant [value].
  Matrix<T> buildIdentity(int count, T value) {
    final result = build(count, count);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, i, value);
    }
    return result;
  }

  /// Builds a matrix from calling a [callback] on every value.
  Matrix<T> buildGenerate(
      int rowCount, int colCount, T callback(int row, int col)) {
    final result = build(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, callback(row, col));
      }
    }
    return result;
  }

  /// Builds a matrix from another matrix.
  Matrix<T> buildFromMatrix(Matrix<T> source) {
    final result = build(source.rowCount, source.colCount);
    for (var row = 0; row < result.rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(row, col, source.getUnchecked(row, col));
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of rows.
  Matrix<T> buildFromRows(List<List<T>> source) {
    if (source.isEmpty) {
      ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = build(source.length, source[0].length);
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
  Matrix<T> buildFromCols(List<List<T>> source) {
    if (source.isEmpty) {
      ArgumentError.value(source, 'source', 'Must be not empty');
    }
    final result = build(source[0].length, source.length);
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
