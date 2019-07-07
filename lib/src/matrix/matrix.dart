library data.matrix.matrix;

import 'package:data/src/matrix/builder.dart';
import 'package:data/src/matrix/format.dart';
import 'package:data/src/matrix/view/cast_matrix.dart';
import 'package:data/src/matrix/view/flipped_horizontal_matrix.dart';
import 'package:data/src/matrix/view/flipped_vertical_matrix.dart';
import 'package:data/src/matrix/view/index_matrix.dart';
import 'package:data/src/matrix/view/overlay_mask_matrix.dart';
import 'package:data/src/matrix/view/overlay_offset_matrix.dart';
import 'package:data/src/matrix/view/range_matrix.dart';
import 'package:data/src/matrix/view/transformed_matrix.dart';
import 'package:data/src/matrix/view/transposed_matrix.dart';
import 'package:data/src/matrix/view/unmodifiable_matrix.dart';
import 'package:data/src/vector/view/column_matrix_vector.dart';
import 'package:data/src/vector/view/diagonal_matrix_vector.dart';
import 'package:data/src/vector/view/row_matrix_vector.dart';
import 'package:data/tensor.dart' show Tensor;
import 'package:data/type.dart' show DataType;
import 'package:data/vector.dart' show Vector;
import 'package:more/collection.dart' show IntegerRange;
import 'package:more/printer.dart' show Printer;

/// Abstract matrix type.
abstract class Matrix<T> extends Tensor<T> {
  /// Default builder for new matrices.
  static Builder<Object> get builder =>
      Builder<Object>(Format.rowMajor, DataType.object);

  /// Unnamed default constructor.
  Matrix();

  /// Returns the shape of this matrix.
  @override
  List<int> get shape => [rowCount, colCount];

  /// Returns a copy of this matrix.
  @override
  Matrix<T> copy();

  /// Returns a mutable row vector of this matrix. Convenience method to read
  /// matrix values using row and column indexes: `matrix[row][col]`.
  @override
  Vector<T> operator [](int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return rowUnchecked(row);
  }

  /// Returns the scalar at the provided [row] and [col] index. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
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
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Sets the scalar at the provided [row] and [col] index to [value]. The
  /// behavior is undefined if [row] or [col] are outside of bounds.
  void setUnchecked(int row, int col, T value);

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns a mutable row vector of this matrix. Throws a [RangeError], if
  /// [row] is out of bounds.
  Vector<T> row(int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return rowUnchecked(row);
  }

  /// Returns a mutable row vector of this matrix. The behavior is undefined,
  /// if [row] is out of bounds.
  Vector<T> rowUnchecked(int row) => RowMatrixVector<T>(this, row);

  /// Returns an iterable over the rows of this matrix.
  Iterable<Vector<T>> get rows sync* {
    for (var r = 0; r < rowCount; r++) {
      yield rowUnchecked(r);
    }
  }

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a mutable column vector of this matrix. Throws a [RangeError], if
  /// [col] is out of bounds.
  Vector<T> col(int col) {
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return colUnchecked(col);
  }

  /// Returns a mutable column vector of this matrix. The behavior is undefined,
  /// if [col] is out of bounds. An offset of `0` refers to the diagonal in the
  /// center of the matrix, a negative offset to the diagonals above, a positive
  /// offset to the diagonals below.
  Vector<T> colUnchecked(int col) => ColumnMatrixVector<T>(this, col);

  /// Returns an iterable over the columns of this matrix.
  Iterable<Vector<T>> get cols sync* {
    for (var c = 0; c < colCount; c++) {
      yield colUnchecked(c);
    }
  }

  /// Returns a mutable diagonal vector of this matrix. Throws a [RangeError],
  /// if [offset] is out of bounds. An offset of `0` refers to the diagonal
  /// in the center of the matrix, a negative offset to the diagonals above,
  /// and a positive offset to the diagonals below.
  Vector<T> diagonal([int offset = 0]) {
    RangeError.checkValueInInterval(
        offset, -colCount + 1, rowCount - 1, 'offset');
    return diagonalUnchecked(offset);
  }

  /// Returns a mutable diagonal vector of the matrix. The behavior is
  /// undefined, if [offset] is out of bounds. An offset of `0` refers to the
  /// diagonal in the center of the matrix, a negative offset to the diagonals
  /// above, and a positive offset to the diagonals below.
  Vector<T> diagonalUnchecked([int offset = 0]) =>
      DiagonalMatrixVector<T>(this, offset);

  /// Returns an iterable over the diagonals of this matrix.
  Iterable<Vector<T>> get diagonals sync* {
    for (var d = -colCount + 1; d < rowCount; d++) {
      yield diagonalUnchecked(d);
    }
  }

