library data.matrix.view.unmodifiable_matrix;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/src/matrix/mixins/unmodifiable_matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

List<int> foo;

/// Read-only view of a mutable matrix.
class UnmodifiableMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final Matrix<T> _matrix;

  UnmodifiableMatrix(this._matrix);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.rowCount;

  @override
  int get colCount => _matrix.colCount;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Matrix<T> copy() => UnmodifiableMatrix(_matrix.copy());

  @override
  T getUnchecked(int row, int col) => _matrix.getUnchecked(row, col);
}
