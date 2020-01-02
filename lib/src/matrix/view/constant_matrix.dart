library data.matrix.view.constant;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix_mixin.dart';

/// Read-only matrix with a constant value.
class ConstantMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  final T value;

  ConstantMatrix(this.dataType, this.rowCount, this.columnCount, this.value);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => value;
}
