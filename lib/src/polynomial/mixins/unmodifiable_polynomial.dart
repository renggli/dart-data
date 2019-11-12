library data.polynomial.mixins.unmodifiable;

import '../polynomial.dart';

/// Mixin for unmodifiable polynomials.
mixin UnmodifiablePolynomialMixin<T> implements Polynomial<T> {
  @override
  Polynomial<T> get unmodifiable => this;

  @override
  void setUnchecked(int exponent, T value) =>
      throw UnsupportedError('Polynomial is not mutable.');
}
