import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable horizontal concatenation of matrices.
class ConcatHorizontalMatrix<T> with Matrix<T> {
  final List<Matrix<T>> matrices;
  final List<int> indexes;

  ConcatHorizontalMatrix(DataType<T> dataType, Iterable<Matrix<T>> matrices)
      : this._withList(dataType, matrices.toList(growable: false));

  ConcatHorizontalMatrix._withList(
      DataType<T> dataType, List<Matrix<T>> matrices)
      : this._withListAndIndexes(dataType, matrices, computeIndexes(matrices));

  ConcatHorizontalMatrix._withListAndIndexes(
      this.dataType, this.matrices, this.indexes);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => matrices.first.rowCount;

  @override
  int get columnCount => indexes.last;

  @override
  Set<Storage> get storage =>
      matrices.expand((matrix) => matrix.storage).toSet();

  @override
  Matrix<T> copy() => ConcatHorizontalMatrix._withListAndIndexes(dataType,
      matrices.map((vector) => vector.copy()).toList(growable: false), indexes);

  @override
  T getUnchecked(int row, int col) {
    var matrixIndex = binarySearch(indexes, 0, indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    return matrices[matrixIndex].getUnchecked(row, col - indexes[matrixIndex]);
  }

  @override
  void setUnchecked(int row, int col, T value) {
    var matrixIndex = binarySearch(indexes, 0, indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    matrices[matrixIndex].setUnchecked(row, col - indexes[matrixIndex], value);
  }
}

List<int> computeIndexes(List<Matrix> matrices) {
  final indexes = indexDataType.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].columnCount;
  }
  return indexes;
}
