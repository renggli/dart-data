import 'dart:math' as math;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Sparse matrix with diagonal storage.
class DiagonalMatrix<T> with Matrix<T> {
  final Map<int, List<T>> _diagonals;

  DiagonalMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(dataType, rowCount, colCount, <int, List<T>>{});

  DiagonalMatrix._(
      this.dataType, this.rowCount, this.columnCount, this._diagonals);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => DiagonalMatrix._(
      dataType,
      rowCount,
      columnCount,
      Map.of(_diagonals)
        ..updateAll((offset, diagonal) => dataType.copyList(diagonal)));

  @override
  T getUnchecked(int row, int col) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    final diagonal = _diagonals[offset];
    return diagonal == null ? dataType.defaultValue : diagonal[index];
  }

  @override
  void setUnchecked(int row, int col, T value) {
    final offset = row - col;
    final index = offset < 0 ? col + offset : col;
    _diagonals.putIfAbsent(offset, () {
      final length = math.min(rowCount - offset, columnCount + offset);
      return dataType.newList(length);
    })[index] = value;
  }
}
