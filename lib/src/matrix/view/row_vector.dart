library data.matrix.view.row_vector;

import 'package:data/type.dart';
import 'package:data/vector.dart';

import '../matrix.dart';

/// A mutable vector of a row of a matrix.
class RowVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _row;

  RowVector(this._matrix, this._row) {
    RangeError.checkValidIndex(_row, _matrix, 'row', _matrix.rowCount);
  }

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get count => _matrix.colCount;

  @override
  T getUnchecked(int index) => _matrix.getUnchecked(_row, index);

  @override
  void setUnchecked(int index, T value) =>
      _matrix.setUnchecked(_row, index, value);
}
