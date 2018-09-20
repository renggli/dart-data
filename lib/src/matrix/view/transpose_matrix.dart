library data.matrix.view.transpose_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable transposed view of a matrix.
class TransposeMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;

  TransposeMatrix(this._matrix);

  @override
  Matrix<T> copy() => TransposeMatrix(_matrix.copy());

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _matrix.colCount;

  @override
  int get colCount => _matrix.rowCount;

  @override
  T getUnchecked(int row, int col) => _matrix.getUnchecked(col, row);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(col, row, value);

  @override
  Matrix<T> get transpose => _matrix;
}
