library data.matrix.view.diagonal_vector;

import 'dart:math' as math;

import 'package:data/type.dart';
import 'package:data/vector.dart';

import '../matrix.dart';

/// A mutable vector of a diagonal of a matrix.
class DiagonalVector<T> extends Vector<T> {
  final Matrix<T> _matrix;
  final int _offset;
  final int _count;

  DiagonalVector(this._matrix, this._offset)
      : _count = math.min(
          _matrix.rowCount - _offset,
          _matrix.colCount + _offset,
        ) {
    RangeError.checkValueInInterval(
        _offset, -_matrix.colCount + 1, _matrix.rowCount - 1);
  }

  @override
  DataType<T> get dataType => _matrix.dataType;

  @override
  int get count => _count;

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
