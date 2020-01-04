library data.matrix.view.flipped_horizontal;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable matrix flipped on its horizontal axis.
class FlippedHorizontalMatrix<T> with Matrix<T> {
  final Matrix<T> matrix;

  FlippedHorizontalMatrix(this.matrix);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get columnCount => matrix.columnCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  Matrix<T> copy() => FlippedHorizontalMatrix(matrix.copy());

  @override
  T getUnchecked(int row, int col) =>
      matrix.getUnchecked(matrix.rowCount - row - 1, col);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(matrix.rowCount - row - 1, col, value);
}

extension FlippedHorizontalMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the horizontally flipped matrix.
  Matrix<T> get flippedHorizontal => _flippedHorizontal(this);

  // TODO(renggli): https://github.com/dart-lang/sdk/issues/39959
  static Matrix<T> _flippedHorizontal<T>(Matrix<T> self) =>
      self is FlippedHorizontalMatrix<T>
          ? self.matrix
          : FlippedHorizontalMatrix<T>(self);
}
