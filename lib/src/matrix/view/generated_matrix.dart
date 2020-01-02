library data.matrix.view.generator;

import '../../../type.dart';
import '../matrix.dart';
import '../mixins/unmodifiable_matrix.dart';

/// Read-only generator matrix.
class GeneratedMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final T Function(int row, int col) callback;

  GeneratedMatrix(this.dataType, this.rowCount, this.colCount, this.callback);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => callback(row, col);
}
