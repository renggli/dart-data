import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable row vector of a matrix.
class RowVector<T> with Vector<T> {
  RowVector(this.matrix, this.row);

  final Matrix<T> matrix;
  final int row;

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  int get count => matrix.columnCount;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  T getUnchecked(int index) => matrix.getUnchecked(row, index);

  @override
  void setUnchecked(int index, T value) =>
      matrix.setUnchecked(row, index, value);
}

extension RowVectorExtension<T> on Matrix<T> {
  /// Returns a mutable row vector of this matrix. Throws a [RangeError], if
  /// [row] is out of bounds.
  Vector<T> row(int row) {
    RangeError.checkValidIndex(row, this, 'row', rowCount);
    return rowUnchecked(row);
  }

  /// Returns an iterable over the rows of this matrix.
  Iterable<Vector<T>> get rows sync* {
    for (var r = 0; r < rowCount; r++) {
      yield rowUnchecked(r);
    }
  }

  /// Returns a mutable row vector of this matrix. The behavior is undefined,
  /// if [row] is out of bounds.
  Vector<T> rowUnchecked(int row) => RowVector<T>(this, row);
}
