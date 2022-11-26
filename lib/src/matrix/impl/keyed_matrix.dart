import '../../../type.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Sparse keyed matrix.
class KeyedMatrix<T> with Matrix<T> {
  KeyedMatrix(this.dataType, this.rowCount, this.colCount);

  final Map<int, T> _values = <int, T>{};

  @override
  final DataType<T> dataType;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  Set<Storage> get storage => {this};

  @override
  T getUnchecked(int row, int col) =>
      _values[row * colCount + col] ?? dataType.defaultValue;

  @override
  void setUnchecked(int row, int col, T value) {
    final index = row * colCount + col;
    if (value == dataType.defaultValue) {
      _values.remove(index);
    } else {
      _values[index] = value;
    }
  }

  @override
  void forEach(void Function(int row, int col, T value) callback) {
    for (final entry in _values.entries) {
      callback(entry.key ~/ colCount, entry.key % colCount, entry.value);
    }
  }
}
