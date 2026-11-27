import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/trig.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/sign.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart';
import 'parts.dart';
import 'radical.dart';
import 'rational.dart';
import 'substitution.dart';
import 'transcendental.dart';
import 'trigonometric.dart';
import 'trigonometric_helpers.dart';

Expr antiDerivPow(
  Expr base,
  Expr exponent,
  Expr original,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
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
      final numer = Pow.of(base, nPlus1).simplify();
      return (numer / denom).simplify();
    }
    if (tryMonomialPowerProduct(original, variable, assumptions: assumptions)
        case final monoPowRes?) {
      return monoPowRes;
    }
    // Standard trig powers: sin^2, cos^2, tan^2, sinh^2, cosh^2, tanh^2
    if (exponent == IntegerNumber.two ||
        (exponent is RealNumber && exponent.value == 2.0)) {
      if (base case Call(id: FunctionId.sin, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two -
                  Fn.sin(twoInner) / (IntegerNumber.of(4) * a))
              .simplify();
        }
        if (matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one - Fn.cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
        }
      }
      if (base case Call(id: FunctionId.cos, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (xVar / IntegerNumber.two +
                  Fn.sin(twoInner) / (IntegerNumber.of(4) * a))
              .simplify();
        }
        if (matchScaledSquare(inner, variable) != null) {
          const half = FractionNumber.half;
          final reduced =
              (half * (IntegerNumber.one + Fn.cos(IntegerNumber.two * inner)))
                  .simplify(assumptions: assumptions);
          return antiDerivative(
            reduced,
            variable,
            assumptions: assumptions,
            depth: 1,
          );
        }
      }
      if (base case Call(id: FunctionId.tan, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (Fn.tan(inner) / a - xVar).simplify();
        }
      }
      if (base case Call(id: FunctionId.sinh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Fn.sinh(twoInner) / (IntegerNumber.of(4) * a) -
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
      if (base case Call(id: FunctionId.cosh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          final twoInner = (IntegerNumber.two * inner).simplify();
          return (Fn.sinh(twoInner) / (IntegerNumber.of(4) * a) +
                  xVar / IntegerNumber.two)
              .simplify();
        }
      }
      if (base case Call(id: FunctionId.tanh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final xVar = Variable(variable);
          return (xVar - Fn.tanh(inner) / a).simplify();
        }
      }
    }
    // Higher trig/hyperbolic integer powers: sin^n, cos^n, sinh^n, cosh^n (3 <= n <= 10)
    if (exponent case IntegerNumber(asInt: final n?) when n >= 3 && n <= 10) {
      if (base case Call(:final id, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nExpr = IntegerNumber.of(n);
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final (
            Expr? coeff,
            Expr Function(Expr)? partner,
            Expr remSign,
          ) = switch (id) {
            FunctionId.sin => (
              -IntegerNumber.one,
              (Expr e) => Fn.cos(e),
              IntegerNumber.one,
            ),
            FunctionId.cos => (
              IntegerNumber.one,
              (Expr e) => Fn.sin(e),
              IntegerNumber.one,
            ),
            FunctionId.sinh => (
              IntegerNumber.one,
              (Expr e) => Fn.cosh(e),
              IntegerNumber.negativeOne,
            ),
            FunctionId.cosh => (
              IntegerNumber.one,
              (Expr e) => Fn.sinh(e),
              IntegerNumber.one,
            ),
            _ => (null, null, IntegerNumber.one),
          };
          if (coeff != null && partner != null) {
            final term1 =
                (coeff * Pow.of(base, nMinus1) * partner(inner) / (nExpr * a))
                    .simplify(assumptions: assumptions);
            final rem = antiDerivative(
              Pow.of(base, nMinus2).simplify(assumptions: assumptions),
              variable,
              assumptions: assumptions,
            );
            if (!hasUnevaluatedIntegral(rem, variable)) {
              return (term1 + remSign * (nMinus1 / nExpr) * rem).simplify(
                assumptions: assumptions,
              );
            }
          }
        }
      }
      if (base case Call(id: FunctionId.tan, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (Pow.of(Fn.tan(inner), nMinus1) / (nMinus1 * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow.of(Fn.tan(inner), nMinus2).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - rem).simplify(assumptions: assumptions);
          }
        }
      }
      if (base case Call(id: FunctionId.tanh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final nMinus1 = IntegerNumber.of(n - 1);
          final nMinus2 = IntegerNumber.of(n - 2);
          final term1 = (-Pow.of(Fn.tanh(inner), nMinus1) / (nMinus1 * a))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow.of(Fn.tanh(inner), nMinus2).simplify(assumptions: assumptions),
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
      if (base case Call(id: FunctionId.cos, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (Fn.sin(inner) / (km1 * a * Pow.of(Fn.cos(inner), km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow.of(Fn.cos(inner), -km2).simplify(assumptions: assumptions),
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
      if (base case Call(id: FunctionId.sin, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (-Fn.cos(inner) / (km1 * a * Pow.of(Fn.sin(inner), km1)))
                  .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow.of(Fn.sin(inner), -km2).simplify(assumptions: assumptions),
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
    // Powers of logarithms and affine-log forms: (A + B*ln(c*(ax+b)^n))^k
    if (_matchAffineLogPowerBase(base, variable) case final logInfo?) {
      final (:aConst, :bConst, :linBase, :linSlope, :logArg, :nExp) = logInfo;
      final effB = (bConst * nExp).simplify(assumptions: assumptions);
      if (!(effB is Number && effB.isZero)) {
        if (exponent case IntegerNumber(asInt: final k?)
            when k >= 2 && k <= 6) {
          final kExpr = IntegerNumber.of(k);
          final term1 = ((linBase / linSlope) * original).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            Pow.of(
              base,
              IntegerNumber.of(k - 1),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
            depth: depth + 1,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - kExpr * effB * rem).simplify(
              assumptions: assumptions,
            );
          }
        }
        if ((exponent == IntegerNumber.negativeOne ||
                (exponent is RealNumber && exponent.value == -1.0)) &&
            !(aConst is Number &&
                aConst.isZero &&
                bConst == IntegerNumber.one &&
                nExp == IntegerNumber.one)) {
          final p = (IntegerNumber.one / nExp).simplify(
            assumptions: assumptions,
          );
          final scale =
              (linBase /
                      (linSlope * effB * Pow.of(logArg, p)) *
                      Pow.of(Constant.e, (-p * aConst / bConst).simplify()))
                  .simplify(assumptions: assumptions);
          return (scale *
                  Fn.ei((p * base / bConst).simplify(assumptions: assumptions)))
              .simplify(assumptions: assumptions);
        }
        if (exponent case IntegerNumber(asInt: final negK?)
            when negK <= -2 && negK >= -6) {
          final k = -negK;
          final km1 = IntegerNumber.of(k - 1);
          final term1 = (-linBase / (linSlope * effB * km1 * Pow.of(base, km1)))
              .simplify(assumptions: assumptions);
          final rem = antiDerivative(
            Pow.of(
              base,
              IntegerNumber.of(-(k - 1)),
            ).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
            depth: depth + 1,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem / (effB * km1)).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
    }
    // Powers 2..3 of inverse trig/hyperbolic functions: asin(ax+b)^2, acos(ax+b)^3, ...
    if (exponent == IntegerNumber.two ||
        exponent == IntegerNumber.of(3) ||
        (exponent is RealNumber &&
            (exponent.value == 2.0 || exponent.value == 3.0))) {
      if (base is Call && _inverseTrigHypIds.contains(base.id)) {
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
        final combPow = Pow.of(
          combinedBase,
          exponent,
        ).simplify(assumptions: assumptions);
        if (combPow != original && depth < 4) {
          return antiDerivative(
            combPow,
            variable,
            assumptions: assumptions,
            depth: depth + 1,
          );
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
    if (exponent is IntegerNumber && exponent.value > BigInt.one) {
      final expanded = original.expand().simplify(assumptions: assumptions);
      if (expanded != original && depth < 4) {
        return antiDerivative(
          expanded,
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
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
      final den = posExp == IntegerNumber.one ? base : Pow.of(base, posExp);
      final divRes = tryAntiDerivDiv(
        IntegerNumber.one,
        den,
        variable,
        depth: depth,
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
        final denom = (a * Fn.ln(base)).simplify();
        return (original / denom).simplify();
      }
    }
    if (base == Constant.e) {
      final gaussRes = tryGaussianAntiderivative(exponent, variable);
      if (gaussRes != null) return gaussRes;

      // e^(e^(a*x + b)) -> Ei(e^(a*x + b)) / a
      if (exponent case Pow(base: Constant.e, exponent: final innerExp)) {
        if (innerExp.matchLinear(variable) case (:final a, b: _)) {
          return (Fn.ei(exponent) / a).simplify(assumptions: assumptions);
        }
      }

      // e^(a/x) -> x * e^(a/x) - a * Ei(a/x)
      final prod = (exponent * Variable(variable)).simplify();
      if (!prod.dependsOn(variable)) {
        return (Variable(variable) * original - prod * Fn.ei(exponent))
            .simplify();
      }
    }
    // b^ln(x) -> x^ln(b)
    if (isValidExponentialBase(base)) {
      if (exponent case Call(id: FunctionId.ln, args: [Variable(:final name)])
          when name == variable) {
        final lnB = Fn.ln(base).simplify(assumptions: assumptions);
        return antiDerivative(
          Pow.of(Variable(variable), lnB),
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
    final hasCompoundExpLnDen =
        (denExpr is Add ||
            (denExpr is Pow && denExpr.base is Add) ||
            (denExpr is Mul &&
                denExpr.factors.any(
                  (f) => f is Add || (f is Pow && f.base is Add),
                ))) &&
        denExpr.anyNode(
          (n) =>
              (n is Call &&
                  n.id == FunctionId.ln &&
                  n.args[0].dependsOn(variable)) ||
              (n is Pow &&
                  n.base == Constant.e &&
                  n.exponent.dependsOn(variable)),
        );
    if (hasCompoundExpLnDen) {
      if (tryTranscendentalTower(
            original,
            variable,
            assumptions: assumptions,
            depth: depth,
          )
          case final towerRes?) {
        return towerRes;
      }
    }
    if (depth < 2 &&
        !original.anyNode(
          (n) => n is Call && _trigAndInverseTrigHypIds.contains(n.id),
        )) {
      final expTerms = <Expr>[];
      final otherFactors = <Expr>[];
      for (final f in original.factors) {
        if (f case Pow(:final base, :final exponent)
            when base == Constant.e && exponent.dependsOn(variable)) {
          expTerms.add(exponent);
        } else {
          otherFactors.add(f);
        }
      }
      if (expTerms.isNotEmpty) {
        final g = expTerms.length == 1
            ? expTerms.first
            : Add.of(expTerms).simplify(assumptions: assumptions);
        final cofactor = otherFactors.isEmpty
            ? IntegerNumber.one
            : (otherFactors.length == 1
                  ? otherFactors.first
                  : Mul.of(otherFactors).simplify(assumptions: assumptions));
        if (tryExpRischOde(cofactor, g, variable, assumptions: assumptions)
            case final odeRes?) {
          return odeRes;
        }
      }
    }
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
        : Mul.of(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul.of(varFactors).simplify(assumptions: assumptions);
    return antiDerivative(
      varPart,
      variable,
      assumptions: assumptions,
      depth: depth,
    ).scale(constPart);
  }

  if (tryMonomialPowerProduct(original, variable, assumptions: assumptions)
      case final monoPowRes?) {
    return monoPowRes;
  }

  // Fast-path for x^m * (a*x + b)^n with large integer n > 8 to avoid expansion.
  if (polynomialDegree(original, variable) != null &&
      varFactors.any(
        (f) =>
            f is Pow &&
            f.exponent is IntegerNumber &&
            (f.exponent as IntegerNumber).value > BigInt.from(8) &&
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
          : Mul.of(restFactors).simplify(assumptions: assumptions);
      final deg = polynomialDegree(restExpr, variable);
      if (deg != null && deg <= 16) {
        final expandedPoly = restExpr.expand().simplify(
          assumptions: assumptions,
        );
        final terms = expandedPoly is Add ? expandedPoly.terms : [expandedPoly];
        if (terms.length > 1) {
          return Add.of([
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
    if (isIntegrationBudgetExhausted()) {
      return unsupportedIntegral(original, variable);
    }
    final candidate = varFactors[i];
    final others = <Expr>[
      for (var j = 0; j < varFactors.length; j++)
        if (i != j) varFactors[j],
    ];
    final otherExpr = others.length == 1
        ? others.first
        : Mul.of(others).simplify();
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
        return (k * Fn.ei(Pow.of(Constant.e, innerU))).simplify(
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
        return (-Pow.of(Constant.e, b) *
                Pow.of(Variable(variable), s + IntegerNumber.one) *
                Fn.expIntegralE(-s, -a * Variable(variable)))
            .simplify(assumptions: assumptions);
      }
    }
  }
  // Mixed hyperbolic-trigonometric products: rewrite sinh/cosh as exponentials
  bool isSinOrCos(Expr n) =>
      n is Call && (n.id == FunctionId.sin || n.id == FunctionId.cos);
  bool isSinhOrCosh(Expr n) =>
      n is Call && (n.id == FunctionId.sinh || n.id == FunctionId.cosh);
  final hasTrig = varFactors.any(
    (f) => isSinOrCos(f) || (f is Pow && isSinOrCos(f.base)),
  );
  final hasHyp = varFactors.any(
    (f) => isSinhOrCosh(f) || (f is Pow && isSinhOrCosh(f.base)),
  );
  if (depth < 2 && hasTrig && hasHyp) {
    Expr hypToExp(Expr e) {
      if (e case Call(id: FunctionId.sinh, args: [final expr])) {
        return (Pow.of(Constant.e, expr) - Pow.of(Constant.e, -expr)) /
            IntegerNumber.two;
      }
      if (e case Call(id: FunctionId.cosh, args: [final expr])) {
        return (Pow.of(Constant.e, expr) + Pow.of(Constant.e, -expr)) /
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
  if (tryHypPowerProduct(
        original,
        IntegerNumber.one,
        variable,
        assumptions: assumptions,
      )
      case final hypPowRes?) {
    return hypPowRes;
  }
  if (trySymbolicTrigPowerProduct(original, variable, assumptions: assumptions)
      case final symTrigPowRes?) {
    return symTrigPowRes;
  }
  if (tryOddTrigHypSubstitution(
        original,
        variable,
        assumptions: assumptions,
        depth: depth,
      )
      case final oddTrigHypRes?) {
    return oddTrigHypRes;
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
    if (isIntegrationBudgetExhausted()) {
      return unsupportedIntegral(original, variable);
    }
    if (varFactors[i] case Pow(:final base, :final exponent)) {
      if (halfIntExponent(exponent) case final halfExp?) {
        final others = <Expr>[
          for (var j = 0; j < varFactors.length; j++)
            if (i != j) varFactors[j],
        ];
        final otherExpr = others.length == 1
            ? others.first
            : Mul.of(others).simplify();
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
  if (tryShiftAngleTrigPowerDerivative(
        varFactors,
        variable,
        assumptions: assumptions,
      )
      case final shiftTrigRes?) {
    return shiftTrigRes;
  }

  // 3e. Linear-power times affine-log-power: (d*x + e)^m * (A + B*ln(c*(a*x+b)^n))^k
  if (depth < 3 && varFactors.length == 2) {
    final affineLogMul =
        _tryIntegrateLinearPowTimesAffineLogPow(
          varFactors[0],
          varFactors[1],
          variable,
          assumptions: assumptions,
          depth: depth,
        ) ??
        _tryIntegrateLinearPowTimesAffineLogPow(
          varFactors[1],
          varFactors[0],
          variable,
          assumptions: assumptions,
          depth: depth,
        );
    if (affineLogMul != null) {
      return affineLogMul;
    }
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
      if (isIntegrationBudgetExhausted()) {
        return unsupportedIntegral(original, variable);
      }
      final candidate = varFactors[i];
      final others = <Expr>[
        for (var j = 0; j < varFactors.length; j++)
          if (i != j) varFactors[j],
      ];
      final otherExpr = Mul.of(others).simplify(assumptions: assumptions);
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

  // 4b. Expand powered Add factors (2 <= m <= 4) when combined with inverse trig/hyperbolic or log functions:
  if (depth < 2) {
    bool isInvTrigOrHyp(Expr n) =>
        n is Call &&
        (_inverseTrigHypIds.contains(n.id) || n.id == FunctionId.ln);
    bool hasLnNode(Expr e) =>
        e.anyNode((n) => n is Call && n.id == FunctionId.ln);
    final hasPoweredAdd = varFactors.any(
      (f) =>
          f is Pow &&
          f.base is Add &&
          f.exponent is IntegerNumber &&
          ((f.exponent as IntegerNumber).asInt ?? 0) >= 2 &&
          ((f.exponent as IntegerNumber).asInt ?? 0) <= 4 &&
          !hasLnNode(f.base),
    );
    if (hasPoweredAdd && varFactors.any((f) => f.anyNode(isInvTrigOrHyp))) {
      final expandedFactors = <Expr>[
        for (final f in varFactors)
          if (f case Pow(base: Add(), exponent: IntegerNumber(asInt: final m?))
              when m >= 2 && m <= 4 && !hasLnNode(f.base))
            f.expand(assumptions: assumptions)
          else
            f,
      ];
      final rewritten = Mul.of(expandedFactors)
          .simplify(assumptions: assumptions);
      final res = antiDerivative(
        rewritten,
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }

    // 4c. Partial-fraction decomposition of rational cofactors multiplied by
    // inverse trig/hyperbolic or logarithmic factors:
    bool isStandaloneOrAffineInvFn(Expr n) {
      var core = n;
      if (core case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
          when k >= 1 && k <= 4) {
        core = base;
      }
      if (isInvTrigOrHyp(core)) {
        return true;
      }
      if (core case Add(:final terms) when terms.length == 2) {
        final vTerms = [
          for (final t in terms)
            if (t.dependsOn(variable)) t,
        ];
        if (vTerms.length != 1) return false;
        final vt = vTerms.first;
        if (isInvTrigOrHyp(vt)) {
          return true;
        }
        if (vt case Mul(:final factors)) {
          final vfs = [
            for (final mf in factors)
              if (mf.dependsOn(variable)) mf,
          ];
          if (vfs.length == 1) {
            return isInvTrigOrHyp(vfs.first);
          }
        }
      }
      return false;
    }

    for (var i = 0; i < varFactors.length; i++) {
      final invFactor = varFactors[i];
      if (!isStandaloneOrAffineInvFn(invFactor)) continue;
      final rest = <Expr>[
        ...constFactors,
        for (var j = 0; j < varFactors.length; j++)
          if (j != i) varFactors[j],
      ];
      if (rest.isEmpty) continue;
      final rationalCofactor = rest.length == 1
          ? rest.first
          : Mul.of(rest).simplify(assumptions: assumptions);
      final (rNum, rDen) = splitNumeratorDenominator(rationalCofactor);
      if (!rDen.dependsOn(variable)) continue;
      final rNumExp = rNum.expand().simplify(assumptions: assumptions);
      final rDenExp = rDen.expand().simplify(assumptions: assumptions);
      final degN = polynomialDegree(rNumExp, variable);
      final degD = polynomialDegree(rDenExp, variable);
      if (degN != null && degD != null && degN <= 8 && degD >= 1 && degD <= 8) {
        final apartCofactor = rationalCofactor.apart(variable);
        if (apartCofactor is Add) {
          final partTerms = <Expr>[];
          var allOk = true;
          for (final t in apartCofactor.terms) {
            final tInt = antiDerivative(
              (invFactor * t).simplify(assumptions: assumptions),
              variable,
              assumptions: assumptions,
              depth: depth + 1,
            );
            if (hasUnevaluatedIntegral(tInt, variable)) {
              allOk = false;
              break;
            }
            partTerms.add(tInt);
          }
          if (allOk) {
            return Add.of(partTerms).simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  // 4d. Try self-power exponential tower before distributing across Add:
  if (depth < 2 &&
      varFactors.any(
        (f) =>
            f is Pow &&
            f.base != Constant.e &&
            f.base.dependsOn(variable) &&
            f.exponent.dependsOn(variable),
      )) {
    if (tryTranscendentalTower(
          original,
          variable,
          assumptions: assumptions,
          depth: depth,
        )
        case final towerRes?) {
      return towerRes;
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
          : Mul.of(others).simplify(assumptions: assumptions);
      final (_, otherDen) = splitNumeratorDenominator(otherExpr);
      final hasVarDen = otherDen.dependsOn(variable);
      if (hasVarDen && terms.length > 12 && exceedsNodeBudget(otherExpr, 120)) {
        break;
      }
      final distDepth = hasVarDen ? (depth >= 1 ? depth : 1) : depth;
      final distTerms = <Expr>[];
      for (final t in terms) {
        if (isIntegrationBudgetExhausted()) {
          return unsupportedIntegral(original, variable);
        }
        distTerms.add(
          antiDerivative(
            (t * otherExpr).simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
            depth: distDepth,
          ),
        );
      }
      final distSum = Add.of(distTerms).simplify(assumptions: assumptions);
      final distHasIntegral = hasUnevaluatedIntegral(distSum, variable);
      if (!distHasIntegral) {
        return distSum;
      }
      if (depth == 0) {
        final distAdd = Add.of([
          for (final t in terms)
            (t * otherExpr).simplify(assumptions: assumptions),
        ]).expand(assumptions: assumptions).simplify(assumptions: assumptions);
        final paired = tryAdditiveProductRule(
          distAdd,
          variable,
          assumptions: assumptions,
        );
        if (paired != null) return paired;
      }
      if (!hasVarDen) {
        return distSum;
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
  if (isIntegrationBudgetExhausted() || exceedsNodeBudget(expr, 350)) {
    return null;
  }
  final terms = expr is Add ? expr.terms : [expr];
  if (terms.length > 12) return null;
  if (_tryLinearExpTranscendentalElimination(terms, variable, assumptions)
      case final expElim?) {
    return expElim;
  }
  final candidates = <Expr>{};
  void addCandidate(Expr e) {
    if (e.dependsOn(variable)) candidates.add(e);
  }

  for (final term in terms) {
    final factors = term is Mul ? term.factors : [term];
    for (final f in factors) {
      addCandidate(f);
      if (f case Call(id: FunctionId.sin, args: [final expr])) {
        addCandidate(Fn.cos(expr));
      } else if (f case Call(id: FunctionId.cos, args: [final expr])) {
        addCandidate(Fn.sin(expr));
      } else if (f case Pow(:final base, exponent: IntegerNumber(:final asInt?))
          when asInt < 0) {
        addCandidate(Pow.of(base, IntegerNumber.negativeOne));
        if (asInt < -1) {
          addCandidate(Pow.of(base, IntegerNumber.of(asInt + 1)));
        }
      }
    }
  }

  final candList = candidates.take(8).toList();
  for (final c in candList) {
    if (isIntegrationBudgetExhausted()) return null;
    final rawDiff = (c.derivative(variable, assumptions: assumptions) - expr)
        .simplify(assumptions: assumptions);
    if (rawDiff is Number && rawDiff.isZero) {
      return c.simplify(assumptions: assumptions);
    }
    if (!exceedsNodeBudget(rawDiff, 300)) {
      final diff = rawDiff
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      if (diff is Number && diff.isZero) {
        return c.simplify(assumptions: assumptions);
      }
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

Expr? _tryLinearExpTranscendentalElimination(
  List<Expr> terms,
  String variable,
  Assumptions assumptions,
) {
  Expr? commonExp;
  Expr? expDeriv;
  final remainderTerms = <Expr>[];
  for (final term in terms) {
    final factors = term is Mul ? term.factors : [term];
    Pow? expFactor;
    final rest = <Expr>[];
    for (final f in factors) {
      if (expFactor == null &&
          f is Pow &&
          f.base == Constant.e &&
          f.exponent.dependsOn(variable)) {
        expFactor = f;
      } else {
        rest.add(f);
      }
    }
    if (expFactor == null) return null;
    if (commonExp == null) {
      commonExp = expFactor;
      expDeriv = expFactor.exponent
          .derivative(variable, assumptions: assumptions)
          .simplify(assumptions: assumptions);
      if (expDeriv.dependsOn(variable) ||
          (expDeriv is Number && expDeriv.isZero)) {
        return null;
      }
    } else if (commonExp != expFactor) {
      return null;
    }
    remainderTerms.add(
      rest.isEmpty ? IntegerNumber.one : Mul.of(rest).simplify(),
    );
  }
  if (commonExp == null || expDeriv == null) return null;

  var remaining = Add.of(remainderTerms)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  bool hasInvTrigOrLog(Expr e) => e.anyNode(
    (n) =>
        n is Call &&
        n.args.isNotEmpty &&
        n.args.first.dependsOn(variable) &&
        (n.id == FunctionId.ln ||
            n.id == FunctionId.atan ||
            n.id == FunctionId.asin ||
            n.id == FunctionId.acos ||
            n.id == FunctionId.asinh ||
            n.id == FunctionId.acosh ||
            n.id == FunctionId.atanh),
  );
  if (!hasInvTrigOrLog(remaining)) return null;

  Expr yAcc = IntegerNumber.zero;
  for (var step = 0; step < 8; step++) {
    if (remaining is Number && remaining.isZero) {
      return (yAcc * commonExp).simplify(assumptions: assumptions);
    }
    final remTerms = remaining is Add ? remaining.terms : [remaining];
    Expr? bestTerm;
    var bestXDeg = -1;
    var bestScore = -1;
    for (final rt in remTerms) {
      if (!hasInvTrigOrLog(rt)) continue;
      final factors = rt is Mul ? rt.factors : [rt];
      var xDeg = 0;
      for (final f in factors) {
        if (f is Variable && f.name == variable) {
          xDeg += 1;
        } else if (f
            case Pow(
              base: Variable(:final name),
              exponent: IntegerNumber(asInt: final e?),
            )
            when name == variable && e > 0) {
          xDeg += e;
        }
      }
      final score =
          rt is Mul && rt.factors.any((f) => f is Call && f.id == FunctionId.ln)
          ? 2
          : 1;
      if (score > bestScore || (score == bestScore && xDeg > bestXDeg)) {
        bestScore = score;
        bestXDeg = xDeg;
        bestTerm = rt;
      }
    }
    if (bestTerm == null) break;
    final stepY = (bestTerm / expDeriv).simplify(assumptions: assumptions);
    yAcc = (yAcc + stepY).simplify(assumptions: assumptions);
    final contrib =
        (stepY.derivative(variable, assumptions: assumptions) +
                expDeriv * stepY)
            .expand(assumptions: assumptions)
            .simplify(assumptions: assumptions);
    remaining = (remaining - contrib)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    if (exceedsNodeBudget(remaining, 350)) return null;
  }
  if (remaining is Number && remaining.isZero) {
    return (yAcc * commonExp).simplify(assumptions: assumptions);
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
      (node is Call &&
          node.id == FunctionId.ln &&
          (isSyntacticallyNegative(node.args[0]) ||
              isNegativeConstant(node.args[0]))),
);

Expr stripAbs(Expr expr) => switch (expr) {
  Call(id: FunctionId.abs, args: [final expr]) => stripAbs(expr),
  _ => expr.mapChildren(stripAbs),
};

Expr stripAbsInLn(Expr expr) => switch (expr) {
  Call(id: FunctionId.ln, args: [final expr]) => Fn.ln(stripAbs(expr)),
  _ => expr.mapChildren(stripAbsInLn),
};

Expr rewriteTanToSinCos(Expr node, String variable) {
  if (!node.dependsOn(variable)) return node;
  if (node case Call(id: FunctionId.tan, args: [final expr])) {
    return Fn.sin(expr) * Pow.of(Fn.cos(expr), IntegerNumber.negativeOne);
  }
  return node.mapChildren((c) => rewriteTanToSinCos(c, variable));
}

Expr? tryExpandTrigAtan(
  Expr node,
  String variable, {
  required Assumptions assumptions,
}) {
  if (node is! Call || node.args.length != 1) return null;
  if (node.id != FunctionId.sin && node.id != FunctionId.cos) return null;
  final inner = node.args[0];
  if (inner
      case Mul(
        factors: [
          IntegerNumber(asInt: final k?),
          Call(id: FunctionId.atan, args: [final u]),
        ],
      )
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
    if (expDen case Call(id: FunctionId.ln, args: [final lnBase])
        when lnBase == base) {
      return Pow.of(Constant.e, expNum);
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
        return (Pow.of(scale, exponent) *
                Pow.of(Variable(variable), (power * exponent).simplify()))
            .simplify();
      }
    }
  }
  return mapped;
}

/// Rewrites `exp(c + k * fn(u))` for inverse hyperbolic and inverse
/// trigonometric functions (`atanh`, `atan`, `asinh`, `acosh`) into algebraic
/// powers or rational factors and integrates via [antiDerivative].
Expr? tryRewriteExpInverseTrigHyp(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 2) return null;
  var changed = false;

  Expr rewriteExp(Expr node) {
    if (!node.dependsOn(variable)) return node;
    if (node case Pow(base: Constant.e, exponent: final exp)
        when exp.dependsOn(variable)) {
      final terms = exp is Add ? exp.terms : [exp];
      final constTerms = <Expr>[];
      final varTerms = <Expr>[];
      for (final t in terms) {
        if (t.dependsOn(variable)) {
          varTerms.add(t);
        } else {
          constTerms.add(t);
        }
      }
      if (varTerms.length == 1) {
        var coeff = IntegerNumber.one as Expr;
        Call? fnNode;
        final vt = varTerms.first;
        bool isExpInvFn(Expr e) =>
            e is Call &&
            (e.id == FunctionId.atanh ||
                e.id == FunctionId.atan ||
                e.id == FunctionId.asinh ||
                e.id == FunctionId.acosh);
        if (isExpInvFn(vt)) {
          fnNode = vt as Call;
        } else if (vt is Mul) {
          final cParts = <Expr>[];
          final vParts = <Expr>[];
          for (final mf in vt.factors) {
            if (mf.dependsOn(variable)) {
              vParts.add(mf);
            } else {
              cParts.add(mf);
            }
          }
          if (vParts.length == 1) {
            final vf = vParts.first;
            if (isExpInvFn(vf)) {
              fnNode = vf as Call;
              coeff = cParts.isEmpty
                  ? IntegerNumber.one
                  : Mul.of(cParts).simplify(assumptions: assumptions);
            }
          }
        }
        if (fnNode != null) {
          final shiftExp = constTerms.isEmpty
              ? IntegerNumber.one
              : Pow.of(
                  Constant.e,
                  Add.of(constTerms).simplify(assumptions: assumptions),
                );
          switch (fnNode) {
            case Call(id: FunctionId.atanh, args: [final u])
                when u.dependsOn(variable):
              changed = true;
              final halfC = (coeff / IntegerNumber.two).simplify(
                assumptions: assumptions,
              );
              if (u.matchLinear(variable) != null) {
                return (shiftExp *
                        Pow.of(IntegerNumber.one + u, halfC) *
                        Pow.of(
                          IntegerNumber.one - u,
                          (-halfC).simplify(assumptions: assumptions),
                        ))
                    .simplify(assumptions: assumptions);
              }
              final ratio = ((IntegerNumber.one + u) / (IntegerNumber.one - u))
                  .together(assumptions: assumptions)
                  .cancel(assumptions: assumptions);
              return (shiftExp * Pow.of(ratio, halfC)).simplify(
                assumptions: assumptions,
              );
            case Call(id: FunctionId.atan, args: [final u])
                when u.dependsOn(variable):
              final alpha = (-ComplexNumber.i * coeff / IntegerNumber.two)
                  .simplify(assumptions: assumptions);
              if (!alpha.anyNode((n) => n is ComplexNumber)) {
                changed = true;
                final iU = ComplexNumber.i * u;
                if (u.matchLinear(variable) != null) {
                  return (shiftExp *
                          Pow.of(IntegerNumber.one + iU, alpha) *
                          Pow.of(
                            IntegerNumber.one - iU,
                            (-alpha).simplify(assumptions: assumptions),
                          ))
                      .simplify(assumptions: assumptions);
                }
                final ratio =
                    ((IntegerNumber.one + iU) / (IntegerNumber.one - iU))
                        .together(assumptions: assumptions)
                        .cancel(assumptions: assumptions);
                return (shiftExp * Pow.of(ratio, alpha)).simplify(
                  assumptions: assumptions,
                );
              }
            case Call(id: FunctionId.asinh, args: [final u])
                when u.dependsOn(variable):
              changed = true;
              final inner =
                  (u +
                          Pow.of(
                            IntegerNumber.one + Pow.of(u, IntegerNumber.two),
                            FractionNumber.half,
                          ))
                      .simplify(assumptions: assumptions);
              return (shiftExp * Pow.of(inner, coeff)).simplify(
                assumptions: assumptions,
              );
            case Call(id: FunctionId.acosh, args: [final u])
                when u.dependsOn(variable):
              changed = true;
              final inner =
                  (u +
                          Pow.of(u - IntegerNumber.one, FractionNumber.half) *
                              Pow.of(
                                u + IntegerNumber.one,
                                FractionNumber.half,
                              ))
                      .simplify(assumptions: assumptions);
              return (shiftExp * Pow.of(inner, coeff)).simplify(
                assumptions: assumptions,
              );
            default:
              break;
          }
        }
      }
    }
    return node.mapChildren(rewriteExp);
  }

  final rewritten = rewriteExp(expr).simplify(assumptions: assumptions);
  if (!changed || rewritten == expr) return null;
  final res = antiDerivative(
    rewritten,
    variable,
    assumptions: assumptions,
    depth: depth + 1,
  );
  return hasUnevaluatedIntegral(res, variable) ? null : res;
}

/// Integrates products of scaled monomial powers `prod_i (c_i * x^(k_i))^(e_i)`
/// with exact branch preservation: `int f(x) dx = x * f(x) / (D + 1)` when
/// `D = sum k_i * e_i != -1`, and `x * f(x) * ln(|x|)` when `D = -1`.
Expr? tryMonomialPowerProduct(
  Expr expr,
  String variable, {
  required Assumptions assumptions,
}) {
  final factors = expr is Mul ? expr.factors : [expr];
  final xVar = Variable(variable);
  var totalDeg = IntegerNumber.zero as Expr;
  var hasVarFactor = false;

  for (final f in factors) {
    if (!f.dependsOn(variable)) continue;
    hasVarFactor = true;
    if (f is Variable && f.name == variable) {
      totalDeg = (totalDeg + IntegerNumber.one).simplify(
        assumptions: assumptions,
      );
      continue;
    }
    if (f case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable)) {
      if (_extractMonomialVarPower(base, variable)
          case (:final scale, :final power)
          when !power.dependsOn(variable) &&
              !(power is Number && power.isZero) &&
              !scale.dependsOn(variable)) {
        totalDeg = (totalDeg + power * exponent).simplify(
          assumptions: assumptions,
        );
        continue;
      }
    }
    return null;
  }

  if (!hasVarFactor || totalDeg.dependsOn(variable)) return null;
  final degPlus1 = (totalDeg + IntegerNumber.one).simplify(
    assumptions: assumptions,
  );
  if (degPlus1 is Number && degPlus1.isZero) {
    return (xVar * expr * logAntiderivative(xVar, assumptions)).simplify(
      assumptions: assumptions,
    );
  }
  return (xVar * expr / degPlus1).simplify(assumptions: assumptions);
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

({
  Expr aConst,
  Expr bConst,
  Expr linBase,
  Expr linSlope,
  Expr logArg,
  Expr nExp,
})?
_matchAffineLogPowerBase(Expr expr, String variable) {
  Expr aConst = IntegerNumber.zero;
  Expr bConst = IntegerNumber.one;
  Call? lnNode;

  if (expr is Call && expr.id == FunctionId.ln) {
    lnNode = expr;
  } else if (expr is Add) {
    final constTerms = <Expr>[];
    final varTerms = <Expr>[];
    for (final t in expr.terms) {
      if (!t.dependsOn(variable)) {
        constTerms.add(t);
      } else {
        varTerms.add(t);
      }
    }
    if (varTerms.length != 1) return null;
    aConst = constTerms.isEmpty
        ? IntegerNumber.zero
        : (constTerms.length == 1
              ? constTerms.first
              : Add.of(constTerms).simplify());
    final vt = varTerms.first;
    if (vt is Call && vt.id == FunctionId.ln) {
      lnNode = vt;
    } else if (vt is Mul) {
      final cFs = <Expr>[];
      final vFs = <Expr>[];
      for (final f in vt.factors) {
        if (!f.dependsOn(variable)) {
          cFs.add(f);
        } else {
          vFs.add(f);
        }
      }
      if (vFs.length != 1 ||
          vFs.first is! Call ||
          (vFs.first as Call).id != FunctionId.ln) {
        return null;
      }
      lnNode = vFs.first as Call;
      bConst = cFs.isEmpty
          ? IntegerNumber.one
          : (cFs.length == 1 ? cFs.first : Mul.of(cFs).simplify());
    }
  }
  if (lnNode == null) return null;

  final arg = lnNode.args[0];
  // Match c * (a*x + b)^n inside ln(...):
  final argFactors = arg is Mul ? arg.factors : [arg];
  final vFactors = [
    for (final f in argFactors)
      if (f.dependsOn(variable)) f,
  ];
  if (vFactors.length != 1) return null;
  final vf = vFactors.first;
  final Expr linCand;
  final Expr nExp;
  if (vf case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    linCand = base;
    nExp = exponent;
  } else {
    linCand = vf;
    nExp = IntegerNumber.one;
  }
  final lin = linCand.matchLinear(variable);
  if (lin == null) return null;
  return (
    aConst: aConst,
    bConst: bConst,
    linBase: linCand,
    linSlope: lin.a,
    logArg: arg,
    nExp: nExp,
  );
}

Expr? _tryIntegrateLinearPowTimesAffineLogPow(
  Expr linFactor,
  Expr logPowFactor,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  final Expr linSub;
  final Expr mExp;
  if (linFactor case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    linSub = base;
    mExp = exponent;
  } else {
    linSub = linFactor;
    mExp = IntegerNumber.one;
  }
  final linSubMatch = linSub.matchLinear(variable);
  if (linSubMatch == null) return null;

  final Expr logBaseExpr;
  final Expr kExp;
  if (logPowFactor case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    logBaseExpr = base;
    kExp = exponent;
  } else {
    logBaseExpr = logPowFactor;
    kExp = IntegerNumber.one;
  }
  final logInfo = _matchAffineLogPowerBase(logBaseExpr, variable);
  if (logInfo == null) return null;
  final (:aConst, :bConst, :linBase, :linSlope, :logArg, :nExp) = logInfo;

  // Require linSub == scale * linBase with !scale.dependsOn(variable).
  final ratio = (linSubMatch.a / linSlope).cancel(assumptions: assumptions);
  if (ratio.dependsOn(variable)) return null;
  final linDiff = (linSub - ratio * linBase).expand().simplify(
    assumptions: assumptions,
  );
  if (linDiff != IntegerNumber.zero) return null;
  final outerScale = (ratio == IntegerNumber.one)
      ? IntegerNumber.one
      : Pow.of(ratio, mExp).simplify(assumptions: assumptions);

  final effB = (bConst * nExp).simplify(assumptions: assumptions);
  if (effB is Number && effB.isZero) return null;

  // m == -1: direct u-substitution.
  if (mExp == IntegerNumber.negativeOne ||
      (mExp is RealNumber && mExp.value == -1.0)) {
    if (kExp == IntegerNumber.negativeOne ||
        (kExp is RealNumber && kExp.value == -1.0)) {
      return (outerScale *
              logAntiderivative(logBaseExpr, assumptions) /
              (linSlope * effB))
          .simplify(assumptions: assumptions);
    }
    final kp1 = (kExp + IntegerNumber.one).simplify(assumptions: assumptions);
    if (kp1 is Number && kp1.isZero) return null;
    return (outerScale * Pow.of(logBaseExpr, kp1) / (linSlope * effB * kp1))
        .simplify(assumptions: assumptions);
  }

  final mPlus1 = (mExp + IntegerNumber.one).simplify(assumptions: assumptions);
  if (mPlus1 is Number && mPlus1.isZero) return null;

  return _integrateLinBasePowTimesAffineLog(
    outerScale,
    linBase,
    linSlope,
    mExp,
    mPlus1,
    logBaseExpr,
    aConst,
    bConst,
    logArg,
    nExp,
    kExp,
    variable,
    assumptions: assumptions,
    depth: depth,
  );
}

Expr? _integrateLinBasePowTimesAffineLog(
  Expr outerScale,
  Expr linBase,
  Expr linSlope,
  Expr mExp,
  Expr mPlus1,
  Expr logBaseExpr,
  Expr aConst,
  Expr bConst,
  Expr logArg,
  Expr nExp,
  Expr kExp,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  final effB = (bConst * nExp).simplify(assumptions: assumptions);
  if (effB is Number && effB.isZero) return null;

  // k == -1: incomplete gamma / ExpIntegral closed form.
  if (kExp == IntegerNumber.negativeOne ||
      (kExp is RealNumber && kExp.value == -1.0)) {
    final p = (mPlus1 / nExp).simplify(assumptions: assumptions);
    final pre =
        (outerScale *
                Pow.of(linBase, mPlus1) /
                (linSlope * effB * Pow.of(logArg, p)) *
                Pow.of(Constant.e, (-p * aConst / bConst).simplify()))
            .simplify(assumptions: assumptions);
    return (pre *
            Fn.ei(
              (p * logBaseExpr / bConst).simplify(assumptions: assumptions),
            ))
        .simplify(assumptions: assumptions);
  }

  // Negative integer k in [-6, -2]: step-up recurrence to k + 1.
  if (kExp case IntegerNumber(asInt: final negK?)
      when negK <= -2 && negK >= -6) {
    final absKm1 = IntegerNumber.of(-negK - 1);
    final term1 =
        (-Pow.of(linBase, mPlus1) /
                (linSlope * effB * absKm1 * Pow.of(logBaseExpr, absKm1)))
            .simplify(assumptions: assumptions);
    final rem = _integrateLinBasePowTimesAffineLog(
      IntegerNumber.one,
      linBase,
      linSlope,
      mExp,
      mPlus1,
      logBaseExpr,
      aConst,
      bConst,
      logArg,
      nExp,
      IntegerNumber.of(negK + 1),
      variable,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (rem == null) return null;
    return (outerScale * (term1 + (mPlus1 / (effB * absKm1)) * rem)).simplify(
      assumptions: assumptions,
    );
  }

  // Positive integer k in [1, 5]: step-down recurrence to k - 1.
  if (kExp case IntegerNumber(asInt: final k?) when k >= 1 && k <= 6) {
    final basePow = (Pow.of(linBase, mPlus1) / (linSlope * mPlus1)).simplify(
      assumptions: assumptions,
    );
    final term1 = (basePow * Pow.of(logBaseExpr, kExp)).simplify(
      assumptions: assumptions,
    );
    final rem = k == 1
        ? (mExp == IntegerNumber.zero
              ? (linBase / linSlope).simplify(assumptions: assumptions)
              : antiDerivative(
                  Pow.of(linBase, mExp).simplify(assumptions: assumptions),
                  variable,
                  assumptions: assumptions,
                  depth: depth + 1,
                ))
        : _integrateLinBasePowTimesAffineLog(
            IntegerNumber.one,
            linBase,
            linSlope,
            mExp,
            mPlus1,
            logBaseExpr,
            aConst,
            bConst,
            logArg,
            nExp,
            IntegerNumber.of(k - 1),
            variable,
            assumptions: assumptions,
            depth: depth + 1,
          );
    if (rem == null || hasUnevaluatedIntegral(rem, variable)) return null;
    final coeff = (IntegerNumber.of(k) * effB / mPlus1).simplify(
      assumptions: assumptions,
    );
    return (outerScale * (term1 - coeff * rem)).simplify(
      assumptions: assumptions,
    );
  }

  return null;
}

const _inverseTrigHypIds = {
  FunctionId.asin,
  FunctionId.acos,
  FunctionId.atan,
  FunctionId.asinh,
  FunctionId.acosh,
  FunctionId.atanh,
};

const _trigAndInverseTrigHypIds = {
  FunctionId.sin,
  FunctionId.cos,
  FunctionId.tan,
  FunctionId.sinh,
  FunctionId.cosh,
  FunctionId.tanh,
  FunctionId.asin,
  FunctionId.acos,
  FunctionId.atan,
  FunctionId.asinh,
  FunctionId.acosh,
  FunctionId.atanh,
};
