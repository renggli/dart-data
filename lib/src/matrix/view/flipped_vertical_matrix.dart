import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable matrix flipped on its vertical axis.
class FlippedVerticalMatrix<T> with Matrix<T> {
  FlippedVerticalMatrix(this.matrix);

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
      matrix.getUnchecked(row, matrix.colCount - col - 1);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(row, matrix.colCount - col - 1, value);
}

extension FlippedVerticalMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the vertically flipped matrix.
  Matrix<T> get flippedVertical => switch (this) {
        FlippedVerticalMatrix<T>(matrix: final matrix) => matrix,
        _ => FlippedVerticalMatrix<T>(this),
      };
}
