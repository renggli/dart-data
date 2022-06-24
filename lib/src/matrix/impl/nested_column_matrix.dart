import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// A matrix built from nested column arrays.
class NestedColumnMatrix<T> with Matrix<T> {
  NestedColumnMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            List<List<T>>.generate(
                colCount, (index) => dataType.newList(rowCount),
                growable: false));

  NestedColumnMatrix._(
      this.dataType, this.rowCount, this.columnCount, this._cols);

  List<List<T>> _cols;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() => NestedColumnMatrix._(
      dataType,
      rowCount,
      columnCount,
      List<List<T>>.generate(
          columnCount, (index) => dataType.copyList(_cols[index]),
          growable: false));

  @override
  T getUnchecked(int row, int col) => _cols[col][row];

  @override
  void setUnchecked(int row, int col, T value) => _cols[col][row] = value;
}
