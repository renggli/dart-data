import '../ast.dart';
import '../simplifier.dart';
import 'differentiation.dart';

/// Taylor series polynomial expansion extension on [Expr].
extension TaylorExtension on Expr {
  /// Computes the Taylor series expansion
  /// $\sum_{k=0}^n \frac{f^{(k)}(a)}{k!} (x - a)^k$ of this expression around
  /// [around] up to [order].
  ///
  /// Conceptually, a Taylor series approximates smooth non-linear functions
  /// (such as $\sin(x)$ or $e^x$) using simple polynomials near an expansion
  /// point. Formally, this truncates the analytic power series expansion at
  /// order $n$, with remainder given by Lagrange's formula.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expansion = Exp(x).taylorSeries('x', order: 2);
  /// // 1 + x + 0.5 * (x ^ 2)
  /// ```
  Expr taylorSeries(String variable, {double around = 0.0, int order = 4}) =>
      _computeTaylorSeries(this, variable, around: around, order: order);
}

Expr _computeTaylorSeries(
  Expr function,
  String variable, {
  double around = 0.0,
  int order = 4,
}) {
  final x = Variable(variable);
  final a = Constant(around);
  final delta = around == 0.0 ? x : Sub(x, a);

  var currentDeriv = function;
  var result = currentDeriv.substitute(variable, a).simplify();
  var factorial = 1.0;

  for (var step = 1; step <= order; step++) {
    currentDeriv = currentDeriv.diff(variable);
    factorial *= step;
    final termVal = currentDeriv.substitute(variable, a).simplify();
    final polyTerm = Mul(
      Div(termVal, Constant(factorial)),
      step == 1 ? delta : Pow(delta, Constant(step.toDouble())),
    );
    result = Add(result, polyTerm).simplify();
  }

  return result;
}
