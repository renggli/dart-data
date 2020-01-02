library data.matrix.view.column;

import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable column vector of a matrix.
class ColumnVector<T> extends Vector<T> {
  final Matrix<T> matrix;
  final int columnIndex;

  ColumnVector(this.matrix, this.columnIndex);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get count => matrix.rowCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  Vector<T> copy() => ColumnVector(matrix.copy(), columnIndex);

  @override
  T getUnchecked(int index) => matrix.getUnchecked(index, columnIndex);

  @override
  void setUnchecked(int index, T value) =>
      matrix.setUnchecked(index, columnIndex, value);
}

extension ColumnVectorExtension<T> on Matrix<T> {
  /// Returns a mutable column [Vector] of this [Matrix]. Throws a [RangeError],
  /// if [index] is out of bounds.
  Vector<T> column(int index) {
    RangeError.checkValidIndex(index, this, 'col', columnCount);
    return columnUnchecked(index);
  }

  /// Returns an iterable over the columns of this [Matrix].
  Iterable<Vector<T>> get columns sync* {
    for (var c = 0; c < columnCount; c++) {
      yield columnUnchecked(c);
    }
  }

  /// Returns a mutable column [Vector] of this [Matrix]. The behavior is
  /// undefined, if [index] is out of bounds. An offset of `0` refers to the
  /// diagonal in the center of the matrix, a negative offset to the diagonals
  /// above, a positive offset to the diagonals below.
  Vector<T> columnUnchecked(int index) => ColumnVector<T>(this, index);
}
