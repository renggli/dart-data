part of '../ast.dart';

/// Error function $\operatorname{erf}(expr) = \frac{2}{\sqrt{\pi}} \int_0^{expr} e^{-t^2} dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erf(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      special_erf.erf(expr.evaluate(context));
}

/// Complementary error function $\operatorname{erfc}(expr) = 1 - \operatorname{erf}(expr)$.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Erfc(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) =>
      special_erf.erfc(expr.evaluate(context));
}

/// Euler gamma function $\Gamma(expr) = \int_0^\infty t^{expr-1} e^{-t} dt$.
final class Gamma extends UnaryExpr {
  /// Creates an Euler gamma function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Gamma(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    if (v <= 0.0 && v == v.roundToDouble()) {
      throw ArgumentError(
        'Gamma function singularity at non-positive integer $v',
      );
    }
    return special_gamma.gamma(v);
  }
}

/// Euler beta function $\operatorname{B}(a, b) = \frac{\Gamma(a)\Gamma(b)}{\Gamma(a+b)}$.
final class Beta extends BinaryExpr {
  /// Creates an Euler beta function node.
  const new(super.left, super.right);

  /// First argument $a$.
  Expr get a => left;

  /// Second argument $b$.
  Expr get b => right;

  @override
  Expr substitute(String variable, Expr replacement) => Beta(
    left.substitute(variable, replacement),
    right.substitute(variable, replacement),
  );

  @override
  double evaluate(Map<String, double> context) =>
      special_beta.beta(left.evaluate(context), right.evaluate(context));
}

/// Inverse hyperbolic sine $\operatorname{asinh}(expr) = \ln(expr + \sqrt{expr^2 + 1})$.
final class Asinh extends UnaryExpr {
  /// Creates an inverse hyperbolic sine function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Asinh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    return math.log(v + math.sqrt(v * v + 1.0));
  }
}

/// Inverse hyperbolic cosine $\operatorname{acosh}(expr) = \ln(expr + \sqrt{expr^2 - 1})$.
final class Acosh extends UnaryExpr {
  /// Creates an inverse hyperbolic cosine function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Acosh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    if (v < 1.0) throw ArgumentError('acosh domain error: argument $v < 1.0');
    return math.log(v + math.sqrt(v * v - 1.0));
  }
}

/// Inverse hyperbolic tangent $\operatorname{atanh}(expr) = \frac{1}{2} \ln(\frac{1+expr}{1-expr})$.
final class Atanh extends UnaryExpr {
  /// Creates an inverse hyperbolic tangent function node.
  const new(super.expr);

  @override
  Expr substitute(String variable, Expr replacement) =>
      Atanh(expr.substitute(variable, replacement));

  @override
  double evaluate(Map<String, double> context) {
    final v = expr.evaluate(context);
    if (v.abs() >= 1.0) throw ArgumentError('atanh domain error: |$v| >= 1.0');
    return 0.5 * math.log((1.0 + v) / (1.0 - v));
  }
}
