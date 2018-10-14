library data.matrix.impl.keyed_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// Dictionary of keys based sparse matrix (DOK).
class KeyedMatrix<T> extends Matrix<T> {
  final Map<int, T> _values;

  KeyedMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.internal(dataType, rowCount, colCount, <int, T>{});

  KeyedMatrix.internal(
      this.dataType, this.rowCount, this.colCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Matrix<T> get base => this;

  @override
  Matrix<T> copy() =>
      KeyedMatrix.internal(dataType, rowCount, colCount, Map.of(_values));

  @override
  T getUnchecked(int row, int col) =>
      _values[row * colCount + col] ?? dataType.nullValue;

  @override
  void setUnchecked(int row, int col, T value) {
    final index = row * colCount + col;
    if (value != dataType.nullValue) {
      _values[index] = value;
    } else {
      _values.remove(index);
    }
  }
}
