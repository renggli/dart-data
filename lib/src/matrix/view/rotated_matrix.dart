import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable matrix rotated clockwise by multiples of 90 degrees.
class RotatedMatrix<T> with Matrix<T> {
  RotatedMatrix(this.matrix, this.count);

  final Matrix<T> matrix;
  final int count;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => count.isEven ? matrix.rowCount : matrix.columnCount;

  @override
  int get columnCount => count.isEven ? matrix.columnCount : matrix.rowCount;

  @override
  T getUnchecked(int row, int col) {
    switch (count) {
      case 1:
        return matrix.getUnchecked(matrix.rowCount - col - 1, row);
      case 2:
        return matrix.getUnchecked(
            matrix.rowCount - row - 1, matrix.columnCount - col - 1);
      case 3:
        return matrix.getUnchecked(col, matrix.columnCount - row - 1);
    }
    throw ArgumentError('Invalid rotation: ${90 * count}');
  }

  @override
  void setUnchecked(int row, int col, T value) {
    switch (count) {
      case 1:
        return matrix.setUnchecked(matrix.rowCount - col - 1, row, value);
      case 2:
        return matrix.setUnchecked(
            matrix.rowCount - row - 1, matrix.columnCount - col - 1, value);
      case 3:
        return matrix.setUnchecked(col, matrix.columnCount - row - 1, value);
    }
    throw ArgumentError('Invalid rotation: ${90 * count}');
  }

  @override
  Set<Storage> get storage => matrix.storage;
}

extension RotatedMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the matrix rotated clockwise by multiples
  /// of 90 degrees.
  Matrix<T> rotated({int count = 1}) => _rotated(this, count);

  // TODO(renggli): https://github.com/dart-lang/sdk/issues/39959
  static Matrix<T> _rotated<T>(Matrix<T> self, int count) {
    if (self is RotatedMatrix<T>) {
      count += self.count;
      self = self.matrix;
    }
    count = count % 4;
    return count == 0 ? self : RotatedMatrix(self, count);
  }
}
