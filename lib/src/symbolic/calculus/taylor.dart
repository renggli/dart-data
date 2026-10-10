import '../ast.dart';
import '../simplifier.dart';
import 'differentiation.dart';

/// Taylor series polynomial expansion extension on [Expr].
extension TaylorExtension on Expr {
  /// Computes the Taylor series expansion of this expression around [around] up to [order].
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
