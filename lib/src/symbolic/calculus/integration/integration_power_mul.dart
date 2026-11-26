import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart';
import 'parts.dart';
import 'radical.dart';
import 'rational.dart';
import 'substitution.dart';
import 'trigonometric.dart';
import 'trigonometric_helpers.dart';

Expr antiDerivPow(
  Expr base,
  Expr exponent,
  Expr original,
  String variable, {
  required Assumptions assumptions,
}) {
  // Form: (ax + b)^n
  if (!exponent.dependsOn(variable)) {
    if (base.matchLinear(variable) case (:final a, b: _)) {
      if (exponent == IntegerNumber.negativeOne ||
          (exponent is RealNumber && exponent.value == -1.0)) {
        return (logAntiderivative(base, assumptions) / a).simplify(
          assumptions: assumptions,
        );
      }
      final nPlus1 = (exponent + IntegerNumber.one).simplify();
      final denom = (a * nPlus1).simplify();
      final numer = Pow(base, nPlus1).simplify();
      return (numer / denom).simplify();
    }
    // Standard trig powers: sin^2, cos^2, tan^2, sinh^2, cosh^2, tanh^2
    if (exponent == IntegerNumber.two ||
        (exponent is RealNumber && exponent.value == 2.0)) {
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two -
                  Sin(twoInner) / (const IntegerNumber(Integer(4)) * a))
              .simplify();
        }
        if (matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one - Cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
        }
      }
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two +
                  Sin(twoInner) / (const IntegerNumber(Integer(4)) * a))
              .simplify();
        }
        if (matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one + Cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
        }
      }
      if (base case Tan(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (Tan(inner) / a - xVar).simplify();
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Sinh(twoInner) / (const IntegerNumber(Integer(4)) * a) -
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Sinh(twoInner) / (const IntegerNumber(Integer(4)) * a) +
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
      if (base case Tanh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (xVar - Tanh(inner) / a).simplify();
        }
      }
    }
    // Higher trig/hyperbolic integer powers: sin^n, cos^n, sinh^n, cosh^n (3 <= n <= 10)
    if (exponent case IntegerNumber(asInt: final n?) when n >= 3 && n <= 10) {
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow(Sin(inner), nMinus1) * Cos(inner) / (nExpr * a))
              .simplify();
          final rem = antiDerivative(
            Pow(Sin(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cos(inner), nMinus1) * Sin(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cos(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Sinh(inner), nMinus1) * Cosh(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Sinh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Cosh(inner), nMinus1) * Sinh(inner) / (nExpr * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cosh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (nMinus1 / nExpr) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Tan(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow(Tan(inner), nMinus1) / (nMinus1 * a)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(Tan(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - rem).simplify(assumptions: assumptions);
          }
        }
      }
      if (base case Tanh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow(Tanh(inner), nMinus1) / (nMinus1 * a)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(Tanh(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify(assumptions: assumptions);
          }
        }
      }
    }
    // Negative powers of sin and cos: sin(ax+b)^(-k), cos(ax+b)^(-k) for 3 <= k <= 12
    if (exponent case IntegerNumber(asInt: final negK?)
        when negK <= -3 && negK >= -12) {
      final k = -negK;
      final km1 = IntegerNumber.of(k - 1);
      final km2 = IntegerNumber.of(k - 2);
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (Sin(inner) / (km1 * a * Pow(Cos(inner), km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Cos(inner), -km2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (km2 / km1) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (-Cos(inner) / (km1 * a * Pow(Sin(inner), km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow(Sin(inner), -km2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (km2 / km1) * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
    }
    // Powers of logarithms: ln(ax + b)^k for 2 <= k <= 6 and ln(ax + b)^(-k) for 2 <= k <= 6
    if (base case Ln(expr: final inner)) {
      if (exponent case IntegerNumber(asInt: final k?) when k >= 2 && k <= 6) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final kExpr = IntegerNumber.of(k);
          final term1 = ((inner / a) * original).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(
              base,
              IntegerNumber.of(k - 1),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - kExpr * rem).simplify(assumptions: assumptions);
          }
        }
      }
      if (exponent case IntegerNumber(asInt: final negK?)
          when negK <= -2 && negK >= -6) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final k = -negK;
          final km1 = IntegerNumber.of(k - 1);
          final term1 = (-inner / (a * km1 * Pow(base, km1))).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow(
              base,
              IntegerNumber.of(-(k - 1)),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem / km1).simplify(assumptions: assumptions);
          }
        }
      }
    }
    // Squares of inverse trig/hyperbolic functions: asin(ax+b)^2, acos(ax+b)^2, atan(ax+b)^2, ...
    if (exponent == IntegerNumber.two ||
        (exponent is RealNumber && exponent.value == 2.0)) {
      if (base is Asin ||
          base is Acos ||
          base is Atan ||
          base is Asinh ||
          base is Acosh ||
          base is Atanh) {
        final ibp = tryIntegrationByParts(
          IntegerNumber.one,
          original,
          variable,
          assumptions: assumptions,
        );
        if (ibp != null) return ibp;
      }
    }
    // Radical quadratic sqrt(a^2 - u^2) or sqrt(u^2 +- a^2) and (Ax^2 + Bx + C)^(n/2)
    if (exponent == FractionNumber.half ||
        (exponent is RealNumber && exponent.value == 0.5)) {
      final radQuad = tryRadicalQuadratic(base, variable);
      if (radQuad != null) return radQuad;
    }
    if (exponent is FractionNumber) {
      final combinedBase = base.together(assumptions: assumptions);
      if (combinedBase != base) {
        final combPow = Pow(
          combinedBase,
          exponent,
        ).simplify(assumptions: assumptions);
        if (combPow != original) {
          return antiDerivative(combPow, variable, assumptions: assumptions);
        }
      }
    }
    if (halfIntExponent(exponent) case final halfExp?) {
      final quadRad = tryQuadraticRadical(
        IntegerNumber.one,
        base,
        halfExp,
        variable,
      );
      if (quadRad != null) return quadRad;
    }
    if (exponent is IntegerNumber && exponent.value > Integer.one) {
      final expanded = original.expand().simplify(assumptions: assumptions);
      if (expanded != original) {
        return antiDerivative(expanded, variable, assumptions: assumptions);
      }
    }
    // Check if this is 1 / g(x) represented as g(x)^(-n)
    final isNegExp = switch (exponent) {
      RationalNumber(:final isNegative) => isNegative,
      RealNumber(:final value) => value < 0,
      _ => false,
    };
    if (isNegExp) {
      final posExp = (-exponent).simplify();
      final den = posExp == IntegerNumber.one ? base : Pow(base, posExp);
      final divRes = tryAntiDerivDiv(
        IntegerNumber.one,
        den,
        variable,
        assumptions: assumptions,
      );
      if (divRes != null) return divRes;
    }
  }

  // Form: c^(ax + b) or e^(ax + b) or Gaussian e^(-a*x^2 + b*x + c)
  if (!base.dependsOn(variable)) {
    if (exponent.matchLinear(variable) case (:final a, b: _)) {
      if (base == Constant.e) {
        return (original / a).simplify();
      }
      if (isValidExponentialBase(base)) {
        final denom = (a * Ln(base)).simplify();
        return (original / denom).simplify();
      }
    }
    if (base == Constant.e) {
      final gaussRes = tryGaussianAntiderivative(exponent, variable);
      if (gaussRes != null) return gaussRes;

      // e^(e^(a*x + b)) -> Ei(e^(a*x + b)) / a
      if (exponent case Pow(base: Constant.e, exponent: final innerExp)) {
        if (innerExp.matchLinear(variable) case (:final a, b: _)) {
          return (ExpIntegral(exponent) / a).simplify(assumptions: assumptions);
        }
      }

      // e^(a/x) -> x * e^(a/x) - a * Ei(a/x)
      final prod = (exponent * Variable(variable)).simplify();
      if (!prod.dependsOn(variable)) {
        return (Variable(variable) * original - prod * ExpIntegral(exponent))
            .simplify();
      }
    }
    // b^ln(x) -> x^ln(b)
    if (isValidExponentialBase(base)) {
      if (exponent case Ln(expr: Variable(:final name)) when name == variable) {
        final lnB = Ln(base).simplify(assumptions: assumptions);
        return antiDerivative(
          Pow(Variable(variable), lnB),
          variable,
          assumptions: assumptions,
        );
      }
    }
  }

  return unsupportedIntegral(original, variable);
}

Expr antiDerivMul(
  Mul original,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  // 1. Check if this product represents a quotient f(x) / g(x) where g depends on variable
  final (numExpr, denExpr) = splitNumeratorDenominator(original);
  if (denExpr != IntegerNumber.one && denExpr.dependsOn(variable)) {
    final divRes = tryAntiDerivDiv(
      numExpr,
      denExpr,
      variable,
      depth: depth,
      assumptions: assumptions,
    );
    if (divRes != null) return divRes;
  }

  // 2. Separate constant factors from variable-dependent factors
  final (:constFactors, :varFactors) = partitionFactors(
    original.factors,
    variable,
  );

  if (constFactors.isNotEmpty) {
    final constPart = constFactors.length == 1
        ? constFactors.first
        : Mul(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify(assumptions: assumptions);
    return antiDerivative(
      varPart,
      variable,
      assumptions: assumptions,
      depth: depth,
    ).scale(constPart);
  }

  // Fast-path for x^m * (a*x + b)^n with large integer n > 8 to avoid expansion.
  if (polynomialDegree(original, variable) != null &&
      varFactors.any(
        (f) =>
            f is Pow &&
            f.exponent is IntegerNumber &&
            (f.exponent as IntegerNumber).value > const Integer(8) &&
            f.base.matchLinear(variable) != null,
      )) {
    final binomRes = trySymbolicBinomialAffine(
      original,
      variable,
      assumptions: assumptions,
    );
    if (binomRes != null) return binomRes;
  }

  // Expand x^m * P(x) for symbolic or non-integer exponent m and polynomial P(x).
  if (varFactors.length >= 2) {
    final powIdx = varFactors.indexWhere(
      (f) =>
          f is Pow &&
          f.base is Variable &&
          (f.base as Variable).name == variable &&
          !f.exponent.dependsOn(variable),
    );
    if (powIdx != -1) {
      final powFactor = varFactors[powIdx] as Pow;
      final restFactors = <Expr>[
        for (var i = 0; i < varFactors.length; i++)
          if (i != powIdx) varFactors[i],
      ];
      final restExpr = restFactors.length == 1
          ? restFactors.first
          : Mul(restFactors).simplify(assumptions: assumptions);
      final deg = polynomialDegree(restExpr, variable);
      if (deg != null && deg <= 16) {
        final expandedPoly = restExpr.expand().simplify(
          assumptions: assumptions,
        );
        final terms = expandedPoly is Add ? expandedPoly.terms : [expandedPoly];
        if (terms.length > 1) {
          return Add([
            for (final t in terms)
              antiDerivative(
                (powFactor * t).simplify(assumptions: assumptions),
                variable,
                assumptions: assumptions,
                depth: depth,
              ),
          ]).simplify(assumptions: assumptions);
        }
      }
    }
  }

  // 3. Chain-rule substitution across any factor as candidate and remaining product as factor:
  for (var i = 0; i < varFactors.length; i++) {
    final candidate = varFactors[i];
    final others = <Expr>[
      for (var j = 0; j < varFactors.length; j++)
        if (i != j) varFactors[j],
    ];
    final otherExpr = others.length == 1
        ? others.first
        : Mul(others).simplify();
    if (tryChainRule(candidate, otherExpr, variable, assumptions: assumptions)
        case final subRes?) {
      return subRes;
    }
    if (candidate case Pow(
      base: Constant.e,
      exponent: Pow(base: Constant.e, exponent: final innerU),
    )) {
      final uPrime = innerU.derivative(variable).simplify();
      if (otherExpr.matchScalarMultiple(uPrime, variable) case final k?) {
        return (k * ExpIntegral(Pow(Constant.e, innerU))).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 3b. Product of sines and cosines:
  if (varFactors case [final f1, final f2]) {
    if (tryTrigProduct(f1, f2, variable) case final trigRes?) {
      return trigRes;
    }
  }
  if (varFactors.length == 2) {
    final (f0, f1) = (varFactors[0], varFactors[1]);
    final (Pow? xPow, Pow? expPow) =
        (f0 is Pow &&
            f0.base == Variable(variable) &&
            f1 is Pow &&
            f1.base == Constant.e)
        ? (f0, f1)
        : (f1 is Pow &&
              f1.base == Variable(variable) &&
              f0 is Pow &&
              f0.base == Constant.e)
        ? (f1, f0)
        : (null, null);
    if (xPow != null &&
        expPow != null &&
        xPow.exponent is! IntegerNumber &&
        !xPow.exponent.dependsOn(variable)) {
      if (expPow.exponent.matchLinear(variable) case (:final a, :final b)) {
        final s = xPow.exponent;
        return (-Pow(Constant.e, b) *
                Pow(Variable(variable), s + IntegerNumber.one) *
                ExpIntegralE(-s, -a * Variable(variable)))
            .simplify(assumptions: assumptions);
      }
    }
  }
  // Mixed hyperbolic-trigonometric products: rewrite sinh/cosh as exponentials
  final hasTrig = varFactors.any(
    (f) =>
        f is Sin || f is Cos || (f is Pow && (f.base is Sin || f.base is Cos)),
  );
  final hasHyp = varFactors.any(
    (f) =>
        f is Sinh ||
        f is Cosh ||
        (f is Pow && (f.base is Sinh || f.base is Cosh)),
  );
  if (depth < 2 && hasTrig && hasHyp) {
    Expr hypToExp(Expr e) {
      if (e case Sinh(:final expr)) {
        return (Pow(Constant.e, expr) - Pow(Constant.e, -expr)) /
            IntegerNumber.two;
      }
      if (e case Cosh(:final expr)) {
        return (Pow(Constant.e, expr) + Pow(Constant.e, -expr)) /
            IntegerNumber.two;
      }
      return e.mapChildren(hypToExp);
    }

    final rewritten = hypToExp(original)
        .expand()
        .simplify(assumptions: assumptions);
    if (rewritten != original) {
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }
  if (tryTrigPowerProduct(original, IntegerNumber.one, variable)
      case final trigPowRes?) {
    return trigPowRes;
  }
  if (trySymbolicTrigPowerProduct(original, variable, assumptions: assumptions)
      case final symTrigPowRes?) {
    return symTrigPowRes;
  }
  if (tryExpandTrigBinomialProduct(
        varFactors,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final trigBinomRes?) {
    return trigBinomRes;
  }

  // 3c. Linear polynomial times quadratic radical: (px + q) * (Ax^2 + Bx + C)^(k/2)
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i] case Pow(:final base, :final exponent)) {
      if (halfIntExponent(exponent) case final halfExp?) {
        final others = <Expr>[
          for (var j = 0; j < varFactors.length; j++)
            if (i != j) varFactors[j],
        ];
        final otherExpr = others.length == 1
            ? others.first
            : Mul(others).simplify();
        if (tryQuadraticRadical(otherExpr, base, halfExp, variable)
            case final quadRes?) {
          return quadRes;
        }
      }
    }
  }

  // 3d. Polynomial times trig power or trig product: P(x) * sin^n(u), P(x) * sin(ax)*cos(bx)
  if (tryPolyTrigPowerReduction(varFactors, variable) case final trigPolyRes?) {
    return trigPolyRes;
  }

  // 4. Integration by parts (try pairing one factor with the rest):
  if (varFactors case [final left, final right]) {
    if (tryIntegrationByParts(
          left,
          right,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final ibpLR?) {
      return ibpLR;
    }
    if (tryIntegrationByParts(
          right,
          left,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final ibpRL?) {
      return ibpRL;
    }
  } else {
    for (var i = 0; i < varFactors.length; i++) {
      final candidate = varFactors[i];
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = Mul(others).simplify(assumptions: assumptions);
      if (tryIntegrationByParts(
            candidate,
            otherExpr,
            variable,
            assumptions: assumptions,
            depth: depth,
          )
          case final ibp1?) {
        return ibp1;
      }
      if (tryIntegrationByParts(
            otherExpr,
            candidate,
            variable,
            assumptions: assumptions,
            depth: depth,
          )
          case final ibp2?) {
        return ibp2;
      }
    }
  }

  // 4b. Expand powered Add factors (2 <= m <= 4) when combined with inverse trig/hyperbolic functions:
  if (depth < 2) {
    bool isInvTrigOrHyp(Expr n) =>
        n is Asin ||
        n is Acos ||
        n is Atan ||
        n is Asinh ||
        n is Acosh ||
        n is Atanh;
    final hasPoweredAdd = varFactors.any(
      (f) =>
          f is Pow &&
          f.base is Add &&
          f.exponent is IntegerNumber &&
          ((f.exponent as IntegerNumber).asInt ?? 0) >= 2 &&
          ((f.exponent as IntegerNumber).asInt ?? 0) <= 4,
    );
    if (hasPoweredAdd && varFactors.any((f) => f.anyNode(isInvTrigOrHyp))) {
      final expandedFactors = <Expr>[
        for (final f in varFactors)
          if (f case Pow(base: Add(), exponent: IntegerNumber(asInt: final m?))
              when m >= 2 && m <= 4)
            f.expand(assumptions: assumptions)
          else
            f,
      ];
      final rewritten = Mul(expandedFactors).simplify(assumptions: assumptions);
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  // 5. Distributive expansion across additions:
  for (var i = 0; i < varFactors.length; i++) {
    if (varFactors[i] case Add(:final terms)) {
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = others.length == 1
          ? others.first
          : Mul(others).simplify(assumptions: assumptions);
      final (_, otherDen) = splitNumeratorDenominator(otherExpr);
      final hasVarDen = otherDen.dependsOn(variable);
      final distDepth = hasVarDen ? (depth >= 1 ? depth : 1) : depth;
      final distSum = Add([
        for (final t in terms)
          antiDerivative(
            (t * otherExpr).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
            depth: distDepth,
          ),
      ]).simplify(assumptions: assumptions);
      if (!hasVarDen || !hasUnevaluatedIntegral(distSum, variable)) {
        return distSum;
      }
      if (depth == 0) {
        final distAdd = Add([
          for (final t in terms)
            (t * otherExpr).simplify(assumptions: assumptions),
        ]);
        final paired = tryAdditiveProductRule(
          distAdd,
          variable,
          assumptions: assumptions,
        );
        if (paired != null) return paired;
      }
      break;
    }
  }

  // 6. Full polynomial expansion fallback (e.g. factored polynomials like (x-1)*(x-2)*(x+2)):
  if (!isIntegrationBudgetExhausted() &&
      !exceedsNodeBudget(original, 300) &&
      polynomialDegree(original, variable) != null) {
    final expanded = original.expand().simplify(assumptions: assumptions);
    if (expanded != original) {
      return antiDerivative(
        expanded,
        variable,
        assumptions: assumptions,
        depth: depth,
      );
    }
  }

  return unsupportedIntegral(original, variable);
}

Expr? tryAdditiveProductRule(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final terms = expr is Add ? expr.terms : [expr];
  final candidates = <Expr>{};
  void addCandidate(Expr e) {
    if (e.dependsOn(variable)) candidates.add(e);
  }

  for (final term in terms) {
    final factors = term is Mul ? term.factors : [term];
    for (final f in factors) {
      addCandidate(f);
      if (f case Sin(:final expr)) {
        addCandidate(Cos(expr));
      } else if (f case Cos(:final expr)) {
        addCandidate(Sin(expr));
      } else if (f case Pow(:final base, exponent: IntegerNumber(:final asInt?))
          when asInt < 0) {
        addCandidate(Pow(base, IntegerNumber.negativeOne));
        if (asInt < -1) {
          addCandidate(Pow(base, IntegerNumber.of(asInt + 1)));
        }
      }
    }
  }

  final candList = candidates.take(8).toList();
  for (final c in candList) {
    if (isIntegrationBudgetExhausted()) return null;
    final diff = (c.derivative(variable, assumptions: assumptions) - expr)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    if (diff is Number && diff.isZero) {
      return c.simplify(assumptions: assumptions);
    }
  }
  for (var i = 0; i < candList.length; i++) {
    for (var j = i; j < candList.length; j++) {
      if (isIntegrationBudgetExhausted()) return null;
      final prod = (candList[i] * candList[j]).simplify(
        assumptions: assumptions,
      );
      if (!prod.dependsOn(variable)) continue;
      final diff = (prod.derivative(variable, assumptions: assumptions) - expr)
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      if (diff is Number && diff.isZero) {
        return prod;
      }
    }
  }
  return null;
}

bool mayBeComplexExpr(Expr expr) => expr.anyNode(
  (node) =>
      node is ComplexNumber ||
      (node is Pow &&
          node.exponent is FractionNumber &&
          (node.exponent as FractionNumber).denominator.isEven &&
          (isSyntacticallyNegative(node.base) ||
              isNegativeConstant(node.base))) ||
      (node is Ln &&
          (isSyntacticallyNegative(node.expr) ||
              isNegativeConstant(node.expr))),
);

Expr stripAbs(Expr expr) => switch (expr) {
  Abs(:final expr) => stripAbs(expr),
  _ => expr.mapChildren(stripAbs),
};

Expr stripAbsInLn(Expr expr) => switch (expr) {
  Ln(:final expr) => Ln(stripAbs(expr)),
  _ => expr.mapChildren(stripAbsInLn),
};

Expr rewriteTanToSinCos(Expr node, String variable) {
  if (!node.dependsOn(variable)) return node;
  if (node case Tan(:final expr)) {
    return Sin(expr) * Pow(Cos(expr), IntegerNumber.negativeOne);
  }
  return node.mapChildren((c) => rewriteTanToSinCos(c, variable));
}

Expr? tryExpandTrigAtan(
  Expr node,
  String variable, {
  required Assumptions assumptions,
}) {
  final Expr inner;
  if (node case Sin(:final expr)) {
    inner = expr;
  } else if (node case Cos(:final expr)) {
    inner = expr;
  } else {
    return null;
  }
  if (inner
      case Mul(factors: [IntegerNumber(asInt: final k?), Atan(expr: final u)])
      when k >= 2 && k <= 6 && u.matchLinear(variable) != null) {
    return node
        .expandTrig(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  return null;
}

Expr rewritePowerLogIdentities(
  Expr node,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (!node.dependsOn(variable)) return node;
  final mapped = node.mapChildren(
    (c) => rewritePowerLogIdentities(c, variable, assumptions: assumptions),
  );
  if (mapped case Pow(:final base, :final exponent)) {
    // 1. u^(c / ln(u)) -> e^c
    final (expNum, expDen) = splitNumeratorDenominator(exponent);
    if (expDen case Ln(expr: final lnBase) when lnBase == base) {
      return Pow(Constant.e, expNum);
    }
    // 2. Nested variable power: (c * x^a)^b -> c^b * x^(a*b) when sound
    if (!exponent.dependsOn(variable)) {
      if (base is Variable && base.name == variable) return mapped;
      if (_extractMonomialVarPower(base, variable)
          case (:final scale, :final power)
          when exponent is IntegerNumber ||
              (isPositiveExpr(scale, assumptions: assumptions) &&
                  (power == IntegerNumber.one ||
                      power == IntegerNumber.negativeOne ||
                      (power is FractionNumber && power.denominator.isEven) ||
                      isPositiveExpr(
                        Variable(variable),
                        assumptions: assumptions,
                      )))) {
        return (Pow(scale, exponent) *
                Pow(Variable(variable), (power * exponent).simplify()))
            .simplify();
      }
    }
  }
  return mapped;
}

({Expr scale, Expr power})? _extractMonomialVarPower(
  Expr expr,
  String variable,
) {
  if (!expr.dependsOn(variable)) {
    return (scale: expr, power: IntegerNumber.zero);
  }
  if (expr is Variable && expr.name == variable) {
    return (scale: IntegerNumber.one, power: IntegerNumber.one);
  }
  if (expr case Pow(base: Variable(:final name), :final exponent)
      when name == variable && !exponent.dependsOn(variable)) {
    return (scale: IntegerNumber.one, power: exponent);
  }
  if (expr is Mul) {
    var scale = IntegerNumber.one as Expr;
    var power = IntegerNumber.zero as Expr;
    for (final f in expr.factors) {
      final sub = _extractMonomialVarPower(f, variable);
      if (sub == null) return null;
      scale = (scale * sub.scale).simplify();
      power = (power + sub.power).simplify();
    }
    return (scale: scale, power: power);
  }
  return null;
}
