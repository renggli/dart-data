library data.matrix.view.row_view;

import 'dart:collection';

import 'package:collection/collection.dart' show NonGrowableListMixin;
import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto the row of a matrix.
class RowView<T> extends ListBase<T> with NonGrowableListMixin<T> {
  final Matrix<T> _matrix;
  final int _row;

  RowView(this._matrix, this._row) {
    RangeError.checkValidIndex(_row, _matrix, 'row', _matrix.rowCount);
  }

  @override
  int get length => _matrix.colCount;

  DataType<T> get dataType => _matrix.dataType;

  @override
  T operator [](int col) {
    RangeError.checkValidIndex(col, _matrix, 'col', _matrix.colCount);
    return _matrix.getUnchecked(_row, col);
  }

  @override
  void operator []=(int col, T value) {
    RangeError.checkValidIndex(col, _matrix, 'col', _matrix.colCount);
    _matrix.setUnchecked(_row, col, value);
  }
}
