import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// A matrix built from nested row arrays.
class NestedRowMatrix<T> with Matrix<T> {
  NestedRowMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(
            dataType,
            rowCount,
            colCount,
            List<List<T>>.generate(
                rowCount, (index) => dataType.newList(colCount),
                growable: false));

  NestedRowMatrix._(this.dataType, this.rowCount, this.columnCount, this._rows);

  List<List<T>> _rows;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => _rows[row][col];

  @override
  void setUnchecked(int row, int col, T value) => _rows[row][col] = value;
}
