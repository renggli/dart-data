library data.matrix.view.index_matrix;

import 'package:data/src/type/type.dart';

import '../matrix.dart';

/// A mutable view onto indexes of another matrix.
class IndexMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;
  final List<int> _rowIndexes;
  final List<int> _colIndexes;

  IndexMatrix(this._matrix, this._rowIndexes, this._colIndexes);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get rowCount => _rowIndexes.length;

  @override
  int get colCount => _colIndexes.length;

  @override
  T getUnchecked(int row, int col) =>
      _matrix.getUnchecked(_rowIndexes[row], _colIndexes[col]);

  @override
  void setUnchecked(int row, int col, T value) =>
      _matrix.setUnchecked(_rowIndexes[row], _colIndexes[col], value);
}
