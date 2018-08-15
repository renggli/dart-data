library data.matrix.view.column_vector;

import 'package:data/type.dart';
import 'package:data/vector.dart';

import '../matrix.dart';

/// A mutable vector of a column of a matrix.
class ColumnVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _col;

  ColumnVector(this._matrix, this._col) {
    RangeError.checkValidIndex(_col, _matrix, 'col', _matrix.colCount);
  }

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get count => _matrix.rowCount;

  @override
  T getUnchecked(int index) => _matrix.getUnchecked(index, _col);

  @override
  void setUnchecked(int index, T value) =>
      _matrix.setUnchecked(index, _col, value);
}
