import '../ast.dart';

/// Analytical symbolic differentiation extension on [Expr].
extension DifferentiationExtension on Expr {
  /// Computes the exact analytical symbolic derivative $\frac{d}{dx} f(x)$ with respect to [variable].
  ///
  /// Conceptually, the derivative describes the instantaneous rate
  /// of change or the slope of the tangent line to the graph at any point (such as how
  /// the derivative of $x^3$ is $3x^2$).
  /// Formally, this executes recursive formal differentiation $\frac{\partial}{\partial x}$
  /// applying the product rule, quotient rule, chain rule, and generalized power rule
  /// across the abstract syntax tree.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final d = (x * x * x).diff('x').simplify();
  /// // d: 3 * (x ^ 2)
  /// ```
  Expr diff(String variable) => _differentiate(this, variable);
}

Expr _differentiate(Expr expr, String variable) => switch (expr) {
  Constant() => const Constant(0.0),
  Variable(:final name) =>
    name == variable ? const Constant(1.0) : const Constant(0.0),
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
    Pow(right, const Constant(2.0)),
  ),
  Pow(:final base, :final exponent) => switch ((
    base.dependsOn(variable),
    exponent.dependsOn(variable),
  )) {
    (false, false) => const Constant(0.0),
    (true, false) => Mul(
      Mul(exponent, Pow(base, Sub(exponent, const Constant(1.0)))),
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
  Exp(expr: final inner) => Mul(expr, _differentiate(inner, variable)),
  Ln(expr: final inner) => Div(_differentiate(inner, variable), inner),
};
