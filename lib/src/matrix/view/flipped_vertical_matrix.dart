library data.vector.view.flipped_vertical;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable matrix flipped on its vertical axis.
class FlippedVerticalMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;

  FlippedVerticalMatrix(this._matrix);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> get flippedVertical => _matrix;

  @override
  Matrix<T> copy() => FlippedVerticalMatrix(_matrix.copy());

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(row, _matrix.colCount - col - 1);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(row, _matrix.colCount - col - 1, value);
}
