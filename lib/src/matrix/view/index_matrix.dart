library data.matrix.view.index_matrix;

import 'package:data/src/type/type.dart';

import '../../shared/config.dart';
import '../matrix.dart';

/// A mutable indexed view of the rows and columns of a matrix.
class IndexMatrix<T> extends Matrix<T> {
  final Matrix<T> _matrix;
  final List<int> _rowIndexes;
  final List<int> _colIndexes;

  IndexMatrix(this._matrix, Iterable<int> rowIndexes, Iterable<int> colIndexes)
      : _rowIndexes = indexDataType.copyList(rowIndexes),
        _colIndexes = indexDataType.copyList(colIndexes);

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

  @override
  Matrix<T> indexUnchecked(
          Iterable<int> rowIndexes, Iterable<int> colIndexes) =>
      IndexMatrix<T>(_matrix, rowIndexes.map((index) => _rowIndexes[index]),
          colIndexes.map((index) => _colIndexes[index]));
}
