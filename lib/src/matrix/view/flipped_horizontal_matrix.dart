library data.matrix.view.flipped_horizontal;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable matrix flipped on its horizontal axis.
class FlippedHorizontalMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;

  FlippedHorizontalMatrix(this._matrix);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> get flippedHorizontal => _matrix;

  @override
  Matrix<T> copy() => FlippedHorizontalMatrix(_matrix.copy());

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(_matrix.rowCount - row - 1, col);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(_matrix.rowCount - row - 1, col, value);
}
