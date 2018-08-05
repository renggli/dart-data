library data.matrix.row;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;

import 'matrix.dart';

class Row<T> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> matrix;
  final int row;

  Row(this.matrix, this.row) {
    RangeError.checkValidIndex(row, matrix, 'row', matrix.rowCount);
  }

  @override
  int get length => matrix.colCount;

  @override
  T operator [](int col) {
    RangeError.checkValidIndex(col, matrix, 'col', matrix.colCount);
    return matrix.getUnchecked(row, col);
  }

  @override
  void operator []=(int col, T value) {
    RangeError.checkValidIndex(col, matrix, 'col', matrix.colCount);
    matrix.setUnchecked(row, col, value);
  }
}
