import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

/// Read-only identity matrix.
class IdentityMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  IdentityMatrix(this.dataType, this.rowCount, this.columnCount, this.value);

  final T value;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) =>
      row == col ? value : dataType.field.additiveIdentity;
}
