library data.matrix.view.column_vector;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart';

/// Mutable column matrix of a vector.
class ColumnVectorMatrix<T> extends Matrix<T> {
  final Vector<T> _vector;

  ColumnVectorMatrix(this._vector);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get rowCount => _vector.count;

  @override
  int get colCount => 1;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Matrix<T> copy() => ColumnVectorMatrix(_vector.copy());

  @override
  T getUnchecked(int row, int col) => _vector.getUnchecked(row);

  @override
  void setUnchecked(int row, int col, T value) =>
      _vector.setUnchecked(row, value);
}
