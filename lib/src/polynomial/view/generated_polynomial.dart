library data.polynomial.view.generated;

import '../../../type.dart';
import '../mixins/unmodifiable_polynomial.dart';
import '../polynomial.dart';

/// Read-only polynomial generated from a callback.
class GeneratedPolynomial<T> extends Polynomial<T>
    with UnmodifiablePolynomialMixin<T> {
  final T Function(int exponent) _callback;

  GeneratedPolynomial(this.dataType, this.degree, this._callback);

  @override
  final DataType<T> dataType;

  @override
  final int degree;

  @override
  Polynomial<T> copy() => this;

  @override
  T getUnchecked(int exponent) =>
      exponent <= degree ? _callback(exponent) : zeroCoefficient;
}
