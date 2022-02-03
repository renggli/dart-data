import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_polynomial.dart';
import '../polynomial.dart';

/// Read-only view of a mutable polynomial.
class UnmodifiablePolynomial<T>
    with Polynomial<T>, UnmodifiablePolynomialMixin<T> {
  UnmodifiablePolynomial(this.polynomial);

  final Polynomial<T> polynomial;

  @override
  DataType<T> get dataType => polynomial.dataType;

  @override
  int get degree => polynomial.degree;

  @override
  Set<Storage> get storage => polynomial.storage;

  @override
  Polynomial<T> copy() => UnmodifiablePolynomial(polynomial.copy());

  @override
  T getUnchecked(int exponent) => polynomial.getUnchecked(exponent);
}

extension UnmodifiablePolynomialExtension<T> on Polynomial<T> {
  /// Returns a unmodifiable view of this polynomial.
  Polynomial<T> get unmodifiable => this is UnmodifiablePolynomialMixin<T>
      ? this
      : UnmodifiablePolynomial<T>(this);
}
