import '../ast.dart';

/// Analytical symbolic differentiation extension on [Expr].
extension DifferentiationExtension on Expr {
  /// Computes the exact analytical symbolic derivative of order [order] with
  /// respect to [variable].
  ///
  /// Conceptually, the derivative describes the instantaneous rate of change or
  /// the slope of the tangent line to the graph at any point (such as how the
  /// derivative of $x^3$ is $3x^2$). Formally, this executes recursive formal
  /// differentiation $\frac{\partial^n}{\partial x^n}$ applying the product
  /// rule, quotient rule, chain rule, and generalized power rule across the
  /// abstract syntax tree for [order] times.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final d1 = (x * x * x).derivative('x').simplify(); // 3 * (x ^ 2)
  /// final d2 = (x * x * x).derivative('x', order: 2).simplify(); // 6 * x
  /// ```
  Expr derivative(String variable, {int order = 1}) {
    RangeError.checkValueInInterval(order, 0, 1000, 'order');
    var current = this;
    for (var i = 0; i < order; i++) {
      current = _differentiate(current, variable);
    }
    return current;
  }
}

Expr _differentiate(Expr expr, String variable) => switch (expr) {
  Number() => RationalNumber.zero,
  Variable(:final name) =>
    name == variable ? RationalNumber.one : RationalNumber.zero,
  Add(:final left, :final right) => Add(
    _differentiate(left, variable),
    _differentiate(right, variable),
  ),
  Sub(:final left, :final right) => Sub(
    _differentiate(left, variable),
    _differentiate(right, variable),
  ),
  Mul(:final left, :final right) => Add(
    Mul(_differentiate(left, variable), right),
    Mul(left, _differentiate(right, variable)),
  ),
  Div(:final left, :final right) => Div(
    Sub(
      Mul(_differentiate(left, variable), right),
      Mul(left, _differentiate(right, variable)),
    ),
    Pow(right, const RationalNumber(2)),
  ),
  Pow(:final base, :final exponent) => switch ((
    base.dependsOn(variable),
    exponent.dependsOn(variable),
  )) {
    (false, false) => RationalNumber.zero,
    (true, false) => Mul(
      Mul(exponent, Pow(base, Sub(exponent, RationalNumber.one))),
      _differentiate(base, variable),
    ),
    (false, true) => Mul(
      Mul(expr, Ln(base)),
      _differentiate(exponent, variable),
    ),
    (true, true) => Mul(
      expr,
      Add(
        Mul(_differentiate(exponent, variable), Ln(base)),
        Div(Mul(exponent, _differentiate(base, variable)), base),
      ),
    ),
  },
  Neg(expr: final inner) => Neg(_differentiate(inner, variable)),
  Sin(expr: final inner) => Mul(Cos(inner), _differentiate(inner, variable)),
  Cos(expr: final inner) => Mul(
    Neg(Sin(inner)),
    _differentiate(inner, variable),
  ),
  Tan(expr: final inner) => Div(
    _differentiate(inner, variable),
    Pow(Cos(inner), const RationalNumber(2)),
  ),
  Asin(expr: final inner) => Div(
    _differentiate(inner, variable),
    Pow(
      Sub(RationalNumber.one, Pow(inner, const RationalNumber(2))),
      const RationalNumber(1, 2),
    ),
  ),
  Acos(expr: final inner) => Div(
    Neg(_differentiate(inner, variable)),
    Pow(
      Sub(RationalNumber.one, Pow(inner, const RationalNumber(2))),
      const RationalNumber(1, 2),
    ),
  ),
  Atan(expr: final inner) => Div(
    _differentiate(inner, variable),
    Add(RationalNumber.one, Pow(inner, const RationalNumber(2))),
  ),
  Sinh(expr: final inner) => Mul(Cosh(inner), _differentiate(inner, variable)),
  Cosh(expr: final inner) => Mul(Sinh(inner), _differentiate(inner, variable)),
  Tanh(expr: final inner) => Div(
    _differentiate(inner, variable),
    Pow(Cosh(inner), const RationalNumber(2)),
  ),
  Abs(expr: final inner) => Mul(
    Div(inner, Abs(inner)),
    _differentiate(inner, variable),
  ),
  Exp(expr: final inner) => Mul(expr, _differentiate(inner, variable)),
  Ln(expr: final inner) => Div(_differentiate(inner, variable), inner),
};
