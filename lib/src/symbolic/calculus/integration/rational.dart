import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'radical.dart';
import 'trigonometric.dart';

/// Attempts quotient and rational-function integration on `left / right` with
/// respect to [variable].
Expr? tryAntiDerivDiv(
  Expr left,
  Expr right,
  String variable, {
  int depth = 0,
  required Assumptions assumptions,
}) {
  // int (c / g(x)) dx
  if (!left.dependsOn(variable)) {
    // int c / (ax + b) dx = (c ln(|ax + b|)) / a
    if (right.matchLinear(variable) case (:final a, b: _)) {
      final num = (left * logAntiderivative(right, assumptions)).simplify(
        assumptions: assumptions,
      );
      return (num / a).simplify(assumptions: assumptions);
    }

    // int c / (ax + b)^n dx = int c * (ax + b)^(-n) dx
    if (right case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            base.matchLinear(variable) != null) {
      final negExp = (-exponent).simplify();
      final powExpr = Pow(base, negExp);
      return antiDerivative(
        powExpr,
        variable,
        depth: depth,
        assumptions: assumptions,
      ).scale(left);
    }

    // int c / cosh(ax + b) dx = (c / a) * atan(sinh(ax + b))
    if (right case Cosh(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Atan(Sinh(inner))) / a).simplify();
      }
    }

    // int c / cos(ax + b) dx = (c / a) * ln| (1 + sin(ax + b)) / cos(ax + b) |
    if (right case Cos(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final secTan = ((IntegerNumber.one + Sin(inner)) / Cos(inner))
            .simplify();
        return ((left * Ln(Abs(secTan))) / a).simplify();
      }
    }

    // int c / sin(ax + b) dx = -(c / a) * ln| (1 + cos(ax + b)) / sin(ax + b) |
    if (right case Sin(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final cscCot = ((IntegerNumber.one + Cos(inner)) / Sin(inner))
            .simplify();
        return ((-left * Ln(Abs(cscCot))) / a).simplify();
      }
    }

    // int c / cos(ax + b)^2 dx = (c / a) * tan(ax + b)
    if (right case Pow(base: Cos(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Tan(inner)) / a).simplify();
      }
    }

    // int c / sin(ax + b)^2 dx = -(c / a) * (cos(ax + b) / sin(ax + b))
    if (right case Pow(base: Sin(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((-left * Cos(inner)) / (a * Sin(inner))).simplify();
      }
    }

    // int c / sinh(ax + b) dx = (c / a) * ln|tanh((ax + b) / 2)|
    if (right case Sinh(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Ln(Abs(Tanh(inner / IntegerNumber.two)))) / a)
            .simplify();
      }
    }

    // int c / cosh(ax + b)^2 dx = (c / a) * tanh(ax + b)
    if (right case Pow(base: Cosh(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Tanh(inner)) / a).simplify();
      }
    }

    // int c / sinh(ax + b)^2 dx = -(c / a) * (cosh(ax + b) / sinh(ax + b))
    if (right case Pow(base: Sinh(expr: final inner), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((-left * Cosh(inner)) / (a * Sinh(inner))).simplify();
      }
    }

    // Higher negative trig/hyperbolic powers: sec^n, csc^n, sech^n, csch^n (3 <= n <= 10)
    if (right case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
        when n >= 3 && n <= 10) {
      final nMinus1 = IntegerNumber.of(n - 1);
      final nMinus2 = IntegerNumber.of(n - 2);
      if (base case Cos(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (Sin(inner) / (a * nMinus1 * Pow(Cos(inner), nMinus1)))
              .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Cos(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Sin(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 = (-Cos(inner) / (a * nMinus1 * Pow(Sin(inner), nMinus1)))
              .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Sin(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Cosh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (Sinh(inner) / (a * nMinus1 * Pow(Cosh(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Cosh(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Sinh(expr: final inner)) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (-Cosh(inner) / (a * nMinus1 * Pow(Sinh(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow(Sinh(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 - (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
    }

    // Weierstrass substitution for c / (A + B*sin(u) + C*cos(u))
    if (tryWeierstrassSubstitution(left, right, variable)
        case final weierRes?) {
      return weierRes;
    }

    // Completing the square for quadratic denominator: c / (Ax^2 + Bx + C)
    final coeffs = extractPolynomialCoefficients(right, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final a = coeffs[2] ?? IntegerNumber.zero;
      final b = coeffs[1] ?? IntegerNumber.zero;
      final c = coeffs[0] ?? IntegerNumber.zero;
      final delta = (const IntegerNumber(Integer(4)) * a * c - b * b)
          .simplify();
      final twoA = (IntegerNumber.two * a).simplify();
      final twoAxPlusB = (twoA * Variable(variable) + b).simplify();

      if (delta case RealNumeric(:final sign) when sign > 0) {
        final sqrtDelta = Pow(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Atan(twoAxPlusB / sqrtDelta))
            .simplify();
      } else if (delta case RealNumeric(:final sign) when sign == 0) {
        final xPlus = (twoAxPlusB / twoA).simplify();
        return (-left / (a * xPlus)).simplify();
      } else if (delta case RealNumeric(:final sign) when sign < 0) {
        final dPos = (-delta).simplify();
        final sqrtD = Pow(dPos, FractionNumber.half).simplify();
        final arg = ((twoAxPlusB - sqrtD) / (twoAxPlusB + sqrtD)).simplify();
        return ((left / sqrtD) * Ln(Abs(arg))).simplify();
      } else if (!isSyntacticallyNegative(delta)) {
        final sqrtDelta = Pow(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Atan(twoAxPlusB / sqrtDelta))
            .simplify();
      } else {
        final dPos = (-delta).simplify();
        final sqrtD = Pow(dPos, FractionNumber.half).simplify();
        final arg = ((twoAxPlusB - sqrtD) / (twoAxPlusB + sqrtD)).simplify();
        return ((left / sqrtD) * Ln(Abs(arg))).simplify();
      }
    }

    // int c / (d + exp(ax + b)) dx = (c / d) * (x - (1 / a) * ln(d + exp(ax + b)))
    if (right
        case Add(terms: [final rL, Pow(base: Constant.e, :final exponent)])
        when !rL.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, b: _)) {
        final term = (Variable(variable) - (Ln(right) / a)).simplify();
        return ((left / rL) * term).simplify();
      }
    }
  }

  // int x^n / ln(x) dx = Ei((n + 1) * ln(x)) (or ln|ln(x)| for n = -1)
  if (right case Ln(expr: Variable(:final name)) when name == variable) {
    Expr? nExp;
    var scale = IntegerNumber.one as Expr;
    if (!left.dependsOn(variable)) {
      nExp = IntegerNumber.zero;
      scale = left;
    } else if (left is Variable && left.name == variable) {
      nExp = IntegerNumber.one;
    } else if (left case Pow(base: Variable(name: final lName), :final exponent)
        when lName == variable && !exponent.dependsOn(variable)) {
      nExp = exponent;
    }
    if (nExp != null) {
      if (nExp == IntegerNumber.negativeOne) {
        return (scale * Ln(Abs(right))).simplify(assumptions: assumptions);
      }
      if (nExp is Number && nExp.isZero) {
        return (scale * LogIntegralLi(Variable(variable))).simplify(
          assumptions: assumptions,
        );
      }
      final nPlus1 = (nExp + IntegerNumber.one).simplify(
        assumptions: assumptions,
      );
      return (scale *
              ExpIntegralEi(
                (nPlus1 * right).simplify(assumptions: assumptions),
              ))
          .simplify(assumptions: assumptions);
    }
  }

  // int sin(a*x) / x^k dx and cos(a*x) / x^k dx for k >= 2
  if (right
      case Pow(
        base: Variable(name: final rName),
        exponent: IntegerNumber(asInt: final k?),
      )
      when rName == variable && k >= 2 && k <= 6) {
    if (left is Sin || left is Cos) {
      final inner = left is Sin ? left.expr : (left as Cos).expr;
      if (inner.matchLinear(variable) case (:final a, b: final b)
          when b is Number && b.isZero) {
        final km1 = IntegerNumber.of(k - 1);
        final xPow = k - 1 == 1
            ? Variable(variable)
            : Pow(Variable(variable), km1);
        if (left is Sin) {
          final term1 = (-Sin(inner) / (km1 * xPow)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            (Cos(inner) / xPow).simplify(assumptions: assumptions),
            variable,
            depth: depth + 1,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + (a / km1) * rem).simplify(assumptions: assumptions);
          }
        } else {
          final term1 = (-Cos(inner) / (km1 * xPow)).simplify(
            assumptions: assumptions,
          );
          final rem = antiDerivative(
            (Sin(inner) / xPow).simplify(assumptions: assumptions),
            variable,
            depth: depth + 1,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 - (a / km1) * rem).simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  // int u'(x) / (a + b * u(x)^2) dx = (1 / sqrt(a * b)) * arctan(sqrt(b / a) * u(x))
  if (right case Add(terms: [final rL, final rR])) {
    if (rL case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      if (extractSquareBase(rR) case final u? when u.dependsOn(variable)) {
        final uPrime = u.derivative(variable).simplify();
        if (left.matchScalarMultiple(uPrime, variable) case final k?) {
          return Atan(u).scale(k);
        }
      }
    }
    // General positive constant a + sqTerm
    if (!rL.dependsOn(variable) &&
        rR.dependsOn(variable) &&
        isSymbolicPositive(rL)) {
      if (extractScaledSquareBase((rR / rL).simplify(), variable) case final w?
          when w.dependsOn(variable)) {
        final wPrime = w.derivative(variable).simplify();
        if (left.matchScalarMultiple(wPrime, variable) case final k?) {
          return Atan(w).scale((k / rL).simplify());
        }
      }
    }
  }

  // int u'(x) / sqrt(a - u(x)^2) dx = asin(u(x) / sqrt(a))
  // int u'(x) / sqrt(a + u(x)^2) dx = asinh(u(x) / sqrt(a))
  // int u'(x) / sqrt(u(x)^2 - a) dx = ln|u(x) + sqrt(u(x)^2 - a)|
  if (right case Pow(base: Add(terms: [final t0, final t1]), :final exponent)
      when exponent == FractionNumber.half ||
          (exponent is RealNumber && exponent.value == 0.5)) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst != null) {
      if (isSymbolicPositive(aConst)) {
        final sqrtA = aConst == IntegerNumber.one
            ? IntegerNumber.one
            : Pow(aConst, FractionNumber.half).simplify();
        final negTerm = (-varTerm).simplify();
        if (extractScaledSquareBase(negTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Asin(u / sqrtA).scale(k);
          }
        }
        if (extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Asinh(u / sqrtA).scale(k);
          }
        }
      } else if (isSymbolicPositive((-aConst).simplify())) {
        if (extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Ln(Abs((u + right).simplify())).scale(k);
          }
        }
      }
    }
  }

  // c / ln(ax + b) -> (c / a) * li(ax + b)
  if (!left.dependsOn(variable)) {
    if (right case Ln(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left / a) * LogIntegralLi(inner)).simplify();
      }
    }
  }

  // c * ln(x) / (a*x + b) -> (c / a) * (ln(x) * ln(1 + a*x/b) + polylog(2, -a*x/b))
  if (left case Ln(expr: Variable(:final name)) when name == variable) {
    if (right.matchLinear(variable) case (:final a, :final b)
        when b != IntegerNumber.zero) {
      final ratio = (a * Variable(variable) / b).simplify();
      return ((Ln(Variable(variable)) * Ln(IntegerNumber.one + ratio) +
                  Polylog(IntegerNumber.two, -ratio)) /
              a)
          .simplify();
    }
  }

  // c * exp(a*x + b) / (c1*x + d)^k -> Ei reduction
  if (left case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (:final a, :final b)) {
      if (right.matchLinear(variable) case (a: final c1, b: final d1)) {
        final shift = (b - (a * d1) / c1).simplify();
        final eiArg = (a * right / c1).simplify();
        return (Pow(Constant.e, shift) * ExpIntegralEi(eiArg) / c1).simplify();
      }
      if (right
          case Pow(base: final rBase, exponent: IntegerNumber(asInt: final k?))
          when k >= 2 && k <= 8) {
        if (rBase.matchLinear(variable) case (a: final c1, b: _)) {
          final kMinus1 = IntegerNumber.of(k - 1);
          final term1 = (-left / (c1 * kMinus1 * Pow(rBase, kMinus1)))
              .simplify();
          final rem = antiDerivative(
            (a * left / (c1 * kMinus1 * (k == 2 ? rBase : Pow(rBase, kMinus1))))
                .simplify(),
            variable,
            depth: 1,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify();
          }
        }
      }
    }
  }

  // c * sin(ax)/x, cos(ax)/x, sinh(ax)/x, cosh(ax)/x, exp(ax+b)/x
  if (right is Variable && right.name == variable) {
    final (:constFactors, :varFactors) = partitionFactors(
      left is Mul ? left.factors : [left],
      variable,
    );
    if (varFactors case [final vf]) {
      final scale = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(constFactors).simplify(),
      };
      switch (vf) {
        case Sin(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * SinIntegralSi(inner)).simplify();
          }
        case Cos(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * CosIntegralCi(inner)).simplify();
          }
        case Sinh(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * SinhIntegralShi(inner)).simplify();
          }
        case Cosh(expr: final inner):
          if (inner.matchLinear(variable) case (a: _, b: final b)
              when b == IntegerNumber.zero) {
            return (scale * CoshIntegralChi(inner)).simplify();
          }
        case Pow(base: Constant.e, exponent: final expInner):
          if (expInner.matchLinear(variable) case (:final a, :final b)) {
            return (scale *
                    Pow(Constant.e, b) *
                    ExpIntegralEi(a * Variable(variable)))
                .simplify();
          }
        default:
          break;
      }
    }
  }

  // Quadratic radical denominator: (p*x + q) / (Ax^2 + Bx + C)^(k/2)
  if (right case Pow(:final base, :final exponent)) {
    if (halfIntExponent(exponent) case final halfExp?) {
      final quadRad = tryQuadraticRadical(left, base, -halfExp, variable);
      if (quadRad != null) return quadRad;
    }
  }

  // c / (x * sqrt(A*x^2 + C))
  if (!left.dependsOn(variable)) {
    if (right case Mul(factors: [final f0, final f1])) {
      final Variable? xFactor;
      final Pow? radFactor;
      if (f0 is Variable && f0.name == variable && f1 is Pow) {
        xFactor = f0;
        radFactor = f1;
      } else if (f1 is Variable && f1.name == variable && f0 is Pow) {
        xFactor = f1;
        radFactor = f0;
      } else {
        xFactor = null;
        radFactor = null;
      }
      if (xFactor != null &&
          radFactor != null &&
          halfIntExponent(radFactor.exponent) == 1) {
        final coeffs = extractPolynomialCoefficients(radFactor.base, variable);
        if (coeffs != null &&
            maxPolynomialDegree(coeffs) == 2 &&
            (coeffs[1] == null || coeffs[1] == IntegerNumber.zero)) {
          final cConst = coeffs[0] ?? IntegerNumber.zero;
          if (isSymbolicPositive(cConst)) {
            final sqrtC = Pow(cConst, FractionNumber.half).simplify();
            return ((-left / sqrtC) * Ln(Abs((sqrtC + radFactor) / xFactor)))
                .simplify();
          }
          final negC = (-cConst).simplify();
          if (isSymbolicPositive(negC)) {
            final sqrtNegC = Pow(negC, FractionNumber.half).simplify();
            return ((left / sqrtNegC) * Atan(radFactor / sqrtNegC)).simplify();
          }
        }
      }
    }
  }

  // Chain rule quotient: int u'(x) / u(x) dx = ln(|u(x)|)
  if (right.dependsOn(variable)) {
    final uPrime = right.derivative(variable).simplify();
    final k = left.matchScalarMultiple(uPrime, variable);
    if (k != null) {
      return logAntiderivative(
        right,
        assumptions,
      ).simplify(assumptions: assumptions).scale(k);
    }
  }

  // Trigonometric quotients/powers: sin^p(u) / cos^q(u), cot^n(u), etc.
  if (tryTrigPowerProduct(left, right, variable) case final trigQuot?) {
    return trigQuot;
  }

  // Linear trig quotient: (a1*sin(u) + b1*cos(u) + c1) / (a*sin(u) + b*cos(u) + c)
  if (tryLinearTrigQuotient(left, right, variable) case final linTrigRes?) {
    return linTrigRes;
  }

  // Polynomial / (x^k * sqrt(Q)) or sqrt(Q) / x^k or x^m / sqrt(Q)
  if (tryPolynomialOverSqrtQuadratic(left, right, variable)
      case final polySqrtRes?) {
    return polySqrtRes;
  }

  // Repeated quadratic denominator: P(x) / (Ax^2 + Bx + C)^m (m >= 2)
  if (right case Pow(base: final quad, exponent: IntegerNumber(asInt: final m?))
      when m >= 2 && m <= 10) {
    if (_tryRepeatedQuadratic(left, quad, m, variable) case final repRes?) {
      return repRes;
    }
  }

  // Rationalize P(x) / (c1 * sqrt(A) + c2 * sqrt(B)) denominators when A - B is radical-free
  if (depth < 2 && right is Add && right.terms.length == 2) {
    final conjRes = _tryConjugateRadicalDenominator(
      left,
      right.terms[0],
      right.terms[1],
      variable,
      depth: depth,
      assumptions: assumptions,
    );
    if (conjRes != null) return conjRes;
  }

  // Rational functions P(x) / Q(x): polynomial division and partial fractions
  if (right.dependsOn(variable)) {
    final rawDegLeft = polynomialDegree(left, variable);
    final rawDegRight = polynomialDegree(right, variable);
    if (rawDegLeft != null && rawDegRight != null && rawDegRight >= 4) {
      if (_tryPowerSubstitution(
            left,
            right,
            variable,
            depth: depth,
            assumptions: assumptions,
          )
          case final powSubRes?) {
        return powSubRes;
      }
    }
    if (rawDegLeft != null &&
        rawDegRight != null &&
        rawDegRight >= 1 &&
        (rawDegLeft >= rawDegRight ? rawDegRight <= 24 : rawDegRight <= 12)) {
      final leftExp = left.expand().simplify();
      final rightExp = right.expand().simplify();
      final degLeft = polynomialDegree(leftExp, variable);
      final degRight = polynomialDegree(rightExp, variable);
      if (degLeft != null && degRight != null && degRight >= 1) {
        if (degLeft >= degRight && degRight <= 24) {
          final (:quotient, :remainder) = leftExp.polynomialDivide(
            rightExp,
            variable,
          );
          final qInt = antiDerivative(
            quotient,
            variable,
            depth: depth,
            assumptions: assumptions,
          );
          if (remainder is Number && remainder.isZero) {
            return qInt;
          }
          final rInt = antiDerivative(
            (remainder / rightExp).simplify(),
            variable,
            depth: depth,
            assumptions: assumptions,
          );
          return (qInt + rInt).simplify();
        }
        if (degRight == 2 && degLeft <= 1) {
          final quadCoeffs = extractPolynomialCoefficients(rightExp, variable)!;
          final numCoeffs = extractPolynomialCoefficients(leftExp, variable)!;
          final a = quadCoeffs[2] ?? IntegerNumber.zero;
          final b = quadCoeffs[1] ?? IntegerNumber.zero;
          final d = numCoeffs[1] ?? IntegerNumber.zero;
          final e = numCoeffs[0] ?? IntegerNumber.zero;
          final quadRes = _integrateLinearOverQuad(
            d,
            e,
            rightExp,
            a,
            b,
            variable,
          );
          if (!hasUnevaluatedIntegral(quadRes, variable)) {
            return quadRes;
          }
        }
        if (degRight == 3) {
          if (_tryCubicBinomialDenominator(leftExp, rightExp, variable)
              case final cubRes?) {
            return cubRes;
          }
        }
        if (degRight == 4) {
          if (_trySophieGermainQuartic(leftExp, rightExp, variable)
              case final quartRes?) {
            return quartRes;
          }
          if (_tryBiquadraticDenominator(leftExp, rightExp, variable)
              case final biqRes?) {
            return biqRes;
          }
        }
        if (degRight >= 2) {
          if (_tryDistinctLinearPartialFractions(left, right, variable)
              case final pfRes?) {
            return pfRes;
          }
        }
        if (degRight >= 2 && right is! Pow) {
          final sqFree = _squareFreeFactorization(rightExp, variable);
          if (sqFree != null && sqFree.any((e) => e.mult > 1)) {
            final rightCoeffs = extractPolynomialCoefficients(
              rightExp,
              variable,
            )!;
            final lead = rightCoeffs[degRight] ?? IntegerNumber.one;
            var factoredDen = lead;
            for (final entry in sqFree) {
              factoredDen =
                  factoredDen *
                  (entry.mult == 1
                      ? entry.factor
                      : Pow(entry.factor, IntegerNumber.of(entry.mult)));
            }
            if (sqFree.length == 1) {
              final factor = sqFree.first.factor;
              final mult = sqFree.first.mult;
              final degF = polynomialDegree(factor, variable) ?? 0;
              if (degF == 2) {
                final scaledLeft = (leftExp / lead).simplify(
                  assumptions: assumptions,
                );
                if (_tryRepeatedQuadratic(scaledLeft, factor, mult, variable)
                    case final repRes?) {
                  return repRes;
                }
              }
            }
            final factoredRatio = (leftExp / factoredDen).simplify(
              assumptions: assumptions,
            );
            final decomposed = factoredRatio.apart(variable);
            if (decomposed is Add) {
              return Add([
                for (final term in decomposed.terms)
                  antiDerivative(
                    term,
                    variable,
                    depth: depth,
                    assumptions: assumptions,
                  ),
              ]).simplify(assumptions: assumptions);
            }
          }
        }
        if (degRight >= 2 && degRight <= 12) {
          final originalRatio = (left / right).simplify();
          final decomposed = originalRatio.apart(variable);
          if (decomposed case Add(:final terms)) {
            return Add([
              for (final term in terms)
                antiDerivative(
                  term,
                  variable,
                  depth: depth,
                  assumptions: assumptions,
                ),
            ]).simplify();
          }
          if (decomposed != originalRatio) {
            final (_, newDen) = splitNumeratorDenominator(decomposed);
            final newDeg = polynomialDegree(
              newDen.expand().simplify(),
              variable,
            );
            if ((newDeg != null && newDeg < degRight) ||
                (newDen is Pow &&
                    (newDen.base.matchLinear(variable) != null ||
                        (newDen.exponent is IntegerNumber &&
                            (newDen.exponent as IntegerNumber).value >
                                Integer.one))) ||
                newDen.matchLinear(variable) != null) {
              return antiDerivative(
                decomposed,
                variable,
                depth: depth,
                assumptions: assumptions,
              );
            }
          }
        }
      }
    }
  }

  return null;
}

Expr? _tryRepeatedQuadratic(Expr left, Expr quad, int m, String variable) {
  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  final rawDegLeft = polynomialDegree(left, variable);
  if (rawDegLeft == null) return null;
  final degLeft = polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null) return null;
  if (degLeft >= 2) {
    final (:quotient, :remainder) = left.polynomialDivide(quad, variable);
    final qTerm = antiDerivative(
      (quotient / Pow(quad, IntegerNumber.of(m - 1))).simplify(),
      variable,
      assumptions: Assumptions.none,
    );
    if (hasUnevaluatedIntegral(qTerm, variable)) return null;
    if (remainder is Number && remainder.isZero) return qTerm;
    final rTerm = _tryRepeatedQuadratic(remainder, quad, m, variable);
    if (rTerm == null) return null;
    return (qTerm + rTerm).simplify();
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 1) return null;
  final d = numCoeffs[1] ?? IntegerNumber.zero;
  final e = numCoeffs[0] ?? IntegerNumber.zero;

  final twoA = (IntegerNumber.two * a).simplify();
  final mMinus1 = IntegerNumber.of(m - 1);
  var result = IntegerNumber.zero as Expr;

  if (d != IntegerNumber.zero) {
    result = (-d / (twoA * mMinus1 * Pow(quad, mMinus1))).simplify();
  }

  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constPart = _integrateRepeatedQuadConst(quad, a, b, c, m, variable);
    if (constPart == null) return null;
    result = (result + eRem * constPart).simplify();
  }
  return result;
}

Expr? _integrateRepeatedQuadConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int m,
  String variable,
) {
  if (m == 1) {
    final res = antiDerivative(
      IntegerNumber.one / quad,
      variable,
      assumptions: Assumptions.none,
    );
    return hasUnevaluatedIntegral(res, variable) ? null : res;
  }
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b).simplify();
  if (disc is Number && disc.isZero) return null;

  final prev = _integrateRepeatedQuadConst(quad, a, b, c, m - 1, variable);
  if (prev == null) return null;

  final mMinus1 = IntegerNumber.of(m - 1);
  final twoAxPlusB = (IntegerNumber.two * a * Variable(variable) + b)
      .simplify();
  final denom = (mMinus1 * disc).simplify();
  final term1 = (twoAxPlusB / (denom * Pow(quad, mMinus1))).simplify();
  final coeff2 = ((IntegerNumber.two * IntegerNumber.of(2 * m - 3) * a) / denom)
      .simplify();
  return (term1 + coeff2 * prev).simplify();
}

