library data.matrix.view.column_view;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto the column of a matrix.
class ColumnView<T> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> _matrix;
  final int _col;

  ColumnView(this._matrix, this._col) {
    RangeError.checkValidIndex(_col, _matrix, 'col', _matrix.colCount);
  }

  @override
  int get length => _matrix.rowCount;

  DataType<T> get dataType => _matrix.dataType;

  @override
  T operator [](int row) {
    RangeError.checkValidIndex(row, _matrix, 'row', _matrix.rowCount);
    return _matrix.getUnchecked(row, _col);
  }

  @override
  void operator []=(int row, T value) {
    RangeError.checkValidIndex(row, _matrix, 'row', _matrix.rowCount);
    _matrix.setUnchecked(row, _col, value);
  }
}
