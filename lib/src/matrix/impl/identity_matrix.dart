library data.matrix.impl.identity_matrix;

import 'package:data/type.dart';

import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

class IdentityMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final T _value;

  IdentityMatrix(this.dataType, this.rowCount, this.colCount, this._value);

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => row == col ? _value : dataType.nullValue;
}