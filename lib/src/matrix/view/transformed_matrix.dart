library data.matrix.view.transformed;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/src/matrix/mixins/unmodifiable_matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Read-only transformed matrix.
class TransformedMatrix<S, T> extends Matrix<T>
    with UnmodifiableMatrixMixin<T> {
  final Matrix<S> _matrix;
  final T Function(int row, int col, S value) _callback;

  TransformedMatrix(this._matrix, this._callback, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() => TransformedMatrix(_matrix.copy(), _callback, dataType);

  @override
  T getUnchecked(int row, int col) =>
      _callback(row, col, _matrix.getUnchecked(row, col));
}
