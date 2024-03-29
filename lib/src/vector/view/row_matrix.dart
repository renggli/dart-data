import '../../../type.dart';
import '../../../vector.dart';
import '../../matrix/matrix.dart';
import '../../shared/storage.dart';

/// Mutable row matrix of a vector.
class RowMatrix<T> with Matrix<T> {
  RowMatrix(this.vector);

  final Vector<T> vector;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get rowCount => 1;

  @override
  int get colCount => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

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
