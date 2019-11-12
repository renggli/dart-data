library data.matrix.view.row_vector;

import '../../../tensor.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../matrix.dart';

/// Mutable row matrix of a vector.
class RowMatrix<T> extends Matrix<T> {
  final Vector<T> _vector;

  RowMatrix(this._vector);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get rowCount => 1;

  @override
  int get colCount => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Matrix<T> copy() => RowMatrix(_vector.copy());

  @override
  T getUnchecked(int row, int col) => _vector.getUnchecked(col);

  @override
  void setUnchecked(int row, int col, T value) =>
      _vector.setUnchecked(col, value);
}
