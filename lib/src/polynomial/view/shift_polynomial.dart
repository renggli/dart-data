library data.polynomial.view.shift;

import 'dart:math' as math;

import '../../../tensor.dart';
import '../../../type.dart';
import '../polynomial.dart';

/// Shifts the polynomial by a given offset.
class ShiftPolynomial<T> extends Polynomial<T> {
  final Polynomial<T> _polynomial;
  final int _offset;

  ShiftPolynomial(this._polynomial, this._offset);

  @override
  DataType<T> get dataType => _polynomial.dataType;

  @override
  int get degree {
    final degree = _polynomial.degree;
    if (degree >= 0) {
      return math.max(degree + _offset, -1);
    }
    return -1;
  }

  @override
  Set<Tensor> get storage => _polynomial.storage;

  @override
  Polynomial<T> copy() => ShiftPolynomial(_polynomial.copy(), _offset);

  @override
  Polynomial<T> shift(int offset) => _polynomial.shift(_offset + offset);

  @override
  T getUnchecked(int exponent) {
    final index = exponent - _offset;
    if (index >= 0) {
      return _polynomial.getUnchecked(index);
    }
    return zeroCoefficient;
  }

  @override
  void setUnchecked(int exponent, T value) {
    final index = exponent - _offset;
    if (index >= 0) {
      _polynomial.setUnchecked(index, value);
    }
  }
}
