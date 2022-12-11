import '../../../type.dart';
import '../../shared/lists.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable vertical concatenation of matrices.
class ConcatVerticalMatrix<T> with Matrix<T> {
  ConcatVerticalMatrix(this.dataType, this.matrices)
      : indexes = computeIndexes(matrices);

  final List<Matrix<T>> matrices;
  final List<int> indexes;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => indexes.last;

  @override
  int get colCount => matrices.first.colCount;

  @override
  Set<Storage> get storage =>
      matrices.expand((matrix) => matrix.storage).toSet();

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

List<int> computeIndexes<T>(List<Matrix<T>> matrices) {
  final indexes = DataType.indexDataType.newList(matrices.length + 1);
  for (var i = 0; i < matrices.length; i++) {
    indexes[i + 1] = indexes[i] + matrices[i].rowCount;
  }
  return indexes;
}
