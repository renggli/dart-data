library data.matrix.view.transposed_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A transposed mutable view onto another matrix.
class TransposedMatrix<T> extends Matrix<T> {
  final Matrix<T> matrix;

  TransposedMatrix(this.matrix);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.colCount;

  @override
  int get colCount => matrix.rowCount;

  @override
  T getUnchecked(int row, int col) => matrix.getUnchecked(col, row);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(col, row, value);

  @override
  Matrix<T> get transposed => matrix;
}
