library data.matrix.matrix;

import 'package:data/type.dart';

import 'column.dart';
import 'row.dart';

abstract class Matrix<T> {
  const Matrix();

  /// The data type of this matrix.
  DataType<T> get dataType;

  /// Returns the value at the provided [row] and [col] index. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  T get(int row, int col) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    return getUnchecked(row, col);
  }

  /// Returns the value at the provided [row] and [col] index. The behavior is
  /// undefined if [row] or [col] are outside of bounds.
  T getUnchecked(int row, int col);

  /// Sets the value at the provided [row] and [col] index to [value]. Throws a
  /// [RangeError] if [row] or [col] are outside of bounds.
  void set(int row, int col, T value) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    RangeError.checkValidIndex(col, this, 'col', colCount);
    setUnchecked(row, col, value);
  }

  /// Sets the value at the provided [row] and [col] index to [value]. The
  /// behavior is undefined if [row] or [col] are outside of bounds.
  void setUnchecked(int row, int col, T value);

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns a row of the matrix. Throws a [RangeError] if [row] is outside
  /// of bounds.
  Row<T> row(int row) => Row<T>(this, row);

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a column of the matrix. Throws a [RangeError] if [col] is outside
  /// of bounds.
  Column<T> col(int col) => Column<T>(this, col);

  /// Pretty prints the matrix.
  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    buffer.write('[$rowCount * $colCount]');
    for (var r = 0; r < rowCount; r++) {
      buffer.writeln();
      for (var c = 0; c < colCount; c++) {
        buffer.write('  ${getUnchecked(r, c)}');
      }
    }
    return buffer.toString();
  }
}
