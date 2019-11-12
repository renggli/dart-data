library data.matrix.view.transformed;

import '../../../tensor.dart';
import '../../../type.dart';
import '../matrix.dart';

/// Mutable two-way transformed matrix.
class TransformedMatrix<S, T> extends Matrix<T> {
  final Matrix<S> _matrix;
  final T Function(int row, int col, S value) _read;
  final S Function(int row, int col, T value) _write;

  TransformedMatrix(this._matrix, this._read, this._write, this.dataType);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() =>
      TransformedMatrix(_matrix.copy(), _read, _write, dataType);

  @override
  T getUnchecked(int row, int col) =>
      _read(row, col, _matrix.getUnchecked(row, col));

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(row, col, _write(row, col, value));
}
