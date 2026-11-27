import 'package:more/math.dart';

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/sign.dart' show isPositiveExpr, isProvenReal;
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
        : Mul.of(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul.of(varFactors).simplify(assumptions: assumptions);
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

  // Domain [0, pi/2], [0, pi], or [0, 2*pi]
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();
  final twoPi = (IntegerNumber.two * Constant.pi).simplify();
  if (fromExpr == IntegerNumber.zero &&
      (toExpr == halfPi || toExpr == Constant.pi || toExpr == twoPi)) {
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
  if (den == xVar && num is Call && num.id == FunctionId.sin) {
    if (num.args[0].matchLinear(variable) case (a: final slope, :final b)
        when b == IntegerNumber.zero && isProvenReal(slope, assumptions)) {
      return (Constant.pi / IntegerNumber.two * Fn.sign(slope)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (den case Pow(base: final b, exponent: IntegerNumber(asInt: 2))
      when b == xVar) {
    if (num case Pow(
      base: Call(id: FunctionId.sin, args: [final inner]),
      exponent: IntegerNumber(asInt: 2),
    )) {
      if (inner.matchLinear(variable) case (a: final slope, b: final shift)
          when shift == IntegerNumber.zero &&
              isProvenReal(slope, assumptions)) {
        return (Constant.pi / IntegerNumber.two * Fn.abs(slope)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 1b. Laplace-Dirichlet integral: exp(-a*x) * sin(b*x) / x -> atan(b / a)
  if (den == xVar) {
    final numFactors = num is Mul ? num.factors : [num];
    if (numFactors.length == 2) {
      final f0 = numFactors[0];
      final f1 = numFactors[1];
      final expFac = f0 is Pow && f0.base == Constant.e
          ? f0
          : (f1 is Pow && f1.base == Constant.e ? f1 : null);
      final sinFac = expFac == f0
          ? (f1 is Call && f1.id == FunctionId.sin ? f1 : null)
          : (f0 is Call && f0.id == FunctionId.sin ? f0 : null);
      if (expFac != null && sinFac != null) {
        final expLin = expFac.exponent.matchLinear(variable);
        final sinLin = sinFac.args[0].matchLinear(variable);
        if (expLin != null &&
            sinLin != null &&
            expLin.b == IntegerNumber.zero &&
            sinLin.b == IntegerNumber.zero) {
          final posA = (-expLin.a).simplify(assumptions: assumptions);
          if ((isPositiveConstant(posA) ||
                  isPositiveExpr(posA, assumptions: assumptions)) &&
              isProvenReal(sinLin.a, assumptions)) {
            return Fn.atan((sinLin.a / posA).simplify(assumptions: assumptions))
                .simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  // 1c. Frullani improper integrals on [0, infty):
  //     (e^(-a*x) - e^(-b*x)) / x = ln(b / a) for a, b > 0
  //     (atan(a*x) - atan(b*x)) / x = pi/2 * ln(a / b) for a, b > 0
  if (den == xVar && num is Add && num.terms.length == 2) {
    ({Expr? expDecay, Expr? atanSlope}) matchSingle(Expr t) {
      var sign = IntegerNumber.one as Expr;
      var core = t;
      if (core case Mul(:final factors) when factors.length == 2) {
        if (factors[0] == IntegerNumber.negativeOne) {
          sign = IntegerNumber.negativeOne;
          core = factors[1];
        } else if (factors[1] == IntegerNumber.negativeOne) {
          sign = IntegerNumber.negativeOne;
          core = factors[0];
        }
      }
      if (core case Pow(base: Constant.e, :final exponent)
          when exponent.matchLinear(variable) != null) {
        final lin = exponent.matchLinear(variable)!;
        if (lin.b == IntegerNumber.zero) {
          final posA = (-lin.a).simplify(assumptions: assumptions);
          if (isPositiveConstant(posA) ||
              isPositiveExpr(posA, assumptions: assumptions)) {
            return (
              expDecay: sign == IntegerNumber.one ? posA : null,
              atanSlope: null,
            );
          }
        }
      }
      if (core case Call(id: FunctionId.atan, args: [final expr])
          when expr.matchLinear(variable) != null) {
        final lin = expr.matchLinear(variable)!;
        if (lin.b == IntegerNumber.zero &&
            (isPositiveConstant(lin.a) ||
                isPositiveExpr(lin.a, assumptions: assumptions))) {
          return (
            expDecay: null,
            atanSlope: sign == IntegerNumber.one ? lin.a : null,
          );
        }
      }
      return (expDecay: null, atanSlope: null);
    }

    final t0 = num.terms[0];
    final t1 = num.terms[1];
    final m0Pos = matchSingle(t0);
    final m1Neg = matchSingle((-t1).simplify(assumptions: assumptions));
    if (m0Pos.expDecay != null && m1Neg.expDecay != null) {
      return Fn.ln(
        (m1Neg.expDecay! / m0Pos.expDecay!).simplify(assumptions: assumptions),
      ).simplify(assumptions: assumptions);
    }
    if (m0Pos.atanSlope != null && m1Neg.atanSlope != null) {
      return (Constant.pi /
              IntegerNumber.two *
              Fn.ln(
                (m0Pos.atanSlope! / m1Neg.atanSlope!).simplify(
                  assumptions: assumptions,
                ),
              ))
          .simplify(assumptions: assumptions);
    }
    final m1Pos = matchSingle(t1);
    final m0Neg = matchSingle((-t0).simplify(assumptions: assumptions));
    if (m1Pos.expDecay != null && m0Neg.expDecay != null) {
      return Fn.ln(
        (m0Neg.expDecay! / m1Pos.expDecay!).simplify(assumptions: assumptions),
      ).simplify(assumptions: assumptions);
    }
    if (m1Pos.atanSlope != null && m0Neg.atanSlope != null) {
      return (Constant.pi /
              IntegerNumber.two *
              Fn.ln(
                (m1Pos.atanSlope! / m0Neg.atanSlope!).simplify(
                  assumptions: assumptions,
                ),
              ))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. Fresnel integrals: sin(a*x^2) or cos(a*x^2) -> 1/4 * sqrt(2*pi / |a|)
  if (function case Call(
    id: FunctionId.sin || FunctionId.cos,
    args: [final inner],
  )) {
    final coeffs = extractPolynomialCoefficients(inner, variable);
    if (coeffs != null &&
        maxPolynomialDegree(coeffs) == 2 &&
        (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
        (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
      final a2 = coeffs[2] ?? IntegerNumber.zero;
      if (isProvenReal(a2, assumptions)) {
        final absA = Fn.abs(a2).simplify(assumptions: assumptions);
        if (isPositiveExpr(absA, assumptions: assumptions) ||
            isPositiveConstant(absA)) {
          final fresnelVal =
              (FractionNumber.quarter *
                      Pow.of(
                        (IntegerNumber.two * Constant.pi) / absA,
                        FractionNumber.half,
                      ))
                  .simplify(assumptions: assumptions);
          return function.id == FunctionId.sin
              ? (Fn.sign(a2) * fresnelVal).simplify(assumptions: assumptions)
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
      return (Fn.gamma(sPlus1) / Pow.of(expSlope, sPlus1)).simplify(
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
      return (FractionNumber.half * Fn.gamma(alpha) / Pow.of(gaussCoeff, alpha))
          .simplify(assumptions: assumptions);
    }
  }

  // 5. Bose-Einstein & Fermi-Dirac integrals:
  //    int_0^infty x^(s-1) / (e^x - 1) dx = Gamma(s) * zeta(s)
  //    int_0^infty x^(s-1) / (e^x + 1) dx = Gamma(s) * eta(s)
  //    int_0^infty x^(s-1) * (1 + e^(-x)) / (e^x - 1) dx = 2*Gamma(s)*zeta(s) - Gamma(s)
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
      int? extractEvenS(Expr nExpr) {
        if (nExpr == xVar) return 2;
        if (nExpr
            case Pow(base: final b, exponent: IntegerNumber(asInt: final m?))
            when b == xVar && m >= 1 && m.isOdd && m <= 15) {
          return m + 1;
        }
        return null;
      }

      var s = extractEvenS(num);
      var hasOnePlusExpNeg = false;
      if (s == null && constTerm == IntegerNumber.negativeOne && num is Mul) {
        final sParts = <Expr>[];
        var matchedFactor = false;
        for (final f in num.factors) {
          if (!matchedFactor &&
              (f - (IntegerNumber.one + Pow.of(Constant.e, -xVar))).simplify(
                    assumptions: assumptions,
                  ) ==
                  IntegerNumber.zero) {
            matchedFactor = true;
          } else {
            sParts.add(f);
          }
        }
        if (matchedFactor && sParts.length == 1) {
          s = extractEvenS(sParts.first);
          hasOnePlusExpNeg = s != null;
        }
      }
      if (s != null && s.isEven) {
        final factSMinus1 = IntegerNumber(BigInt.from(s - 1).factorial());
        final zetaS = evenZetaValue(s);
        if (hasOnePlusExpNeg) {
          return (IntegerNumber.two * factSMinus1 * zetaS - factSMinus1)
              .simplify(assumptions: assumptions);
        }
        if (constTerm == IntegerNumber.negativeOne) {
          return (factSMinus1 * zetaS).simplify(assumptions: assumptions);
        } else {
          final etaFactor =
              (IntegerNumber.one -
                      Pow.of(IntegerNumber.two, IntegerNumber.of(1 - s)))
                  .simplify();
          return (factSMinus1 * etaFactor * zetaS).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  // 6. Euler Beta II integral on [0, infty):
  //    int_0^infty c_n * x^s / (b * x + c)^d dx
  //      = c_n * c^(s + 1 - d) * b^(-(s + 1)) * Beta(s + 1, d - s - 1)
  {
    Expr numScale = IntegerNumber.one;
    Expr xExp = IntegerNumber.zero;
    var validNum = true;
    for (final f in num is Mul ? num.factors : [num]) {
      if (!f.dependsOn(variable)) {
        numScale = (numScale * f).simplify(assumptions: assumptions);
      } else if (f == xVar && xExp == IntegerNumber.zero) {
        xExp = IntegerNumber.one;
      } else if (f is Pow &&
          f.base == xVar &&
          !f.exponent.dependsOn(variable) &&
          xExp == IntegerNumber.zero) {
        xExp = f.exponent;
      } else {
        validNum = false;
        break;
      }
    }
    if (validNum && den != IntegerNumber.one) {
      Expr denScale = IntegerNumber.one;
      Expr? linBase;
      Expr? denExp;
      var validDen = true;
      for (final f in den is Mul ? den.factors : [den]) {
        if (!f.dependsOn(variable)) {
          denScale = (denScale * f).simplify(assumptions: assumptions);
        } else if (linBase == null && f.matchLinear(variable) != null) {
          linBase = f;
          denExp = IntegerNumber.one;
        } else if (linBase == null &&
            f is Pow &&
            !f.exponent.dependsOn(variable) &&
            f.base.matchLinear(variable) != null) {
          linBase = f.base;
          denExp = f.exponent;
        } else {
          validDen = false;
          break;
        }
      }
      if (validDen && linBase != null && denExp != null) {
        final lin = linBase.matchLinear(variable)!;
        final b = lin.a;
        final c = lin.b;
        final sPlus1 = (xExp + IntegerNumber.one).simplify(
          assumptions: assumptions,
        );
        final dMinusS1 = (denExp - sPlus1).simplify(assumptions: assumptions);
        bool isPos(Expr e) =>
            isPositiveConstant(e) ||
            isPositiveExpr(e, assumptions: assumptions);
        if (isPos(b) && isPos(c) && isPos(sPlus1) && isPos(dMinusS1)) {
          final pref =
              (numScale /
                      denScale *
                      Pow.of(c, (sPlus1 - denExp).simplify()) /
                      Pow.of(b, sPlus1))
                  .simplify(assumptions: assumptions);
          return (pref * Fn.beta(sPlus1, dMinusS1)).simplify(
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
  if (function
      case Call(
        id: FunctionId.ln,
        args: [Call(id: FunctionId.sin, args: [final inner])],
      )
      when inner == xVar) {
    if (toExpr == halfPi) {
      return (-halfPi * Fn.ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
    if (toExpr == Constant.pi) {
      return (-Constant.pi * Fn.ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (function
      case Call(
        id: FunctionId.ln,
        args: [Call(id: FunctionId.cos, args: [final inner])],
      )
      when inner == xVar && toExpr == halfPi) {
    return (-halfPi * Fn.ln(IntegerNumber.two)).simplify(
      assumptions: assumptions,
    );
  }

  // 1b. int_0^(pi/2) x * cot(x) dx = pi * ln(2) / 2
  if (toExpr == halfPi &&
      (function - (xVar * Fn.cos(xVar) / Fn.sin(xVar))).simplify() ==
          IntegerNumber.zero) {
    return (halfPi * Fn.ln(IntegerNumber.two)).simplify(
      assumptions: assumptions,
    );
  }

  // 2. Wallis / Beta trigonometric integrals on [0, pi/2], [0, pi], and [0, 2*pi]:
  //    int_0^(pi/2) sin(x)^m * cos(x)^n dx = 1/2 * Beta((m+1)/2, (n+1)/2)
  final twoPi = (IntegerNumber.two * Constant.pi).simplify();
  if (toExpr == halfPi || toExpr == Constant.pi || toExpr == twoPi) {
    final factors = function is Mul ? function.factors : [function];
    Expr mExp = IntegerNumber.zero;
    Expr nExp = IntegerNumber.zero;
    var validWallis = true;
    for (final f in factors) {
      if (f case Call(id: FunctionId.sin, args: [final inner])
          when inner == xVar) {
        mExp = (mExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Call(id: FunctionId.cos, args: [final inner])
          when inner == xVar) {
        nExp = (nExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f
          case Pow(
            base: Call(id: FunctionId.sin, args: [final inner]),
            :final exponent,
          )
          when inner == xVar && !exponent.dependsOn(variable)) {
        mExp = (mExp + exponent).simplify();
        continue;
      }
      if (f
          case Pow(
            base: Call(id: FunctionId.cos, args: [final inner]),
            :final exponent,
          )
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
        final qVal = (FractionNumber.half * Fn.beta(aArg, bArg)).simplify(
          assumptions: assumptions,
        );
        if (toExpr == halfPi) return qVal;
        final mInt = mExp is IntegerNumber ? mExp.asInt : null;
        final nInt = nExp is IntegerNumber ? nExp.asInt : null;
        if (mInt != null && nInt != null && mInt >= 0 && nInt >= 0) {
          if (toExpr == Constant.pi) {
            return nInt.isOdd
                ? IntegerNumber.zero
                : (IntegerNumber.two * qVal).simplify(assumptions: assumptions);
          }
          if (toExpr == twoPi) {
            return (mInt.isOdd || nInt.isOdd)
                ? IntegerNumber.zero
                : (IntegerNumber.of(4) * qVal).simplify(
                    assumptions: assumptions,
                  );
          }
        }
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
  if (num case Call(id: FunctionId.ln, args: [final lnArg])
      when lnArg == xVar) {
    if ((den - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
    if ((den - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
  }
  if (den == xVar && num is Call && num.id == FunctionId.ln) {
    if ((num.args[0] - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
    if ((num.args[0] - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
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
      return Fn.beta(aArg, bArg).simplify(assumptions: assumptions);
    }
  }

  // 3. Generalized Frullani / log-quotient on [0, 1]:
  //    int_0^1 (sum_i c_i * x^{m_i}) / ln(x) dx = sum_i c_i * ln(m_i + 1)
  //    when sum_i c_i == 0 and every m_i + 1 > 0.
  if (den case Call(id: FunctionId.ln, args: [final lnArg])
      when lnArg == xVar) {
    final expandedNum = num.expand().simplify(assumptions: assumptions);
    final numTerms = expandedNum is Add ? expandedNum.terms : [expandedNum];
    if (numTerms.length >= 2) {
      final decomposed = <({Expr coeff, Expr expPlus1})>[];
      var validFrullani = true;
      for (final term in numTerms) {
        final rawFactors = term is Mul ? term.factors : [term];
        final (:constFactors, :varFactors) = partitionFactors(
          rawFactors,
          variable,
        );
        final coeff = constFactors.isEmpty
            ? IntegerNumber.one
            : constFactors.length == 1
            ? constFactors.first
            : Mul.of(constFactors).simplify(assumptions: assumptions);
        Expr exponent;
        if (varFactors.isEmpty) {
          exponent = IntegerNumber.zero;
        } else if (varFactors.length == 1 && varFactors.first == xVar) {
          exponent = IntegerNumber.one;
        } else if (varFactors.length == 1 &&
            varFactors.first is Pow &&
            (varFactors.first as Pow).base == xVar &&
            !(varFactors.first as Pow).exponent.dependsOn(variable)) {
          exponent = (varFactors.first as Pow).exponent;
        } else {
          validFrullani = false;
          break;
        }
        final expPlus1 = (exponent + IntegerNumber.one).simplify(
          assumptions: assumptions,
        );
        if (!isPositiveConstant(expPlus1) &&
            !isPositiveExpr(expPlus1, assumptions: assumptions)) {
          validFrullani = false;
          break;
        }
        decomposed.add((coeff: coeff, expPlus1: expPlus1));
      }
      if (validFrullani) {
        final coeffSum = Add.of([for (final item in decomposed) item.coeff])
            .simplify(assumptions: assumptions);
        if (coeffSum == IntegerNumber.zero) {
          if (decomposed.length == 2) {
            return (decomposed[0].coeff *
                    Fn.ln(decomposed[0].expPlus1 / decomposed[1].expPlus1))
                .simplify(assumptions: assumptions);
          }
          return Add.of([
            for (final item in decomposed) item.coeff * Fn.ln(item.expPlus1),
          ]).simplify(assumptions: assumptions);
        }
      }
    }
  }

  return null;
}
