import 'dart:math' as math;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension AddPolynomialExtension<T> on Polynomial<T> {
  /// Adds [other] to this [Polynomial].
  Polynomial<T> add(
    Polynomial<T> other, {
    DataType<T>? dataType,
    PolynomialFormat? format,
  }) {
    final result = createPolynomial<T>(
      this,
      math.max(degree, other.degree),
      dataType,
      format,
    );
    binaryOperator<T>(result, this, other, result.dataType.field.add);
    return result;
  }

  /// In-place adds [other] to this [Polynomial].
  Polynomial<T> addEq(Polynomial<T> other) {
    binaryOperator<T>(this, this, other, dataType.field.add);
    return this;
  }

  /// Adds [other] to this [Polynomial].
  Polynomial<T> operator +(Polynomial<T> other) => add(other);
}
