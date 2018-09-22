library data.matrix.impl.identity_matrix;

import 'package:data/type.dart';

import '../matrix.dart';

class IdentityMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final T _value;

  const IdentityMatrix(
      this.dataType, this.rowCount, this.colCount, this._value);

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => row == col ? _value : dataType.nullValue;

  @override
  void setUnchecked(int row, int col, T value) =>
      throw UnsupportedError('Matrix is not mutable.');
}
