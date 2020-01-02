library data.matrix.builder;

import '../../type.dart';
import '../vector/vector.dart';
import '../vector/view/column_matrix.dart' show ColumnMatrixExtension;
import '../vector/view/diagonal_matrix.dart' show DiagonalMatrixExtension;
import '../vector/view/row_matrix.dart' show RowMatrixExtension;
import 'format.dart';
import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'matrix.dart';
import 'view/cast_matrix.dart';
import 'view/concat_horizontal_matrix.dart';
import 'view/concat_vertical_matrix.dart';
import 'view/constant_matrix.dart';
import 'view/generated_matrix.dart';
import 'view/identity_matrix.dart';
import 'view/transformed_matrix.dart';

/// Builds a matrix of a custom type.
class Builder<T> {
  /// Constructors a builder with the provided storage [format] and data [type].
  Builder(this.format, this.type);

  /// Returns the storage format of the builder.
  final Format format;

  /// Returns the data type of the builder.
  final DataType<T> type;

  /// Returns a builder for row major matrices.
  Builder<T> get rowMajor => withFormat(Format.rowMajor);

  /// Returns a builder for column major matrices.
  Builder<T> get columnMajor => withFormat(Format.columnMajor);

  /// Returns a builder for compressed row matrices.
  Builder<T> get compressedRow => withFormat(Format.compressedRow);

  /// Returns a builder for compressed column matrices.
  Builder<T> get compressedColumn => withFormat(Format.compressedColumn);

  /// Returns a builder for coordinate list matrices.
  Builder<T> get coordinateList => withFormat(Format.coordinateList);

  /// Returns a builder for keyed matrices.
  Builder<T> get keyed => withFormat(Format.keyed);

  /// Returns a builder for diagonal matrices.
  Builder<T> get diagonal => withFormat(Format.diagonal);

  /// Returns a builder with the provided storage [format].
  Builder<T> withFormat(Format format) =>
      this.format == format ? this : Builder<T>(format, type);

  /// Returns a builder with the provided data [type].
  Builder<S> withType<S>(DataType<S> type) =>
      // ignore: unrelated_type_equality_checks
      this.type == type ? this : Builder<S>(format, type);

  /// Builds a new matrix of the configured format.
  Matrix<T> call(int rowCount, [int colCount]) {
    RangeError.checkNotNegative(rowCount, 'rowCount');
    if (colCount != null) {
      RangeError.checkNotNegative(colCount, 'colCount');
    } else {
      colCount = rowCount;
    }
    ArgumentError.checkNotNull(type, 'type');
    switch (format) {
      case Format.rowMajor:
        return RowMajorMatrix<T>(type, rowCount, colCount);
      case Format.columnMajor:
        return ColumnMajorMatrix<T>(type, rowCount, colCount);
      case Format.compressedRow:
        return CompressedRowMatrix<T>(type, rowCount, colCount);
      case Format.compressedColumn:
        return CompressedColumnMatrix<T>(type, rowCount, colCount);
      case Format.coordinateList:
        return CoordinateListMatrix<T>(type, rowCount, colCount);
      case Format.keyed:
        return KeyedMatrix<T>(type, rowCount, colCount);
      case Format.diagonal:
        return DiagonalMatrix<T>(type, rowCount, colCount);
    }
    throw ArgumentError.value(format, 'format');
  }

  /// Builds a matrix with a constant [value].
  Matrix<T> constant(int rowCount, int colCount, T value,
      {bool mutable = false}) {
    final result = ConstantMatrix(type, rowCount, colCount, value);
    return mutable ? fromMatrix(result) : result;
  }

  /// Builds an identity matrix with a constant [value].
  Matrix<T> identity(int rowCount, int colCount, T value,
      {bool mutable = false}) {
    final result = IdentityMatrix(type, rowCount, colCount, value);
    return mutable ? fromMatrix(result) : result;
  }

  /// Builds a matrix from calling a [callback] on every value.
  Matrix<T> generate(
      int rowCount, int colCount, T Function(int row, int col) callback,
      {bool lazy = false}) {
    final result = GeneratedMatrix(type, rowCount, colCount, callback);
    return lazy ? result : fromMatrix(result);
  }

  /// Builds a matrix by transforming another matrix with [callback].
  Matrix<T> transform<S>(
      Matrix<S> source, T Function(int row, int col, S input) callback,
      {bool lazy = false}) {
    final result = source.map(callback, type);
    return lazy ? result : fromMatrix(result);
  }

