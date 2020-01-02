library data.matrix.matrix;

import 'package:more/printer.dart' show Printer;

import '../../type.dart' show DataType;
import '../../vector.dart' show Vector;
import '../shared/storage.dart';
import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'matrix_format.dart';
import 'view/constant_matrix.dart';
import 'view/generated_matrix.dart';
import 'view/identity_matrix.dart';
import 'view/row_vector.dart';

/// Abstract matrix type.
abstract class Matrix<T> implements Storage {
  /// Constructs a default matrix of the desired [dataType], the provided
  /// [rowCount] and [columnCount], and possibly a custom [format].
  factory Matrix(DataType<T> dataType, int rowCount, int columnCount,
      {MatrixFormat format}) {
    ArgumentError.checkNotNull(dataType, 'dataType');
    RangeError.checkNotNegative(rowCount, 'rowCount');
    RangeError.checkNotNegative(columnCount, 'columnCount');
    switch (format ?? defaultMatrixFormat) {
      case MatrixFormat.rowMajor:
        return RowMajorMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.columnMajor:
        return ColumnMajorMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.compressedRow:
        return CompressedRowMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.compressedColumn:
        return CompressedColumnMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.coordinateList:
        return CoordinateListMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.keyed:
        return KeyedMatrix<T>(dataType, rowCount, columnCount);
      case MatrixFormat.diagonal:
        return DiagonalMatrix<T>(dataType, rowCount, columnCount);
      default:
        throw ArgumentError.value(format, 'format', 'Unknown matrix format.');
    }
  }

  /// Constructs a matrix with a constant [value]. If [format] is specified
  /// the resulting matrix is mutable, otherwise this is a read-only view.
  factory Matrix.constant(DataType<T> dataType, int rowCount, int columnCount,
      {T value, MatrixFormat format}) {
    final result = ConstantMatrix<T>(
        dataType, rowCount, columnCount, value ?? dataType.nullValue);
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a generated matrix from calling a [callback] on every value. If
  /// [format] is specified the resulting matrix is mutable, otherwise this is
  /// a read-only view.
  factory Matrix.generate(DataType<T> dataType, int rowCount, int columnCount,
      MatrixGeneratorCallback<T> callback,
      {MatrixFormat format}) {
    final result =
        GeneratedMatrix<T>(dataType, rowCount, columnCount, callback);
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs an identity matrix with the constant [value]. If [format] is
  /// specified the resulting matrix is mutable, otherwise this is a read-only
  /// view.
  factory Matrix.identity(DataType<T> dataType, int rowCount, int columnCount,
      {T value, MatrixFormat format}) {
    final result = IdentityMatrix<T>(dataType, rowCount, columnCount,
        value ?? dataType.field.multiplicativeIdentity);
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a nested list of rows.
  factory Matrix.fromRows(DataType<T> dataType, List<List<T>> source,
      {MatrixFormat format}) {
    final result = Matrix<T>(
        dataType, source.length, source.isEmpty ? 0 : source[0].length,
        format: format);
    for (var r = 0; r < result.rowCount; r++) {
      final sourceRow = source[r];
      if (sourceRow.length != result.columnCount) {
        throw ArgumentError.value(
            source, 'source', 'All rows must be equally sized.');
      }
      for (var c = 0; c < result.columnCount; c++) {
        result.setUnchecked(r, c, sourceRow[c]);
      }
    }
    return result;
  }

  /// Constructs a matrix from a packed list of rows.
  factory Matrix.fromPackedRows(
      DataType<T> dataType, int rowCount, int columnCount, List<T> source,
      {MatrixFormat format}) {
    if (rowCount * columnCount != source.length) {
      throw ArgumentError.value(
          source, 'source', 'Row and column count do not match.');
    }
    final result = Matrix<T>(dataType, rowCount, columnCount, format: format);
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < result.columnCount; c++) {
        result.set(r, c, source[r * columnCount + c]);
      }
    }
    return result;
  }

  /// Constructs a matrix from a nested list of columns.
  factory Matrix.fromColumns(DataType<T> dataType, List<List<T>> source,
      {MatrixFormat format}) {
    final result = Matrix<T>(
        dataType, source.isEmpty ? 0 : source[0].length, source.length,
        format: format);
    for (var c = 0; c < result.columnCount; c++) {
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

  /// Constructs a matrix from a packed list of columns.
  factory Matrix.fromPackedColumns(
      DataType<T> dataType, int rowCount, int colCount, List<T> source,
      {MatrixFormat format}) {
    if (rowCount * colCount != source.length) {
      throw ArgumentError.value(
          source, 'source', 'Row and column count do not match.');
    }
    final result = Matrix<T>(dataType, rowCount, colCount, format: format);
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < result.columnCount; c++) {
        result.set(r, c, source[r + c * rowCount]);
      }
    }
    return result;
  }

  /// Returns the data type of this matrix.
  DataType<T> get dataType;

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns the number of columns in the matrix.
  int get columnCount;

  /// Returns a mutable row vector of this matrix. Convenience method to read
  /// matrix values using row and column indexes: `matrix[row][col]`.
  Vector<T> operator [](int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return rowUnchecked(row);
  }

  /// Returns the scalar at the provided [row] and [col] index. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  T get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', columnCount);
    return getUnchecked(row, col);
  }

