library data.matrix.view.unmodifiable_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// An unmodifiable matrix.
class UnmodifiableMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;

  UnmodifiableMatrix(this._matrix);

  @override
  Matrix<T> copy() => UnmodifiableMatrix(_matrix.copy());

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  T getUnchecked(int row, int col) => _matrix.getUnchecked(row, col);

  @override
  void setUnchecked(int row, int col, T value) =>
      throw UnsupportedError('Matrix is not mutable.');

  @override
  Matrix<T> get unmodifiable => this;
}
