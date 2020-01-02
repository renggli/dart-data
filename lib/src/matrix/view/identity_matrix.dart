library data.matrix.view.identity;

import '../../../type.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

/// Read-only identity matrix.
class IdentityMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final T value;

  IdentityMatrix(this.dataType, this.rowCount, this.colCount, this.value);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => row == col ? value : dataType.nullValue;
}