  /// Builds a matrix by casting to another type.
  Matrix<T> cast<S>(Matrix<S> source, {bool lazy = false}) {
    final result = source.cast(type);
    return lazy ? result : fromMatrix(result);
  }

  /// Builds a matrix by concatenating a list of [matrices] horizontally.
  Matrix<T> concatHorizontal(Iterable<Matrix<T>> matrices,
      {bool lazy = false}) {
    final result = ConcatHorizontalMatrix<T>(type, matrices);
    return lazy ? result : fromMatrix(result);
  }

  /// Builds a matrix by concatenating a list of [matrices] vertically.
  Matrix<T> concatVertical(Iterable<Matrix<T>> matrices, {bool lazy = false}) {
    final result = ConcatVerticalMatrix<T>(type, matrices);
    return lazy ? result : fromMatrix(result);
  }

  /// Builds a matrix from another matrix.
  Matrix<T> fromMatrix(Matrix<T> source) {
    final result = this(source.rowCount, source.colCount);
    for (var r = 0; r < result.rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(r, c, source.getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Builds a matrix from a row vector.
  Matrix<T> fromRow(Vector<T> source, {bool lazy = false}) =>
      lazy ? source.rowMatrix : fromMatrix(source.rowMatrix);

  /// Builds a matrix from a column vector.
  Matrix<T> fromColumn(Vector<T> source, {bool lazy = false}) =>
      lazy ? source.columnMatrix : fromMatrix(source.columnMatrix);

  /// Builds a matrix from a diagonal vector.
  Matrix<T> fromDiagonal(Vector<T> source, {bool lazy = false}) =>
      lazy ? source.diagonalMatrix : fromMatrix(source.diagonalMatrix);

  /// Builds a matrix from a nested list of rows.
  Matrix<T> fromRows(List<List<T>> source) {
    final result = this(source.length, source.isEmpty ? 0 : source[0].length);
    for (var r = 0; r < result.rowCount; r++) {
      final sourceRow = source[r];
      if (sourceRow.length != result.colCount) {
        throw ArgumentError.value(
            source, 'source', 'All rows must be equally sized.');
      }
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(r, c, sourceRow[c]);
      }
    }
    return result;
  }

  /// Builds a matrix from a list of row vectors.
  Matrix<T> fromRowVectors(List<Vector<T>> source) {
    final result = this(source.length, source.isEmpty ? 0 : source[0].count);
    for (var r = 0; r < result.rowCount; r++) {
      final sourceRow = source[r];
      if (sourceRow.count != result.colCount) {
        throw ArgumentError.value(
            source, 'source', 'All row vectors must be equally sized.');
      }
      for (var c = 0; c < result.colCount; c++) {
        result.setUnchecked(r, c, sourceRow[c]);
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
    if (Format.rowMajor == format) {
      // Optimized case for row major matrices.
      return RowMajorMatrix.fromList(
          type, rowCount, colCount, type.copyList(source));
    }
    final result = this(rowCount, colCount);
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.set(r, c, source[r * colCount + c]);
      }
    }
    return result;
  }

  /// Builds a matrix from a nested list of columns.
  Matrix<T> fromColumns(List<List<T>> source) {
    final result = this(source.isEmpty ? 0 : source[0].length, source.length);
    for (var c = 0; c < result.colCount; c++) {
      final sourceCol = source[c];
      if (sourceCol.length != result.rowCount) {
        throw ArgumentError.value(
            source, 'source', 'All columns must be equally sized.');
      }
      for (var r = 0; r < result.rowCount; r++) {
        result.setUnchecked(r, c, sourceCol[r]);
      }
    }
    return result;
  }

  /// Builds a matrix from a list of column vectors.
  Matrix<T> fromColumnVectors(List<Vector<T>> source) {
    final result = this(source.isEmpty ? 0 : source[0].count, source.length);
    for (var c = 0; c < result.colCount; c++) {
      final sourceCol = source[c];
      if (sourceCol.count != result.rowCount) {
        throw ArgumentError.value(
            source, 'source', 'All column vectors must be equally sized.');
      }
      for (var r = 0; r < result.rowCount; r++) {
        result.setUnchecked(r, c, sourceCol[r]);
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
    if (Format.columnMajor == format) {
      // Optimized case for column major matrices.
      return ColumnMajorMatrix.fromList(
          type, rowCount, colCount, type.copyList(source));
    }
    final result = this(rowCount, colCount);
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < result.colCount; c++) {
        result.set(r, c, source[r + c * rowCount]);
      }
    }
    return result;
  }
}
