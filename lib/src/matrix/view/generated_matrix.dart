library data.matrix.view.generator;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/src/matrix/mixins/unmodifiable_matrix.dart';
import 'package:data/type.dart';

/// Read-only generator matrix.
class GeneratedMatrix<T> extends Matrix<T> with UnmodifiableMatrixMixin<T> {
  final T Function(int row, int col) _callback;

  GeneratedMatrix(this.dataType, this.rowCount, this.colCount, this._callback);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => this;

  @override
  T getUnchecked(int row, int col) => _callback(row, col);
}
