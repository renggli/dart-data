library data.matrix.view.diagonal_vector;

import 'dart:math' as math;

import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart';

import '../matrix.dart';

/// Mutable diagonal vector of a matrix.
class DiagonalVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _offset;
  final int _count;

  DiagonalVector(Matrix<T> matrix, int offset)
      : this.internal(
            matrix,
            offset,
            math.min(
              matrix.rowCount - offset,
              matrix.colCount + offset,
            ));

  DiagonalVector.internal(this._matrix, this._offset, this._count);

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get count => _count;

  @override
  Set<Tensor> get storage => _matrix.storage;

  @override
  Vector<T> copy() => DiagonalVector.internal(_matrix.copy(), _offset, _count);

  @override
  T getUnchecked(int index) {
    if (_offset < 0) {
      return _matrix.getUnchecked(index, index - _offset);
    } else {
      return _matrix.getUnchecked(index + _offset, index);
    }
  }

  @override
  void setUnchecked(int index, T value) {
    if (_offset < 0) {
      _matrix.setUnchecked(index, index - _offset, value);
    } else {
      _matrix.setUnchecked(index + _offset, index, value);
    }
  }
}
