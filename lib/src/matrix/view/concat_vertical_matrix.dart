import '../../../type.dart';
import '../../shared/config.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable vertical concatenation of matrices.
class ConcatVerticalMatrix<T> with Matrix<T> {
  final List<Matrix<T>> matrices;
  final List<int> indexes;

  ConcatVerticalMatrix(DataType<T> dataType, Iterable<Matrix<T>> matrices)
      : this._withList(dataType, matrices.toList(growable: false));

  ConcatVerticalMatrix._withList(DataType<T> dataType, List<Matrix<T>> matrices)
      : this._withListAndIndexes(dataType, matrices, computeIndexes(matrices));

  ConcatVerticalMatrix._withListAndIndexes(
      this.dataType, this.matrices, this.indexes);

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => indexes.last;

  @override
  int get columnCount => matrices.first.columnCount;

  @override
  Set<Storage> get storage =>
      matrices.expand((matrix) => matrix.storage).toSet();

  @override
  Matrix<T> copy() => ConcatVerticalMatrix._withListAndIndexes(dataType,
      matrices.map((vector) => vector.copy()).toList(growable: false), indexes);

  @override
  T getUnchecked(int row, int col) {
    var matrixIndex = binarySearch<num>(indexes, 0, indexes.length, row);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    return matrices[matrixIndex].getUnchecked(row - indexes[matrixIndex], col);
  }

  @override
  void setUnchecked(int row, int col, T value) {
    var matrixIndex = binarySearch<num>(indexes, 0, indexes.length, row);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    matrices[matrixIndex].setUnchecked(row - indexes[matrixIndex], col, value);
  }
}

List<int> computeIndexes(List<Matrix> matrices) {
  final indexes = indexDataType.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].rowCount;
  }
  return indexes;
}
