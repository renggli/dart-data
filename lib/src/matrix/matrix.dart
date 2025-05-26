import 'package:meta/meta.dart';
import 'package:more/functional.dart';
import 'package:more/printer.dart' show Printer, StandardPrinter;

import '../../type.dart' show DataType;
import '../../vector.dart' show Vector;
import '../shared/storage.dart';
import '../tensor/tensor.dart';
import 'impl/column_major_matrix.dart';
import 'impl/compressed_column_matrix.dart';
import 'impl/compressed_row_matrix.dart';
import 'impl/coordinate_list_matrix.dart';
import 'impl/diagonal_matrix.dart';
import 'impl/keyed_matrix.dart';
import 'impl/nested_column_matrix.dart';
import 'impl/nested_row_matrix.dart';
import 'impl/row_major_matrix.dart';
import 'impl/tensor_matrix.dart';
import 'matrix_format.dart';
import 'view/concat_horizontal_matrix.dart';
import 'view/concat_vertical_matrix.dart';
import 'view/constant_matrix.dart';
import 'view/generated_matrix.dart';
import 'view/identity_matrix.dart';
import 'view/row_vector.dart';

/// Abstract matrix type.
abstract mixin class Matrix<T> implements Storage {
  /// Constructs a default matrix of the desired [dataType], the provided
  /// [rowCount] and [columnCount], and possibly a custom [format].
  factory Matrix(
    DataType<T> dataType,
    int rowCount,
    int columnCount, {
    MatrixFormat? format,
  }) {
    RangeError.checkNotNegative(rowCount, 'rowCount');
    RangeError.checkNotNegative(columnCount, 'columnCount');
    return switch (format ?? MatrixFormat.standard) {
      MatrixFormat.rowMajor => RowMajorMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.columnMajor => ColumnMajorMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.nestedRow => NestedRowMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.nestedColumn => NestedColumnMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.compressedRow => CompressedRowMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.compressedColumn => CompressedColumnMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.coordinateList => CoordinateListMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.keyed => KeyedMatrix<T>(dataType, rowCount, columnCount),
      MatrixFormat.diagonal => DiagonalMatrix<T>(
        dataType,
        rowCount,
        columnCount,
      ),
      MatrixFormat.tensor => TensorMatrix<T>(dataType, rowCount, columnCount),
    };
  }

  /// Returns the horizontal concatenation of [matrices].
  factory Matrix.concatHorizontal(
    DataType<T> dataType,
    Iterable<Matrix<T>> matrices, {
    MatrixFormat? format,
  }) {
    if (matrices.isEmpty) {
      throw ArgumentError.value(
        matrices,
        'matrices',
        'Expected at least 1 matrix.',
      );
    }
    final result = matrices.length == 1
        ? matrices.first
        : ConcatHorizontalMatrix<T>(dataType, matrices.toList(growable: false));
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Returns the vertical concatenation of [matrices].
  factory Matrix.concatVertical(
    DataType<T> dataType,
    Iterable<Matrix<T>> matrices, {
    MatrixFormat? format,
  }) {
    if (matrices.isEmpty) {
      throw ArgumentError.value(
        matrices,
        'matrices',
        'Expected at least 1 matrix.',
      );
    }
    final result = matrices.length == 1
        ? matrices.first
        : ConcatVerticalMatrix<T>(dataType, matrices.toList(growable: false));
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Returns a matrix with a constant [value].
  ///
  /// If [format] is specified the resulting matrix is mutable, otherwise this
  /// is a read-only view.
  factory Matrix.constant(
    DataType<T> dataType,
    int rowCount,
    int columnCount, {
    T? value,
    MatrixFormat? format,
  }) {
    final result = ConstantMatrix<T>(
      dataType,
      rowCount,
      columnCount,
      value ?? dataType.defaultValue,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Generates a matrix from calling a [callback] on every value.
  ///
  /// If [format] is specified the resulting matrix is mutable, otherwise this
  /// is a read-only view.
  factory Matrix.generate(
    DataType<T> dataType,
    int rowCount,
    int columnCount,
    MatrixGeneratorCallback<T> callback, {
    MatrixFormat? format,
  }) {
    final result = GeneratedMatrix<T>(
      dataType,
      rowCount,
      columnCount,
      callback,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Returns an identity matrix with the constant [value].
  ///
  /// If [format] is specified the resulting matrix is mutable, otherwise this
  /// is a read-only view.
  factory Matrix.identity(
    DataType<T> dataType,
    int rowCount,
    int columnCount, {
    T? value,
    MatrixFormat? format,
  }) {
    final result = IdentityMatrix<T>(
      dataType,
      rowCount,
      columnCount,
      value ?? dataType.field.multiplicativeIdentity,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Returns a Vandermonde matrix, a matrix with the terms of a geometric
  /// progression in each row.
  ///
  /// If [format] is specified the resulting matrix is mutable, otherwise this
  /// is a read-only view.
  factory Matrix.vandermonde(
    DataType<T> dataType,
    Vector<T> data,
    int columnCount, {
    MatrixFormat? format,
  }) {
    final pow = dataType.field.pow;
    final exponents = Vector<T>.generate(
      dataType,
      columnCount,
      (i) => dataType.cast(i),
    );
    return Matrix.generate(
      dataType,
      data.count,
      columnCount,
      (r, c) => pow(data[r], exponents[c]),
      format: format,
    );
  }

  /// Constructs a matrix from a nested list of rows.
  ///
  /// If [format] is specified, [source] is copied into a mutable matrix of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Matrix.fromRows(
    DataType<T> dataType,
    List<List<T>> source, {
    MatrixFormat? format,
  }) {
    final rowCount = source.length;
    final columnCount = source.isEmpty ? 0 : source[0].length;
    if (!source.every((row) => row.length == columnCount)) {
      throw ArgumentError.value(
        source,
        'source',
        'All rows must be equally sized.',
      );
    }
    final result = NestedRowMatrix.fromList(
      dataType,
      rowCount,
      columnCount,
      source,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a packed list of rows.
  ///
  /// If [format] is specified, [source] is copied into a mutable matrix of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Matrix.fromPackedRows(
    DataType<T> dataType,
    int rowCount,
    int columnCount,
    List<T> source, {
    MatrixFormat? format,
  }) {
    if (rowCount * columnCount != source.length) {
      throw ArgumentError.value(
        source,
        'source',
        'Row and column count do not match.',
      );
    }
    final result = RowMajorMatrix.fromList(
      dataType,
      rowCount,
      columnCount,
      source,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a nested list of columns.
  ///
  /// If [format] is specified, [source] is copied into a mutable matrix of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Matrix.fromColumns(
    DataType<T> dataType,
    List<List<T>> source, {
    MatrixFormat? format,
  }) {
    final rowCount = source.isEmpty ? 0 : source[0].length;
    final columnCount = source.length;
    if (!source.every((column) => column.length == rowCount)) {
      throw ArgumentError.value(
        source,
        'source',
        'All columns must be equally sized.',
      );
    }
    final result = NestedColumnMatrix.fromList(
      dataType,
      rowCount,
      columnCount,
      source,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a packed list of columns.
  ///
  /// If [format] is specified, [source] is copied into a mutable matrix of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Matrix.fromPackedColumns(
    DataType<T> dataType,
    int rowCount,
    int columnCount,
    List<T> source, {
    MatrixFormat? format,
  }) {
    if (rowCount * columnCount != source.length) {
      throw ArgumentError.value(
        source,
        'source',
        'Row and column count do not match.',
      );
    }
    final result = ColumnMajorMatrix.fromList(
      dataType,
      rowCount,
      columnCount,
      source,
    );
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a [Tensor].
  ///
  /// If [format] is specified, [source] is copied into a mutable matrix of the
  /// selected format; otherwise a view onto the possibly mutable [source] is
  /// provided.
  factory Matrix.fromTensor(Tensor<T> source, {MatrixFormat? format}) {
    final result = TensorMatrix<T>.fromTensor(source);
    return format == null ? result : result.toMatrix(format: format);
  }

  /// Constructs a matrix from a [String].
  ///
  /// An optional [converter] maps the extracted [String] values to the
  /// [dataType] of the matrix; by default the standard converter of the
  /// [DataType] is used.
  ///
  /// [rowSplitter] and [columnSplitter] are used to split the input string
  /// into rows and columns respectively. By default rows are separated by
  /// newlines, and columns by one or more whitespaces. The last row trimmed
  /// if the input is concluded with the row separator.
  factory Matrix.fromString(
    DataType<T> dataType,
    String source, {
    T Function(String)? converter,
    Pattern? rowSplitter,
    Pattern? columnSplitter,
    MatrixFormat? format,
  }) {
    final converter_ = converter ?? dataType.cast;
    final rowSplitter_ = rowSplitter ?? '\n';
    final columnSplitter_ = columnSplitter ?? RegExp(r'\s+');
    return Matrix<T>.fromRows(
      dataType,
      source
          .split(rowSplitter_)
          .also((rows) {
            if (rows.isNotEmpty && rows.last.isEmpty) {
              rows.removeLast();
            }
            return rows;
          })
          .map(
            (row) => row
                .split(columnSplitter_)
                .map(converter_)
                .toList(growable: false),
          )
          .toList(growable: false),
      format: format,
    );
  }

  /// Returns the data type of this matrix.
  DataType<T> get dataType;

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a mutable row vector of this matrix. Convenience method to read
  /// matrix values using row and column indexes: `matrix[row][col]`.
  @nonVirtual
  Vector<T> operator [](int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return rowUnchecked(row);
  }

  /// Returns the scalar at the provided [row] and [col] index. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  @nonVirtual
  T get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return getUnchecked(row, col);
  }

  /// Returns the scalar at the provided [row] and [col] index. The behavior is
  /// undefined if [row] or [col] are outside of bounds.
  T getUnchecked(int row, int col);

  /// Sets the scalar at the provided [row] and [col] index to [value]. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  @nonVirtual
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Sets the scalar at the provided [row] and [col] index to [value]. The
  /// behavior is undefined if [row] or [col] are outside of bounds.
  void setUnchecked(int row, int col, T value);

  /// Tests if [row] and [col] are within the bounds of this matrix.
  @nonVirtual
  bool isWithinBounds(int row, int col) =>
      0 <= row && row < rowCount && 0 <= col && col < colCount;

  /// Returns the shape of this matrix.
  @override
  List<int> get shape => [rowCount, colCount];

  /// Returns the target matrix with all elements of this matrix copied into it.
  Matrix<T> copyInto(Matrix<T> target) {
    assert(
      rowCount == target.rowCount,
      'Row count of this matrix ($rowCount) and the target matrix '
      '(${target.rowCount}) must match.',
    );
    assert(
      colCount == target.colCount,
      'Column count of this matrix ($colCount) and the target matrix '
      '(${target.colCount}) must match.',
    );
    if (this != target) {
      for (var r = 0; r < rowCount; r++) {
        for (var c = 0; c < colCount; c++) {
          target.setUnchecked(r, c, getUnchecked(r, c));
        }
      }
    }
    return target;
  }

  /// Creates a new [Matrix] containing the same elements as this one.
  Matrix<T> toMatrix({MatrixFormat? format}) =>
      copyInto(Matrix(dataType, rowCount, colCount, format: format));

  /// Iterates over each value in the matrix. Skips over default values, which
  /// can be done very efficiently on sparse matrices.
  void forEach(void Function(int row, int col, T value) callback) {
    for (var row = 0; row < rowCount; row++) {
      for (var col = 0; col < colCount; col++) {
        final value = getUnchecked(row, col);
        if (dataType.defaultValue != value) {
          callback(row, col, getUnchecked(row, col));
        }
      }
    }
  }

  /// Returns a human readable representation of the matrix.
  String format({
    Printer<T>? valuePrinter,
    Printer<String>? paddingPrinter,
    Printer<String>? ellipsesPrinter,
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
    paddingPrinter ??= const StandardPrinter<String>();
    ellipsesPrinter ??= const StandardPrinter<String>();
    for (var r = 0; r < rowCount; r++) {
      if (r > 0) {
        buffer.write(verticalSeparator);
      }
      if (limit && leadingItems <= r && r < rowCount - trailingItems) {
        final ellipsesVector = Vector.constant(
          DataType.string,
          colCount,
          value: verticalEllipses,
        );
        buffer.write(
          ellipsesVector.format(
            valuePrinter: ellipsesPrinter,
            paddingPrinter: paddingPrinter,
            ellipsesPrinter: ellipsesPrinter,
            limit: limit,
            leadingItems: leadingItems,
            trailingItems: trailingItems,
            separator: horizontalSeparator,
            ellipses: diagonalEllipses,
          ),
        );
        r = rowCount - trailingItems - 1;
      } else {
        buffer.write(
          rowUnchecked(r).format(
            valuePrinter: valuePrinter,
            paddingPrinter: paddingPrinter,
            ellipsesPrinter: ellipsesPrinter,
            limit: limit,
            leadingItems: leadingItems,
            trailingItems: trailingItems,
            separator: horizontalSeparator,
            ellipses: horizontalEllipses,
          ),
        );
      }
    }
    return buffer.toString();
  }

  /// Returns the string representation of this matrix.
  @override
  String toString() =>
      '$runtimeType('
      'dataType: ${dataType.name}, '
      'rowCount: $rowCount, '
      'columnCount: $colCount):\n'
      '${format()}';
}
