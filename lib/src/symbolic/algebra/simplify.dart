import 'dart:collection';

import '../assumptions.dart';
import '../ast.dart';
import '../calculus/product.dart';
import '../calculus/summation.dart';
import 'simplify/additive.dart';
import 'simplify/complex.dart';
import 'simplify/discrete.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'simplify/special.dart';
import 'simplify/transcendental.dart';

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
Expr simplifyExpr(Expr expr, {required Assumptions assumptions}) {
  if ((identical(assumptions, Assumptions.none) || assumptions.isEmpty) &&
      expr.isSimplified) {
    return expr;
  }
  return _simplify(expr, assumptions, HashMap<Expr, Expr>());
}

Expr _simplify(Expr expr, Assumptions assumptions, Map<Expr, Expr> cache) {
  if (expr.isSimplified &&
      (identical(assumptions, Assumptions.none) || assumptions.isEmpty)) {
    return expr;
  }
  if (expr is Number || expr is Constant || expr is Variable) {
    return expr;
  }
  final cached = cache[expr];
  if (cached != null) return cached;

  final result = switch (expr) {
    Number() || Constant() || Variable() => expr,
    VariableFunction(:final name, :final arguments) => () {
      var changed = false;
      final newArgs = <Expr>[
        for (final argument in arguments)
          () {
            final simplified = _simplify(argument, assumptions, cache);
            if (!identical(simplified, argument)) changed = true;
            return simplified;
          }(),
      ];
      return changed
          ? VariableFunction(name, newArgs, isSimplified: true)
          : expr;
    }(),
    OrderTerm(:final variable, :final order, :final point) => () {
      final newPoint = _simplify(point, assumptions, cache);
      return identical(newPoint, point)
          ? expr
          : OrderTerm(variable, order, point: newPoint);
    }(),
    Add(:final terms) => simplifyAdd(
      [for (final term in terms) _simplify(term, assumptions, cache)],
      assumptions: assumptions,
      simplify: (e) => _simplify(e, assumptions, cache),
    ),
    Mul(:final factors) => simplifyMul([
      for (final factor in factors) _simplify(factor, assumptions, cache),
    ], assumptions: assumptions),
    Pow(:final base, :final exponent) => simplifyPow(
      _simplify(base, assumptions, cache),
      _simplify(exponent, assumptions, cache),
      assumptions: assumptions,
    ),
    Sin(:final expr) => simplifySin(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Cos(:final expr) => simplifyCos(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Tan(:final expr) => simplifyTan(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Asin(:final expr) => simplifyAsin(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Acos(:final expr) => simplifyAcos(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Atan(:final expr) => simplifyAtan(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Atan2(:final left, :final right) => simplifyAtan2(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    Sinh(:final expr) => simplifySinh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Cosh(:final expr) => simplifyCosh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Tanh(:final expr) => simplifyTanh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Abs(:final expr) => simplifyAbs(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Ln(:final expr) => simplifyLn(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Re(:final expr) => simplifyRe(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Im(:final expr) => simplifyIm(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Arg(:final expr) => simplifyArg(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Conjugate(:final expr) => simplifyConjugate(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    LambertW(:final expr, :final branch) => simplifyLambertW(
      _simplify(expr, assumptions, cache),
      branch,
      assumptions: assumptions,
    ),
    Erf(:final expr) => simplifyErf(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Erfc(:final expr) => simplifyErfc(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Gamma(:final expr) => simplifyGamma(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Zeta(:final expr, :final shift) => simplifyZeta(
      _simplify(expr, assumptions, cache),
      shift: shift == null ? null : _simplify(shift, assumptions, cache),
    ),
    Digamma(:final expr) => simplifyDigamma(
      _simplify(expr, assumptions, cache),
    ),
    Polygamma(:final left, :final right) => simplifyPolygamma(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    BesselJ(:final left, :final right) => simplifyBesselJ(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    BesselY(:final left, :final right) => simplifyBesselY(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    BesselI(:final left, :final right) => simplifyBesselI(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    BesselK(:final left, :final right) => simplifyBesselK(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    EllipticK(:final expr) => simplifyEllipticK(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    EllipticE(:final expr) => simplifyEllipticE(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Erfi(:final expr) => simplifyErfi(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    FresnelS(:final expr) => simplifyFresnelS(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    FresnelC(:final expr) => simplifyFresnelC(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    ExpIntegralEi(:final expr) => simplifyExpIntegralEi(
      _simplify(expr, assumptions, cache),
    ),
    LogIntegralLi(:final expr) => simplifyLogIntegralLi(
      _simplify(expr, assumptions, cache),
    ),
    SinIntegralSi(:final expr) => simplifySinIntegralSi(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    CosIntegralCi(:final expr) => simplifyCosIntegralCi(
      _simplify(expr, assumptions, cache),
    ),
    SinhIntegralShi(:final expr) => simplifySinhIntegralShi(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    CoshIntegralChi(:final expr) => simplifyCoshIntegralChi(
      _simplify(expr, assumptions, cache),
    ),
    UpperGamma(:final left, :final right) => simplifyUpperGamma(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    LowerGamma(:final left, :final right) => simplifyLowerGamma(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    Polylog(:final left, :final right) => simplifyPolylog(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    EllipticF(:final left, :final right) => simplifyEllipticF(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    EllipticEIncomplete(:final left, :final right) =>
      simplifyEllipticEIncomplete(
        _simplify(left, assumptions, cache),
        _simplify(right, assumptions, cache),
        assumptions: assumptions,
      ),
    EllipticPi(:final characteristic, :final amplitude, :final modulus) =>
      simplifyEllipticPi(
        _simplify(characteristic, assumptions, cache),
        _simplify(amplitude, assumptions, cache),
        _simplify(modulus, assumptions, cache),
        assumptions: assumptions,
      ),
    ExpIntegralE(:final left, :final right) => simplifyExpIntegralE(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
    ),
    Hypergeometric(:final upper, :final lower, :final argument) =>
      simplifyHypergeometric(
        upper.map((u) => _simplify(u, assumptions, cache)).toList(),
        lower.map((l) => _simplify(l, assumptions, cache)).toList(),
        _simplify(argument, assumptions, cache),
      ),
    Min(:final args) => simplifyMin(
      args.map((a) => _simplify(a, assumptions, cache)).toList(),
    ),
    Max(:final args) => simplifyMax(
      args.map((a) => _simplify(a, assumptions, cache)).toList(),
    ),
    Beta(:final left, :final right) => simplifyBeta(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    Factorial(:final expr) => simplifyFactorial(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Binomial(:final left, :final right) => simplifyBinomial(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    Floor(:final expr) => simplifyFloor(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Ceil(:final expr) => simplifyCeil(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Round(:final expr) => simplifyRound(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Sign(:final expr) => simplifySign(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Mod(:final left, :final right) => simplifyMod(
      _simplify(left, assumptions, cache),
      _simplify(right, assumptions, cache),
      assumptions: assumptions,
    ),
    Asinh(:final expr) => simplifyAsinh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Acosh(:final expr) => simplifyAcosh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
    ),
    Atanh(:final expr) => simplifyAtanh(
      _simplify(expr, assumptions, cache),
      assumptions: assumptions,
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
    Derivative(:final expr, :final variable, :final order, :final point) =>
      simplifyDerivative(
        expr,
        variable,
        order: order,
        point: point,
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
    Sum(:final expr, :final variable, :final lower, :final upper) => computeSum(
      expr,
      variable,
      lower,
      upper,
      assumptions: assumptions,
    ),
    Product(:final expr, :final variable, :final lower, :final upper) =>
      computeProduct(expr, variable, lower, upper, assumptions: assumptions),
  };
  cache[expr] = result;
  return result;
}
