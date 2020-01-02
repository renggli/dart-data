library data.matrix.view.identity;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix_mixin.dart';

/// Read-only identity matrix.
class IdentityMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  final T value;

  IdentityMatrix(this.dataType, this.rowCount, this.columnCount, this.value);

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
  T getUnchecked(int row, int col) => row == col ? value : dataType.nullValue;
}
