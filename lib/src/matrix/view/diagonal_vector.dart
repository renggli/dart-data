import 'dart:math' as math;

import '../../../type.dart';
import '../../../vector.dart';
import '../../shared/storage.dart';
import '../matrix.dart';

/// Mutable diagonal vector of a matrix.
class DiagonalVector<T> with Vector<T> {
  final Matrix<T> matrix;
  final int offset;

  DiagonalVector(Matrix<T> matrix, int offset)
      : this._(
            matrix,
            offset,
            math.min(
              matrix.rowCount - offset,
              matrix.columnCount + offset,
            ));

  DiagonalVector._(this.matrix, this.offset, this.count);

  @override
  DataType<T> get dataType => matrix.dataType;

  @override
  final int count;

  @override
  Set<Storage> get storage => matrix.storage;

  @override
  Vector<T> copy() => DiagonalVector<T>._(matrix.copy(), offset, count);

  @override
  T getUnchecked(int index) {
    if (offset < 0) {
      return matrix.getUnchecked(index, index - offset);
    } else {
      return matrix.getUnchecked(index + offset, index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    if (offset < 0) {
      matrix.setUnchecked(index, index - offset, value);
    } else {
      matrix.setUnchecked(index + offset, index, value);
    }
  }
}

extension DiagonalVectorExtension<T> on Matrix<T> {
  /// Returns a mutable diagonal [Vector] of this [Matrix]. Throws a
  /// [RangeError], if [offset] is out of bounds. An offset of `0` refers to the
  /// diagonal in the center of the matrix, a negative offset to the diagonals
  /// above, and a positive offset to the diagonals below.
  Vector<T> diagonal([int offset = 0]) {
    RangeError.checkValueInInterval(
        offset, -columnCount + 1, rowCount - 1, 'offset');
    return diagonalUnchecked(offset);
  }

  /// Returns an iterable over the diagonals of this [Matrix].
  Iterable<Vector<T>> get diagonals sync* {
    for (var d = -columnCount + 1; d < rowCount; d++) {
      yield diagonalUnchecked(d);
    }
  }

  /// Returns a mutable diagonal [Vector] of this [Matrix]. The behavior is
  /// undefined, if [offset] is out of bounds. An offset of `0` refers to the
  /// diagonal in the center of the matrix, a negative offset to the diagonals
  /// above, and a positive offset to the diagonals below.
  Vector<T> diagonalUnchecked([int offset = 0]) =>
      DiagonalVector<T>(this, offset);
}
