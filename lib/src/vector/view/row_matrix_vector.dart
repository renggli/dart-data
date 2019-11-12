library data.vector.view.row_matrix;

import '../../../tensor.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../../matrix/matrix.dart';

/// Mutable row vector of a matrix.
class RowMatrixVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _row;

  RowMatrixVector(this._matrix, this._row);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get count => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Vector<T> copy() => RowMatrixVector(_matrix.copy(), _row);

  @override
  T getUnchecked(int index) => _matrix.getUnchecked(_row, index);

  @override
  void setUnchecked(int index, T value) =>
      _matrix.setUnchecked(_row, index, value);
}