  /// Returns an iterable that walks clockwise over the matrix starting in the
  /// upper left corner.
  Iterable<T> get spiral sync* {
    var k = 0, l = 0;
    var m = rowCount, n = colCount;
    while (k < m && l < n) {
      // First row from the remaining rows:
      for (var i = l; i < n; i++) {
        yield getUnchecked(k, i);
      }
      k++;
      // Last column from the remaining columns:
      for (var i = k; i < m; i++) {
        yield getUnchecked(i, n - 1);
      }
      n--;
      // Last row from the remaining rows:
      if (k < m) {
        for (var i = n - 1; i >= l; i--) {
          yield getUnchecked(m - 1, i);
        }
        m--;
      }
      // First column from the remaining columns:
      if (l < n) {
        for (var i = m - 1; i >= k; i--) {
          yield getUnchecked(i, l);
        }
        l++;
      }
    }
  }

  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRange(int rowStart, [int rowEnd]) =>
      range(rowStart, rowEnd, 0, colCount);

  /// Returns a mutable view onto the row range. The behavior is undefined, if
  /// [rowStart] or [rowEnd] are out of bounds.
  Matrix<T> rowRangeUnchecked(int rowStart, int rowEnd) =>
      rangeUnchecked(rowStart, rowEnd, 0, colCount);

  /// Returns a mutable view onto the row range. Throws a [RangeError], if
  /// [colStart] or [colEnd] are out of bounds.
  Matrix<T> colRange(int colStart, [int colEnd]) =>
      range(0, rowCount, colStart, colEnd);

  /// Returns a mutable view onto the row range. The behavior is undefed, if
  /// [colStart] or [colEnd] are out of bounds.
  Matrix<T> colRangeUnchecked(int colStart, int colEnd) =>
      rangeUnchecked(0, rowCount, colStart, colEnd);

  /// Returns a mutable view onto the row and column ranges. Throws a
  /// [RangeError], if any of the ranges are out of bounds.
  Matrix<T> range(int rowStart, int rowEnd, int colStart, int colEnd) {
    rowEnd = RangeError.checkValidRange(
        rowStart, rowEnd, rowCount, 'rowStart', 'rowEnd');
    colEnd = RangeError.checkValidRange(
        colStart, colEnd, colCount, 'colStart', 'colEnd');
    if (rowStart == 0 &&
        rowEnd == rowCount &&
        colStart == 0 &&
        colEnd == colCount) {
      return this;
    } else {
      return rangeUnchecked(rowStart, rowEnd, colStart, colEnd);
    }
  }

  /// Returns a mutable view onto the row and column ranges. The behavior is
  /// undefined if any of the ranges are out of bounds.
  Matrix<T> rangeUnchecked(
          int rowStart, int rowEnd, int colStart, int colEnd) =>
      RangeMatrix<T>(this, rowStart, rowEnd, colStart, colEnd);

  /// Returns a mutable view onto row indexes. Throws a [RangeError], if
  /// any of the [rowIndexes] are out of bounds.
  Matrix<T> rowIndex(Iterable<int> rowIndexes) =>
      index(rowIndexes, IntegerRange(0, colCount));

  /// Returns a mutable view onto row indexes. The behavior is undefined, if
  /// any of the [rowIndexes] are out of bounds.
  Matrix<T> rowIndexUnchecked(Iterable<int> rowIndexes) =>
      indexUnchecked(rowIndexes, IntegerRange(0, colCount));

  /// Returns a mutable view onto column indexes. Throws a [RangeError], if
  /// any of the [colIndexes] are out of bounds.
  Matrix<T> colIndex(Iterable<int> colIndexes) =>
      index(IntegerRange(0, rowCount), colIndexes);

  /// Returns a mutable view onto column indexes. The behavior is undefined, if
  /// any of the [colIndexes] are out of bounds.
  Matrix<T> colIndexUnchecked(Iterable<int> colIndexes) =>
      indexUnchecked(IntegerRange(0, rowCount), colIndexes);

  /// Returns a mutable view onto row and column indexes. Throws a
  /// [RangeError], if any of the indexes are out of bounds.
  Matrix<T> index(Iterable<int> rowIndexes, Iterable<int> colIndexes) {
    for (final index in rowIndexes) {
      RangeError.checkValueInInterval(index, 0, rowCount - 1, 'rowIndexes');
    }
    for (final index in colIndexes) {
      RangeError.checkValueInInterval(index, 0, colCount - 1, 'colIndexes');
    }
    return indexUnchecked(rowIndexes, colIndexes);
  }

  /// Returns a mutable view onto row and column indexes. The behavior is
  /// undefined if any of the indexes are out of bounds.
  Matrix<T> indexUnchecked(
          Iterable<int> rowIndexes, Iterable<int> colIndexes) =>
      IndexMatrix<T>(this, rowIndexes, colIndexes);

