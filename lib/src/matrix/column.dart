library data.matrix.column;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;

import 'matrix.dart';

class Column<T> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> matrix;
  final int col;

  Column(this.matrix, this.col) {
    RangeError.checkValidIndex(col, matrix, 'col', matrix.colCount);
  }

  @override
  int get length => matrix.rowCount;

  @override
  T operator [](int row) {
    RangeError.checkValidIndex(row, matrix, 'row', matrix.rowCount);
    return matrix.getUnchecked(row, col);
  }

  @override
  void operator []=(int row, T value) {
    RangeError.checkValidIndex(row, matrix, 'row', matrix.rowCount);
    matrix.setUnchecked(row, col, value);
  }
}
