import 'dart:math' as math;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension AddExtension<T> on Polynomial<T> {
  /// Adds [other] to this [Polynomial].
  Polynomial<T> add(Polynomial<T> other,
      {DataType<T>? dataType, PolynomialFormat? format}) {
    final result = createPolynomial<T>(
        this, math.max(degree, other.degree), dataType, format);
    binaryOperator<T>(result, this, other, result.dataType.field.add);
    return result;
  }

  /// Adds [other] to this [Polynomial].
  Polynomial<T> operator +(Polynomial<T> other) => add(other);
}
