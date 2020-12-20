import 'dart:math' as math;

import '../../../type.dart';
import '../polynomial.dart';
import '../polynomial_format.dart';
import 'utils.dart';

extension LerpPolynomialExtension<T> on Polynomial<T> {
  /// Interpolates linearly between this [Polynomial] and [other] with a factor
  /// of [t]. If [t] is equal to `0` the result is `this`, if [t] is equal to
  /// `1` the result is [other].
  Polynomial<T> lerp(Polynomial<T> other, num t,
      {DataType<T>? dataType, PolynomialFormat? format}) {
    final result = createPolynomial<T>(
        this, math.max(degree, other.degree), dataType, format);
    final add = result.dataType.field.add, scale = result.dataType.field.scale;
    binaryOperator<T>(
        result, this, other, (a, b) => add(scale(a, 1.0 - t), scale(b, t)));
    return result;
  }
}
