import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension DivPolynomialExtension<T> on Polynomial<T> {
  /// Divides this [Polynomial] by [other], returns the quotient and remainder
  /// such that `dividend = quotient * divisor + remainder`.
  PolynomialDivision<T> div(Polynomial<T> other,
      {DataType<T>? dataType, PolynomialFormat? format}) {
    final dividend = this;
    final divisor = other;
    final dividendDegree = dividend.degree;
    final divisorDegree = divisor.degree;
    final effectiveDataType = dataType ?? this.dataType;
    final sub = effectiveDataType.field.sub;
    final mul = effectiveDataType.field.mul;
    final div = effectiveDataType.field.div;
    if (divisorDegree < 0) {
      // Divisor is zero.
      throw UnsupportedError('Division by zero polynomial.');
    } else if (dividendDegree < 0) {
      // Dividend is zero.
      return PolynomialDivision(
        quotient: createPolynomial<T>(this, 0, effectiveDataType, format),
        remainder: createPolynomial<T>(this, 0, effectiveDataType, format),
      );
    } else if (divisorDegree == 0) {
      // Divisor is constant.
      final scalar = divisor.getUnchecked(0);
      return PolynomialDivision<T>(
        quotient: Polynomial<T>.generate(effectiveDataType, dividendDegree,
            (i) => div(dividend.getUnchecked(i), scalar),
            format: format),
        remainder: Polynomial<T>(effectiveDataType, format: format),
      );
    } else if (dividendDegree < divisorDegree) {
      // Divisor degree higher than dividend.
      return PolynomialDivision<T>(
        quotient: Polynomial<T>(effectiveDataType, format: format),
        remainder: dividend.toPolynomial(format: format),
      );
    }
    // Perform synthetic division:
    // https://en.wikipedia.org/wiki/Synthetic_division
    final dividendLead = dividend.lead;
    final output = effectiveDataType.copyList(dividend.iterable);
    for (var i = dividendDegree - divisorDegree; i >= 0; i--) {
      final coefficient = output[i + 1] = div(output[i + 1], dividendLead);
      if (coefficient != effectiveDataType.defaultValue) {
        for (var j = divisorDegree - 1; j >= 0; j--) {
          output[i + j] =
              sub(output[i + j], mul(divisor.getUnchecked(j), coefficient));
        }
      }
    }
    return PolynomialDivision<T>(
      quotient: Polynomial<T>.fromList(
          effectiveDataType, output.sublist(divisorDegree),
          format: format),
      remainder: Polynomial<T>.fromList(
          effectiveDataType, output.sublist(0, divisorDegree),
          format: format),
    );
  }

  /// Divides this [Polynomial] by [other], returns the quotient and remainder
  /// such that `dividend = quotient * divisor + remainder`.
  PolynomialDivision<T> operator /(Polynomial<T> other) => div(other);

  /// Divides this [Polynomial] by [other], returns the quotient.
  Polynomial<T> operator ~/(Polynomial<T> other) => div(other).quotient;

  /// Divides this [Polynomial] by [other], returns the remainder.
  Polynomial<T> operator %(Polynomial<T> other) => div(other).remainder;
}

/// Data holder for the result of a polynomial division.
class PolynomialDivision<T> {
  PolynomialDivision({required this.quotient, required this.remainder});

  final Polynomial<T> quotient;
  final Polynomial<T> remainder;
}
