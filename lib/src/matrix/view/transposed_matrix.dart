library data.matrix.view.transposed_matrix;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable transposed view of a matrix.
class TransposedMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;

  TransposedMatrix(this._matrix);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.colCount;

  @override
  int get colCount => _matrix.rowCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() => TransposedMatrix(_matrix.copy());

  @override
  T getUnchecked(int row, int col) => _matrix.getUnchecked(col, row);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(col, row, value);

  @override
  Matrix<T> get transposed => _matrix;
}
