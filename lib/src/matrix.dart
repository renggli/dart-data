library matrix;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;

import 'type.dart';

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

class Row<T extends num> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> matrix;
  final int row;

  Row(this.matrix, this.row) {
    RangeError.checkValueInInterval(row, 0, matrix.rowCount);
  }

  @override
  int get length => matrix.colCount;

  @override
  T operator [](int index) => matrix.get(row, index);

  @override
  void operator []=(int index, T value) => matrix.set(row, index, value);
}

class Col<T extends num> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> matrix;
  final int col;

  Col(this.matrix, this.col) {
    RangeError.checkValueInInterval(col, 0, matrix.colCount);
  }

  @override
  int get length => matrix.rowCount;

  @override
  T operator [](int index) => matrix.get(index, col);

  @override
  void operator []=(int index, T value) => matrix.set(index, col, value);
}

class RowMajorMatrix<T extends num> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> data;

  RowMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : data = dataType.newList(rowCount * colCount);

  @override
  T get(int row, int col) => data[row * rowCount + col];

  @override
  T set(int row, int col, T value) => data[row * rowCount + col] = value;
}

class ColumnMajorMatrix<T extends num> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final List<T> data;

  ColumnMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : data = dataType.newList(rowCount * colCount);

  @override
  T get(int row, int col) => data[row + col * colCount];

  @override
  T set(int row, int col, T value) => data[row + col * colCount] = value;
}

abstract class SparseMatrix<T extends num> extends Matrix<T> {}

//class SparseMatrix<T> extends SparseMatrix<T> {}

void main() {
  final rmm = RowMajorMatrix<int>(DataType.UINT_16, 5, 6);
  final cmm = ColumnMajorMatrix<int>(DataType.UINT_16, 5, 6);

  print(rmm);

  print(cmm);
}
