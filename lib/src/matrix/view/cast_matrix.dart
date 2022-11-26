import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable matrix cast to a new type.
class CastMatrix<S, T> with Matrix<T> {
  CastMatrix(this.matrix, this.dataType);

  final Matrix<S> matrix;

  @override
  final DataType<T> dataType;

  @override
  int get rowCount => matrix.rowCount;

  @override
  int get columnCount => matrix.columnCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int row, int col) =>
      dataType.cast(matrix.getUnchecked(row, col));

  @override
  void setUnchecked(int row, int col, T value) =>
      matrix.setUnchecked(row, col, matrix.dataType.cast(value));
}

extension CastMatrixExtension<T> on Matrix<T> {
  /// Returns a [Matrix] with the elements cast to [dataType].
  Matrix<S> cast<S>(DataType<S> dataType) => CastMatrix<T, S>(this, dataType);
}
