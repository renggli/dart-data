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

  /// Tests if [row] and [col] are within the bounds of this matrix.
  bool isWithinBounds(int row, int col) =>
      0 <= row && row < rowCount && 0 <= col && col < colCount;

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
