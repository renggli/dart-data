library data.matrix.impl.row_major;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Row major matrix.
class RowMajorMatrix<T> with Matrix<T> {
  final List<T> _values;

  RowMajorMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this.fromList(dataType, rowCount, colCount,
            dataType.newList(rowCount * colCount));

  RowMajorMatrix.fromList(
      this.dataType, this.rowCount, this.columnCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => RowMajorMatrix.fromList(
      dataType, rowCount, columnCount, dataType.copyList(_values));

  @override
  T getUnchecked(int row, int col) => _values[row * columnCount + col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row * columnCount + col] = value;
}
