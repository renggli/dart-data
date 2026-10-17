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
  /// final expansion = Pow(Constant.e, x).taylorSeries('x', order: 2);
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
  if (n is int) return IntegerNumber.of(n);
  final dVal = n.toDouble();
  for (var den = 1; den <= 64; den++) {
    final numRound = (dVal * den).round();
    if ((dVal - numRound / den).abs() < 1e-12) {
      return RationalNumber(numRound, den);
    }
  }
  return RealNumber(dVal);
}

Expr _computeTaylorSeriesByDerivatives(
  Expr function,
  String variable, {
  required Expr around,
  required int order,
}) {
  final x = Variable(variable);
  final delta = around is Number && around.isZero ? x : x - around;

  var currentDeriv = function;
  final terms = <Expr>[];
  final c0 = currentDeriv.substitute(variable, around).simplify();
  if (!(c0 is Number && c0.isZero)) {
    terms.add(c0);
  }
  var factorial = 1;

  for (var step = 1; step <= order; step++) {
    currentDeriv = currentDeriv.derivative(variable);
    factorial *= step;
    final termVal = currentDeriv.substitute(variable, around).simplify();
    if (termVal is Number && termVal.isZero) continue;
    final coeff = (termVal / IntegerNumber.of(factorial)).simplify();
    final power = step == 1 ? delta : Pow(delta, IntegerNumber.of(step));
    final polyTerm = switch (coeff) {
      Number(isOne: true) => power,
      Number(isNegativeOne: true) => -power,
      _ => Mul([coeff, power]),
    };
    terms.add(polyTerm);
  }

  return switch (terms) {
    [] => IntegerNumber.zero,
    [final single] => single,
    _ => Add(terms),
  };
}
