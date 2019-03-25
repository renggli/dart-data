library data.vector.view.vertical_concat;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/src/shared/config.dart';
import 'package:data/src/shared/lists.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Mutable vertical concatenation of matrices.
class VerticalConcatMatrix<T> extends Matrix<T> {
  final List<Matrix<T>> _matrices;
  final List<int> _indexes;

  VerticalConcatMatrix(DataType<T> dataType, Iterable<Matrix<T>> matrices)
      : this._withList(dataType, matrices.toList(growable: false));

  VerticalConcatMatrix._withList(DataType<T> dataType, List<Matrix<T>> matrices)
      : this._withListAndIndexes(dataType, matrices, computeIndexes(matrices));

  VerticalConcatMatrix._withListAndIndexes(
      this.dataType, this._matrices, this._indexes);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => _indexes.last;

  @override
  int get colCount => _matrices.first.colCount;

  @override
  Set<Tensor> get storage => Set.of(_matrices);

  @override
  Matrix<T> copy() => VerticalConcatMatrix._withListAndIndexes(
      dataType,
      _matrices.map((vector) => vector.copy()).toList(growable: false),
      _indexes);

  @override
  T getUnchecked(int row, int col) {
    var matrixIndex = binarySearch(_indexes, 0, _indexes.length, row);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    return _matrices[matrixIndex]
        .getUnchecked(row - _indexes[matrixIndex], col);
  }

  @override
  void setUnchecked(int row, int col, T value) {
    var matrixIndex = binarySearch(_indexes, 0, _indexes.length, row);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    _matrices[matrixIndex]
        .setUnchecked(row - _indexes[matrixIndex], col, value);
  }
}

List<int> computeIndexes(List<Matrix> matrices) {
  final indexes = indexDataType.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].rowCount;
  }
  return indexes;
}
