library data.polynomial.operator.mul;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension MulExtension<T> on Polynomial<T> {
  /// Multiplies this [Polynomial] with [other].
  Polynomial<T> mul(/* Polynomial<T>|T */ Object other,
      {DataType<T> dataType, PolynomialFormat format}) {
    if (other is Polynomial<T>) {
      return mulPolynomial(other, dataType: dataType, format: format);
    } else if (other is T) {
      return mulScalar(other, dataType: dataType, format: format);
    } else {
      throw ArgumentError.value(other, 'other', 'Invalid multiplication.');
    }
  }

  /// Multiplies this [Polynomial] with [other].
  Polynomial<T> operator *(/* Polynomial<T>|T */ Object other) => mul(other);

  /// Multiplies this [Polynomial] with a [Polynomial].
  Polynomial<T> mulPolynomial(Polynomial<T> other,
      {DataType<T> dataType, PolynomialFormat format}) {
    if (degree < 0 || other.degree < 0) {
      // One of the polynomials has zero coefficients.
      return createPolynomial<T>(this, 0, dataType, format);
    }
    final result =
        createPolynomial<T>(this, degree + other.degree, dataType, format);
    final add = result.dataType.field.add, mul = result.dataType.field.mul;
    if (degree == 0) {
      // First polynomial is constant.
      final factor = getUnchecked(0);
      for (var i = other.degree; i >= 0; i--) {
        result.setUnchecked(i, mul(factor, other.getUnchecked(i)));
      }
    } else if (other.degree == 0) {
      // Second polynomial is constant.
      final factor = other.getUnchecked(0);
      for (var i = degree; i >= 0; i--) {
        result.setUnchecked(i, mul(getUnchecked(i), factor));
      }
      return result;
    } else {
      // Churn through full multiplication.
      for (var a = degree; a >= 0; a--) {
        for (var b = other.degree; b >= 0; b--) {
          result.setUnchecked(
              a + b,
              add(result.getUnchecked(a + b),
                  mul(getUnchecked(a), other.getUnchecked(b))));
        }
      }
    }
    return result;
  }

  /// Multiplies this [Polynomial] with a scalar.
  Polynomial<T> mulScalar(T other,
      {DataType<T> dataType, PolynomialFormat format}) {
    final result = createPolynomial<T>(this, degree, dataType, format);
    final mul = result.dataType.field.mul;
    unaryOperator<T>(result, this, (a) => mul(a, other));
    return result;
  }
}
