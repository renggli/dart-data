library data.polynomial.mixin.unmodifiable;

import '../polynomial.dart';

/// Mixin for unmodifiable polynomials.
mixin UnmodifiablePolynomialMixin<T> implements Polynomial<T> {
  @override
  void setUnchecked(int exponent, T value) =>
      throw UnsupportedError('Polynomial is not mutable.');
}