  /// Returns the scalar at the provided [row] and [col] index. The behavior is
  /// undefined if [row] or [col] are outside of bounds.
  T getUnchecked(int row, int col);

  /// Sets the scalar at the provided [row] and [col] index to [value]. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', columnCount);
    setUnchecked(row, col, value);
  }

  /// Sets the scalar at the provided [row] and [col] index to [value]. The
  /// behavior is undefined if [row] or [col] are outside of bounds.
  void setUnchecked(int row, int col, T value);

  /// Tests if [row] and [col] are within the bounds of this matrix.
  bool isWithinBounds(int row, int col) =>
      0 <= row && row < rowCount && 0 <= col && col < columnCount;

  /// Returns the shape of this matrix.
  @override
  List<int> get shape => [rowCount, columnCount];

  /// Returns a copy of this matrix.
  @override
  Matrix<T> copy();

  /// Creates a new [Matrix] containing the same elements as this matrix.
  Matrix<T> toMatrix({MatrixFormat format}) {
    final result = Matrix(dataType, rowCount, columnCount, format: format);
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < columnCount; c++) {
        result.setUnchecked(r, c, getUnchecked(r, c));
      }
    }
    return result;
  }

  /// Returns a human readable representation of the matrix.
  String format({
    Printer valuePrinter,
    Printer paddingPrinter,
    Printer ellipsesPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    String horizontalSeparator = ' ',
    String verticalSeparator = '\n',
    String horizontalEllipses = '\u2026',
    String verticalEllipses = '\u22ee',
    String diagonalEllipses = '\u22f1',
  }) {
    final buffer = StringBuffer();
    valuePrinter ??= dataType.printer;
    paddingPrinter ??= Printer.standard();
    ellipsesPrinter ??= Printer.standard();
    for (var r = 0; r < rowCount; r++) {
      if (r > 0) {
        buffer.write(verticalSeparator);
      }
      if (limit && leadingItems <= r && r < rowCount - trailingItems) {
        final ellipsesVector = Vector.builder
            .withType(DataType.string)
            .constant(columnCount, verticalEllipses);
        buffer.write(ellipsesVector.format(
          valuePrinter: ellipsesPrinter,
          paddingPrinter: paddingPrinter,
          ellipsesPrinter: ellipsesPrinter,
          limit: limit,
          leadingItems: leadingItems,
          trailingItems: trailingItems,
          separator: horizontalSeparator,
          ellipses: diagonalEllipses,
        ));
        r = rowCount - trailingItems - 1;
      } else {
        buffer.write(rowUnchecked(r).format(
          valuePrinter: valuePrinter,
          paddingPrinter: paddingPrinter,
          ellipsesPrinter: ellipsesPrinter,
          limit: limit,
          leadingItems: leadingItems,
          trailingItems: trailingItems,
          separator: horizontalSeparator,
          ellipses: horizontalEllipses,
        ));
      }
    }
    return buffer.toString();
  }

  /// Returns the string representation of this matrix.
  @override
  String toString() => '$runtimeType('
      'dataType: ${dataType.name}, '
      'rowCount: $rowCount, '
      'columnCount: $columnCount):\n'
      '${format()}';
}
