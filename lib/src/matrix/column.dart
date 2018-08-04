library data.matrix.column;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;

import 'matrix.dart';

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