Expr _integrateLinearOverQuad(
  Expr d,
  Expr e,
  Expr quad,
  Expr a,
  Expr b,
  String variable,
) {
  final twoA = (IntegerNumber.two * a).simplify();
  var result = IntegerNumber.zero as Expr;
  if (d != IntegerNumber.zero) {
    result = ((d / twoA) * Ln(quad)).simplify();
  }
  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constInt = antiDerivative(
      (eRem / quad).simplify(),
      variable,
      assumptions: Assumptions.none,
    );
    result = (result + constInt).simplify();
  }
  return result;
}

Expr? _tryCubicBinomialDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 3) return null;
  if ((denCoeffs[2] != null && denCoeffs[2] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a3 = denCoeffs[3] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a3 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 2) return null;
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a3).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a3).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a3).simplify();
  final c = (c0 / a3).simplify();

  final r = Pow(c, const FractionNumber(Integer.one, Integer(3))).simplify();
  final xVar = Variable(variable);
  final linFactor = (xVar + r).simplify();
  final quadFactor = (xVar * xVar - r * xVar + r * r).simplify();

  final aCoeff = ((p2 * r * r - p1 * r + p0) / (IntegerNumber.of(3) * r * r))
      .simplify();
  final bCoeff = (p2 - aCoeff).simplify();
  final cCoeff = (p0 / r - aCoeff * r).simplify();

  final linInt = antiDerivative(
    (aCoeff / linFactor).simplify(),
    variable,
    assumptions: Assumptions.none,
  );
  final quadInt = _integrateLinearOverQuad(
    bCoeff,
    cCoeff,
    quadFactor,
    IntegerNumber.one,
    (-r).simplify(),
    variable,
  );
  if (hasUnevaluatedIntegral(linInt, variable) ||
      hasUnevaluatedIntegral(quadInt, variable)) {
    return null;
  }
  return (linInt + quadInt).simplify();
}

