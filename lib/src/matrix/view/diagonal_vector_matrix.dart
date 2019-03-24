library data.matrix.view.diagonal_vector;

import 'package:data/src/matrix/matrix.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart';

/// Mutable diagonal matrix of a vector.
class DiagonalVectorMatrix<T> extends Matrix<T> {
  final Vector<T> _vector;

  DiagonalVectorMatrix(this._vector);

  @override
  DataType<T> get dataType => _vector.dataType;

  @override
  int get rowCount => _vector.count;

  @override
  int get colCount => _vector.count;

  @override
  Set<Tensor> get storage => _vector.storage;

  @override
  Matrix<T> copy() => DiagonalVectorMatrix(_vector.copy());

  @override
  T getUnchecked(int row, int col) =>
      row == col ? _vector.getUnchecked(row) : dataType.nullValue;

  @override
  void setUnchecked(int row, int col, T value) {
    if (row == col) {
      _vector.setUnchecked(row, value);
    } else {
      throw ArgumentError('Row $row and column $col do not match.');
    }
  }
}
