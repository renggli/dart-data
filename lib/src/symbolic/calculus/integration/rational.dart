import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/term_accumulator.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
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
          .expand()
          .simplify();
      final twoA = (IntegerNumber.two * a).simplify();
      final twoAxPlusB = (twoA * Variable(variable) + b).simplify();

      Expr atanBranch() {
        final sqrtDelta = Pow(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Atan(twoAxPlusB / sqrtDelta))
            .simplify();
      }

      Expr logAbsBranch() {
        final dPos = (-delta).simplify();
        final sqrtD = Pow(dPos, FractionNumber.half).simplify();
        final arg = ((twoAxPlusB - sqrtD) / (twoAxPlusB + sqrtD)).simplify();
        return ((left / sqrtD) * Ln(Abs(arg))).simplify();
      }

      if (delta is Number && delta.isZero) {
        final xPlus = (twoAxPlusB / twoA).simplify();
        return (-left / (a * xPlus)).simplify();
      }
      if (delta.freeVariables.isEmpty && !_containsComplexSubexpr(delta)) {
        try {
          final val = delta.evaluate(const {});
          if (val.isFinite && val != 0.0) {
            return val > 0.0 ? atanBranch() : logAbsBranch();
          }
        } on Object {
          // Fall through to symbolic check below.
        }
      }
      if (delta case RealNumeric(:final sign)) {
        if (sign > 0) return atanBranch();
        if (sign < 0) return logAbsBranch();
      }
      if (isSyntacticallyNegative(delta) && !_containsComplexSubexpr(delta)) {
        final dPos = (-delta).simplify();
        if (isSymbolicPositive(dPos) || _isPositiveCoeffMonomial(dPos)) {
          return logAbsBranch();
        }
      }
      return atanBranch();
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

  if (_tryPowerOverLogPower(left, right, variable, assumptions: assumptions)
      case final logPowRes?) {
    return logPowRes;
  }

  if (_tryTrigOrHypOverLinearPower(
        left,
        right,
        variable,
        assumptions: assumptions,
      )
      case final trigHypLinRes?) {
    return trigHypLinRes;
  }
  if (_tryExpOverRational(
        left,
        right,
        variable,
        depth: depth,
        assumptions: assumptions,
      )
      case final expRatRes?) {
    return expRatRes;
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
  // L / (a + b * ln(c*x + d)) -> (L / (b*c)) * exp(-a/b) * li((c*x + d) * exp(a/b))
  if (!left.dependsOn(variable)) {
    if (right case Ln(expr: final inner)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left / a) * LogIntegral(inner)).simplify();
      }
    }
    if (_matchLinearLog(right, variable) case (
      :final a,
      :final b,
      :final inner,
    )) {
      if (inner.matchLinear(variable) case (a: final c, b: _)) {
        final ratio = (a / b).simplify(assumptions: assumptions);
        return ((left / (b * c)) *
                Pow(Constant.e, -ratio) *
                LogIntegral(inner * Pow(Constant.e, ratio)))
            .simplify(assumptions: assumptions);
      }
    }
  }

  // Split ln(c * x) -> ln(c) + ln(x) when denominator contains ln(x)
  if (depth < 2 &&
      right.anyNode((n) => n is Ln && n.expr == Variable(variable)) &&
      left.anyNode((n) => _isScaledVarLn(n, variable))) {
    final splitLeft = _splitScaledVarLn(
      left,
      variable,
    ).simplify(assumptions: assumptions);
    if (splitLeft != left) {
      final res = antiDerivative(
        (splitLeft / right).simplify(assumptions: assumptions),
        variable,
        depth: depth + 1,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
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
        return (Pow(Constant.e, shift) * ExpIntegral(eiArg) / c1).simplify();
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

  // c * (sin|cos|sinh|cosh|exp)(a*x + b) / (c1*x + d1)
  if (right.matchLinear(variable) case (a: final c1, b: final d1)) {
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
      Expr? shiftedTrigInt(
        Expr inner,
        Expr Function(Expr) sameFn,
        Expr Function(Expr) crossFn,
        Expr Function(Expr) sameWeight,
        Expr Function(Expr) crossWeight,
        int crossSign,
      ) {
        if (inner.matchLinear(variable) case (:final a, :final b)) {
          final alpha = (a / c1).simplify();
          final u = (alpha * right).simplify();
          final phi = (b - (a * d1) / c1).simplify();
          if (phi is Number && phi.isZero) {
            return (scale * sameFn(u) / c1).simplify();
          }
          final sum = crossSign > 0
              ? sameWeight(phi) * sameFn(u) + crossWeight(phi) * crossFn(u)
              : sameWeight(phi) * sameFn(u) - crossWeight(phi) * crossFn(u);
          return (scale * sum / c1).simplify();
        }
        return null;
      }

      switch (vf) {
        case Sin(expr: final inner):
          if (shiftedTrigInt(
                inner,
                SinIntegral.new,
                CosIntegral.new,
                Cos.new,
                Sin.new,
                1,
              )
              case final res?) {
            return res;
          }
        case Cos(expr: final inner):
          if (shiftedTrigInt(
                inner,
                CosIntegral.new,
                SinIntegral.new,
                Cos.new,
                Sin.new,
                -1,
              )
              case final res?) {
            return res;
          }
        case Sinh(expr: final inner):
          if (shiftedTrigInt(
                inner,
                SinhIntegral.new,
                CoshIntegral.new,
                Cosh.new,
                Sinh.new,
                1,
              )
              case final res?) {
            return res;
          }
        case Cosh(expr: final inner):
          if (shiftedTrigInt(
                inner,
                CoshIntegral.new,
                SinhIntegral.new,
                Cosh.new,
                Sinh.new,
                1,
              )
              case final res?) {
            return res;
          }
        case Pow(base: Constant.e, exponent: final expInner):
          if (expInner.matchLinear(variable) case (:final a, :final b)) {
            final phi = (b - (a * d1) / c1).simplify();
            final u = ((a / c1) * right).simplify();
            return (scale * Pow(Constant.e, phi) * ExpIntegral(u) / c1)
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

  // Chain rule quotient: int u'(x) / u(x) dx = ln(|u(x)|) and u'(x) / u(x)^m dx
  if (right.dependsOn(variable)) {
    final uPrime = right.derivative(variable).simplify();
    var k = left.matchScalarMultiple(uPrime, variable);
    if (k == null) {
      if ((left - uPrime).simplify() == IntegerNumber.zero) {
        k = IntegerNumber.one;
      } else if ((left + uPrime).simplify() == IntegerNumber.zero) {
        k = IntegerNumber.negativeOne;
      }
    }
    if (k != null) {
      return logAntiderivative(
        right,
        assumptions,
      ).simplify(assumptions: assumptions).scale(k);
    }
    if (right
        case Pow(base: final uBase, exponent: IntegerNumber(asInt: final m?))
        when m >= 2 && uBase.dependsOn(variable)) {
      final basePrime = uBase.derivative(variable).simplify();
      var km = left.matchScalarMultiple(basePrime, variable);
      if (km == null) {
        if ((left - basePrime).simplify() == IntegerNumber.zero) {
          km = IntegerNumber.one;
        } else if ((left + basePrime).simplify() == IntegerNumber.zero) {
          km = IntegerNumber.negativeOne;
        }
      }
      if (km != null) {
        final oneMinusM = IntegerNumber.of(1 - m);
        return (km * Pow(uBase, oneMinusM) / oneMinusM).simplify(
          assumptions: assumptions,
        );
      }
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

  // Ostrogradsky reduction for x^k / (a + b*x^n)^m
  if (_tryBinomialPowerOstrogradsky(
        left,
        right,
        variable,
        depth: depth,
        assumptions: assumptions,
      )
      case final ostroRes?) {
    return ostroRes;
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

    final sumProdRes = _trySumToProductTrigQuotient(
      left,
      right,
      variable,
      depth: depth,
      assumptions: assumptions,
    );
    if (sumProdRes != null) return sumProdRes;
  }

  // Rational functions P(x) / Q(x): polynomial division and partial fractions
  if (right.dependsOn(variable)) {
    if (_tryMonomialDenominator(left, right, variable, assumptions: assumptions)
        case final monoRes?) {
      return monoRes;
    }
    if (_tryLinearPowerDenominator(
          left,
          right,
          variable,
          assumptions: assumptions,
        )
        case final linPowRes?) {
      return linPowRes;
    }
    if (_tryTwoLinearPowersDenominator(
          left,
          right,
          variable,
          assumptions: assumptions,
        )
        case final twoLinPowRes?) {
      return twoLinPowRes;
    }
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
        (rawDegLeft >= rawDegRight ? rawDegRight <= 24 : rawDegRight <= 12) &&
        !isIntegrationBudgetExhausted() &&
        !exceedsNodeBudget(left, 250) &&
        !exceedsNodeBudget(right, 250)) {
      final leftExp = left.expand().simplify();
      final rightExp = right.expand().simplify();
      final degLeft = polynomialDegree(leftExp, variable);
      final degRight = polynomialDegree(rightExp, variable);
      if (degLeft != null && degRight != null && degRight >= 1) {
        if (depth < 2 && degLeft <= 12 && degRight <= 12) {
          final canceled = (leftExp / rightExp).cancel(
            assumptions: assumptions,
          );
          final (_, cDen) = splitNumeratorDenominator(canceled);
          final cDegDen = polynomialDegree(cDen.expand().simplify(), variable);
          if (cDegDen != null && cDegDen < degRight) {
            return antiDerivative(
              canceled,
              variable,
              depth: depth + 1,
              assumptions: assumptions,
            );
          }
        }
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
  final disc = (b * b - const IntegerNumber(Integer(4)) * a * c)
      .expand()
      .simplify();
  if (disc is Number && disc.isZero) return null;
  if (isSymbolicPositive(disc)) {
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final r1 = ((b + sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final r2 = ((b - sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final diffR = (r2 - r1).expand().simplify();
    if (diffR is Number && diffR.isZero) return null;
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
  if (numCoeffs == null ||
      denCoeffs == null ||
      numCoeffs.isEmpty ||
      denCoeffs.isEmpty) {
    return null;
  }

  var n0 = numCoeffs.keys.first;
  for (final e in numCoeffs.keys) {
    if (e < n0) n0 = e;
  }
  var d0 = denCoeffs.keys.first;
  for (final e in denCoeffs.keys) {
    if (e < d0) d0 = e;
  }
  final common = n0 < d0 ? n0 : d0;
  final shiftedNum = {
    for (final MapEntry(:key, :value) in numCoeffs.entries) key - common: value,
  };
  final shiftedDen = {
    for (final MapEntry(:key, :value) in denCoeffs.entries) key - common: value,
  };
  d0 -= common;

  var k = 0;
  for (final e in shiftedDen.keys) {
    final diff = e - d0;
    if (diff > 0) {
      k = k == 0 ? diff : k.gcd(diff);
    }
  }
  if (k < 2) return null;

  for (final e in shiftedNum.keys) {
    final shifted = e + 1 - d0;
    if (shifted < 0) return null;
    if (shifted > 0) k = k.gcd(shifted);
  }
  if (k < 2) return null;

  final uName = '_upow$depth';
  final uVar = Variable(uName);

  var uNum = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in shiftedNum.entries) {
    final q = (e + 1 - d0) ~/ k;
    final uPow = q == 0
        ? IntegerNumber.one
        : (q == 1 ? uVar : Pow(uVar, IntegerNumber.of(q)));
    uNum = uNum + c * uPow;
  }

  var uDen = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in shiftedDen.entries) {
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
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(a, 250) ||
      exceedsNodeBudget(b, 250)) {
    return null;
  }
  var u = a.expand().simplify();
  var v = b.expand().simplify();
  for (var iter = 0; iter < 20; iter++) {
    if (isIntegrationBudgetExhausted() ||
        exceedsNodeBudget(u, 250) ||
        exceedsNodeBudget(v, 250)) {
      return null;
    }
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

bool _containsComplexSubexpr(Expr expr) => expr.anyNode(
  (node) =>
      node is ComplexNumber ||
      (node is Pow &&
          node.exponent is FractionNumber &&
          (node.exponent as FractionNumber).denominator.isEven &&
          (isSyntacticallyNegative(node.base) ||
              isNegativeConstant(node.base))),
);

bool _isPositiveCoeffMonomial(Expr expr) => switch (expr) {
  RealNumeric(:final sign) => sign > 0,
  Variable() => true,
  Pow(:final base) => _isPositiveCoeffMonomial(base),
  Mul(:final factors) => factors.every(_isPositiveCoeffMonomial),
  _ => false,
};

Expr? _tryMonomialDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr scale, int n})? extractMonomial(Expr e) {
    if (e case Variable(:final name) when name == variable) {
      return (scale: IntegerNumber.one, n: 1);
    }
    if (e
        case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final k?),
        )
        when name == variable && k >= 1) {
      return (scale: IntegerNumber.one, n: k);
    }
    if (e case Mul(:final factors)) {
      final constFactors = <Expr>[];
      final varFactors = <Expr>[];
      for (final f in factors) {
        if (f.dependsOn(variable)) {
          varFactors.add(f);
        } else {
          constFactors.add(f);
        }
      }
      if (varFactors.length == 1) {
        final inner = extractMonomial(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul(constFactors).simplify(assumptions: assumptions);
          return (scale: scale, n: inner.n);
        }
      }
    }
    return null;
  }

  final mono = extractMonomial(right);
  if (mono == null) return null;
  final (:scale, :n) = mono;

  final rawDeg = polynomialDegree(left, variable);
  if (rawDeg == null || rawDeg > 40) return null;

  final coeffs = extractPolynomialCoefficients(left, variable);
  if (coeffs == null) return null;

  final xVar = Variable(variable);
  final terms = <Expr>[];
  for (final MapEntry(:key, :value) in coeffs.entries) {
    if (value is Number && value.isZero) continue;
    final exp = key - n;
    if (exp == -1) {
      terms.add((value * logAntiderivative(xVar, assumptions)) / scale);
    } else {
      final newExp = IntegerNumber.of(exp + 1);
      terms.add((value * Pow(xVar, newExp)) / (scale * newExp));
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add(terms).simplify(assumptions: assumptions);
}

Expr? _tryLinearPowerDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  ({Expr scale, Expr linBase, int q})? extractLinPow(Expr e) {
    if (e
        case Pow(base: final linBase, exponent: IntegerNumber(asInt: final q?))
        when q >= 2 && linBase.dependsOn(variable)) {
      return (scale: IntegerNumber.one, linBase: linBase, q: q);
    }
    if (e case Mul(:final factors)) {
      final constFactors = <Expr>[];
      final varFactors = <Expr>[];
      for (final f in factors) {
        if (f.dependsOn(variable)) {
          varFactors.add(f);
        } else {
          constFactors.add(f);
        }
      }
      if (varFactors.length == 1) {
        final inner = extractLinPow(varFactors.first);
        if (inner != null) {
          final scale = constFactors.isEmpty
              ? IntegerNumber.one
              : Mul(constFactors).simplify(assumptions: assumptions);
          return (scale: scale, linBase: inner.linBase, q: inner.q);
        }
      }
    }
    return null;
  }

  final lp = extractLinPow(right);
  if (lp == null) return null;
  final (:scale, :linBase, :q) = lp;

  final lin = linBase.matchLinear(variable);
  if (lin == null) return null;
  final (:a, :b) = lin;
  if (b is Number && b.isZero) return null;

  final rawDeg = polynomialDegree(left, variable);
  if (rawDeg == null || rawDeg == 0 || rawDeg > 20) return null;

  const uName = '_lin_u';
  const uVar = Variable(uName);
  final xOfU = ((uVar - b) / a).simplify(assumptions: assumptions);
  final numU = left
      .substitute(variable, xOfU)
      .simplify(assumptions: assumptions);
  final denU = (a * scale * Pow(uVar, IntegerNumber.of(q))).simplify(
    assumptions: assumptions,
  );
  final resU = _tryMonomialDenominator(
    numU,
    denU,
    uName,
    assumptions: assumptions,
  );
  if (resU == null) return null;
  return resU.substitute(uName, linBase).simplify(assumptions: assumptions);
}

Expr? _tryPowerOverLogPower(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final numFactors = left is Mul ? left.factors : [left];
  final denFactors = right is Mul ? right.factors : [right];

  var scale = IntegerNumber.one as Expr;
  var nExp = IntegerNumber.zero as Expr;
  Expr? logInner;
  Expr? logScale;
  int? kInt;

  bool processFactor(Expr f, {required bool isNum}) {
    if (!f.dependsOn(variable)) {
      scale = (isNum ? scale * f : scale / f).simplify(
        assumptions: assumptions,
      );
      return true;
    }
    if (f is Variable && f.name == variable) {
      nExp = (nExp + (isNum ? IntegerNumber.one : IntegerNumber.negativeOne))
          .simplify(assumptions: assumptions);
      return true;
    }
    if (f case Pow(base: Variable(:final name), :final exponent)
        when name == variable && !exponent.dependsOn(variable)) {
      nExp = (nExp + (isNum ? exponent : -exponent)).simplify(
        assumptions: assumptions,
      );
      return true;
    }
    if (f case Ln(:final expr) when !isNum) {
      if (kInt != null) return false;
      if (expr.matchLinear(variable) case (:final a, :final b)
          when b is Number && b.isZero) {
        logInner = expr;
        logScale = a;
        kInt = 1;
        return true;
      }
      return false;
    }
    if (f case Pow(
      base: Ln(:final expr),
      exponent: IntegerNumber(asInt: final p?),
    )) {
      final k = isNum ? -p : p;
      if (k < 1 || k > 6 || kInt != null) return false;
      if (expr.matchLinear(variable) case (:final a, :final b)
          when b is Number && b.isZero) {
        logInner = expr;
        logScale = a;
        kInt = k;
        return true;
      }
      return false;
    }
    return false;
  }

  for (final f in numFactors) {
    if (!processFactor(f, isNum: true)) return null;
  }
  for (final f in denFactors) {
    if (!processFactor(f, isNum: false)) return null;
  }
  if (logInner == null || logScale == null || kInt == null) return null;

  final inner = logInner!;
  final c = logScale!;
  final k = kInt!;
  final lnExpr = Ln(inner);
  final xVar = Variable(variable);

  if (nExp == IntegerNumber.negativeOne) {
    final res = k == 1
        ? logAntiderivative(lnExpr, assumptions)
        : (-Pow(lnExpr, IntegerNumber.of(1 - k)) / IntegerNumber.of(k - 1));
    return (scale * res).simplify(assumptions: assumptions);
  }

  final np1 = (nExp + IntegerNumber.one).simplify(assumptions: assumptions);
  final isZeroN = nExp is Number && (nExp as Number).isZero;
  Expr integrateK(int m) {
    if (m == 1) {
      if (isZeroN) {
        return (LogIntegral(inner) / c).simplify(assumptions: assumptions);
      }
      return (ExpIntegral((np1 * lnExpr).simplify(assumptions: assumptions)) /
              Pow(c, np1))
          .simplify(assumptions: assumptions);
    }
    final m1 = IntegerNumber.of(m - 1);
    final term1 = -Pow(xVar, np1) / (m1 * Pow(lnExpr, m1));
    final term2 = (np1 / m1) * integrateK(m - 1);
    return (term1 + term2).simplify(assumptions: assumptions);
  }

  return (scale * integrateK(k)).simplify(assumptions: assumptions);
}

Expr? _tryTrigOrHypOverLinearPower(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final Expr linBase;
  final int k;
  if (right
      case Pow(base: final rBase, exponent: IntegerNumber(asInt: final p?))
      when p >= 1 && p <= 6) {
    linBase = rBase;
    k = p;
  } else {
    linBase = right;
    k = 1;
  }

  final linDen = linBase.matchLinear(variable);
  if (linDen == null) return null;
  final (a: d, b: c) = linDen;

  // Handle powered trig/hyperbolic numerator: (sin|cos|sinh|cosh)(u)^n / (c + d*x)^k
  if (left
      case Pow(
        base: Sin() || Cos() || Sinh() || Cosh(),
        exponent: IntegerNumber(asInt: final n?),
      )
      when n >= 2 && n <= 4) {
    final reduced = reduceTrigPower(left, variable);
    if (reduced != null) {
      final expanded = reduced
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      final terms = expanded is Add ? expanded.terms : [expanded];
      final results = <Expr>[];
      for (final t in terms) {
        final res = antiDerivative(
          (t / right).simplify(assumptions: assumptions),
          variable,
          depth: 2,
          assumptions: assumptions,
        );
        if (hasUnevaluatedIntegral(res, variable)) return null;
        results.add(res);
      }
      return Add(results).simplify(assumptions: assumptions);
    }
  }

  final Expr inner;
  if (left case Sin(:final expr)) {
    inner = expr;
  } else if (left case Cos(:final expr)) {
    inner = expr;
  } else if (left case Sinh(:final expr)) {
    inner = expr;
  } else if (left case Cosh(:final expr)) {
    inner = expr;
  } else {
    return null;
  }

  final linNum = inner.matchLinear(variable);
  if (linNum == null) return null;
  final (a: b, b: a) = linNum;

  Expr integrateBase(Expr fn) {
    final beta = (b / d).simplify(assumptions: assumptions);
    final alpha = (a - b * c / d).simplify(assumptions: assumptions);
    final arg = (beta * linBase).simplify(assumptions: assumptions);
    return switch (fn) {
      Sin() =>
        ((Cos(alpha) * SinIntegral(arg) + Sin(alpha) * CosIntegral(arg)) / d)
            .simplify(assumptions: assumptions),
      Cos() =>
        ((Cos(alpha) * CosIntegral(arg) - Sin(alpha) * SinIntegral(arg)) / d)
            .simplify(assumptions: assumptions),
      Sinh() =>
        ((Cosh(alpha) * SinhIntegral(arg) + Sinh(alpha) * CoshIntegral(arg)) /
                d)
            .simplify(assumptions: assumptions),
      Cosh() =>
        ((Cosh(alpha) * CoshIntegral(arg) + Sinh(alpha) * SinhIntegral(arg)) /
                d)
            .simplify(assumptions: assumptions),
      _ => throw StateError('Unreachable'),
    };
  }

  Expr integrateK(Expr fn, int m) {
    if (m == 1) return integrateBase(fn);
    final m1 = IntegerNumber.of(m - 1);
    final denomPow = m - 1 == 1 ? linBase : Pow(linBase, m1);
    final term1 = (-fn / (d * m1 * denomPow)).simplify(
      assumptions: assumptions,
    );
    final (Expr derivScale, Expr nextFn) = switch (fn) {
      Sin() => (b, Cos(inner)),
      Cos() => (-b, Sin(inner)),
      Sinh() => (b, Cosh(inner)),
      Cosh() => (b, Sinh(inner)),
      _ => throw StateError('Unreachable'),
    };
    final rem = integrateK(nextFn, m - 1);
    return (term1 + (derivScale / (d * m1)) * rem).simplify(
      assumptions: assumptions,
    );
  }

  return integrateK(left, k);
}

Expr? _tryExpOverRational(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  var scale = IntegerNumber.one as Expr;
  Pow? expNode;
  if (left is Pow && left.base == Constant.e) {
    expNode = left;
  } else if (left is Mul) {
    final consts = <Expr>[];
    final vars = <Expr>[];
    for (final f in left.factors) {
      if (f.dependsOn(variable)) {
        vars.add(f);
      } else {
        consts.add(f);
      }
    }
    if (vars.length == 1 && vars.first is Pow) {
      final p = vars.first as Pow;
      if (p.base == Constant.e) {
        expNode = p;
        if (consts.isNotEmpty) {
          scale = Mul(consts).simplify(assumptions: assumptions);
        }
      }
    }
  }
  if (expNode == null) return null;

  final linExp = expNode.exponent.matchLinear(variable);
  if (linExp == null) return null;
  final (a: b, b: a) = linExp;

  // Case 1: right is (c + d*x)^k with 1 <= k <= 6
  final Expr linBase;
  final int k;
  if (right
      case Pow(base: final rBase, exponent: IntegerNumber(asInt: final p?))
      when p >= 1 && p <= 6) {
    linBase = rBase;
    k = p;
  } else {
    linBase = right;
    k = 1;
  }
  final linDen = linBase.matchLinear(variable);
  if (linDen != null) {
    final (a: d, b: c) = linDen;
    Expr integrateK(int m) {
      if (m == 1) {
        final shift = Pow(
          Constant.e,
          (a - b * c / d).simplify(assumptions: assumptions),
        );
        final arg = ((b / d) * linBase).simplify(assumptions: assumptions);
        return (scale * shift * ExpIntegral(arg) / d).simplify(
          assumptions: assumptions,
        );
      }
      final m1 = IntegerNumber.of(m - 1);
      final denomPow = m - 1 == 1 ? linBase : Pow(linBase, m1);
      final term1 = (-left / (d * m1 * denomPow)).simplify(
        assumptions: assumptions,
      );
      final rem = integrateK(m - 1);
      return (term1 + (b / (d * m1)) * rem).simplify(assumptions: assumptions);
    }

    return integrateK(k);
  }

  // Case 2: right is a polynomial of degree 2..4 -> partial fractions
  if (depth < 2) {
    final deg = polynomialDegree(right, variable);
    if (deg != null && deg >= 2 && deg <= 4) {
      final pf = (IntegerNumber.one / right).apart(variable);
      if (pf is Add) {
        final results = <Expr>[];
        for (final term in pf.terms) {
          final res = antiDerivative(
            (left * term).simplify(assumptions: assumptions),
            variable,
            depth: depth + 1,
            assumptions: assumptions,
          );
          if (hasUnevaluatedIntegral(res, variable)) return null;
          results.add(res);
        }
        return Add(results).simplify(assumptions: assumptions);
      }
    }
  }
  return null;
}

Expr? _trySumToProductTrigQuotient(
  Expr left,
  Add right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (left is! Add || left.terms.length != 2 || right.terms.length != 2) {
    return null;
  }

  ({int sign, Expr arg})? matchSignedSin(Expr e) => switch (e) {
    Sin(:final expr) => (sign: 1, arg: expr),
    Mul(factors: [IntegerNumber(isNegativeOne: true), Sin(:final expr)]) => (
      sign: -1,
      arg: expr,
    ),
    _ => null,
  };

  ({int sign, Expr arg})? matchSignedCos(Expr e) => switch (e) {
    Cos(:final expr) => (sign: 1, arg: expr),
    Mul(factors: [IntegerNumber(isNegativeOne: true), Cos(:final expr)]) => (
      sign: -1,
      arg: expr,
    ),
    _ => null,
  };

  final s0 = matchSignedSin(left.terms[0]);
  final s1 = matchSignedSin(left.terms[1]);
  final c0 = matchSignedCos(right.terms[0]);
  final c1 = matchSignedCos(right.terms[1]);
  if (s0 == null || s1 == null || c0 == null || c1 == null) return null;

  final ({int sign, Expr arg}) cosA;
  final ({int sign, Expr arg}) cosB;
  if (s0.arg == c0.arg && s1.arg == c1.arg) {
    cosA = c0;
    cosB = c1;
  } else if (s0.arg == c1.arg && s1.arg == c0.arg) {
    cosA = c1;
    cosB = c0;
  } else {
    return null;
  }

  final a = s0.arg;
  final b = s1.arg;
  if (a == b ||
      a.matchLinear(variable) == null ||
      b.matchLinear(variable) == null) {
    return null;
  }

  var numSignA = s0.sign;
  var numSignB = s1.sign;
  var denSignA = cosA.sign;
  var denSignB = cosB.sign;
  var overallSign = 1;
  if (denSignA == -1) {
    denSignA = 1;
    denSignB = -denSignB;
    overallSign = -overallSign;
  }
  if (numSignA == -1) {
    numSignA = 1;
    numSignB = -numSignB;
    overallSign = -overallSign;
  }

  final Expr rewritten;
  if (denSignB == 1) {
    final angle = ((numSignB == 1 ? a + b : a - b) / IntegerNumber.two)
        .simplify(assumptions: assumptions);
    rewritten = (IntegerNumber.of(overallSign) * Tan(angle)).simplify(
      assumptions: assumptions,
    );
  } else {
    final angle = ((numSignB == 1 ? a - b : a + b) / IntegerNumber.two)
        .simplify(assumptions: assumptions);
    rewritten = (IntegerNumber.of(-overallSign) / Tan(angle)).simplify(
      assumptions: assumptions,
    );
  }

  final res = antiDerivative(
    rewritten,
    variable,
    assumptions: assumptions,
    depth: depth + 1,
  );
  return hasUnevaluatedIntegral(res, variable) ? null : res;
}

({Expr a, Expr b, Expr inner})? _matchLinearLog(Expr expr, String variable) {
  final terms = expr is Add ? expr.terms : [expr];
  var a = IntegerNumber.zero as Expr;
  Expr? b;
  Expr? inner;
  for (final t in terms) {
    if (!t.dependsOn(variable)) {
      a = (a + t).simplify();
      continue;
    }
    if (t case Ln(expr: final arg) when inner == null || inner == arg) {
      inner = arg;
      b = ((b ?? IntegerNumber.zero) + IntegerNumber.one).simplify();
      continue;
    }
    if (t case Mul(:final factors)) {
      var coeff = IntegerNumber.one as Expr;
      Expr? lnArg;
      var valid = true;
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          coeff = (coeff * f).simplify();
        } else if (f case Ln(expr: final arg) when lnArg == null) {
          lnArg = arg;
        } else {
          valid = false;
          break;
        }
      }
      if (valid && lnArg != null && (inner == null || inner == lnArg)) {
        inner = lnArg;
        b = ((b ?? IntegerNumber.zero) + coeff).simplify();
        continue;
      }
    }
    return null;
  }
  if (b == null || inner == null || (b is Number && b.isZero)) return null;
  return (a: a, b: b, inner: inner);
}

bool _isScaledVarLn(Expr node, String variable) {
  if (node case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number && b.isZero && a != IntegerNumber.one) {
      return true;
    }
  }
  return false;
}

Expr _splitScaledVarLn(Expr node, String variable) {
  if (node case Ln(expr: final inner)) {
    if (inner.matchLinear(variable) case (a: final a, b: final b)
        when b is Number && b.isZero && a != IntegerNumber.one) {
      return Ln(a) + Ln(Variable(variable));
    }
  }
  return node.mapChildren((c) => _splitScaledVarLn(c, variable));
}

Expr? _tryTwoLinearPowersDenominator(
  Expr left,
  Expr right,
  String variable, {
  required Assumptions assumptions,
}) {
  final factors = right is Mul ? right.factors : [right];
  var scale = IntegerNumber.one as Expr;
  final linFactors = <Expr, int>{};

  for (final f in factors) {
    if (!f.dependsOn(variable)) {
      scale = (scale * f).simplify(assumptions: assumptions);
      continue;
    }
    if (f.matchLinear(variable) != null) {
      linFactors[f] = (linFactors[f] ?? 0) + 1;
      continue;
    }
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
        when exp >= 1 && exp <= 20 && base.matchLinear(variable) != null) {
      linFactors[base] = (linFactors[base] ?? 0) + exp;
      continue;
    }
    return null;
  }

  if (linFactors.length == 3 && !left.dependsOn(variable)) {
    final entries = linFactors.entries.toList();
    final u1 = entries[0].key;
    final p1 = entries[0].value;
    final u2 = entries[1].key;
    final p2 = entries[1].value;
    final u3 = entries[2].key;
    final p3 = entries[2].value;
    if (p1 + p2 + p3 > 16) return null;
    final l1 = u1.matchLinear(variable)!;
    final l2 = u2.matchLinear(variable)!;
    final l3 = u3.matchLinear(variable)!;
    final det12 = (l1.a * l2.b - l1.b * l2.a).expand().simplify(
      assumptions: assumptions,
    );
    final det13 = (l1.a * l3.b - l1.b * l3.a).expand().simplify(
      assumptions: assumptions,
    );
    final det23 = (l2.a * l3.b - l2.b * l3.a).expand().simplify(
      assumptions: assumptions,
    );
    if ((det12 is Number && det12.isZero) ||
        (det13 is Number && det13.isZero) ||
        (det23 is Number && det23.isZero)) {
      return null;
    }
    final decomp23 = _decomposeTwoLinearPowers(
      (left / scale).simplify(assumptions: assumptions),
      u2,
      p2,
      u3,
      p3,
      l2.a,
      l3.a,
      det23,
      assumptions,
    );
    final terms = <Expr>[];
    for (final (:coeff, :factor, :power) in decomp23) {
      if (factor == u2) {
        terms.add(
          _integrateTwoLinearPowersConst(
            coeff,
            u1,
            p1,
            u2,
            power,
            l1.a,
            l2.a,
            det12,
            assumptions,
          ),
        );
      } else {
        terms.add(
          _integrateTwoLinearPowersConst(
            coeff,
            u1,
            p1,
            u3,
            power,
            l1.a,
            l3.a,
            det13,
            assumptions,
          ),
        );
      }
    }
    return Add(terms).simplify(assumptions: assumptions);
  }

  if (linFactors.length != 2) return null;
  final entries = linFactors.entries.toList();
  final u = entries[0].key;
  final p = entries[0].value;
  final v = entries[1].key;
  final q = entries[1].value;
  if (p + q > 20) return null;

  final uLin = u.matchLinear(variable)!;
  final vLin = v.matchLinear(variable)!;
  final b = uLin.a;
  final a = uLin.b;
  final d = vLin.a;
  final c = vLin.b;
  final det = (b * c - a * d).expand().simplify(assumptions: assumptions);
  if (det is Number && det.isZero) return null;

  if (!left.dependsOn(variable)) {
    return _integrateTwoLinearPowersConst(
      (left / scale).simplify(assumptions: assumptions),
      u,
      p,
      v,
      q,
      b,
      d,
      det,
      assumptions,
    );
  }

  final degLeft = polynomialDegree(left, variable);
  if (degLeft == null || degLeft > 4) return null;

  // Decompose left in powers of u: left = sum c_m * u^m
  final coeffsInU = <Expr>[];
  var cur = left.expand().simplify(assumptions: assumptions);
  for (var m = 0; m <= degLeft; m++) {
    final (:quotient, :remainder) = cur.polynomialDivide(
      u,
      variable,
      assumptions: assumptions,
    );
    coeffsInU.add(remainder);
    cur = quotient;
  }

  final terms = <Expr>[];
  for (var m = 0; m < coeffsInU.length; m++) {
    final cm = coeffsInU[m];
    if (cm is Number && cm.isZero) continue;
    final scaledCm = (cm / scale).simplify(assumptions: assumptions);
    if (m < p) {
      terms.add(
        _integrateTwoLinearPowersConst(
          scaledCm,
          u,
          p - m,
          v,
          q,
          b,
          d,
          det,
          assumptions,
        ),
      );
    } else {
      final numExpr = m == p
          ? scaledCm
          : (scaledCm * Pow(u, IntegerNumber.of(m - p))).simplify();
      final remInt = _tryLinearPowerDenominator(
        numExpr,
        Pow(v, IntegerNumber.of(q)),
        variable,
        assumptions: assumptions,
      );
      if (remInt == null) return null;
      terms.add(remInt);
    }
  }
  return terms.isEmpty
      ? IntegerNumber.zero
      : Add(terms).simplify(assumptions: assumptions);
}

List<({Expr coeff, Expr factor, int power})> _decomposeTwoLinearPowers(
  Expr coeff,
  Expr u,
  int p,
  Expr v,
  int q,
  Expr b,
  Expr d,
  Expr det,
  Assumptions assumptions,
) {
  final result = <({Expr coeff, Expr factor, int power})>[];
  final negD = (-d).simplify(assumptions: assumptions);

  // Terms A_i / u^i for 1 <= i <= p:
  // A_i = C(p - i + q - 1, q - 1) * (-d)^(p - i) * b^q / det^(p - i + q)
  final bPowQ = Pow(b, IntegerNumber.of(q));
  for (var i = 1; i <= p; i++) {
    final binom = Integer.from(p - i + q - 1).binomial(Integer.from(q - 1));
    final ai =
        (coeff *
                IntegerNumber(binom) *
                Pow(negD, IntegerNumber.of(p - i)) *
                bPowQ /
                Pow(det, IntegerNumber.of(p - i + q)))
            .simplify(assumptions: assumptions);
    result.add((coeff: ai, factor: u, power: i));
  }

  // Terms B_j / v^j for 1 <= j <= q:
  // B_j = C(p - 1 + q - j, p - 1) * (-d)^p * b^(q - j) / det^(p + q - j)
  final negDPowP = Pow(negD, IntegerNumber.of(p));
  for (var j = 1; j <= q; j++) {
    final binom = Integer.from(p - 1 + q - j).binomial(Integer.from(p - 1));
    final bj =
        (coeff *
                IntegerNumber(binom) *
                negDPowP *
                Pow(b, IntegerNumber.of(q - j)) /
                Pow(det, IntegerNumber.of(p + q - j)))
            .simplify(assumptions: assumptions);
    result.add((coeff: bj, factor: v, power: j));
  }

  return result;
}

Expr _integrateTwoLinearPowersConst(
  Expr coeff,
  Expr u,
  int p,
  Expr v,
  int q,
  Expr b,
  Expr d,
  Expr det,
  Assumptions assumptions,
) {
  final decomp = _decomposeTwoLinearPowers(
    coeff,
    u,
    p,
    v,
    q,
    b,
    d,
    det,
    assumptions,
  );
  final terms = <Expr>[];
  for (final (:coeff, :factor, :power) in decomp) {
    final slope = factor == u ? b : d;
    if (power == 1) {
      terms.add(
        ((coeff / slope) * logAntiderivative(factor, assumptions)).simplify(
          assumptions: assumptions,
        ),
      );
    } else {
      final oneMinusPow = IntegerNumber.of(1 - power);
      terms.add(
        ((coeff / (slope * oneMinusPow)) * Pow(factor, oneMinusPow)).simplify(
          assumptions: assumptions,
        ),
      );
    }
  }
  return Add(terms).simplify(assumptions: assumptions);
}

Expr? _tryBinomialPowerOstrogradsky(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth > 8) return null;
  if (right is! Pow) return null;
  final base = right.base;
  final mExpr = right.exponent;
  if (mExpr.dependsOn(variable) || mExpr == IntegerNumber.one) return null;
  if (base is! Add || base.terms.length != 2) return null;
  final t0 = base.terms[0];
  final t1 = base.terms[1];

  final Expr a;
  final Expr bXn;
  if (!t0.dependsOn(variable) && t1.dependsOn(variable)) {
    a = t0;
    bXn = t1;
  } else if (!t1.dependsOn(variable) && t0.dependsOn(variable)) {
    a = t1;
    bXn = t0;
  } else {
    return null;
  }
  if (a == IntegerNumber.zero) return null;

  ({Expr coeff, Expr exp})? extractMonomial(Expr e) {
    if (!e.dependsOn(variable)) return (coeff: e, exp: IntegerNumber.zero);
    if (e is Variable && e.name == variable) {
      return (coeff: IntegerNumber.one, exp: IntegerNumber.one);
    }
    if (e case Pow(base: Variable(:final name), exponent: final exp)
        when name == variable && !exp.dependsOn(variable)) {
      return (coeff: IntegerNumber.one, exp: exp);
    }
    if (e case Mul(:final factors)) {
      final consts = <Expr>[];
      Expr? xPow;
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          consts.add(f);
        } else if (xPow == null) {
          xPow = f;
        } else {
          return null;
        }
      }
      if (xPow == null) return null;
      final inner = extractMonomial(xPow);
      if (inner == null) return null;
      final c = consts.isEmpty
          ? IntegerNumber.one
          : Mul(consts).simplify(assumptions: assumptions);
      return (
        coeff: (c * inner.coeff).simplify(assumptions: assumptions),
        exp: inner.exp,
      );
    }
    return null;
  }

  final bxnInfo = extractMonomial(bXn);
  if (bxnInfo == null || bxnInfo.exp == IntegerNumber.zero) return null;
  final leftInfo = extractMonomial(left);
  if (leftInfo == null) return null;

  final n = bxnInfo.exp;
  final k = leftInfo.exp;
  final c = leftInfo.coeff;
  final mMinus1 = (mExpr - IntegerNumber.one).simplify(
    assumptions: assumptions,
  );
  if (mMinus1 == IntegerNumber.zero) return null;

  final remNum = (n * mMinus1 - k - IntegerNumber.one).simplify(
    assumptions: assumptions,
  );
  final isIntM =
      mExpr is IntegerNumber &&
      mExpr.value >= const Integer(2) &&
      mExpr.value <= const Integer(10);
  if (!isIntM && remNum != IntegerNumber.zero) return null;

  final xVar = Variable(variable);
  final denomFactor = (a * n * mMinus1).simplify(assumptions: assumptions);
  if (denomFactor == IntegerNumber.zero) return null;

  final term1 =
      (Pow(xVar, (k + IntegerNumber.one).simplify(assumptions: assumptions)) /
              (denomFactor * Pow(base, mMinus1)))
          .simplify(assumptions: assumptions);

  if (remNum == IntegerNumber.zero) {
    return (c * term1).simplify(assumptions: assumptions);
  }

  final reducedIntegrand = (Pow(xVar, k) / Pow(base, mMinus1)).simplify(
    assumptions: assumptions,
  );
  final reducedIntegral = antiDerivative(
    reducedIntegrand,
    variable,
    depth: depth + 1,
    assumptions: assumptions,
  );
  final term2 = ((remNum / denomFactor) * reducedIntegral).simplify(
    assumptions: assumptions,
  );
  return (c * (term1 + term2)).simplify(assumptions: assumptions);
}
