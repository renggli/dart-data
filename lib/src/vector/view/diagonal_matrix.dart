import '../../../type.dart';
import '../../../vector.dart';
import '../../matrix/matrix.dart';
import '../../shared/storage.dart';

/// Mutable diagonal matrix of a vector.
class DiagonalMatrix<T> with Matrix<T> {
  DiagonalMatrix(this.vector);

  final Vector<T> vector;

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get rowCount => vector.count;

  @override
  int get columnCount => vector.count;

  @override
  Set<Storage> get storage => vector.storage;

  @override
  T getUnchecked(int row, int col) =>
      row == col ? vector.getUnchecked(row) : dataType.defaultValue;

  @override
  void setUnchecked(int row, int col, T value) {
    if (row == col) {
      vector.setUnchecked(row, value);
    } else {
      throw ArgumentError('Row $row and column $col do not match.');
    }
  }
}

extension DiagonalMatrixExtension<T> on Vector<T> {
  /// Returns a square [Matrix] with this [Vector] as its diagonal.
  Matrix<T> get diagonalMatrix => DiagonalMatrix<T>(this);
}
