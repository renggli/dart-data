import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
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
  int depth = 0,
}) {
  if (depth >= 3) return null;

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

  // Inverse trig / inverse hyperbolic IBP: u = f(g(x)) or f(g(x))^2, dv = pExpr dx
  final isInverseTrigOrHyp = switch (vExpr) {
    Asin() || Acos() || Atan() || Asinh() || Acosh() || Atanh() => true,
    Pow(
      base: Asin() || Acos() || Atan() || Asinh() || Acosh() || Atanh(),
      exponent: IntegerNumber(asInt: 2) || RealNumber(value: 2.0),
    ) =>
      true,
    _ => false,
  };
  if (isInverseTrigOrHyp) {
    final v = antiDerivative(pExpr, variable, depth: 2);
    if (!hasUnevaluatedIntegral(v, variable)) {
      final uPrime = vExpr.derivative(variable).simplify();
      final remIntegrand = (v * uPrime).simplify();
      final remIntegral = antiDerivative(
        remIntegrand,
        variable,
        depth: depth + 1,
      );
      if (!hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify();
      }
    }
  }
  // Cyclic IBP: exp(ax + b) * sin(cx + d) or exp(ax + b) * cos(cx + d)
  if (pExpr case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (a: final a, b: _)) {
      if (vExpr case Sin(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify();
          final numer = (pExpr * (a * Sin(trigInner) - c * Cos(trigInner)))
              .simplify();
          return (numer / denom).simplify();
        }
      }
      if (vExpr case Cos(expr: final trigInner)) {
        if (trigInner.matchLinear(variable) case (a: final c, b: _)) {
          final denom = (a * a + c * c).simplify();
          final numer = (pExpr * (a * Cos(trigInner) + c * Sin(trigInner)))
              .simplify();
          return (numer / denom).simplify();
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
          (v * vExpr.derivative(variable)).simplify(),
          variable,
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
    // 1. P(x) * ln(a*x + b)^k where u = ln(a*x + b)^k, dv = P(x) dx
    if (vExpr case Ln(:final expr)
        when degP >= 2 && expr.matchLinear(variable) != null) {
      final v = antiDerivative(pExpr, variable);
      final uPrime = vExpr.derivative(variable).simplify();
      final remIntegrand = (v * uPrime).simplify();
      final remIntegral = antiDerivative(remIntegrand, variable);
      if (!hasUnevaluatedIntegral(v, variable) &&
          !hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify();
      }
    }
    if (vExpr
        case Pow(
          base: Ln(expr: final inner),
          exponent: IntegerNumber(asInt: final k?),
        )
        when k >= 1 && k <= 5 && inner.matchLinear(variable) != null) {
      final v = antiDerivative(pExpr, variable);
      final uPrime = vExpr.derivative(variable).simplify();
      final remIntegrand = (v * uPrime).simplify();
      final remIntegral = antiDerivative(remIntegrand, variable);
      if (!hasUnevaluatedIntegral(v, variable) &&
          !hasUnevaluatedIntegral(remIntegral, variable)) {
        return (v * vExpr - remIntegral).simplify();
      }
    }

    // 2. P(x) * exp(-a*x^2 + b*x + c) (Gaussian moments)
    if (vExpr case Pow(:final base, :final exponent) when base == Constant.e) {
      final expCoeffs = extractPolynomialCoefficients(exponent, variable);
      if (expCoeffs != null && maxPolynomialDegree(expCoeffs) == 2) {
        final a2 = expCoeffs[2] ?? IntegerNumber.zero;
        final a1 = expCoeffs[1] ?? IntegerNumber.zero;
        if (degP >= 2 && a1 == IntegerNumber.zero && isNegativeConstant(a2)) {
          // Write P(x) = x * Q(x) + p0, and integrate x * Q(x) * exp(a2*x^2) via u = Q(x), dv = x*exp(a2*x^2) dx
          final xVar = Variable(variable);
          final (:quotient, :remainder) = pExpr.polynomialDivide(
            xVar,
            variable,
          );
          final dvAnti = (vExpr / (IntegerNumber.two * a2)).simplify();
          final qPrime = quotient.derivative(variable).simplify();
          final ibpRem = antiDerivative(
            (qPrime * dvAnti).expand().simplify(),
            variable,
          );
          final rem0 = (remainder is Number && remainder.isZero)
              ? IntegerNumber.zero
              : antiDerivative((remainder * vExpr).simplify(), variable);
          if (!hasUnevaluatedIntegral(ibpRem, variable) &&
              !hasUnevaluatedIntegral(rem0, variable)) {
            return (quotient * dvAnti - ibpRem + rem0).simplify();
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
        _ => false,
      };
      if (isIntegrableV) {
        final v = antiDerivative(vExpr, variable);
        final pPrime = pExpr.derivative(variable);
        final remIntegral = antiDerivative(
          (pPrime * v).expand().simplify(),
          variable,
        );
        if (!hasUnevaluatedIntegral(v, variable) &&
            !hasUnevaluatedIntegral(remIntegral, variable)) {
          return (pExpr * v - remIntegral).simplify();
        }
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
