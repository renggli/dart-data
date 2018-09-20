library data.matrix.view.mapped_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

typedef T MatrixTransformation<S, T>(int row, int col, S value);

/// A lazy transformed matrix.
class MappedMatrix<S, T> extends Matrix<T> {
  final Matrix<S> _matrix;
  final MatrixTransformation<S, T> _callback;

  MappedMatrix(this._matrix, this._callback, this.dataType);

  @override
  Matrix<T> copy() => MappedMatrix(_matrix.copy(), _callback, dataType);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  T getUnchecked(int row, int col) =>
      _callback(row, col, _matrix.getUnchecked(row, col));

  @override
  void setUnchecked(int row, int col, T value) =>
      throw UnsupportedError('Matrix is not mutable.');
}
