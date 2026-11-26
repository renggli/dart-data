import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart' show isPositiveExpr, isProvenReal;
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../linear_form.dart';
import '../summation.dart';

import 'definite.dart';

Expr? definiteIntegralSpecialCases(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
}) {
  // Flip reversed bounds: int_a^b f(x) dx = -int_b^a f(x) dx when a > b
  if ((fromExpr == Constant.infinity) ||
      (toExpr == negInfinity || toExpr == -Constant.infinity) ||
      (toExpr == IntegerNumber.zero && isPositiveConstant(fromExpr))) {
    final flipped = definiteIntegralSpecialCases(
      function,
      variable,
      toExpr,
      fromExpr,
      assumptions: assumptions,
    );
    return flipped != null
        ? (-flipped).simplify(assumptions: assumptions)
        : null;
  }

  // Extract constant factors independent of variable
  final rawFactors = function is Mul ? function.factors : [function];
  final (:constFactors, :varFactors) = partitionFactors(rawFactors, variable);
  if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
    final constPart = constFactors.length == 1
        ? constFactors.first
        : Mul(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify(assumptions: assumptions);
    final inner = definiteIntegralSpecialCases(
      varPart,
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    );
    if (inner != null) {
      return (constPart * inner).simplify(assumptions: assumptions);
    }
  }

  // Even integrand over [-infty, infty] -> 2 * int_0^infty f(x) dx
  if ((fromExpr == negInfinity || fromExpr == -Constant.infinity) &&
      toExpr == Constant.infinity) {
    final reflected = function
        .substitute(variable, -Variable(variable))
        .simplify(assumptions: assumptions);
    if ((function - reflected).expand().simplify(assumptions: assumptions) ==
        IntegerNumber.zero) {
      final halfInt = definiteIntegralZeroToInfinity(
        function,
        variable,
        assumptions: assumptions,
      );
      if (halfInt != null) {
        return (IntegerNumber.two * halfInt).simplify(assumptions: assumptions);
      }
    }
  }

  // Domain [0, infty)
  if (fromExpr == IntegerNumber.zero && toExpr == Constant.infinity) {
    final res = definiteIntegralZeroToInfinity(
      function,
      variable,
      assumptions: assumptions,
    );
    if (res != null) return res;
  }

  // Domain [0, pi/2] or [0, pi]
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();
  if (fromExpr == IntegerNumber.zero &&
      (toExpr == halfPi || toExpr == Constant.pi)) {
    final trigRes = definiteIntegralTrigDomain(
      function,
      variable,
      toExpr,
      assumptions: assumptions,
    );
    if (trigRes != null) return trigRes;
  }

  // Domain [0, 1]
  if (fromExpr == IntegerNumber.zero && toExpr == IntegerNumber.one) {
    final unitRes = definiteIntegralUnitInterval(
      function,
      variable,
      assumptions: assumptions,
    );
    if (unitRes != null) return unitRes;
  }

  return null;
}

