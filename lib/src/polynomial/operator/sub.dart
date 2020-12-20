import 'dart:math' as math;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension SubPolynomialExtension<T> on Polynomial<T> {
  /// Subs [other] to this [Polynomial].
  Polynomial<T> sub(Polynomial<T> other,
      {DataType<T>? dataType, PolynomialFormat? format}) {
    final result = createPolynomial<T>(
        this, math.max(degree, other.degree), dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.sub);
    return result;
  }

  /// Subs [other] to this [Polynomial].
  Polynomial<T> operator -(Polynomial<T> other) => sub(other);
}
