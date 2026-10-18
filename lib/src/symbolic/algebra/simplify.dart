import '../assumptions.dart';
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
  /// like-term and like-factor reductions, and algebraic canonicalization
  /// under [assumptions].
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
  Expr simplify({Assumptions assumptions = Assumptions.none}) =>
      simplifyExpr(this, assumptions: assumptions);

  /// Rewrites this expression into rectangular complex normal form $a + b i$,
  /// where $a = \Re(\text{this})$ and $b = \Im(\text{this})$.
  Expr toRectangular({Assumptions assumptions = Assumptions.none}) =>
      toRectangularExpr(this, assumptions: assumptions);

  /// Rewrites this expression into polar complex normal form $r e^{i \theta}$,
  /// where $r = |\text{this}|$ and $\theta = \arg(\text{this})$.
  Expr toPolar({Assumptions assumptions = Assumptions.none}) =>
      toPolarExpr(this, assumptions: assumptions);
}

/// Recursively evaluates and canonically simplifies [expr] under [assumptions].
Expr simplifyExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if ((identical(assumptions, Assumptions.none) || assumptions.isEmpty) &&
      expr.isSimplified) {
    return expr;
  }
  return switch (expr) {
    Number() || Constant() || Variable() => expr,
    VariableFunction(:final name, :final arguments) => VariableFunction(name, [
      for (final argument in arguments)
        simplifyExpr(argument, assumptions: assumptions),
    ], isSimplified: true),
    OrderTerm(:final variable, :final order, :final point) => OrderTerm(
      variable,
      order,
      point: simplifyExpr(point, assumptions: assumptions),
    ),
    Add(:final terms) => simplifyAdd([
      for (final term in terms) simplifyExpr(term, assumptions: assumptions),
    ], assumptions: assumptions),
    Mul(:final factors) => simplifyMul([
      for (final factor in factors)
        simplifyExpr(factor, assumptions: assumptions),
    ], assumptions: assumptions),
    Pow(:final base, :final exponent) => simplifyPow(
      simplifyExpr(base, assumptions: assumptions),
      simplifyExpr(exponent, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Sin(:final expr) => simplifySin(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Cos(:final expr) => simplifyCos(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Tan(:final expr) => simplifyTan(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Asin(:final expr) => simplifyAsin(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Acos(:final expr) => simplifyAcos(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Atan(:final expr) => simplifyAtan(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Sinh(:final expr) => simplifySinh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Cosh(:final expr) => simplifyCosh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Tanh(:final expr) => simplifyTanh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Abs(:final expr) => simplifyAbs(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Ln(:final expr) => simplifyLn(simplifyExpr(expr, assumptions: assumptions)),
    Re(:final expr) => simplifyRe(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Im(:final expr) => simplifyIm(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Arg(:final expr) => simplifyArg(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Conjugate(:final expr) => simplifyConjugate(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    LambertW(:final expr, :final branch) => simplifyLambertW(
      simplifyExpr(expr, assumptions: assumptions),
      branch,
    ),
    Erf(:final expr) => simplifyErf(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Erfc(:final expr) => simplifyErfc(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Gamma(:final expr) => simplifyGamma(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Beta(:final left, :final right) => simplifyBeta(
      simplifyExpr(left, assumptions: assumptions),
      simplifyExpr(right, assumptions: assumptions),
    ),
    Factorial(:final expr) => simplifyFactorial(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Binomial(:final left, :final right) => simplifyBinomial(
      simplifyExpr(left, assumptions: assumptions),
      simplifyExpr(right, assumptions: assumptions),
    ),
    Floor(:final expr) => simplifyFloor(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Ceil(:final expr) => simplifyCeil(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Round(:final expr) => simplifyRound(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Sign(:final expr) => simplifySign(
      simplifyExpr(expr, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Mod(:final left, :final right) => simplifyMod(
      simplifyExpr(left, assumptions: assumptions),
      simplifyExpr(right, assumptions: assumptions),
      assumptions: assumptions,
    ),
    Asinh(:final expr) => simplifyAsinh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Acosh(:final expr) => simplifyAcosh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    Atanh(:final expr) => simplifyAtanh(
      simplifyExpr(expr, assumptions: assumptions),
    ),
    RelationalExpr() => simplifyRelational(expr, assumptions: assumptions),
    Piecewise() => simplifyPiecewise(expr, assumptions: assumptions),
    Integral(:final integrand, :final variable, :final lower, :final upper) =>
      simplifyIntegral(
        integrand,
        variable,
        lower: lower,
        upper: upper,
        assumptions: assumptions,
      ),
    Derivative(:final expr, :final variable, :final order) =>
      simplifyDerivative(
        expr,
        variable,
        order: order,
        assumptions: assumptions,
      ),
    Limit(:final expr, :final variable, :final point, :final direction) =>
      simplifyLimit(
        expr,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      ),
  };
}
