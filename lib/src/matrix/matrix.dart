library data.matrix.matrix;

import 'package:more/printer.dart' show Printer;

import '../../tensor.dart' show Tensor;
import '../../type.dart' show DataType;
import '../../vector.dart' show Vector;
import 'builder.dart';
import 'format.dart';
import 'view/row_vector.dart';

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

  /// Returns the number of columns in the matrix.
  int get colCount;

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
    final isEqual = dataType.equality.isEqual;
    for (var r = 1; r < rowCount; r++) {
      for (var c = 0; c < r; c++) {
        if (!isEqual(getUnchecked(r, c), getUnchecked(c, r))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if the matrix is a diagonal matrix, with non-zero values only on
  /// the diagonal.
  bool get isDiagonal {
    final isEqual = dataType.equality.isEqual;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        if (r != c && !isEqual(getUnchecked(r, c), dataType.nullValue)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Tests if the matrix is a lower triangular matrix, with non-zero values
  /// only in the lower-triangle of the matrix.
  bool get isLowerTriangular {
    final isEqual = dataType.equality.isEqual;
    for (var r = 0; r < rowCount; r++) {
      for (var c = r + 1; c < colCount; c++) {
        if (!isEqual(getUnchecked(r, c), dataType.nullValue)) {
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
}
