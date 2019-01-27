library data.matrix.impl.diagonal;

import 'dart:math' as math;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/type.dart';

/// Sparse matrix with diagonal storage.
class DiagonalMatrix<T> extends Matrix<T> {
  final Map<int, List<T>> _diagonals;

  DiagonalMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount, <int, List<T>>{});

  DiagonalMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._diagonals);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> copy() => DiagonalMatrix.internal(
      dataType,
      rowCount,
      colCount,
      Map.of(_diagonals)
        ..updateAll((offset, diagonal) => dataType.copyList(diagonal)));

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
