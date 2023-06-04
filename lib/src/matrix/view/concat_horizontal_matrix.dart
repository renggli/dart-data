import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable horizontal concatenation of matrices.
class ConcatHorizontalMatrix<T> with Matrix<T> {
  ConcatHorizontalMatrix(this.dataType, this.matrices)
      : indexes = computeIndexes(matrices);

  final List<Matrix<T>> matrices;
  final List<int> indexes;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => matrices.first.rowCount;

  @override
  int get colCount => indexes.last;

  @override
  Set<Storage> get storage =>
      matrices.expand((matrix) => matrix.storage).toSet();

  @override
  T getUnchecked(int row, int col) {
    var matrixIndex = binarySearch<num>(indexes, 0, indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    return matrices[matrixIndex].getUnchecked(row, col - indexes[matrixIndex]);
  }

  @override
  void setUnchecked(int row, int col, T value) {
    var matrixIndex = binarySearch<num>(indexes, 0, indexes.length, col);
    if (matrixIndex < 0) {
      matrixIndex = -matrixIndex - 2;
    }
    matrices[matrixIndex].setUnchecked(row, col - indexes[matrixIndex], value);
  }
}

List<int> computeIndexes<T>(List<Matrix<T>> matrices) {
  final indexes = DataType.index.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].colCount;
  }
  return indexes;
}
