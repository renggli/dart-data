import 'dart:math' as math;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Shifts the polynomial by a given offset.
class ShiftPolynomial<T> with Polynomial<T> {
  ShiftPolynomial(this.polynomial, this.offset);

  final Polynomial<T> polynomial;
  final int offset;

  @override
  DataType<T> get dataType => polynomial.dataType;

  @override
  int get degree {
    final degree = polynomial.degree;
    if (degree >= 0) {
      return math.max(degree + offset, -1);
    }
    return -1;
  }

  @override
  Set<Storage> get storage => polynomial.storage;

  @override
  T getUnchecked(int exponent) {
    final index = exponent - offset;
    if (index >= 0) {
      return polynomial.getUnchecked(index);
    }
    return dataType.field.additiveIdentity;
  }

  @override
  void setUnchecked(int exponent, T value) {
    final index = exponent - offset;
    if (index >= 0) {
      polynomial.setUnchecked(index, value);
    }
  }
}

extension ShiftPolynomialExtension<T> on Polynomial<T> {
  /// Returns a mutable view of this polynomial shift by [offset].
  Polynomial<T> shift(int offset) {
    var self = this;
    if (self is ShiftPolynomial<T>) {
      offset += self.offset;
      self = self.polynomial;
    }
    return offset == 0 ? self : ShiftPolynomial<T>(self, offset);
  }
}
