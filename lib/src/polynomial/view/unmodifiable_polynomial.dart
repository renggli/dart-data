library data.polynomial.view.unmodifiable;

import 'package:data/src/polynomial/mixins/unmodifiable_polynomial.dart';
import 'package:data/src/polynomial/polynomial.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';

/// Read-only view of a mutable polynomial.
class UnmodifiablePolynomial<T> extends Polynomial<T>
    with UnmodifiablePolynomialMixin<T> {
  final Polynomial<T> _polynomial;

  UnmodifiablePolynomial(this._polynomial);

  @override
  DataType<T> get dataType => _polynomial.dataType;

  @override
  int get degree => _polynomial.degree;

  @override
  Set<Tensor> get storage => _polynomial.storage;

  @override
  Polynomial<T> copy() => UnmodifiablePolynomial(_polynomial.copy());

  @override
  T getUnchecked(int exponent) => _polynomial.getUnchecked(exponent);
}
