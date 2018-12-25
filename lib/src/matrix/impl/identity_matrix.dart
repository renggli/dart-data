library data.matrix.impl.identity_matrix;

import 'package:data/type.dart';

import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

/// Read-only identity matrix.
class IdentityMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final T _value;

  IdentityMatrix(this.dataType, this.rowCount, this.colCount, this._value);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => row == col ? _value : dataType.nullValue;
}