  /// Returns a mutable view where this matrix is overlaid on top of a provided
  /// [base] matrix. This happens either by using the given [rowOffset] and
  /// [colOffset], or using a boolean [mask].
  Matrix<T> overlay(
    Matrix<T> base, {
    DataType<T> dataType,
    Matrix<bool> mask,
    int rowOffset,
    int colOffset,
  }) {
    dataType ??= this.dataType;
    if (mask == null && rowOffset != null && colOffset != null) {
      return OverlayOffsetMatrix(dataType, this, rowOffset, colOffset, base);
    } else if (mask != null && rowOffset == null && colOffset == null) {
      if (rowCount != base.rowCount ||
          rowCount != mask.rowCount ||
          colCount != base.colCount ||
          colCount != mask.colCount) {
        throw ArgumentError('Dimensions of overlay ($rowCount * $colCount), '
            'mask (${mask.rowCount} * ${mask.colCount}) and base '
            '(${base.rowCount} * ${base.colCount}) matrices do not match.');
      }
      return OverlayMaskMatrix(dataType, this, mask, base);
    }
    throw ArgumentError('Either a mask or an offset required.');
  }

  /// Returns a read-only view on this [Matrix] with all its elements lazily
  /// converted by calling the provided transformation [callback].
  Matrix<S> map<S>(S Function(int row, int col, T value) callback,
          [DataType<S> dataType]) =>
      transform<S>(callback, dataType: dataType);

  /// Returns a view on this [Matrix] with all its elements lazily converted
  /// by calling the provided [read] transformation. An optionally provided
  /// [write] transformation enables writing to the returned matrix.
  Matrix<S> transform<S>(S Function(int row, int col, T value) read,
          {T Function(int row, int col, S value) write,
          DataType<S> dataType}) =>
      TransformedMatrix<T, S>(
        this,
        read,
        write ?? (r, c, v) => throw UnsupportedError('Matrix is not mutable.'),
        dataType ?? DataType.fromType(S),
      );

  /// Returns a lazy [Matrix] with the elements cast to `dataType`.
  Matrix<S> cast<S>(DataType<S> dataType) => CastMatrix<T, S>(this, dataType);

  /// Returns an iterable over the values of this matrix in row-by-row.
  Iterable<T> get rowMajor sync* {
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        yield getUnchecked(r, c);
      }
    }
  }

  /// Returns an iterable over the values of this matrix in column-by-column.
  Iterable<T> get colMajor sync* {
    for (var c = 0; c < colCount; c++) {
      for (var r = 0; r < rowCount; r++) {
        yield getUnchecked(r, c);
      }
    }
  }

  /// Returns a mutable view onto the transposed matrix.
  Matrix<T> get transposed => TransposedMatrix<T>(this);

  /// Returns a mutable view onto the horizontally flipped matrix.
  Matrix<T> get flippedHorizontal => FlippedHorizontalMatrix<T>(this);

  /// Returns a mutable view onto the vertically flipped matrix.
  Matrix<T> get flippedVertical => FlippedVerticalMatrix<T>(this);

  /// Returns a unmodifiable view of the matrix.
  Matrix<T> get unmodifiable => UnmodifiableMatrix<T>(this);

  /// Tests if [row] and [col] are within the bounds of this matrix.
  bool isWithinBounds(int row, int col) =>
      0 <= row && row < rowCount && 0 <= col && col < colCount;

  /// Tests if the matrix is square.
  bool get isSquare => rowCount == colCount;

  /// Tests if the matrix is symmetric (equal to its transposed form).
  bool get isSymmetric {
    if (!isSquare) {
      return false;
    }
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < r; c++) {
        if (getUnchecked(r, c) != getUnchecked(c, r)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if the matrix is a diagonal matrix, with non-zero values only on
  /// the diagonal.
  bool get isDiagonal {
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        if (r != c && getUnchecked(r, c) != dataType.nullValue) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if the matrix is a lower triangular matrix, with non-zero values
  /// only in the lower-triangle of the matrix.
  bool get isLowerTriangular {
    for (var r = 0; r < rowCount; r++) {
      for (var c = r + 1; c < colCount; c++) {
        if (getUnchecked(r, c) != dataType.nullValue) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if the matrix is a upper triangular matrix, with non-zero values
  /// only in the upper-triangle of the matrix.
  bool get isUpperTriangular {
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < colCount && c < r; c++) {
        if (getUnchecked(r, c) != dataType.nullValue) {
          return false;
        }
      }
    }
    return true;
  }

  /// Returns a human readable representation of the matrix.
  @override
  String format({
    Printer valuePrinter,
    Printer paddingPrinter,
    Printer ellipsesPrinter,
    bool limit = true,
    int leadingItems = 3,
    int trailingItems = 3,
    // additional options
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
            .constant(colCount, verticalEllipses);
        buffer.write(ellipsesVector.format(
          valuePrinter: ellipsesPrinter,
          paddingPrinter: paddingPrinter,
          ellipsesPrinter: ellipsesPrinter,
          limit: limit,
          leadingItems: leadingItems,
          trailingItems: trailingItems,
          separator: horizontalSeparator,
          ellipses: horizontalEllipses,
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
}
