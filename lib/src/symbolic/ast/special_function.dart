part of '../ast.dart';

/// Error function $\operatorname{erf}(expr) = \frac{2}{\sqrt{\pi}} \int_0^{expr} e^{-t^2} dt$.
final class Erf extends UnaryExpr {
  /// Creates an error function node.
  const new(super.expr);

  @override
  Erf copyWith(Expr newExpr) => Erf(newExpr);

  @override
  double evaluate(Map<String, double> context) =>
      special_erf.erf(expr.evaluate(context));
}

/// Complementary error function $\operatorname{erfc}(expr) = 1 - \operatorname{erf}(expr)$.
final class Erfc extends UnaryExpr {
  /// Creates a complementary error function node.
  const new(super.expr);

  @override
  Erfc copyWith(Expr newExpr) => Erfc(newExpr);

  @override
  double evaluate(Map<String, double> context) =>
      special_erf.erfc(expr.evaluate(context));
}

/// Euler gamma function $\Gamma(expr) = \int_0^\infty t^{expr-1} e^{-t} dt$.
final class Gamma extends UnaryExpr {
  /// Creates an Euler gamma function node.
  const new(super.expr);

  @override
  Gamma copyWith(Expr newExpr) => Gamma(newExpr);

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
  Beta copyWith(Expr newLeft, Expr newRight) => Beta(newLeft, newRight);

  @override
  double evaluate(Map<String, double> context) =>
      special_beta.beta(left.evaluate(context), right.evaluate(context));
}

/// Inverse hyperbolic sine $\operatorname{asinh}(expr) = \ln(expr + \sqrt{expr^2 + 1})$.
final class Asinh extends UnaryExpr {
  /// Creates an inverse hyperbolic sine function node.
  const new(super.expr);

  @override
  Asinh copyWith(Expr newExpr) => Asinh(newExpr);

  @override
  double evaluate(Map<String, double> context) =>
      evaluateRealAsinh(expr.evaluate(context));
}

/// Inverse hyperbolic cosine $\operatorname{acosh}(expr) = \ln(expr + \sqrt{expr^2 - 1})$.
final class Acosh extends UnaryExpr {
  /// Creates an inverse hyperbolic cosine function node.
  const new(super.expr);

  @override
  Acosh copyWith(Expr newExpr) => Acosh(newExpr);

  @override
  double evaluate(Map<String, double> context) =>
      evaluateRealAcosh(expr.evaluate(context));
}

/// Inverse hyperbolic tangent $\operatorname{atanh}(expr) = \frac{1}{2} \ln(\frac{1+expr}{1-expr})$.
final class Atanh extends UnaryExpr {
  /// Creates an inverse hyperbolic tangent function node.
  const new(super.expr);

  @override
  Atanh copyWith(Expr newExpr) => Atanh(newExpr);

  @override
  double evaluate(Map<String, double> context) =>
      evaluateRealAtanh(expr.evaluate(context));
}

/// Numerically stable evaluation of $\operatorname{asinh}(v)$.
double evaluateRealAsinh(double v) {
  if (v.isNaN || v.isInfinite || v == 0.0) return v;
  final a = v.abs();
  final double res;
  if (a < 1e-5) {
    res = a * (1.0 - a * a / 6.0);
  } else if (a > 1e8) {
    res = math.log(a) + math.ln2;
  } else {
    res = math.log(a + math.sqrt(a * a + 1.0));
  }
  return v < 0.0 ? -res : res;
}

/// Numerically stable evaluation of $\operatorname{acosh}(v)$.
double evaluateRealAcosh(double v) {
  if (v.isNaN) return double.nan;
  if (v < 1.0) throw ArgumentError('acosh domain error: argument $v < 1.0');
  if (v.isInfinite) return double.infinity;
  if (v > 1e8) return math.log(v) + math.ln2;
  return math.log(v + math.sqrt((v - 1.0) * (v + 1.0)));
}

/// Numerically stable evaluation of $\operatorname{atanh}(v)$.
double evaluateRealAtanh(double v) {
  if (v.isNaN) return double.nan;
  if (v.abs() >= 1.0) throw ArgumentError('atanh domain error: |$v| >= 1.0');
  if (v.abs() < 1e-5) return v * (1.0 + v * v / 3.0);
  return 0.5 * math.log((1.0 + v) / (1.0 - v));
}
