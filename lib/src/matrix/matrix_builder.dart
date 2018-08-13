library data.matrix.matrix_builder;

import 'dart:math' as math;

import 'package:data/type.dart';

import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'matrix.dart';

enum MatrixType {
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
  MatrixBuilder(this.matrixType, this.dataType, this.rowCount, this.colCount);

  final MatrixType matrixType;

  final DataType<T> dataType;

  final int rowCount;

  final int colCount;

  MatrixBuilder<T> withMatrixType(MatrixType matrixType) =>
      MatrixBuilder<T>(matrixType, dataType, rowCount, colCount);

  MatrixBuilder<S> withDataType<S>(DataType<S> dataType) =>
      MatrixBuilder<S>(matrixType, dataType, rowCount, colCount);

  MatrixBuilder<T> withRows(int rowCount) =>
      MatrixBuilder<T>(matrixType, dataType, rowCount, colCount);

  MatrixBuilder<T> withCols(int colCount) =>
      MatrixBuilder<T>(matrixType, dataType, rowCount, colCount);

  MatrixBuilder<T> withSize(int rowCount, int colCount) =>
      MatrixBuilder<T>(matrixType, dataType, rowCount, colCount);

  /// Builds a default matrix.
  Matrix<T> build() {
    switch (matrixType) {
      case MatrixType.rowMajor:
        return RowMajorMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.columnMajor:
        return ColumnMajorMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.compressedRow:
        return CompressedRowMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.compressedColumn:
        return CompressedColumnMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.coordinateList:
        return CoordinateListMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.keyed:
        return KeyedMatrix<T>(dataType, rowCount, colCount);
      case MatrixType.diagonal:
        return DiagonalMatrix<T>(dataType, rowCount, colCount);
    }
    throw ArgumentError.value(matrixType, 'matrixType');
  }

  /// Builds a matrix with a constant [value].
  Matrix<T> buildConstant(T value) {
    final result = build();
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, value);
      }
    }
    return result;
  }

  /// Builds an identity matrix with a constant [value].
  Matrix<T> buildIdentity(T value) {
    final result = build();
    final count = math.min(rowCount, colCount);
    for (var i = 0; i < count; i++) {
      result.setUnchecked(i, i, value);
    }
    return result;
  }

  /// Builds a matrix from calling a [callback] on every value.
  Matrix<T> buildGenerate(T callback(int row, int col)) {
    final result = build();
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        result.setUnchecked(row, col, callback(row, col));
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of rows.
  Matrix<T> buildFromRows(List<List<T>> source) {
    final result = build();
    for (var row = 0; row < math.min(rowCount, source.length); row++) {
      final sourceRow = source[row];
      for (var col = 0; col < math.min(colCount, sourceRow.length); col++) {
        result.setUnchecked(row, col, sourceRow[col]);
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of columns.
  Matrix<T> buildFromCols(List<List<T>> source) {
    final result = build();
    for (var col = 0; col < math.min(colCount, source.length); col++) {
      final sourceCol = source[col];
      for (var row = 0; row < math.min(rowCount, sourceCol.length); row++) {
        result.setUnchecked(row, col, sourceCol[row]);
      }
    }
    return result;
  }
}