Expr? _trySophieGermainQuartic(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  for (var deg = 1; deg <= 3; deg++) {
    if (denCoeffs[deg] != null && denCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a4 = denCoeffs[4] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a4 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final c = (c0 / a4).simplify();
  if (!isSymbolicPositive(c)) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a4).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a4).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a4).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a4).simplify();

  final r = Pow(c, FractionNumber.half).simplify();
  final s =
      (Pow(IntegerNumber.two, FractionNumber.half) *
              Pow(c, const FractionNumber(Integer.one, Integer(4))))
          .simplify();
  final xVar = Variable(variable);
  final q1 = (xVar * xVar - s * xVar + r).simplify();
  final q2 = (xVar * xVar + s * xVar + r).simplify();

  final diffAlpha = ((p2 - p0 / r) / s).simplify();
  final sumBeta = (p0 / r).simplify();
  final diffBeta = ((p1 - r * p3) / s).simplify();

  final alpha1 = ((p3 + diffAlpha) / IntegerNumber.two).simplify();
  final alpha2 = ((p3 - diffAlpha) / IntegerNumber.two).simplify();
  final beta1 = ((sumBeta + diffBeta) / IntegerNumber.two).simplify();
  final beta2 = ((sumBeta - diffBeta) / IntegerNumber.two).simplify();

  final int1 = _integrateLinearOverQuad(
    alpha1,
    beta1,
    q1,
    IntegerNumber.one,
    (-s).simplify(),
    variable,
  );
  final int2 = _integrateLinearOverQuad(
    alpha2,
    beta2,
    q2,
    IntegerNumber.one,
    s,
    variable,
  );
  if (hasUnevaluatedIntegral(int1, variable) ||
      hasUnevaluatedIntegral(int2, variable)) {
    return null;
  }
  return (int1 + int2).simplify();
}

