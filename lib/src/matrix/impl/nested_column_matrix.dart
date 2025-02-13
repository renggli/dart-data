import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// A matrix built from nested column arrays.
class NestedColumnMatrix<T> with Matrix<T> {
  NestedColumnMatrix(this.dataType, this.rowCount, this.colCount)
    : _columns = List<List<T>>.generate(
        colCount,
        (index) => dataType.newList(rowCount),
        growable: false,
      );

  NestedColumnMatrix.fromList(
    this.dataType,
    this.rowCount,
    this.colCount,
    this._columns,
  ) : assert(_columns.length == colCount, 'Invalid column count'),
      assert(
        _columns.every((col) => col.length == rowCount),
        'Invalid row count',
      );

  final List<List<T>> _columns;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => _columns[col][row];

  @override
  void setUnchecked(int row, int col, T value) => _columns[col][row] = value;
}
