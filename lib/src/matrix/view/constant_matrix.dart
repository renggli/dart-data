library data.matrix.view.constant;

import '../../../type.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

/// Read-only matrix with a constant value.
class ConstantMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final T _value;

  ConstantMatrix(this.dataType, this.rowCount, this.colCount, this._value);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => _value;
}
