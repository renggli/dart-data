import 'dart:collection';

import '../assumptions.dart';
import '../ast.dart';
import '../calculus/product.dart';
import '../calculus/summation.dart';
import '../functions/fn.dart';
import 'expand.dart';
import 'helpers.dart';
import 'simplify/additive.dart';
import 'simplify/complex.dart';
import 'simplify/discrete.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';
import 'simplify/special.dart';
import 'simplify/special_integrals.dart';
import 'simplify/transcendental.dart';

/// Canonical algebraic simplification extension on [Expr].
extension SimplifierExtension on Expr {
  /// Canonically simplifies this expression by performing constant folding,
  /// like-term and like-factor reductions, and algebraic canonicalization
  /// under [assumptions].
  ///
  /// Conceptually, this simplifies expressions using algebraic identities such
  /// as `x + x -> 2x`, `x * x -> x^2`, `x + 0 -> x`, `x * 1 -> x`,
  /// evaluates constant sub-expressions such as `2 + 3 -> 5`, and canonicalizes
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

  /// Rewrites this expression into rectangular complex normal form `a + b i`,
  /// where `a = Re(this)` and `b = Im(this)`.
  Expr toRectangular({Assumptions assumptions = Assumptions.none}) =>
      toRectangularExpr(this, assumptions: assumptions);

  /// Rewrites this expression into polar complex normal form `r e^{i theta}`,
  /// where `r = |this|` and `theta = arg(this)`.
  Expr toPolar({Assumptions assumptions = Assumptions.none}) =>
      toPolarExpr(this, assumptions: assumptions);
}

/// Recursively evaluates and canonically simplifies [expr] under [assumptions].
Expr simplifyExpr(Expr expr, {required Assumptions assumptions}) =>
    _simplify(expr, assumptions, HashMap<Expr, Expr>());

Expr _simplify(Expr expr, Assumptions assumptions, Map<Expr, Expr> cache) {
  if (expr is Number || expr is Constant || expr is Variable) {
    return expr;
  }
  final cached = cache[expr];
  if (cached != null) return cached;

  final result = switch (expr) {
    Number() || Constant() || Variable() => expr,
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
    Call(:final id, :final args) => _simplifyCall(expr, id, [
      for (final arg in args) _simplify(arg, assumptions, cache),
    ], assumptions),
    Relational() => simplifyRelational(expr, assumptions: assumptions),
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
    RootSum(:final polynomial, :final variable, :final body) =>
      _simplifyRootSum(polynomial, variable, body, assumptions),
  };
  cache[expr] = result;
  return result;
}

