library data.matrix.impl.diagonal_matrix;

import 'dart:math' as math;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// Sparse matrix with diagonal storage (DIA).
class DiagonalMatrix<T> extends Matrix<T> {
  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  final Map<int, List<T>> _diagonals;

  DiagonalMatrix(this.dataType, this.rowCount, this.colCount) : _diagonals = {};

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
