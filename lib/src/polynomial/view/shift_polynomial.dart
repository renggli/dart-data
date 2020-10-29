import 'dart:math' as math;

import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Shifts the polynomial by a given offset.
class ShiftPolynomial<T> with Polynomial<T> {
  final Polynomial<T> polynomial;
  final int offset;

  ShiftPolynomial(this.polynomial, this.offset);

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
  Polynomial<T> copy() => ShiftPolynomial(polynomial.copy(), offset);

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

extension ShiftExtension<T> on Polynomial<T> {
  /// Returns a mutable view of this polynomial shift by [offset].
  Polynomial<T> shift(int offset) => offset == 0 ? this : _shift(this, offset);

  // TODO(renggli): https://github.com/dart-lang/sdk/issues/39959
  static Polynomial<T> _shift<T>(Polynomial<T> self, int offset) {
    final polynomial = self is ShiftPolynomial<T> ? self.polynomial : self;
    final effective =
        self is ShiftPolynomial<T> ? self.offset + offset : offset;
    return effective == 0
        ? polynomial
        : ShiftPolynomial<T>(polynomial, effective);
  }
}
