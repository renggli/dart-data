import '../../../type.dart';
import '../../shared/storage.dart';
import '../polynomial.dart';

/// Differentiate modifiable view of a polynomial.
class DifferentiatePolynomial<T> with Polynomial<T> {
  final Polynomial<T> polynomial;

  DifferentiatePolynomial(this.polynomial);

  @override
  DataType<T> get dataType => polynomial.dataType;

  @override
  int get degree => polynomial.degree <= 0 ? -1 : polynomial.degree - 1;

  @override
  Set<Storage> get storage => polynomial.storage;

  @override
  Polynomial<T> copy() => DifferentiatePolynomial(polynomial.copy());

  @override
  T getUnchecked(int exponent) => dataType.field.mul(
        polynomial.getUnchecked(exponent + 1),
        dataType.cast(exponent + 1),
      );

  @override
  void setUnchecked(int exponent, T value) {
    polynomial.setUnchecked(
      exponent + 1,
      dataType.field.div(
        value,
        dataType.cast(exponent + 1),
      ),
    );
  }
}

extension DifferentiatePolynomialExtension<T> on Polynomial<T> {
  /// Returns a mutable view of the differentiate of this polynomial.
  Polynomial<T> get differentiate => DifferentiatePolynomial<T>(this);
}
