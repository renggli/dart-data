library data.matrix.view.mapped_matrix;

import 'package:data/tensor.dart';
import 'package:data/type.dart';

import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

typedef MatrixTransformation<S, T> = T Function(int row, int col, S value);

/// Read-only transformed matrix.
class MappedMatrix<S, T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final Matrix<S> _matrix;
  final MatrixTransformation<S, T> _callback;

  MappedMatrix(this._matrix, this._callback, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() => MappedMatrix(_matrix.copy(), _callback, dataType);

  @override
  T getUnchecked(int row, int col) =>
      _callback(row, col, _matrix.getUnchecked(row, col));
}
