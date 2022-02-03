import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Integrate modifiable view of a polynomial.
class IntegratePolynomial<T> with Polynomial<T> {
  IntegratePolynomial(this.polynomial, [T? constant])
      : constant = constant ?? polynomial.dataType.field.additiveIdentity;

  final Polynomial<T> polynomial;
  T constant;

  @override
  DataType<T> get dataType => polynomial.dataType;

  @override
  int get degree => polynomial.degree < 0 ? -1 : polynomial.degree + 1;

  @override
  Set<Storage> get storage => polynomial.storage;

  @override
  Polynomial<T> copy() => IntegratePolynomial(polynomial.copy(), constant);

  @override
  T getUnchecked(int exponent) => exponent == 0
      ? constant
      : dataType.field.div(
          polynomial.getUnchecked(exponent - 1),
          dataType.cast(exponent),
        );

  @override
  void setUnchecked(int exponent, T value) {
    if (exponent == 0) {
      constant = value;
    } else {
      polynomial.setUnchecked(
        exponent - 1,
        dataType.field.mul(
          value,
          dataType.cast(exponent),
        ),
      );
    }
  }
}

extension IntegratePolynomialExtension<T> on Polynomial<T> {
  /// Returns a mutable view of the integrate of this polynomial.
  Polynomial<T> get integrate => IntegratePolynomial<T>(this);
}
