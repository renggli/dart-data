library data.matrix.impl.constant_matrix;

import 'package:data/type.dart';

import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

class ConstantMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final T _value;

  ConstantMatrix(this.dataType, this.rowCount, this.colCount, this._value);

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => _value;
}