Expr? _tryBiquadraticDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  if ((denCoeffs[3] != null && denCoeffs[3] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a = denCoeffs[4] ?? IntegerNumber.zero;
  final b = denCoeffs[2] ?? IntegerNumber.zero;
  final c = denCoeffs[0] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero || c == IntegerNumber.zero) {
    return null;
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a).simplify();
  final xVar = Variable(variable);

  // Case 1: b^2 - 4ac > 0 -> a*(x^2 + r1)*(x^2 + r2)
  final disc = (b * b - const IntegerNumber(Integer(4)) * a * c).simplify();
  if (isSymbolicPositive(disc)) {
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final r1 = ((b + sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final r2 = ((b - sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final diffR = (r2 - r1).simplify();
    final q1 = (xVar * xVar + r1).simplify();
    final q2 = (xVar * xVar + r2).simplify();
    final c1Lin = ((p1 - p3 * r1) / diffR).simplify();
    final c1Const = ((p0 - p2 * r1) / diffR).simplify();
    final c2Lin = (-(p1 - p3 * r2) / diffR).simplify();
    final c2Const = (-(p0 - p2 * r2) / diffR).simplify();
    final int1 = _integrateLinearOverQuad(
      c1Lin,
      c1Const,
      q1,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    final int2 = _integrateLinearOverQuad(
      c2Lin,
      c2Const,
      q2,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    if (!hasUnevaluatedIntegral(int1, variable) &&
        !hasUnevaluatedIntegral(int2, variable)) {
      return (int1 + int2).simplify();
    }
  }

  final cNorm = (c / a).simplify();
  final bNorm = (b / a).simplify();
  if (!isSymbolicPositive(cNorm)) return null;

  final r = Pow(cNorm, FractionNumber.half).simplify();
  final sSq = (IntegerNumber.two * r - bNorm).simplify();
  if (!isSymbolicPositive(sSq)) return null;
  final s = Pow(sSq, FractionNumber.half).simplify();

  final q1 = (xVar * xVar - s * xVar + r).simplify();
  final q2 = (xVar * xVar + s * xVar + r).simplify();

  final diffAlpha = ((p2 - p0 / r) / s).simplify();
  final sumBeta = (p0 / r).simplify();
  final diffBeta = ((p1 - r * p3) / s).simplify();

  final alpha1 = ((p3 + diffAlpha) / IntegerNumber.two).simplify();
  final alpha2 = ((p3 - diffAlpha) / IntegerNumber.two).simplify();
  final beta1 = ((sumBeta + diffBeta) / IntegerNumber.two).simplify();
  final beta2 = ((sumBeta - diffBeta) / IntegerNumber.two).simplify();

  final int1 = _integrateLinearOverQuad(
    alpha1,
    beta1,
    q1,
    IntegerNumber.one,
    (-s).simplify(),
    variable,
  );
  final int2 = _integrateLinearOverQuad(
    alpha2,
    beta2,
    q2,
    IntegerNumber.one,
    s,
    variable,
  );
  if (hasUnevaluatedIntegral(int1, variable) ||
      hasUnevaluatedIntegral(int2, variable)) {
    return null;
  }
  return (int1 + int2).simplify();
}

Expr? _tryDistinctLinearPartialFractions(
  Expr left,
  Expr right,
  String variable,
) {
  if (right is! Mul) return null;
  final linFactors = <({Expr factor, Expr a, Expr b})>[];
  var constScale = IntegerNumber.one as Expr;
  for (final f in right.factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f.matchLinear(variable) case (:final a, :final b)) {
      linFactors.add((factor: f, a: a, b: b));
    } else {
      return null;
    }
  }
  if (linFactors.length < 2 || linFactors.length > 5) return null;
  final rawDegLeft = polynomialDegree(left, variable);
  if (rawDegLeft == null) return null;
  final degLeft = rawDegLeft < linFactors.length
      ? rawDegLeft
      : polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null || degLeft >= linFactors.length) return null;

  final terms = <Expr>[];
  for (var i = 0; i < linFactors.length; i++) {
    final fi = linFactors[i];
    final root = (-fi.b / fi.a).simplify();
    final numAtRoot = left.substitute(variable, root).simplify();
    var denAtRoot = constScale * fi.a;
    for (var j = 0; j < linFactors.length; j++) {
      if (i != j) {
        denAtRoot =
            (denAtRoot * linFactors[j].factor.substitute(variable, root))
                .simplify();
      }
    }
    if (denAtRoot is Number && denAtRoot.isZero) return null;
    final coeff = (numAtRoot / denAtRoot).simplify();
    terms.add((coeff * Ln(Abs(fi.factor))).simplify());
  }
  return Add(terms).simplify();
}

Expr? _tryPowerSubstitution(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth >= 2) return null;
  final numCoeffs = extractPolynomialCoefficients(left, variable);
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (numCoeffs == null || denCoeffs == null || denCoeffs.isEmpty) return null;

  var d0 = denCoeffs.keys.first;
  for (final e in denCoeffs.keys) {
    if (e < d0) d0 = e;
  }

  var k = 0;
  for (final e in denCoeffs.keys) {
    final diff = e - d0;
    if (diff > 0) {
      k = k == 0 ? diff : k.gcd(diff);
    }
  }
  if (k < 2) return null;

  for (final e in numCoeffs.keys) {
    final shifted = e + 1 - d0;
    if (shifted < 0 || shifted % k != 0) return null;
  }

  final uName = '_upow$depth';
  final uVar = Variable(uName);

  var uNum = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in numCoeffs.entries) {
    final q = (e + 1 - d0) ~/ k;
    final uPow = q == 0
        ? IntegerNumber.one
        : (q == 1 ? uVar : Pow(uVar, IntegerNumber.of(q)));
    uNum = uNum + c * uPow;
  }

  var uDen = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in denCoeffs.entries) {
    final q = (e - d0) ~/ k;
    final uPow = q == 0
        ? IntegerNumber.one
        : (q == 1 ? uVar : Pow(uVar, IntegerNumber.of(q)));
    uDen = uDen + c * uPow;
  }

  final transformed = (uNum / (IntegerNumber.of(k) * uVar * uDen)).simplify(
    assumptions: assumptions,
  );
  final uInt = antiDerivative(
    transformed,
    uName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(uInt, uName)) return null;
  return uInt
      .substitute(uName, Pow(Variable(variable), IntegerNumber.of(k)))
      .simplify(assumptions: assumptions);
}

List<({Expr factor, int mult})>? _squareFreeFactorization(
  Expr poly,
  String variable,
) {
  final deg = polynomialDegree(poly, variable);
  if (deg == null || deg < 2) return null;
  final deriv = poly.derivative(variable).simplify();
  final g0 = _polyGcd(poly, deriv, variable);
  if (g0 == null) return null;
  final degG = polynomialDegree(g0, variable);
  if (degG == null || degG == 0) return null;

  var c = poly.polynomialDivide(g0, variable).quotient.simplify();
  var g = g0;
  final result = <({Expr factor, int mult})>[];
  var i = 1;

  while ((polynomialDegree(c, variable) ?? 0) > 0) {
    final y = _polyGcd(c, g, variable);
    if (y == null) return null;
    final z = c.polynomialDivide(y, variable).quotient.simplify();
    final degZ = polynomialDegree(z, variable) ?? 0;
    if (degZ > 0) {
      result.add((factor: _makeMonic(z, variable), mult: i));
    }
    c = y;
    g = g.polynomialDivide(y, variable).quotient.simplify();
    i++;
    if (i > deg + 1) return null;
  }
  return result;
}

Expr _makeMonic(Expr poly, String variable) {
  final coeffs = extractPolynomialCoefficients(poly, variable);
  if (coeffs == null || coeffs.isEmpty) return poly;
  final deg = maxPolynomialDegree(coeffs);
  final lead = coeffs[deg];
  if (lead == null || lead == IntegerNumber.one) return poly;
  return (poly / lead).expand().simplify();
}

Expr? _polyGcd(Expr a, Expr b, String variable) {
  var u = a.expand().simplify();
  var v = b.expand().simplify();
  for (var iter = 0; iter < 30; iter++) {
    final degV = polynomialDegree(v, variable);
    if (degV == null) return null;
    if (v is Number && v.isZero) {
      return _makeMonic(u, variable);
    }
    if (degV == 0) return IntegerNumber.one;
    final rem = u.polynomialDivide(v, variable).remainder.expand().simplify();
    u = v;
    v = rem;
  }
  return null;
}

Expr? _tryConjugateRadicalDenominator(
  Expr left,
  Expr t1,
  Expr t2,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  bool isSqrtTerm(Expr e) {
    final factors = e is Mul ? e.factors : [e];
    return factors.any(
      (f) =>
          f is Pow &&
          (f.exponent == FractionNumber.half ||
              (f.exponent is RealNumber &&
                  (f.exponent as RealNumber).value == 0.5)),
    );
  }

  if (!isSqrtTerm(t1) && !isSqrtTerm(t2)) return null;
  final conjDen = (t1 * t1 - t2 * t2).expand().simplify(
    assumptions: assumptions,
  );
  if (conjDen is Number && conjDen.isZero) return null;
  bool hasFracPow(Expr e) {
    if (e is Pow && e.exponent is FractionNumber) return true;
    var found = false;
    e.mapChildren((c) {
      if (!found && hasFracPow(c)) found = true;
      return c;
    });
    return found;
  }

  if (hasFracPow(conjDen)) return null;
  final rationalized = (left * (t1 - t2) / conjDen).simplify(
    assumptions: assumptions,
  );
  final res = antiDerivative(
    rationalized,
    variable,
    depth: depth + 1,
    assumptions: assumptions,
  );
  return hasUnevaluatedIntegral(res, variable) ? null : res;
}
