library data.matrix.view.unmodifiable;

import '../../../tensor.dart';
import '../../../type.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

/// Read-only view of a mutable matrix.
class UnmodifiableMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final Matrix<T> matrix;

  UnmodifiableMatrix(this.matrix);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get colCount => matrix.colCount;

  @override
  Set<Tensor> get storage => matrix.storage;

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
