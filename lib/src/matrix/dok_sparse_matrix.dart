library data.matrix.dok_sparse_matrix;

import 'package:data/src/type/type.dart';

import 'sparse_matrix.dart';

/// Dictionary of keys based sparse matrix.
class DictionarySparseMatrix<T> extends SparseMatrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final Map<int, T> _values;

  DictionarySparseMatrix(this.dataType, this.rowCount, this.colCount)
      : _values = {};

  @override
  T getUnchecked(int row, int col) =>
      _values[row * colCount + col] ?? dataType.nullValue;

  @override
  void setUnchecked(int row, int col, T value) {
    final index = row * colCount + col;
    if (value != dataType.nullValue) {
      _values[index] = value;
    } else {
      _values.remove(index);
    }
  }
}
