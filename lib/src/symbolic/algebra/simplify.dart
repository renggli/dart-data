import '../ast.dart';
import 'simplify/additive.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'simplify/transcendental.dart';

export 'simplify/additive.dart';
export 'simplify/multiplicative.dart';
export 'simplify/power.dart';
export 'simplify/transcendental.dart';

/// Canonical algebraic simplification extension on [Expr].
extension SimplifierExtension on Expr {
  /// Canonically simplifies this expression by performing constant folding,
  /// like-term and like-factor reductions, and algebraic canonicalization.
  ///
  /// Conceptually, this simplifies expressions using algebraic identities such
  /// as $x + x \to 2x$, $x \cdot x \to x^2$, $x + 0 \to x$, $x \cdot 1 \to x$,
  /// evaluates constant sub-expressions such as $2 + 3 \to 5$, and canonicalizes
  /// polynomial terms in increasing order of degree. Formally, this executes
  /// confluent rewriting rules to reduce algebraic expressions into canonical
  /// normal form.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = (x + 1) + (x + 2);
  /// final s = expr.simplify(); // 3 + 2 * x
  /// ```
  Expr simplify() => simplifyExpr(this);
}

/// Recursively evaluates and canonically simplifies [expr].
Expr simplifyExpr(Expr expr) {
  if (expr.isSimplified) return expr;
  return switch (expr) {
    Number() || Constant() || Variable() => expr,
    VariableFunction(:final name, :final arguments) => VariableFunction(name, [
      for (final argument in arguments) simplifyExpr(argument),
    ], isSimplified: true),
    OrderTerm(:final variable, :final order, :final point) => OrderTerm(
      variable,
      order,
      point: simplifyExpr(point),
    ),
    Add(:final terms) => simplifyAdd([
      for (final term in terms) simplifyExpr(term),
    ]),
    Mul(:final factors) => simplifyMul([
      for (final factor in factors) simplifyExpr(factor),
    ]),
    Pow(:final base, :final exponent) => simplifyPow(
      simplifyExpr(base),
      simplifyExpr(exponent),
    ),
    Sin(:final expr) => simplifySin(simplifyExpr(expr)),
    Cos(:final expr) => simplifyCos(simplifyExpr(expr)),
    Tan(:final expr) => simplifyTan(simplifyExpr(expr)),
    Asin(:final expr) => simplifyAsin(simplifyExpr(expr)),
    Acos(:final expr) => simplifyAcos(simplifyExpr(expr)),
    Atan(:final expr) => simplifyAtan(simplifyExpr(expr)),
    Sinh(:final expr) => simplifySinh(simplifyExpr(expr)),
    Cosh(:final expr) => simplifyCosh(simplifyExpr(expr)),
    Tanh(:final expr) => simplifyTanh(simplifyExpr(expr)),
    Abs(:final expr) => simplifyAbs(simplifyExpr(expr)),
    Ln(:final expr) => simplifyLn(simplifyExpr(expr)),
    LambertW(:final expr, :final branch) => simplifyLambertW(
      simplifyExpr(expr),
      branch,
    ),
    Erf(:final expr) => simplifyErf(simplifyExpr(expr)),
    Erfc(:final expr) => simplifyErfc(simplifyExpr(expr)),
    Gamma(:final expr) => simplifyGamma(simplifyExpr(expr)),
    Beta(:final left, :final right) => simplifyBeta(
      simplifyExpr(left),
      simplifyExpr(right),
    ),
    Asinh(:final expr) => simplifyAsinh(simplifyExpr(expr)),
    Acosh(:final expr) => simplifyAcosh(simplifyExpr(expr)),
    Atanh(:final expr) => simplifyAtanh(simplifyExpr(expr)),
    RelationalExpr() => simplifyRelational(expr),
    Piecewise() => simplifyPiecewise(expr),
    Integral(:final integrand, :final variable, :final lower, :final upper) =>
      simplifyIntegral(integrand, variable, lower: lower, upper: upper),
  };
}
