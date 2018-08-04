library data.matrix.row;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;

import 'matrix.dart';

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
