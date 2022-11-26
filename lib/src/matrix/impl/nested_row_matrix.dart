import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// A matrix built from nested row arrays.
class NestedRowMatrix<T> with Matrix<T> {
  NestedRowMatrix(this.dataType, this.rowCount, this.columnCount)
      : _rows = List<List<T>>.generate(
            rowCount, (index) => dataType.newList(columnCount),
            growable: false);

  final List<List<T>> _rows;

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
