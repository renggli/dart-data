library data.matrix.dia_sparse_matrix;

import 'dart:math' as math;

import 'package:data/src/type/type.dart';

import 'sparse_matrix.dart';

/// Sparse matrix with diagonal storage.
class DiagonalSparseMatrix<T> extends SparseMatrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final Map<int, List<T>> _diagonals;

  DiagonalSparseMatrix(this.dataType, this.rowCount, this.colCount)
      : _diagonals = {};

  @override
  T getUnchecked(int row, int col) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    final diagonal = _diagonals[offset];
    return diagonal == null ? dataType.nullValue : diagonal[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    _diagonals.putIfAbsent(offset, () {
      final length = math.min(rowCount - offset, colCount + offset);
      return dataType.newList(length);
    })[index] = value;
  }
}