Expr _simplifyCall(
  Call call,
  FunctionId id,
  List<Expr> args,
  Assumptions assumptions,
) => switch (id) {
  FunctionId.sin => simplifySin(args[0], assumptions: assumptions),
  FunctionId.cos => simplifyCos(args[0], assumptions: assumptions),
  FunctionId.tan => simplifyTan(args[0], assumptions: assumptions),
  FunctionId.asin => simplifyAsin(args[0], assumptions: assumptions),
  FunctionId.acos => simplifyAcos(args[0], assumptions: assumptions),
  FunctionId.atan => simplifyAtan(args[0], assumptions: assumptions),
  FunctionId.atan2 => simplifyAtan2(args[0], args[1], assumptions: assumptions),
  FunctionId.sinh => simplifySinh(args[0], assumptions: assumptions),
  FunctionId.cosh => simplifyCosh(args[0], assumptions: assumptions),
  FunctionId.tanh => simplifyTanh(args[0], assumptions: assumptions),
  FunctionId.asinh => simplifyAsinh(args[0], assumptions: assumptions),
  FunctionId.acosh => simplifyAcosh(args[0], assumptions: assumptions),
  FunctionId.atanh => simplifyAtanh(args[0], assumptions: assumptions),
  FunctionId.abs => simplifyAbs(args[0], assumptions: assumptions),
  FunctionId.ln => simplifyLn(args[0], assumptions: assumptions),
  FunctionId.re => simplifyRe(args[0], assumptions: assumptions),
  FunctionId.im => simplifyIm(args[0], assumptions: assumptions),
  FunctionId.arg => simplifyArg(args[0], assumptions: assumptions),
  FunctionId.conj => simplifyConjugate(args[0], assumptions: assumptions),
  FunctionId.factorial => simplifyFactorial(args[0], assumptions: assumptions),
  FunctionId.binomial => simplifyBinomial(
    args[0],
    args[1],
    assumptions: assumptions,
  ),
  FunctionId.floor => simplifyFloor(args[0], assumptions: assumptions),
  FunctionId.ceil => simplifyCeil(args[0], assumptions: assumptions),
  FunctionId.round => simplifyRound(args[0], assumptions: assumptions),
  FunctionId.sign => simplifySign(args[0], assumptions: assumptions),
  FunctionId.mod => simplifyMod(args[0], args[1], assumptions: assumptions),
  FunctionId.min => simplifyMin(args),
  FunctionId.max => simplifyMax(args),
  FunctionId.gcd => simplifyGcd(args, assumptions: assumptions),
  FunctionId.lcm => simplifyLcm(args, assumptions: assumptions),
  FunctionId.tuple => () {
    for (var i = 0; i < args.length; i++) {
      if (!identical(args[i], call.args[i])) {
        return Fn.tuple(args);
      }
    }
    return call;
  }(),
  FunctionId.erf => simplifyErf(args[0], assumptions: assumptions),
  FunctionId.erfc => simplifyErfc(args[0], assumptions: assumptions),
  FunctionId.erfi => simplifyErfi(args[0], assumptions: assumptions),
  FunctionId.fresnelS => simplifyFresnelS(args[0], assumptions: assumptions),
  FunctionId.fresnelC => simplifyFresnelC(args[0], assumptions: assumptions),
  FunctionId.ei => simplifyExpIntegralEi(args[0]),
  FunctionId.expIntegralE => simplifyExpIntegralE(args[0], args[1]),
  FunctionId.li => simplifyLogIntegralLi(args[0]),
  FunctionId.si => simplifySinIntegralSi(args[0], assumptions: assumptions),
  FunctionId.ci => simplifyCosIntegralCi(args[0]),
  FunctionId.shi => simplifySinhIntegralShi(args[0], assumptions: assumptions),
  FunctionId.chi => simplifyCoshIntegralChi(args[0]),
  FunctionId.gamma => simplifyGamma(args[0], assumptions: assumptions),
  FunctionId.upperGamma => simplifyUpperGamma(
    args[0],
    args[1],
    assumptions: assumptions,
  ),
  FunctionId.lowerGamma => simplifyLowerGamma(
    args[0],
    args[1],
    assumptions: assumptions,
  ),
  FunctionId.logGamma => simplifyLogGamma(args[0]),
  FunctionId.digamma => simplifyDigamma(args[0]),
  FunctionId.polygamma => simplifyPolygamma(args[0], args[1]),
  FunctionId.zeta => simplifyZeta(
    args[0],
    shift: args.length > 1 ? args[1] : null,
  ),
  FunctionId.beta => simplifyBeta(args[0], args[1], assumptions: assumptions),
  FunctionId.polylog => simplifyPolylog(
    args[0],
    args[1],
    assumptions: assumptions,
  ),
  FunctionId.besselJ => simplifyBesselJ(args[0], args[1]),
  FunctionId.besselY => simplifyBesselY(args[0], args[1]),
  FunctionId.besselI => simplifyBesselI(args[0], args[1]),
  FunctionId.besselK => simplifyBesselK(args[0], args[1]),
  FunctionId.ellipticK => simplifyEllipticK(args[0], assumptions: assumptions),
  FunctionId.ellipticE =>
    args.length == 1
        ? simplifyEllipticE(args[0], assumptions: assumptions)
        : simplifyEllipticE(
            args[1],
            amplitude: args[0],
            assumptions: assumptions,
          ),
  FunctionId.ellipticF => simplifyEllipticF(
    args[0],
    args[1],
    assumptions: assumptions,
  ),
  FunctionId.ellipticPi => simplifyEllipticPi(
    args[0],
    args[1],
    args[2],
    assumptions: assumptions,
  ),
  FunctionId.hypergeometric => simplifyHypergeometric(
    args[0] is Call && (args[0] as Call).id == FunctionId.tuple
        ? (args[0] as Call).args
        : [args[0]],
    args[1] is Call && (args[1] as Call).id == FunctionId.tuple
        ? (args[1] as Call).args
        : [args[1]],
    args[2],
  ),
  FunctionId.appellF1 => simplifyAppellF1(
    args[0],
    args[1],
    args[2],
    args[3],
    args[4],
    args[5],
    assumptions: assumptions,
  ),
  FunctionId.lambertW => () {
    final branchExpr = args.length > 1 ? args[1] : null;
    if (branchExpr == null) {
      return simplifyLambertW(args[0], 0, assumptions: assumptions);
    }
    if (branchExpr case IntegerNumber(asInt: final b?)) {
      return simplifyLambertW(args[0], b, assumptions: assumptions);
    }
    return Fn.lambertW(args[0], branchExpr);
  }(),
  FunctionId.symbolic => () {
    for (var i = 0; i < args.length; i++) {
      if (!identical(args[i], call.args[i])) {
        return Call(call.spec, args);
      }
    }
    return call;
  }(),
};

Expr _simplifyRootSum(
  Expr polynomial,
  String variable,
  Expr body,
  Assumptions assumptions,
) {
  final innerAssumptions =
      assumptions.defaultDomain == VariableDomain.unknown &&
          !assumptions.domains.containsKey(variable)
      ? assumptions
      : assumptions.copyWith(domains: {variable: VariableDomain.unknown});

  final simpPoly = polynomial.simplify(assumptions: innerAssumptions);
  final simpBody = body.simplify(assumptions: innerAssumptions);

  if (simpBody is Number && simpBody.isZero) {
    return IntegerNumber.zero;
  }
  if (!simpPoly.dependsOn(variable)) {
    if (simpPoly is Number && !simpPoly.isZero) {
      return IntegerNumber.zero;
    }
    return RootSum(simpPoly, variable, simpBody);
  }

  final coeffs = extractPolynomialCoefficients(
    simpPoly.expand().simplify(assumptions: innerAssumptions),
    variable,
  );
  if (coeffs != null) {
    final deg = maxPolynomialDegree(coeffs);
    if (deg == 0) return IntegerNumber.zero;
    if (deg == 1) {
      final root = (-(coeffs[0] ?? IntegerNumber.zero) / coeffs[1]!).simplify(
        assumptions: innerAssumptions,
      );
      return simpBody
          .substitute(variable, root)
          .simplify(assumptions: assumptions);
    }
    if (!simpBody.dependsOn(variable) && deg > 0) {
      return (IntegerNumber.of(deg) * simpBody).simplify(
        assumptions: assumptions,
      );
    }
  }

  return RootSum(simpPoly, variable, simpBody);
}