/// Improper integrals evaluated over the semi-infinite interval `[0, oo)`.
Expr? definiteIntegralZeroToInfinity(
  Expr function,
  String variable, {
  required Assumptions assumptions,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Dirichlet integral: sin(a*x) / x -> pi/2 * sign(a)
  //    and sin(a*x)^2 / x^2 -> pi/2 * |a| (requires real a)
  if (den == xVar && num is Sin) {
    if (num.expr.matchLinear(variable) case (a: final slope, :final b)
        when b == IntegerNumber.zero && isProvenReal(slope, assumptions)) {
      return (Constant.pi / IntegerNumber.two * Sign(slope)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (den case Pow(base: final b, exponent: IntegerNumber(asInt: 2))
      when b == xVar) {
    if (num case Pow(
      base: Sin(expr: final inner),
      exponent: IntegerNumber(asInt: 2),
    )) {
      if (inner.matchLinear(variable) case (a: final slope, b: final shift)
          when shift == IntegerNumber.zero &&
              isProvenReal(slope, assumptions)) {
        return (Constant.pi / IntegerNumber.two * Abs(slope)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 2. Fresnel integrals: sin(a*x^2) or cos(a*x^2) -> 1/4 * sqrt(2*pi / |a|)
  if (function case Sin(expr: final inner) || Cos(expr: final inner)) {
    final coeffs = extractPolynomialCoefficients(inner, variable);
    if (coeffs != null &&
        maxPolynomialDegree(coeffs) == 2 &&
        (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
        (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
      final a2 = coeffs[2] ?? IntegerNumber.zero;
      if (isProvenReal(a2, assumptions)) {
        final absA = Abs(a2).simplify(assumptions: assumptions);
        if (isPositiveExpr(absA, assumptions: assumptions) ||
            isPositiveConstant(absA)) {
          final fresnelVal =
              (FractionNumber.quarter *
                      Pow(
                        (IntegerNumber.two * Constant.pi) / absA,
                        FractionNumber.half,
                      ))
                  .simplify(assumptions: assumptions);
          return function is Sin
              ? (Sign(a2) * fresnelVal).simplify(assumptions: assumptions)
              : fresnelVal;
        }
      }
    }
  }

  // 3. Euler Gamma integral: x^s * e^(-a*x) -> Gamma(s + 1) / a^(s + 1) for a > 0, s > -1
  final factors = function is Mul ? function.factors : [function];
  Expr? expSlope;
  Expr? xExponent;
  var validGamma = true;
  for (final f in factors) {
    if (expSlope == null && f is Pow && f.base == Constant.e) {
      if (f.exponent.matchLinear(variable) case (a: final slope, :final b)
          when b == IntegerNumber.zero) {
        final posA = (-slope).simplify(assumptions: assumptions);
        if (isPositiveExpr(posA, assumptions: assumptions) ||
            isPositiveConstant(posA)) {
          expSlope = posA;
          continue;
        }
      }
    }
    if (xExponent == null && f == xVar) {
      xExponent = IntegerNumber.one;
      continue;
    }
    if (xExponent == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      xExponent = f.exponent;
      continue;
    }
    validGamma = false;
    break;
  }
  if (validGamma && expSlope != null) {
    final s = xExponent ?? IntegerNumber.zero;
    final sPlus1 = (s + IntegerNumber.one).simplify(assumptions: assumptions);
    if (isPositiveExpr(sPlus1, assumptions: assumptions) ||
        isPositiveConstant(sPlus1)) {
      return (Gamma(sPlus1) / Pow(expSlope, sPlus1)).simplify(
        assumptions: assumptions,
      );
    }
  }

  // 4. Generalized Gaussian / Gamma integral: x^s * e^(-a*x^2) -> 1/2 * Gamma((s+1)/2) / a^((s+1)/2)
  Expr? gaussCoeff;
  Expr? gaussXExp;
  var validGaussGamma = true;
  for (final f in factors) {
    if (gaussCoeff == null && f is Pow && f.base == Constant.e) {
      final coeffs = extractPolynomialCoefficients(f.exponent, variable);
      if (coeffs != null &&
          maxPolynomialDegree(coeffs) == 2 &&
          (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
          (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
        final posA = (-(coeffs[2] ?? IntegerNumber.zero)).simplify(
          assumptions: assumptions,
        );
        if (isPositiveExpr(posA, assumptions: assumptions) ||
            isPositiveConstant(posA)) {
          gaussCoeff = posA;
          continue;
        }
      }
    }
    if (gaussXExp == null && f == xVar) {
      gaussXExp = IntegerNumber.one;
      continue;
    }
    if (gaussXExp == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      gaussXExp = f.exponent;
      continue;
    }
    validGaussGamma = false;
    break;
  }
  if (validGaussGamma && gaussCoeff != null) {
    final s = gaussXExp ?? IntegerNumber.zero;
    final alpha = ((s + IntegerNumber.one) / IntegerNumber.two).simplify(
      assumptions: assumptions,
    );
    if (isPositiveExpr(alpha, assumptions: assumptions) ||
        isPositiveConstant(alpha)) {
      return (FractionNumber.half * Gamma(alpha) / Pow(gaussCoeff, alpha))
          .simplify(assumptions: assumptions);
    }
  }

  // 5. Bose-Einstein & Fermi-Dirac integrals:
  //    int_0^infty x^(s-1) / (e^x - 1) dx = Gamma(s) * zeta(s)
  //    int_0^infty x^(s-1) / (e^x + 1) dx = Gamma(s) * eta(s)
  if (den case Add(terms: [final d0, final d1])) {
    final expTerm = d0 is Pow && d0.base == Constant.e && d0.exponent == xVar
        ? d0
        : (d1 is Pow && d1.base == Constant.e && d1.exponent == xVar
              ? d1
              : null);
    final constTerm = expTerm == d0 ? d1 : d0;
    if (expTerm != null &&
        (constTerm == IntegerNumber.negativeOne ||
            constTerm == IntegerNumber.one)) {
      int? s;
      if (num == xVar) {
        s = 2;
      } else if (num
          case Pow(base: final b, exponent: IntegerNumber(asInt: final m?))
          when b == xVar && m >= 1 && m.isOdd && m <= 15) {
        s = m + 1;
      }
      if (s != null && s.isEven) {
        final factSMinus1 = IntegerNumber(Integer.from(s - 1).factorial());
        final zetaS = evenZetaValue(s);
        if (constTerm == IntegerNumber.negativeOne) {
          return (factSMinus1 * zetaS).simplify(assumptions: assumptions);
        } else {
          final etaFactor =
              (IntegerNumber.one -
                      Pow(IntegerNumber.two, IntegerNumber.of(1 - s)))
                  .simplify();
          return (factSMinus1 * etaFactor * zetaS).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  return null;
}

/// Definite trigonometric integrals evaluated over `[0, pi/2]` or `[0, pi]`.
Expr? definiteIntegralTrigDomain(
  Expr function,
  String variable,
  Expr toExpr, {
  required Assumptions assumptions,
}) {
  final xVar = Variable(variable);
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();

  // 1. Euler's log-sine / log-cosine integrals:
  //    int_0^(pi/2) ln(sin(x)) dx = int_0^(pi/2) ln(cos(x)) dx = -pi/2 * ln(2)
  //    int_0^pi ln(sin(x)) dx = -pi * ln(2)
  if (function case Ln(expr: Sin(expr: final inner)) when inner == xVar) {
    if (toExpr == halfPi) {
      return (-halfPi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
    if (toExpr == Constant.pi) {
      return (-Constant.pi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (function case Ln(expr: Cos(expr: final inner))
      when inner == xVar && toExpr == halfPi) {
    return (-halfPi * Ln(IntegerNumber.two)).simplify(assumptions: assumptions);
  }

  // 2. Wallis / Beta trigonometric integrals on [0, pi/2]:
  //    int_0^(pi/2) sin(x)^m * cos(x)^n dx = 1/2 * Beta((m+1)/2, (n+1)/2)
  if (toExpr == halfPi) {
    final factors = function is Mul ? function.factors : [function];
    Expr mExp = IntegerNumber.zero;
    Expr nExp = IntegerNumber.zero;
    var validWallis = true;
    for (final f in factors) {
      if (f case Sin(expr: final inner) when inner == xVar) {
        mExp = (mExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Cos(expr: final inner) when inner == xVar) {
        nExp = (nExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Pow(base: Sin(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        mExp = (mExp + exponent).simplify();
        continue;
      }
      if (f case Pow(base: Cos(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        nExp = (nExp + exponent).simplify();
        continue;
      }
      validWallis = false;
      break;
    }
    if (validWallis &&
        (mExp != IntegerNumber.zero || nExp != IntegerNumber.zero)) {
      final aArg = ((mExp + IntegerNumber.one) / IntegerNumber.two).simplify(
        assumptions: assumptions,
      );
      final bArg = ((nExp + IntegerNumber.one) / IntegerNumber.two).simplify(
        assumptions: assumptions,
      );
      if ((isPositiveExpr(aArg, assumptions: assumptions) ||
              isPositiveConstant(aArg)) &&
          (isPositiveExpr(bArg, assumptions: assumptions) ||
              isPositiveConstant(bArg))) {
        return (FractionNumber.half * Beta(aArg, bArg)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  return null;
}

/// Definite integrals evaluated over the unit interval `[0, 1]`.
Expr? definiteIntegralUnitInterval(
  Expr function,
  String variable, {
  required Assumptions assumptions,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Logarithmic zeta/eta integrals on [0, 1]:
  //    int_0^1 ln(x) / (1 - x) dx = -pi^2 / 6
  //    int_0^1 ln(x) / (1 + x) dx = -pi^2 / 12
  //    int_0^1 ln(1 + x) / x dx = pi^2 / 12
  //    int_0^1 ln(1 - x) / x dx = -pi^2 / 6
  if (num case Ln(expr: final lnArg) when lnArg == xVar) {
    if ((den - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
    if ((den - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
  }
  if (den == xVar && num is Ln) {
    if ((num.expr - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
    if ((num.expr - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. Euler Beta integral on [0, 1]:
  //    int_0^1 x^(a - 1) * (1 - x)^(b - 1) dx = Beta(a, b)
  final factors = function is Mul ? function.factors : [function];
  Expr aMinus1 = IntegerNumber.zero;
  Expr bMinus1 = IntegerNumber.zero;
  var hasOneMinusX = false;
  var validBeta = true;
  for (final f in factors) {
    if (f == xVar) {
      aMinus1 = (aMinus1 + IntegerNumber.one).simplify();
      continue;
    }
    if (f case Pow(base: final b, :final exponent)
        when b == xVar && !exponent.dependsOn(variable)) {
      aMinus1 = (aMinus1 + exponent).simplify();
      continue;
    }
    if ((f - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      bMinus1 = (bMinus1 + IntegerNumber.one).simplify();
      hasOneMinusX = true;
      continue;
    }
    if (f case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            (base - (IntegerNumber.one - xVar)).expand().simplify() ==
                IntegerNumber.zero) {
      bMinus1 = (bMinus1 + exponent).simplify();
      hasOneMinusX = true;
      continue;
    }
    validBeta = false;
    break;
  }
  if (validBeta && hasOneMinusX) {
    final aArg = (aMinus1 + IntegerNumber.one).simplify(
      assumptions: assumptions,
    );
    final bArg = (bMinus1 + IntegerNumber.one).simplify(
      assumptions: assumptions,
    );
    if ((isPositiveExpr(aArg, assumptions: assumptions) ||
            isPositiveConstant(aArg)) &&
        (isPositiveExpr(bArg, assumptions: assumptions) ||
            isPositiveConstant(bArg))) {
      return Beta(aArg, bArg).simplify(assumptions: assumptions);
    }
  }

  return null;
}
