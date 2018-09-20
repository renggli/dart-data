library data.matrix.view.column_vector;

import 'package:data/type.dart';
import 'package:data/vector.dart';

import '../matrix.dart';

/// A mutable column vector of a matrix.
class ColumnVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _col;

  ColumnVector(this._matrix, this._col);

  @override
  Vector<T> copy() => ColumnVector(_matrix.copy(), _col);

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
