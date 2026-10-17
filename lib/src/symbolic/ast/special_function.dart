part of '../ast.dart';

/// Error function node: $\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}} \int_0^x e^{-t^2}\,dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node $\operatorname{erf}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.erf(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erf(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Erf(transform(expr));
}

/// Complementary error function node: $\operatorname{erfc}(x) = 1 - \operatorname{erf}(x)$.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node $\operatorname{erfc}(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.erfc(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erfc(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Erfc(transform(expr));
}

/// Euler Gamma function node: $\Gamma(x) = \int_0^\infty t^{x-1} e^{-t}\,dt$.
final class Gamma extends UnaryExpr {
  /// Creates a Gamma function node $\Gamma(\text{expr})$.
  new(super.expr, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.gamma(expr.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) =>
      Gamma(expr.substitute(variable, replacement));

  @override
  Expr mapChildren(Expr Function(Expr) transform) => Gamma(transform(expr));
}

/// Euler Beta function node: $\operatorname{B}(a, b) = \frac{\Gamma(a)\Gamma(b)}{\Gamma(a+b)}$.
final class Beta extends BinaryExpr {
  /// Creates a Beta function node $\operatorname{B}(\text{left}, \text{right})$.
  new(super.left, super.right, {super.isSimplified = false});

  @override
  double evaluate([Map<String, double> context = const {}]) =>
      special.beta(left.evaluate(context), right.evaluate(context));

  @override
  Expr substitute(String variable, Expr replacement) => Beta(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  Expr mapChildren(Expr Function(Expr) transform) =>
      Beta(transform(left), transform(right));
}
