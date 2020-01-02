library data.vector.view.diagonal;

import '../../../tensor.dart';
import '../../../type.dart';
import '../../../vector.dart';
import '../../matrix/matrix.dart';

/// Mutable diagonal matrix of a vector.
class DiagonalMatrix<T> extends Matrix<T> {
  final Vector<T> vector;

  DiagonalMatrix(this.vector);

  @override
  DataType<T> get dataType => vector.dataType;

  @override
  int get rowCount => vector.count;

  @override
  int get colCount => vector.count;

  @override
  Set<Tensor> get storage => vector.storage;

  @override
  Matrix<T> copy() => DiagonalMatrix(vector.copy());

  @override
  T getUnchecked(int row, int col) =>
      row == col ? vector.getUnchecked(row) : dataType.nullValue;

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
