import '../../../type.dart';
import '../../../vector.dart';
import '../../matrix/matrix.dart';
import '../../shared/storage.dart';

/// Mutable row matrix of a vector.
class RowMatrix<T> with Matrix<T> {
  final Vector<T> vector;

  RowMatrix(this.vector);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get rowCount => 1;

  @override
  int get columnCount => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  Matrix<T> copy() => RowMatrix<T>(vector.copy());

  @override
  T getUnchecked(int row, int col) => vector.getUnchecked(col);

  @override
  void setUnchecked(int row, int col, T value) =>
      vector.setUnchecked(col, value);
}

extension RowMatrixExtension<T> on Vector<T> {
  /// Returns a [Matrix] with this [Vector] as its single row.
  Matrix<T> get rowMatrix => RowMatrix<T>(this);
}
