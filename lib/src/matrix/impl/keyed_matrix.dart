import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Sparse keyed matrix.
class KeyedMatrix<T> with Matrix<T> {
  final Map<int, T> _values;

  KeyedMatrix(DataType<T> dataType, int rowCount, int colCount)
      : this._(dataType, rowCount, colCount, <int, T>{});

  KeyedMatrix._(this.dataType, this.rowCount, this.columnCount, this._values);

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int columnCount;

  @override
  Set<Storage> get storage => {this};

  @override
  Matrix<T> copy() =>
      KeyedMatrix._(dataType, rowCount, columnCount, Map.of(_values));

  @override
  T getUnchecked(int row, int col) =>
      _values[row * columnCount + col] ?? dataType.defaultValue;

  @override
  void setUnchecked(int row, int col, T value) {
    final index = row * columnCount + col;
    if (value == dataType.defaultValue) {
      _values.remove(index);
    } else {
      _values[index] = value;
    }
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (final entry in _values.entries) {
      callback(entry.key ~/ columnCount, entry.key % columnCount, entry.value);
    }
  }
}
