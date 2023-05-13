import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable transposed view of a matrix.
class TransposedMatrix<T> with Matrix<T> {
  TransposedMatrix(this.matrix);

  final Matrix<T> matrix;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get rowCount => matrix.colCount;

  @override
  int get colCount => matrix.rowCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) => matrix.getUnchecked(col, row);

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(col, row, value);
}

extension TransposedMatrixExtension<T> on Matrix<T> {
  /// Returns a mutable view onto the transposed matrix.
  Matrix<T> get transposed => switch (this) {
        TransposedMatrix<T>(matrix: final matrix) => matrix,
        _ => TransposedMatrix<T>(this),
      };
}
