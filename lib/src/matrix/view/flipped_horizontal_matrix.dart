import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable matrix flipped on its horizontal axis.
class FlippedHorizontalMatrix<T> with Matrix<T> {
  FlippedHorizontalMatrix(this.matrix);

  final Matrix<T> matrix;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get colCount => matrix.colCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(matrix.rowCount - row - 1, col);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(matrix.rowCount - row - 1, col, value);
}

extension FlippedHorizontalMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the horizontally flipped matrix.
  Matrix<T> get flippedHorizontal => switch (this) {
        FlippedHorizontalMatrix<T>(matrix: final matrix) => matrix,
        _ => FlippedHorizontalMatrix<T>(this),
      };
}
