import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';

/// Attempts integration by parts on the product `pExpr * vExpr` with respect
/// to [variable].
Expr? tryIntegrationByParts(
  Expr pExpr,
  Expr vExpr,
  String variable, {
  required Assumptions assumptions,
  int depth = 0,
}) {
  if (depth >= 3 || isIntegrationBudgetExhausted()) return null;

  // Symbolic power times logarithm: x^n * ln(a*x)
  if (vExpr case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: _, b: final b)
        when b == IntegerNumber.zero) {
      if (pExpr case Pow(base: Variable(:final name), exponent: final n)
          when name == variable && !n.dependsOn(variable)) {
        final nPlus1 = (n + IntegerNumber.one).simplify();
        if (nPlus1 is! Number || !nPlus1.isZero) {
          final xNP1 = Pow(pExpr.base, nPlus1);
          return (xNP1 * Ln(inner) / nPlus1 - xNP1 / (nPlus1 * nPlus1))
              .simplify();
        }
      }
    }
  }

  // Inverse trig / inverse hyperbolic IBP: u = f(g(x)), a + b*f(g(x)), or powered 2..3
  bool isInvFn(Expr n) =>
      n is Asin ||
      n is Acos ||
      n is Atan ||
      n is Asinh ||
      n is Acosh ||
      n is Atanh;
  bool isInvOrAffine(Expr n) {
    if (isInvFn(n)) return true;
    if (n case Add(:final terms) when terms.length == 2) {
      final vTerms = [
        for (final t in terms)
          if (t.dependsOn(variable)) t,
      ];
      if (vTerms.length != 1) return false;
      final vt = vTerms.first;
      if (isInvFn(vt)) return true;
      if (vt case Mul(:final factors)) {
        final vfs = [
          for (final mf in factors)
            if (mf.dependsOn(variable)) mf,
        ];
        return vfs.length == 1 && isInvFn(vfs.first);
      }
    }
    return false;
  }

  final isInverseTrigOrHyp = switch (vExpr) {
    _ when isInvOrAffine(vExpr) => true,
    Pow(:final base, exponent: IntegerNumber(asInt: final k?))
        when (k == 2 || k == 3) && isInvOrAffine(base) =>
      true,
    Pow(:final base, exponent: RealNumber(value: 2.0 || 3.0))
        when isInvOrAffine(base) =>
      true,
    _ => false,
  };
  if (isInverseTrigOrHyp) {
    final result = _applySingleStepIbp(
      pExpr,
      vExpr,
      variable,
      assumptions: assumptions,
      depth: depth,
    );
    if (result != null) return result;
  }
  // Cyclic IBP: exp(ax + b) * sin(cx + d) or exp(ax + b) * cos(cx + d)
  if (pExpr case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (depth < 2 && vExpr is Add) {
        final distSum = Add([
          for (final t in vExpr.terms)
            antiDerivative(
              (pExpr * t).simplify(assumptions: assumptions),
              variable,
              assumptions: assumptions,
              depth: depth + 1,
            ),
        ]).simplify(assumptions: assumptions);
        if (!hasUnevaluatedIntegral(distSum, variable)) return distSum;
      }
      if (vExpr case Sin(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify(assumptions: assumptions);
          if (!(denom is Number && denom.isZero)) {
            final numer = (pExpr * (a * Sin(trigInner) - c * Cos(trigInner)))
                .simplify(assumptions: assumptions);
            return (numer / denom).simplify(assumptions: assumptions);
          }
        }
      }
      if (vExpr case Cos(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify(assumptions: assumptions);
          if (!(denom is Number && denom.isZero)) {
            final numer = (pExpr * (a * Cos(trigInner) + c * Sin(trigInner)))
                .simplify(assumptions: assumptions);
            return (numer / denom).simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  // exp(a*x + b) * ln(c*x + d)
  if (pExpr case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (vExpr case Ln(expr: final lnInner)
          when lnInner.matchLinear(variable) != null) {
        final v = (pExpr / a).simplify();
        final rem = antiDerivative(
          (v * vExpr.derivative(variable)).simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
          depth: depth + 1,
        );
        if (!hasUnevaluatedIntegral(rem, variable)) {
          return (v * vExpr - rem).simplify();
        }
      }
    }
  }

  final linP = pExpr.matchLinear(variable);
  if (linP != null) {
    final p = linP.a;
    final linRes = switch (vExpr) {
      Ln(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, :final b) => _ibpLogarithm(pExpr, vExpr, expr, linP, a, b),
        null => null,
      },
      Pow(:final base, :final exponent) when base == Constant.e =>
        switch (exponent.matchLinear(variable)) {
          (:final a, b: _) => _ibpExponential(pExpr, vExpr, p, a),
          null => null,
        },
      Cos(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpCosine(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Sin(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpSine(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Sinh(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpSinh(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Cosh(:final expr) => switch (expr.matchLinear(variable)) {
        (:final a, b: _) => _ibpCosh(pExpr, vExpr, expr, p, a),
        null => null,
      },
      Pow(:final base, :final exponent) when !base.dependsOn(variable) =>
        switch (exponent.matchLinear(variable)) {
          (:final a, b: _) => _ibpGeneralExponential(pExpr, vExpr, base, p, a),
          null => null,
        },
      _ => null,
    };
    if (linRes != null) return linRes;
  }

  // Higher-degree polynomial P(x) * vExpr (e.g. x^n * exp(ax+b), x^n * sin(ax+b), x^n * ln(x), x^n * exp(-a*x^2)):
  final degP = polynomialDegree(pExpr, variable);
  if (degP != null && degP >= 1 && degP <= 10) {
    // 1. P(x) * ln(R(x)) where u = ln(R(x)), dv = P(x) dx
    if (vExpr case Ln(:final expr)
        when (degP >= 2 && expr.matchLinear(variable) != null) || degP <= 6) {
      final uPrime = vExpr
          .derivative(variable)
          .simplify(assumptions: assumptions);
      final (uNum, uDen) = splitNumeratorDenominator(uPrime);
      final uNumExp = uNum.expand().simplify(assumptions: assumptions);
      final uDenExp = uDen.expand().simplify(assumptions: assumptions);
      if (expr.matchLinear(variable) != null ||
          (polynomialDegree(uNumExp, variable) != null &&
              polynomialDegree(uDenExp, variable) != null)) {
        final v = antiDerivative(pExpr, variable, assumptions: assumptions);
        final remIntegrand = (v * uNumExp / uDenExp).simplify(
          assumptions: assumptions,
        );
        final remIntegral = antiDerivative(
          remIntegrand,
          variable,
          assumptions: assumptions,
        );
        if (!hasUnevaluatedIntegral(v, variable) &&
            !hasUnevaluatedIntegral(remIntegral, variable)) {
          return (v * vExpr - remIntegral).simplify(assumptions: assumptions);
        }
      }
    }
    if (vExpr
        case Pow(
          base: Ln(expr: final inner),
          exponent: IntegerNumber(asInt: final k?),
        )
        when k >= 1 && k <= 5 && inner.matchLinear(variable) != null) {
      final v = antiDerivative(pExpr, variable, assumptions: assumptions);
      final uPrime = vExpr
          .derivative(variable)
          .simplify(assumptions: assumptions);
      final remIntegrand = (v * uPrime)
          .together(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final remIntegral = antiDerivative(
        remIntegrand,
        variable,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(v, variable) &&
          !hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify(assumptions: assumptions);
      }
    }

    // 2. P(x) * exp(-a*x^2 + b*x + c) (Gaussian moments)
    if (vExpr case Pow(:final base, :final exponent) when base == Constant.e) {
      final expCoeffs = extractPolynomialCoefficients(exponent, variable);
      if (expCoeffs != null && maxPolynomialDegree(expCoeffs) == 2) {
        final a2 = expCoeffs[2] ?? IntegerNumber.zero;
        final a1 = expCoeffs[1] ?? IntegerNumber.zero;
        if (degP >= 2 &&
            a1 != IntegerNumber.zero &&
            isNegativeConstant(a2) &&
            depth < 2) {
          final shift = (a1 / (IntegerNumber.two * a2)).simplify(
            assumptions: assumptions,
          );
          const wName = '_gw';
          const wVar = Variable(wName);
          final xInW = (wVar - shift).simplify(assumptions: assumptions);
          final pW = pExpr
              .substitute(variable, xInW)
              .expand()
              .simplify(assumptions: assumptions);
          final expW = exponent
              .substitute(variable, xInW)
              .expand()
              .simplify(assumptions: assumptions);
          final wInt = antiDerivative(
            (pW * Pow(Constant.e, expW)).simplify(assumptions: assumptions),
            wName,
            assumptions: assumptions,
            depth: depth + 1,
          );
          if (!hasUnevaluatedIntegral(wInt, wName)) {
            return wInt
                .substitute(wName, (Variable(variable) + shift).simplify())
                .simplify(assumptions: assumptions);
          }
        }
        if (degP >= 2 && a1 == IntegerNumber.zero && isNegativeConstant(a2)) {
          // Write P(x) = x * Q(x) + p0, and integrate x * Q(x) * exp(a2*x^2) via u = Q(x), dv = x*exp(a2*x^2) dx
          final xVar = Variable(variable);
          final (:quotient, :remainder) = pExpr.polynomialDivide(
            xVar,
            variable,
          );
          final dvAnti = (vExpr / (IntegerNumber.two * a2)).simplify(
            assumptions: assumptions,
          );
          final qPrime = quotient
              .derivative(variable)
              .simplify(assumptions: assumptions);
          final ibpRem = antiDerivative(
            (qPrime * dvAnti).expand().simplify(assumptions: assumptions),
            variable,
            assumptions: assumptions,
          );
          final rem0 = (remainder is Number && remainder.isZero)
              ? IntegerNumber.zero
              : antiDerivative(
                  (remainder * vExpr).simplify(assumptions: assumptions),
                  variable,
                  assumptions: assumptions,
                );
          if (!hasUnevaluatedIntegral(ibpRem, variable) &&
              !hasUnevaluatedIntegral(rem0, variable)) {
            return (quotient * dvAnti - ibpRem + rem0).simplify(
              assumptions: assumptions,
            );
          }
        }
      }
    }

    if (degP >= 2) {
      final isIntegrableV = switch (vExpr) {
        Pow(:final base, :final exponent) when base == Constant.e =>
          exponent.matchLinear(variable) != null,
        Sin(:final expr) ||
        Cos(:final expr) ||
        Sinh(:final expr) ||
        Cosh(:final expr) => expr.matchLinear(variable) != null,
        Mul(factors: [final f0, final f1]) =>
          _isExpTrigPair(f0, f1, variable) || _isExpTrigPair(f1, f0, variable),
        _ => false,
      };
      if (isIntegrableV) {
        final v = antiDerivative(vExpr, variable, assumptions: assumptions);
        final pPrime = pExpr.derivative(variable);
        final remIntegral = antiDerivative(
          (pPrime * v).expand().simplify(assumptions: assumptions),
          variable,
          assumptions: assumptions,
        );
        if (!hasUnevaluatedIntegral(v, variable) &&
            !hasUnevaluatedIntegral(remIntegral, variable)) {
          return (pExpr * v - remIntegral).simplify();
        }
      }
    }
  }

  // General log rule: P(x) * ln(g(x))^k where P(x) is any integrable cofactor
  final isLogFactor = switch (vExpr) {
    Ln() => true,
    Pow(base: Ln(), exponent: IntegerNumber(asInt: final k?))
        when k >= 1 && k <= 3 =>
      true,
    _ => false,
  };
  if (depth < 2 && isLogFactor) {
    final result = _applySingleStepIbp(
      pExpr,
      vExpr,
      variable,
      assumptions: assumptions,
      depth: depth,
    );
    if (result != null) return result;
  }

  // General polynomial fallback: P(x) of degree 1..4 times any integrable vExpr
  final allowPolyPolylogOrExpInv = switch (vExpr) {
    Polylog(:final left, right: _) => !left.dependsOn(variable),
    Atan(:final expr) || Atanh(:final expr) || Ln(:final expr) => expr.anyNode(
      (n) =>
          n is Pow &&
          !n.base.dependsOn(variable) &&
          n.exponent.dependsOn(variable),
    ),
    _ => false,
  };
  if (depth < (allowPolyPolylogOrExpInv ? 3 : 2) &&
      degP != null &&
      degP >= 1 &&
      degP <= (allowPolyPolylogOrExpInv ? 4 : 3) &&
      (allowPolyPolylogOrExpInv ||
          !_containsLogOrInverseTrig(vExpr, variable))) {
    final v = antiDerivative(
      vExpr,
      variable,
      assumptions: assumptions,
      depth: depth + 1,
    );
    if (!hasUnevaluatedIntegral(v, variable)) {
      final pPrime = pExpr.derivative(variable, assumptions: assumptions);
      final remIntegral = antiDerivative(
        (pPrime * v).simplify(assumptions: assumptions),
        variable,
        assumptions: assumptions,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(remIntegral, variable)) {
        return (pExpr * v - remIntegral).simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

Expr _ibpLogarithm(
  Expr pExpr,
  Expr vExpr,
  Expr expr,
  ({Expr a, Expr b}) linP,
  Expr c,
  Expr d,
) {
  final p = linP.a;
  final q = linP.b;
  final cSquared = (c * c).simplify();
  final aCap = (p / cSquared).simplify();
  final numB = (q * c - p * d).simplify();
  final bCap = (numB / cSquared).simplify();
  final w = expr;
  final wSquared = Pow(w, IntegerNumber.two).simplify();
  final termA1 = ((aCap * wSquared) / IntegerNumber.two).simplify();
  final termB1 = (bCap * w).simplify();
  final coeff1 = (termA1 + termB1).simplify();

  final termA2 = ((aCap * wSquared) / IntegerNumber.of(4)).simplify();
  final coeff2 = (termA2 + termB1).simplify();

  return (coeff1 * vExpr - coeff2).simplify();
}

Expr _ibpExponential(Expr pExpr, Expr vExpr, Expr p, Expr c) {
  final term1 = (pExpr / c).simplify();
  final cSquared = (c * c).simplify();
  final term2 = (p / cSquared).simplify();
  final coeff = (term1 - term2).simplify();
  return (coeff * vExpr).simplify();
}

Expr? _ibpGeneralExponential(
  Expr pExpr,
  Expr vExpr,
  Expr base,
  Expr p,
  Expr a,
) {
  if (isValidExponentialBase(base)) {
    final cEff = (a * Ln(base)).simplify();
    final term1 = (pExpr / cEff).simplify();
    final cEffSquared = (cEff * cEff).simplify();
    final term2 = (p / cEffSquared).simplify();
    final coeff = (term1 - term2).simplify();
    return (coeff * vExpr).simplify();
  }
  return null;
}

Expr _ibpCosine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Sin(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Cos(expr)).simplify();
  return (term1 + term2).simplify();
}

Expr _ibpSine(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = (-((pExpr / c).simplify() * Cos(expr))).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Sin(expr)).simplify();
  return (term1 + term2).simplify();
}

Expr _ibpSinh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Cosh(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Sinh(expr)).simplify();
  return (term1 - term2).simplify();
}

Expr _ibpCosh(Expr pExpr, Expr vExpr, Expr expr, Expr p, Expr c) {
  final term1 = ((pExpr / c).simplify() * Sinh(expr)).simplify();
  final cSquared = (c * c).simplify();
  final term2 = ((p / cSquared).simplify() * Cosh(expr)).simplify();
  return (term1 - term2).simplify();
}

bool _containsLogOrInverseTrig(Expr expr, String variable) => switch (expr) {
  Ln() || Asin() || Acos() || Atan() || Asinh() || Acosh() || Atanh() => true,
  Add(:final terms) => terms.any((t) => _containsLogOrInverseTrig(t, variable)),
  Mul(:final factors) => factors.any(
    (f) => _containsLogOrInverseTrig(f, variable),
  ),
  Pow(:final base, :final exponent) =>
    (exponent is FractionNumber &&
            base.dependsOn(variable) &&
            !base.anyNode(
              (n) =>
                  n is Pow &&
                  !n.base.dependsOn(variable) &&
                  n.exponent.dependsOn(variable),
            )) ||
        _containsLogOrInverseTrig(base, variable) ||
        _containsLogOrInverseTrig(exponent, variable),
  _ => false,
};

bool _isExpTrigPair(Expr expNode, Expr trigNode, String variable) {
  if (expNode case Pow(:final base, :final exponent) when base == Constant.e) {
    if (exponent.matchLinear(variable) == null) return false;
    return switch (trigNode) {
      Sin(:final expr) ||
      Cos(:final expr) => expr.matchLinear(variable) != null,
      _ => false,
    };
  }
  return false;
}

Expr? _applySingleStepIbp(
  Expr pExpr,
  Expr vExpr,
  String variable, {
  required Assumptions assumptions,
  required int depth,
}) {
  if (isIntegrationBudgetExhausted()) return null;
  final v = antiDerivative(pExpr, variable, assumptions: assumptions, depth: 2);
  if (isIntegrationBudgetExhausted() || hasUnevaluatedIntegral(v, variable)) {
    return null;
  }
  final uPrime = vExpr.derivative(variable).simplify(assumptions: assumptions);
  final prod = (v * uPrime).simplify(assumptions: assumptions);
  final remIntegrand = exceedsNodeBudget(prod, 250)
      ? prod
      : prod
            .together(assumptions: assumptions)
            .simplify(assumptions: assumptions);
  final remIntegral = antiDerivative(
    remIntegrand,
    variable,
    assumptions: assumptions,
    depth: depth + 1,
  );
  if (hasUnevaluatedIntegral(remIntegral, variable)) return null;
  return (v * vExpr - remIntegral).simplify(assumptions: assumptions);
}
