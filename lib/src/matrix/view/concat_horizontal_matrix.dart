library data.matrix.view.horizontal_concat;

import '../../../tensor.dart';
import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../matrix.dart';

/// Mutable horizontal concatenation of matrices.
class ConcatHorizontalMatrix<T> extends Matrix<T> {
  final List<Matrix<T>> _matrices;
  final List<int> _indexes;

  ConcatHorizontalMatrix(DataType<T> dataType, Iterable<Matrix<T>> matrices)
      : this._withList(dataType, matrices.toList(growable: false));

  ConcatHorizontalMatrix._withList(
      DataType<T> dataType, List<Matrix<T>> matrices)
      : this._withListAndIndexes(dataType, matrices, computeIndexes(matrices));

  ConcatHorizontalMatrix._withListAndIndexes(
      this.dataType, this._matrices, this._indexes);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _matrices.first.rowCount;

  @override
  int get colCount => _indexes.last;

  @override
  Set<Tensor> get storage => {..._matrices};

  @override
  Matrix<T> copy() => ConcatHorizontalMatrix._withListAndIndexes(
      dataType,
      _matrices.map((vector) => vector.copy()).toList(growable: false),
      _indexes);

  @override
  T getUnchecked(int row, int col) {
    var matrixIndex = binarySearch(_indexes, 0, _indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    return _matrices[matrixIndex]
        .getUnchecked(row, col - _indexes[matrixIndex]);
  }

  @override
  void setUnchecked(int row, int col, T value) {
    var matrixIndex = binarySearch(_indexes, 0, _indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    _matrices[matrixIndex]
        .setUnchecked(row, col - _indexes[matrixIndex], value);
  }
}

List<int> computeIndexes(List<Matrix> matrices) {
  final indexes = indexDataType.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].colCount;
  }
  return indexes;
}
