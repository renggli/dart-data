library data.matrix.matrix;

import 'package:data/type.dart';

import 'column.dart';
import 'row.dart';

abstract class Matrix<T extends num> {
  const Matrix();

  /// The data type of this matrix.
  DataType<T> get dataType;

  /// Returns the value at the provided [row] and [col] index.
  T get(int row, int col);

  /// Sets the value at the provided [row] and [col] index to [value].
  T set(int row, int col, T value);

  /// Returns the number of rows in the matrix.
  int get rowCount;

  /// Returns a column of the matrix.
  Row<T> row(int row) => Row<T>(this, row);

  /// Returns the number of columns in the matrix.
  int get colCount;

  /// Returns a row of the matrix.
  Col<T> col(int col) => Col<T>(this, col);

  /// Pretty prints the matrix.
  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    buffer.write('[$rowCount * $colCount]');
    for (var r = 0; r < rowCount; r++) {
      buffer.writeln();
      buffer.writeAll(row(r), ' ');
    }
    return buffer.toString();
  }
}
