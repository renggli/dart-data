import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Row major matrix.
class RowMajorMatrix<T> with Matrix<T> {
  RowMajorMatrix(this.dataType, this.rowCount, this.colCount)
      : _values = dataType.newList(rowCount * colCount);

  final List<T> _values;

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) => _values[row * colCount + col];

  @override
  void setUnchecked(int row, int col, T value) =>
      _values[row * colCount + col] = value;
}
