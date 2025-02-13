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
  int get rowCount => count.isEven ? matrix.rowCount : matrix.colCount;

  @override
  int get colCount => count.isEven ? matrix.colCount : matrix.rowCount;

  @override
  T getUnchecked(int row, int col) => switch (count) {
    1 => matrix.getUnchecked(matrix.rowCount - col - 1, row),
    2 => matrix.getUnchecked(
      matrix.rowCount - row - 1,
      matrix.colCount - col - 1,
    ),
    3 => matrix.getUnchecked(col, matrix.colCount - row - 1),
    _ => throw ArgumentError('Invalid rotation: ${90 * count}'),
  };

  @override
  void setUnchecked(int row, int col, T value) => switch (count) {
    1 => matrix.setUnchecked(matrix.rowCount - col - 1, row, value),
    2 => matrix.setUnchecked(
      matrix.rowCount - row - 1,
      matrix.colCount - col - 1,
      value,
    ),
    3 => matrix.setUnchecked(col, matrix.colCount - row - 1, value),
    _ => throw ArgumentError('Invalid rotation: ${90 * count}'),
  };

  @override
  Set<Storage> get storage => matrix.storage;
}

extension RotatedMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the matrix rotated clockwise by multiples
  /// of 90 degrees.
  Matrix<T> rotated({int count = 1}) {
    var self = this;
    if (self is RotatedMatrix<T>) {
      count += self.count;
      self = self.matrix;
    }
    count = count % 4;
    return count == 0 ? self : RotatedMatrix(self, count);
  }
}
