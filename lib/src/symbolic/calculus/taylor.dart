import 'package:more/number.dart' show Fraction;

import '../algebra/simplify.dart';
import '../ast.dart';
import 'differentiation.dart';
import 'series.dart';

export 'series.dart' show PowerSeries, SeriesExtension;

/// Taylor series polynomial expansion extension on [Expr].
extension TaylorExtension on Expr {
  /// Computes the Taylor series expansion
  /// $\sum_{k=0}^n \frac{f^{(k)}(a)}{k!} (x - a)^k$ of this expression around
  /// [around] up to [order].
  ///
  /// Conceptually, a Taylor series approximates smooth non-linear functions
  /// (such as $\sin(x)$ or $e^x$) using simple polynomials near an expansion
  /// point. Formally, this delegates to [SeriesExtension.toPowerSeries] with
  /// `includeOrder: false`, falling back to analytic differentiation if needed.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expansion = Exp(x).taylorSeries('x', order: 2);
  /// // 1 + x + 1/2 * (x ^ 2)
  /// ```
  Expr taylorSeries(String variable, {num around = 0, int order = 4}) {
    final pt = _numToPoint(around);
    try {
      return toPowerSeries(
        variable,
        point: pt,
        order: order + 1,
      ).toExpr(includeOrder: false);
    } catch (_) {
      return _computeTaylorSeriesByDerivatives(
        this,
        variable,
        around: pt,
        order: order,
      );
    }
  }
}

Number _numToPoint(num n) {
  if (n is int) return RationalNumber(n);
  final frac = Fraction.fromDouble(n, maxDenominator: 64);
  if ((n.toDouble() - frac.toDouble()).abs() < 1e-12) {
    return RationalNumber(frac.numerator, frac.denominator);
  }
  return RealNumber(n.toDouble());
}

Expr _computeTaylorSeriesByDerivatives(
  Expr function,
  String variable, {
  required Expr around,
  required int order,
}) {
  final x = Variable(variable);
  final delta = around is RationalNumber && around.isZero ? x : Sub(x, around);

  var currentDeriv = function;
  var result = currentDeriv.substitute(variable, around).simplify();
  var factorial = 1;

  for (var step = 1; step <= order; step++) {
    currentDeriv = currentDeriv.derivative(variable);
    factorial *= step;
    final termVal = currentDeriv.substitute(variable, around).simplify();
    final polyTerm = Mul(
      Div(termVal, RationalNumber(factorial)),
      step == 1 ? delta : Pow(delta, RationalNumber(step)),
    );
    result = Add(result, polyTerm).simplify();
  }

  return result;
}
