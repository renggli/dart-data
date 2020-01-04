library data.matrix.view.unmodifiable;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix_mixin.dart';

/// Read-only view of a mutable matrix.
class UnmodifiableMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  final Matrix<T> matrix;

  UnmodifiableMatrix(this.matrix);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get columnCount => matrix.columnCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  Matrix<T> copy() => UnmodifiableMatrix(matrix.copy());

  @override
  T getUnchecked(int row, int col) => matrix.getUnchecked(row, col);
}

extension UnmodifiableMatrixExtension<T> on Matrix<T> {
  /// Returns a unmodifiable view of the matrix.
  Matrix<T> get unmodifiable =>
      this is UnmodifiableMatrixMixin<T> ? this : UnmodifiableMatrix<T>(this);
}
