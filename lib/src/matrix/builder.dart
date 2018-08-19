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
  Matrix<T> call(int rowCount, [int colCount]) {
    RangeError.checkNotNegative(rowCount, 'rowCount');
    if (colCount != null) {
      RangeError.checkNotNegative(colCount, 'colCount');
    } else {
      colCount = rowCount;
    }
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
  Matrix<T> fromRow(Vector<T> source) {
    final result = this(1, source.count);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(0, index, source.getUnchecked(index));
    }
    return result;
  }

  /// Builds a matrix from a column vector.
  Matrix<T> fromColumn(Vector<T> source) {
    final result = this(source.count, 1);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(index, 0, source.getUnchecked(index));
    }
    return result;
  }

  /// Builds a matrix from a diagonal vector.
  Matrix<T> fromDiagonal(Vector<T> source) {
    final result = this(source.count, source.count);
    for (var index = 0; index < source.count; index++) {
      result.setUnchecked(index, index, source.getUnchecked(index));
    }
    return result;
  }

  /// Builds a matrix from a nested list of rows.
  Matrix<T> fromRows(List<List<T>> source) {
    final result = this(source.length, source.isEmpty ? 0 : source[0].length);
    for (var row = 0; row < result.rowCount; row++) {
      final sourceRow = source[row];
      if (sourceRow.length != result.colCount) {
        throw ArgumentError.value(
            source, 'source', 'All rows must be equally sized.');
      }
      for (var col = 0; col < result.colCount; col++) {
        result.setUnchecked(row, col, sourceRow[col]);
      }
    }
    return result;
  }

  /// Builds a matrix from a packed list of rows.
  Matrix<T> fromPackedRows(int rowCount, int colCount, List<T> source) {
    if (rowCount * colCount != source.length) {
      throw ArgumentError.value(
          source, 'source', 'Row and column count do not match.');
    }
    if (type == RowMajorMatrix) {
      // Optimized case for row major matrices.
      return RowMajorMatrix(type, rowCount, colCount, type.copyList(source));
    }
    final result = this(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.set(row, col, source[row * colCount + col]);
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of columns.
  Matrix<T> fromColumns(List<List<T>> source) {
    final result = this(source.isEmpty ? 0 : source[0].length, source.length);
    for (var col = 0; col < result.colCount; col++) {
      final sourceCol = source[col];
      if (sourceCol.length != result.rowCount) {
        throw ArgumentError.value(
            source, 'source', 'All columns must be equally sized.');
      }
      for (var row = 0; row < result.rowCount; row++) {
        result.setUnchecked(row, col, sourceCol[row]);
      }
    }
    return result;
  }

  /// Builds a matrix from a packed list of columns.
  Matrix<T> fromPackedColumns(int rowCount, int colCount, List<T> source) {
    if (rowCount * colCount != source.length) {
      throw ArgumentError.value(
          source, 'source', 'Row and column count do not match.');
    }
    if (type == ColumnMajorMatrix) {
      // Optimized case for row major matrices.
      return ColumnMajorMatrix(type, rowCount, colCount, type.copyList(source));
    }
    final result = this(rowCount, colCount);
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < result.colCount; col++) {
        result.set(row, col, source[row + col * rowCount]);
      }
    }
    return result;
  }
}
