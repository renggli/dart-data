import 'dart:math' as math;

import '../../../special/bessel.dart' as special_bessel;
import '../../../special/beta.dart' as special_beta;
import '../../../special/digamma.dart' as special_digamma;
import '../../../special/elliptic.dart' as special_elliptic;
import '../../../special/erf.dart' as special_erf;
import '../../../special/gamma.dart' as special_gamma;
import '../../../special/lambert_w.dart' as special_lambert;
import '../../../special/zeta.dart' as special_zeta;
import '../../assumptions.dart';
import '../../ast.dart';
import '../../calculus/differentiation.dart';
import '../../calculus/summation.dart' show evenZetaValue;
import '../../compiler.dart';
import '../../number/integer.dart';
import '../exact_constants.dart';
import '../simplify.dart';
import '../structural_order.dart';
import 'additive.dart';
import 'domain.dart';
import 'multiplicative.dart';
import 'power.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifySin(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.sin(expr.value));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr is Asin) return expr.expr;

  // Parity: sin(-u) = -sin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySin(posExpr, assumptions: assumptions));
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.isInteger) {
      return IntegerNumber.zero;
    }
    final den = piMult.denominator;
    final num = piMult.numerator;
    if (den == Integer.two) {
      final k = (num - Integer.one) ~/ Integer.two;
      return k.isEven ? IntegerNumber.one : IntegerNumber.negativeOne;
    }
    if (den == const Integer(6)) {
      final rem = (num % const Integer(12)).toInt();
      if (rem == 1 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.half);
      }
      if (rem == 7 || rem == 11) {
        return specialRadicalExpr(SpecialRadical.half, negative: true);
      }
    }
    if (den == const Integer(4)) {
      final rem = (num % const Integer(8)).toInt();
      if (rem == 1 || rem == 3) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2);
      }
      if (rem == 5 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true);
      }
    }
    if (den == const Integer(3)) {
      final rem = (num % const Integer(6)).toInt();
      if (rem == 1 || rem == 2) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2);
      }
      if (rem == 4 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2, negative: true);
      }
    }
  }
  if (_matchIntegerPiMultiple(expr, assumptions) != null) {
    return IntegerNumber.zero;
  }

  return Sin(expr, isSimplified: true);
}

/// Simplifies a cosine expression $\cos(expr)$.
Expr simplifyCos(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.cos(expr.value));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr is Acos) return expr.expr;

  // Parity: cos(-u) = cos(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCos(posExpr, assumptions: assumptions);
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.isInteger) {
      return piMult.numerator.isEven
          ? IntegerNumber.one
          : IntegerNumber.negativeOne;
    }
    final den = piMult.denominator;
    final num = piMult.numerator;
    if (den == Integer.two && num.isOdd) {
      return IntegerNumber.zero;
    }
    if (den == const Integer(6)) {
      final rem = (num % const Integer(12)).toInt();
      if (rem == 1 || rem == 11) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2);
      }
      if (rem == 5 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2, negative: true);
      }
    }
    if (den == const Integer(4)) {
      final rem = (num % const Integer(8)).toInt();
      if (rem == 1 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2);
      }
      if (rem == 3 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true);
      }
    }
    if (den == const Integer(3)) {
      final rem = (num % const Integer(6)).toInt();
      if (rem == 1 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.half);
      }
      if (rem == 2 || rem == 4) {
        return specialRadicalExpr(SpecialRadical.half, negative: true);
      }
    }
  }
  if (_matchIntegerPiMultiple(expr, assumptions) case final intFactor?) {
    if (isEvenIntegerExpr(intFactor, assumptions: assumptions)) {
      return IntegerNumber.one;
    }
    return simplifyPow(
      IntegerNumber.negativeOne,
      intFactor,
      assumptions: assumptions,
    );
  }

  return Cos(expr, isSimplified: true);
}

/// Simplifies a tangent expression $\tan(expr)$.
Expr simplifyTan(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = math.tan(expr.value);
    return v.isFinite ? RealNumber.fromDouble(v) : Constant.undefined;
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: tan(atan(u)) = u
  if (expr is Atan) return expr.expr;

  // Parity: tan(-u) = -tan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTan(posExpr, assumptions: assumptions));
  }

  // Multiples of pi
  final piMult = matchPiMultiple(expr);
  if (piMult != null) {
    if (piMult.isInteger) {
      return IntegerNumber.zero;
    }
    final den = piMult.denominator;
    final num = piMult.numerator;
    if (den == Integer.two) {
      return Constant.undefined;
    }
    if (den == const Integer(4)) {
      final rem = (num % const Integer(4)).toInt();
      if (rem == 1) return IntegerNumber.one;
      if (rem == 3) return IntegerNumber.negativeOne;
    }
    if (den == const Integer(6)) {
      final rem = (num % const Integer(6)).toInt();
      if (rem == 1) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over3);
      }
      if (rem == 5) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over3, negative: true);
      }
    }
    if (den == const Integer(3)) {
      final rem = (num % const Integer(3)).toInt();
      if (rem == 1) {
        return specialRadicalExpr(SpecialRadical.sqrt3);
      }
      if (rem == 2) {
        return specialRadicalExpr(SpecialRadical.sqrt3, negative: true);
      }
    }
  }
  if (_matchIntegerPiMultiple(expr, assumptions) != null) {
    return IntegerNumber.zero;
  }

  return Tan(expr, isSimplified: true);
}

/// Simplifies an arcsine expression $\arcsin(expr)$.
Expr simplifyAsin(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < -1.0 || v > 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.asin(v));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul([FractionNumber.half, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul([FractionNumber.negativeHalf, Constant.pi], isSimplified: true);
  }

  // Parity: asin(-u) = -asin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAsin(posExpr));
  }

  if (isHalf(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }

  return Asin(expr, isSimplified: true);
}

/// Simplifies an arccosine expression $\arccos(expr)$.
Expr simplifyAcos(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < -1.0 || v > 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.acos(v));
  }
  if (expr is Number && expr.isOne) return IntegerNumber.zero;
  if (expr is Number && expr.isZero) {
    return Mul([FractionNumber.half, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Constant.pi;
  }

  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    if (isHalf(posExpr)) {
      return Mul([
        const FractionNumber(Integer.two, Integer(3)),
        Constant.pi,
      ], isSimplified: true);
    }
    if (isSqrt2Over2(posExpr)) {
      return Mul([
        const FractionNumber(Integer(3), Integer(4)),
        Constant.pi,
      ], isSimplified: true);
    }
    if (isSqrt3Over2(posExpr)) {
      return Mul([
        const FractionNumber(Integer(5), Integer(6)),
        Constant.pi,
      ], isSimplified: true);
    }
  }

  if (isHalf(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }

  return Acos(expr, isSimplified: true);
}

/// Simplifies an arctangent expression $\arctan(expr)$.
Expr simplifyAtan(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.atan(expr.value));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul([FractionNumber.quarter, Constant.pi], isSimplified: true);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul([
      const FractionNumber(Integer.negativeOne, Integer(4)),
      Constant.pi,
    ], isSimplified: true);
  }

  // Parity: atan(-u) = -atan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyAtan(posExpr));
  }

  if (isSqrt3Over3(posExpr)) {
    return Mul([
      const FractionNumber(Integer.one, Integer(6)),
      Constant.pi,
    ], isSimplified: true);
  }
  if (isSqrt3(posExpr)) {
    return Mul([FractionNumber.third, Constant.pi], isSimplified: true);
  }

  return Atan(expr, isSimplified: true);
}

/// Simplifies a hyperbolic sine expression $\sinh(expr)$.
Expr simplifySinh(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) - math.exp(-v)) / 2.0);
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySinh(posExpr));
  }

  return Sinh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic cosine expression $\cosh(expr)$.
Expr simplifyCosh(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) + math.exp(-v)) / 2.0);
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Parity: cosh(-u) = cosh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCosh(posExpr);
  }

  return Cosh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic tangent expression $\tanh(expr)$.
Expr simplifyTanh(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    final ep = math.exp(v);
    final em = math.exp(-v);
    return RealNumber.fromDouble((ep - em) / (ep + em));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyTanh(posExpr));
  }

  return Tanh(expr, isSimplified: true);
}

/// Simplifies an absolute value expression $|expr|$.
Expr simplifyAbs(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RationalNumber) {
    return expr.isNegative ? expr.neg() : expr;
  }
  if (expr is RealNumber) {
    return RealNumber(expr.value.abs());
  }
  if (expr case ComplexNumber(:final real, :final imaginary)) {
    return simplifyPow(
      simplifyAdd([
        simplifyPow(real, IntegerNumber.two),
        simplifyPow(imaginary, IntegerNumber.two),
      ]),
      FractionNumber.half,
    );
  }
  // Parity: |-u| = |u|
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyAbs(posExpr, assumptions: assumptions);
  }

  if (expr case Pow(base: Constant.e, :final exponent)
      when !isProvenReal(exponent, assumptions)) {
    final reExp = simplifyRe(exponent, assumptions: assumptions);
    if (reExp is Number && reExp.isZero) {
      return IntegerNumber.one;
    }
    if (reExp is! Re || reExp.expr != exponent) {
      return simplifyPow(Constant.e, reExp, assumptions: assumptions);
    }
  }

  if (isNonNegativeExpr(expr, assumptions: assumptions)) {
    return expr;
  }

  // Multiplicative: |a * b| = |a| * |b|
  if (expr is Mul) {
    return simplifyMul([
      for (final f in expr.factors) simplifyAbs(f, assumptions: assumptions),
    ], assumptions: assumptions);
  }

  // Integer powers: |u^k| = |u|^k for integer k
  if (expr is Pow && expr.exponent is IntegerNumber) {
    return simplifyPow(
      simplifyAbs(expr.base, assumptions: assumptions),
      expr.exponent,
      assumptions: assumptions,
    );
  }

  return Abs(expr, isSimplified: true);
}

/// Simplifies an exponential expression $e^{expr}$.
Expr simplifyExp(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.exp(expr.value));
  }
  return simplifyPow(Constant.e, expr, assumptions: assumptions);
}

/// Simplifies a natural logarithm expression $\ln(expr)$.
Expr simplifyLn(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr is RealNumber) {
    if (expr.value <= 0.0) return Constant.undefined;
    return RealNumber.fromDouble(math.log(expr.value));
  }
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == Constant.e) return IntegerNumber.one;
  if (expr is Number && expr.isZero) {
    return simplifyNeg(Constant.infinity);
  }
  if (expr is RealNumeric && expr.isNegative) {
    final absLn = simplifyLn(expr.abs(), assumptions: assumptions);
    return simplifyAdd([
      absLn,
      Mul([ComplexNumber.i, Constant.pi], isSimplified: true),
    ], assumptions: assumptions);
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr == Constant.infinity) {
    return Constant.infinity;
  }

  // ln(1/n) = -ln(n) for positive integer denominator
  if (expr is FractionNumber && expr.numerator.isOne) {
    return simplifyNeg(
      simplifyLn(IntegerNumber(expr.denominator), assumptions: assumptions),
      assumptions: assumptions,
    );
  }

  // ln(b^k) = k * ln(b) for integer powers
  if (expr is IntegerNumber && !expr.isNegative && !expr.isZero) {
    if (Number.integerPower(expr.value) case (final base, final exp)?) {
      return simplifyMul([
        IntegerNumber.of(exp),
        simplifyLn(IntegerNumber(base), assumptions: assumptions),
      ], assumptions: assumptions);
    }
  }

  // ln(e^u) = u for real u
  if (expr is Pow && expr.base == Constant.e) {
    if (isProvenReal(expr.exponent, assumptions)) {
      return expr.exponent;
    }
    return Ln(expr, isSimplified: true);
  }

  // ln(u^k)
  if (expr is Pow) {
    final k = expr.exponent;
    final u = expr.base;
    if (isPositiveExpr(u, assumptions: assumptions)) {
      return simplifyMul([
        k,
        simplifyLn(u, assumptions: assumptions),
      ], assumptions: assumptions);
    }
    if (k is IntegerNumber && k.value.isEven) {
      if (isProvenReal(u, assumptions)) {
        return simplifyMul([
          k,
          simplifyLn(
            simplifyAbs(u, assumptions: assumptions),
            assumptions: assumptions,
          ),
        ], assumptions: assumptions);
      }
      return Ln(expr, isSimplified: true);
    }
    if (k is RationalNumber &&
        k.numerator > -k.denominator &&
        k.numerator <= k.denominator) {
      return simplifyMul([
        k,
        simplifyLn(u, assumptions: assumptions),
      ], assumptions: assumptions);
    }
    return Ln(expr, isSimplified: true);
  }

  return Ln(expr, isSimplified: true);
}

/// Extracts the sign of [expr], returning the non-negative magnitude and sign flag.
(Expr, bool) extractSign(Expr expr) => switch (expr) {
  final RealNumeric n when n.isNegative => (n.neg(), true),
  Mul(factors: [final RealNumeric first, ...final rest])
      when first.isNegative =>
    () {
      final posFirst = first.neg();
      if (posFirst.isOne) {
        return (
          switch (rest) {
            [final single] => single,
            _ => simplifyMul(rest),
          },
          true,
        );
      }
      return (simplifyMul([posFirst, ...rest]), true);
    }(),
  _ => (expr, false),
};

/// Matches if [expr] is a rational multiple of $\pi$.
RationalNumber? matchPiMultiple(Expr expr) => switch (expr) {
  Constant.pi => IntegerNumber.one,
  Mul(factors: [final RationalNumber r, Constant.pi]) ||
  Mul(factors: [Constant.pi, final RationalNumber r]) => r,
  Mul(
    factors: [
      Constant.pi,
      Pow(
        base: IntegerNumber(:final value),
        exponent: IntegerNumber.negativeOne,
      ),
    ],
  ) =>
    RationalNumber.of(Integer.one, value),
  _ => null,
};

/// Simplifies a Lambert W expression $W_b(expr)$.
Expr simplifyLambertW(Expr expr, int branch) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    final res = branch == 0
        ? special_lambert.lambertW0(v)
        : special_lambert.lambertW1(v);
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (branch == 0) {
    if (expr is Number && expr.isZero) {
      return IntegerNumber.zero;
    }
    if (expr == Constant.e) {
      return IntegerNumber.one;
    }
  }
  // W(-1 / e) = -1
  if (expr case Mul(
    factors: [
      IntegerNumber.negativeOne,
      Pow(base: Constant.e, exponent: IntegerNumber.negativeOne),
    ],
  )) {
    return IntegerNumber.negativeOne;
  }
  return LambertW(expr, branch: branch, isSimplified: true);
}

/// Simplifies an error function expression $\operatorname{erf}(expr)$.
Expr simplifyErf(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erf(expr.value));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifyErf(posExpr));
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.one;
  }
  return Erf(expr, isSimplified: true);
}

/// Simplifies a complementary error function expression $\operatorname{erfc}(expr)$.
Expr simplifyErfc(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erfc(expr.value));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.one;
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg && posExpr == Constant.infinity) {
    return IntegerNumber.two;
  }
  return Erfc(expr, isSimplified: true);
}

/// Simplifies an Euler gamma function expression $\Gamma(expr)$.
Expr simplifyGamma(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v <= 0.0 && v == v.roundToDouble()) return Constant.undefined;
    return RealNumber.fromDouble(special_gamma.gamma(v));
  }
  if (expr case IntegerNumber(asInt: final n?) when n > 0 && n <= 18) {
    return IntegerNumber(Integer.from(n - 1).factorial());
  }
  if (expr == FractionNumber.half) {
    return Pow(Constant.pi, FractionNumber.half, isSimplified: true);
  }
  // Half-integer Gamma(n + 1/2) = (2n)! / (4^n * n!) * sqrt(pi)
  if (expr case FractionNumber(:final numerator, :final denominator)
      when denominator == Integer.two && numerator > Integer.one) {
    final n = ((numerator - Integer.one) ~/ Integer.two).asInt;
    if (n != null && n >= 1 && n <= 16) {
      final numFact = Integer.from(2 * n).factorial();
      final denFact = Integer.from(1 << (2 * n)) * Integer.from(n).factorial();
      final coeff = RationalNumber.of(numFact, denFact);
      return simplifyMul([
        coeff,
        Pow(Constant.pi, FractionNumber.half, isSimplified: true),
      ]);
    }
  }
  return Gamma(expr, isSimplified: true);
}

/// Simplifies a Riemann zeta function expression $\zeta(s)$.
Expr simplifyZeta(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_zeta.zeta(expr.value));
  }
  if (expr == IntegerNumber.zero) {
    return FractionNumber.negativeHalf;
  }
  if (expr == IntegerNumber.one) {
    return Constant.undefined;
  }
  if (expr case IntegerNumber(asInt: final n?) when n < 0 && n.isEven) {
    return IntegerNumber.zero;
  }
  if (expr case IntegerNumber(asInt: final n?) when n < 0 && n.isOdd) {
    return switch (n) {
      -1 => RationalNumber(-1, 12),
      -3 => RationalNumber(1, 120),
      -5 => RationalNumber(-1, 252),
      -7 => RationalNumber(1, 240),
      -9 => RationalNumber(-1, 132),
      -11 => RationalNumber(691, 32760),
      -13 => RationalNumber(-1, 12),
      -15 => RationalNumber(3617, 8160),
      _ => Zeta(expr, isSimplified: true),
    };
  }
  if (expr case IntegerNumber(asInt: final n?)
      when n > 0 && n.isEven && n <= 16) {
    return evenZetaValue(n);
  }
  return Zeta(expr, isSimplified: true);
}

/// Simplifies a digamma function expression $\psi(x)$.
Expr simplifyDigamma(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v <= 0.0 && v == v.roundToDouble()) return Constant.undefined;
    return RealNumber.fromDouble(special_digamma.digamma(v));
  }
  return Digamma(expr, isSimplified: true);
}

/// Simplifies a polygamma function expression $\psi^{(m)}(x)$.
Expr simplifyPolygamma(Expr m, Expr x) {
  if (m == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (m is RealNumeric &&
      x is RealNumeric &&
      (m is RealNumber || x is RealNumber)) {
    final dm = m.toDouble().toInt();
    final dx = x.toDouble();
    if (dm < 0 || (dx <= 0.0 && dx == dx.roundToDouble())) {
      return Constant.undefined;
    }
    return RealNumber.fromDouble(special_digamma.polygamma(dm, dx));
  }
  return Polygamma(m, x, isSimplified: true);
}

/// Simplifies a Bessel function of the first kind $J_\nu(x)$.
Expr simplifyBesselJ(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (x == IntegerNumber.zero) {
    if (nu == IntegerNumber.zero) return IntegerNumber.one;
    if (nu is RealNumeric && !nu.isNegative) return IntegerNumber.zero;
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselJ(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselJ(nu, x, isSimplified: true);
}

/// Simplifies a Bessel function of the second kind $Y_\nu(x)$.
Expr simplifyBesselY(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselY(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselY(nu, x, isSimplified: true);
}

/// Simplifies a modified Bessel function of the first kind $I_\nu(x)$.
Expr simplifyBesselI(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (x == IntegerNumber.zero) {
    if (nu == IntegerNumber.zero) return IntegerNumber.one;
    if (nu is RealNumeric && !nu.isNegative) return IntegerNumber.zero;
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselI(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselI(nu, x, isSimplified: true);
}

/// Simplifies a modified Bessel function of the second kind $K_\nu(x)$.
Expr simplifyBesselK(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselK(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselK(nu, x, isSimplified: true);
}

/// Simplifies a complete elliptic integral of the first kind $K(k)$.
Expr simplifyEllipticK(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == IntegerNumber.zero) {
    return simplifyMul([FractionNumber.half, Constant.pi]);
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticK(expr.value));
  }
  return EllipticK(expr, isSimplified: true);
}

/// Simplifies a complete elliptic integral of the second kind $E(k)$.
Expr simplifyEllipticE(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == IntegerNumber.zero) {
    return simplifyMul([FractionNumber.half, Constant.pi]);
  }
  if (expr == IntegerNumber.one) {
    return IntegerNumber.one;
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticE(expr.value));
  }
  return EllipticE(expr, isSimplified: true);
}

/// Simplifies an Euler beta function expression $\operatorname{B}(a, b)$.
Expr simplifyBeta(Expr a, Expr b) {
  if (a == Constant.undefined || b == Constant.undefined) {
    return Constant.undefined;
  }
  if (a is RealNumeric &&
      b is RealNumeric &&
      (a is RealNumber || b is RealNumber)) {
    final da = a.toDouble();
    final db = b.toDouble();
    if (da <= 0.0 || db <= 0.0) return Constant.undefined;
    final res = special_beta.beta(da, db);
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (compareStructural(a, b) > 0) {
    return simplifyBeta(b, a);
  }
  if (a case IntegerNumber(asInt: final m?) when m > 0) {
    if (b case IntegerNumber(asInt: final n?) when n > 0 && m + n <= 18) {
      final factM = Integer.from(m - 1).factorial();
      final factN = Integer.from(n - 1).factorial();
      final factTotal = Integer.from(m + n - 1).factorial();
      return RationalNumber.of(factM * factN, factTotal);
    }
    if (m == 1) {
      return simplifyPow(b, IntegerNumber.negativeOne);
    }
  }
  if (b == IntegerNumber.one) {
    return simplifyPow(a, IntegerNumber.negativeOne);
  }
  // Rational arguments where Gamma(a), Gamma(b), Gamma(a + b) simplify
  if (a is RationalNumber &&
      b is RationalNumber &&
      !a.isNegative &&
      !a.isZero &&
      !b.isNegative &&
      !b.isZero) {
    final sum = a.addRational(b);
    if ((a.denominator == Integer.one || a.denominator == Integer.two) &&
        (b.denominator == Integer.one || b.denominator == Integer.two) &&
        (sum.denominator == Integer.one || sum.denominator == Integer.two)) {
      final ga = simplifyGamma(a);
      final gb = simplifyGamma(b);
      final gab = simplifyGamma(sum);
      if (ga is! Gamma && gb is! Gamma && gab is! Gamma) {
        return simplifyMul([
          ga,
          gb,
          simplifyPow(gab, IntegerNumber.negativeOne),
        ]);
      }
    }
  }
  return Beta(a, b, isSimplified: true);
}

/// Simplifies an inverse hyperbolic sine expression $\operatorname{asinh}(expr)$.
Expr simplifyAsinh(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble(math.log(v + math.sqrt(v * v + 1.0)));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr is Sinh && isProvenReal(expr.expr, assumptions)) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAsinh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Asinh(expr, isSimplified: true);
}

/// Simplifies an inverse hyperbolic cosine expression $\operatorname{acosh}(expr)$.
Expr simplifyAcosh(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.log(v + math.sqrt(v * v - 1.0)));
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr is Cosh && isProvenReal(expr.expr, assumptions)) {
    return simplifyAbs(expr.expr, assumptions: assumptions);
  }
  return Acosh(expr, isSimplified: true);
}

/// Simplifies an inverse hyperbolic tangent expression $\operatorname{atanh}(expr)$.
Expr simplifyAtanh(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v.abs() >= 1.0) return Constant.undefined;
    return RealNumber.fromDouble(0.5 * math.log((1.0 + v) / (1.0 - v)));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr is Tanh && isProvenReal(expr.expr, assumptions)) return expr.expr;
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAtanh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Atanh(expr, isSimplified: true);
}

/// Simplifies a relational expression.
Expr simplifyRelational(
  RelationalExpr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final left = expr.left.simplify(assumptions: assumptions);
  final right = expr.right.simplify(assumptions: assumptions);
  final vL = realScalarValue(left);
  final vR = realScalarValue(right);
  if (vL != null && vR != null) {
    final matched = switch (expr) {
      LessThan() => vL < vR,
      LessEqual() => vL <= vR,
      GreaterThan() => vL > vR,
      GreaterEqual() => vL >= vR,
      Equal() => vL == vR,
      NotEqual() => vL != vR,
    };
    return matched ? IntegerNumber.one : IntegerNumber.zero;
  }
  return switch (expr) {
    LessThan() => LessThan(left, right, isSimplified: true),
    LessEqual() => LessEqual(left, right, isSimplified: true),
    GreaterThan() => GreaterThan(left, right, isSimplified: true),
    GreaterEqual() => GreaterEqual(left, right, isSimplified: true),
    Equal() => Equal(left, right, isSimplified: true),
    NotEqual() => NotEqual(left, right, isSimplified: true),
  };
}

/// Simplifies a piecewise expression.
Expr simplifyPiecewise(
  Piecewise expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplifiedBranches = <PiecewiseBranch>[];
  for (final (:relation, expr: branchExpr) in expr.branches) {
    final sCond = relation.simplify(assumptions: assumptions);
    if (sCond is Number && sCond.isZero) {
      continue;
    }
    final sExpr = branchExpr.simplify(assumptions: assumptions);
    if (sCond is Number && sCond.isOne) {
      if (simplifiedBranches.isEmpty) {
        return sExpr;
      }
      return Piecewise(
        simplifiedBranches,
        otherwise: sExpr,
        isSimplified: true,
      );
    }
    final relCond = sCond is RelationalExpr ? sCond : relation;
    simplifiedBranches.add((relation: relCond, expr: sExpr));
  }
  final sOtherwise = expr.otherwise?.simplify(assumptions: assumptions);
  if (simplifiedBranches.isEmpty) {
    return sOtherwise ?? IntegerNumber.zero;
  }
  return Piecewise(
    simplifiedBranches,
    otherwise: sOtherwise,
    isSimplified: true,
  );
}

/// Simplifies a symbolic [Integral] node.
Expr simplifyIntegral(
  Expr integrand,
  String variable, {
  Expr? lower,
  Expr? upper,
  Assumptions assumptions = Assumptions.none,
}) {
  final sIntegrand = integrand.simplify(assumptions: assumptions);
  if (sIntegrand is Number && sIntegrand.isZero) {
    return IntegerNumber.zero;
  }
  final sLower = lower?.simplify(assumptions: assumptions);
  final sUpper = upper?.simplify(assumptions: assumptions);
  if (sLower != null && sUpper != null && sLower == sUpper) {
    return IntegerNumber.zero;
  }
  return Integral(
    sIntegrand,
    variable,
    lower: sLower,
    upper: sUpper,
    isSimplified: true,
  );
}

/// Simplifies a symbolic [Derivative] node.
Expr simplifyDerivative(
  Expr expr,
  String variable, {
  int order = 1,
  Expr? point,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point?.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return IntegerNumber.zero;
  }
  if (sPoint != null) {
    final derived = sExpr.derivative(
      variable,
      order: order,
      assumptions: assumptions,
    );
    if (!derived.anyNode(
      (node) =>
          node is Derivative && node.variable == variable && node.point == null,
    )) {
      return derived
          .substitute(variable, sPoint)
          .simplify(assumptions: assumptions);
    }
    return Derivative(
      sExpr,
      variable,
      order: order,
      point: sPoint,
      isSimplified: true,
    );
  }
  if (sExpr
      case Derivative(
        expr: final inner,
        variable: final innerVar,
        order: final innerOrder,
        point: null,
      )
      when innerVar == variable) {
    return Derivative(
      inner,
      variable,
      order: innerOrder + order,
      isSimplified: true,
    );
  }
  return Derivative(sExpr, variable, order: order, isSimplified: true);
}

/// Simplifies a symbolic [Limit] node.
Expr simplifyLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) {
  final sExpr = expr.simplify(assumptions: assumptions);
  final sPoint = point.simplify(assumptions: assumptions);
  if (!sExpr.dependsOn(variable)) {
    return sExpr;
  }
  return Limit(
    sExpr,
    variable,
    sPoint,
    direction: direction,
    isSimplified: true,
  );
}

/// Simplifies a factorial expression $n!$.
Expr simplifyFactorial(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return simplifyGamma(RealNumber.fromDouble(expr.value + 1.0));
  }
  if (expr case IntegerNumber(asInt: final n?) when n >= 0 && n <= 100) {
    return IntegerNumber(Integer.from(n).factorial());
  }
  if (expr == FractionNumber.negativeHalf) {
    return Pow(Constant.pi, FractionNumber.half, isSimplified: true);
  }
  return Factorial(expr, isSimplified: true);
}

/// Simplifies a binomial coefficient $\binom{n}{k}$.
Expr simplifyBinomial(Expr nExpr, Expr kExpr) {
  if (nExpr == Constant.undefined || kExpr == Constant.undefined) {
    return Constant.undefined;
  }
  if (nExpr is RealNumeric &&
      kExpr is RealNumeric &&
      (nExpr is RealNumber || kExpr is RealNumber)) {
    final n = nExpr.toDouble();
    final k = kExpr.toDouble();
    final gn = special_gamma.gamma(n + 1.0);
    final gk = special_gamma.gamma(k + 1.0);
    final gnk = special_gamma.gamma(n - k + 1.0);
    final res = gn / (gk * gnk);
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (kExpr is Number && kExpr.isZero) {
    return (nExpr is RealNumber || kExpr is RealNumber)
        ? const RealNumber(1.0)
        : IntegerNumber.one;
  }
  if (kExpr is Number && kExpr.isOne) {
    return kExpr is RealNumber
        ? simplifyMul([const RealNumber(1.0), nExpr])
        : nExpr;
  }
  if (nExpr == kExpr) {
    return nExpr is RealNumber ? const RealNumber(1.0) : IntegerNumber.one;
  }
  if (kExpr case IntegerNumber(:final value) when value.isNegative) {
    return nExpr is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
  }
  if (nExpr case IntegerNumber(asInt: final n?) when n >= 0) {
    if (kExpr case IntegerNumber(asInt: final k?)) {
      if (k < 0 || k > n) return IntegerNumber.zero;
      final m = k < n - k ? k : n - k;
      if (m <= 1000) {
        return IntegerNumber(Integer.from(n).binomial(Integer.from(k)));
      }
    }
  }
  return Binomial(nExpr, kExpr, isSimplified: true);
}

/// Simplifies a floor expression $\lfloor x \rfloor$.
Expr simplifyFloor(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        numerator.isNegative && !(numerator % denominator).isZero
            ? q - Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.floorToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.floorToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.floor()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Floor(expr, isSimplified: true);
  }
}

/// Simplifies a ceiling expression $\lceil x \rceil$.
Expr simplifyCeil(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final q = numerator ~/ denominator;
      return IntegerNumber(
        !numerator.isNegative && !(numerator % denominator).isZero
            ? q + Integer.one
            : q,
      );
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.ceilToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.ceilToDouble());
            }
            if ((v - v.roundToDouble()).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.ceil()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Ceil(expr, isSimplified: true);
  }
}

/// Simplifies a rounding expression $\operatorname{round}(x)$.
Expr simplifyRound(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isIntegerExpr(expr, assumptions: assumptions)) return expr;
  switch (expr) {
    case FractionNumber(:final numerator, :final denominator):
      final absNum = numerator.abs();
      final q2 = denominator * Integer.two;
      final rounded = (absNum * Integer.two + denominator) ~/ q2;
      return IntegerNumber(numerator.isNegative ? -rounded : rounded);
    case RealNumber(:final value):
      return RealNumber.fromDouble(value.roundToDouble());
    default:
      if (expr.freeVariables.isEmpty) {
        try {
          final v = expr.evaluate();
          if (v.isFinite) {
            if (expr.anyNode((n) => n is RealNumber)) {
              return RealNumber.fromDouble(v.roundToDouble());
            }
            if (((v - v.floorToDouble()).abs() - 0.5).abs() > 1e-12) {
              return IntegerNumber(Integer.from(v.round()));
            }
          }
        } on Object {
          // Keep symbolic
        }
      }
      return Round(expr, isSimplified: true);
  }
}

/// Simplifies a signum expression $\operatorname{sgn}(x)$.
Expr simplifySign(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    if (expr.value.isNaN) return Constant.undefined;
    return RealNumber.fromDouble(expr.sign.toDouble());
  }
  if (expr is RationalNumber) {
    return IntegerNumber.of(expr.sign);
  }
  if (expr case Variable(:final name)
      when assumptions.domainOf(name) == VariableDomain.positive) {
    return IntegerNumber.one;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(simplifySign(posExpr, assumptions: assumptions));
  }
  if (expr.freeVariables.isEmpty && isProvenReal(expr, assumptions)) {
    try {
      final v = expr.evaluate();
      if (v.isFinite) {
        final s = v == 0.0 ? 0 : (v > 0.0 ? 1 : -1);
        return expr.anyNode((n) => n is RealNumber)
            ? RealNumber.fromDouble(s.toDouble())
            : IntegerNumber.of(s);
      }
    } on Object {
      // Keep symbolic
    }
  }
  return Sign(expr, isSimplified: true);
}

/// Simplifies a modulo expression $a \bmod b$.
Expr simplifyMod(
  Expr left,
  Expr right, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (left == Constant.undefined || right == Constant.undefined) {
    return Constant.undefined;
  }
  if (right is Number && right.isZero) {
    return Constant.undefined;
  }
  if (left is Number && left.isZero) {
    return left is RealNumber || right is RealNumber
        ? const RealNumber(0.0)
        : IntegerNumber.zero;
  }
  if (right is Number &&
      right.isOne &&
      isIntegerExpr(left, assumptions: assumptions)) {
    return right is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
  }
  if (left is RationalNumber && right is RationalNumber) {
    final q = simplifyFloor(
      left.divRational(right),
      assumptions: assumptions,
    ) as IntegerNumber;
    return left.subRational(right.mulRational(q));
  }
  if (left is RealNumeric && right is RealNumeric) {
    final a = left.toDouble();
    final b = right.toDouble();
    return RealNumber.fromDouble(a - b * (a / b).floorToDouble());
  }
  return Mod(left, right, isSimplified: true);
}

/// Simplifies a real-part expression $\Re(z)$.
Expr simplifyRe(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumeric():
      return expr;
    case ComplexNumber(:final real, :final imaginary):
      return imaginary is RealNumber && real is! RealNumber
          ? RealNumber.fromDouble(real.toDouble())
          : real;
    case Re() || Im() || Arg() || Abs():
      return expr;
    case Conjugate(:final expr):
      return simplifyRe(expr, assumptions: assumptions);
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyRe(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (isProvenReal(expr, assumptions)) {
        return expr;
      }
      final (:re, im: _) = decomposeComplex(expr, assumptions);
      return re;
  }
}

/// Simplifies an imaginary-part expression $\Im(z)$.
Expr simplifyIm(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumber():
      return const RealNumber(0.0);
    case RealNumeric() || Re() || Im() || Arg() || Abs():
      return IntegerNumber.zero;
    case ComplexNumber(:final real, :final imaginary):
      return real is RealNumber && imaginary is! RealNumber
          ? RealNumber.fromDouble(imaginary.toDouble())
          : imaginary;
    case Conjugate(:final expr):
      return simplifyNeg(simplifyIm(expr, assumptions: assumptions));
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms) simplifyIm(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case _:
      if (isProvenReal(expr, assumptions)) {
        return IntegerNumber.zero;
      }
      final (re: _, :im) = decomposeComplex(expr, assumptions);
      return im;
  }
}

/// Simplifies a complex argument expression $\arg(z)$.
Expr simplifyArg(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumber(:final value):
      return RealNumber.fromDouble(math.atan2(0.0, value));
    case RealNumeric(:final isNegative):
      return isNegative ? Constant.pi : IntegerNumber.zero;
    case ComplexNumber(:final real, :final imaginary)
        when real is RealNumber || imaginary is RealNumber:
      return RealNumber.fromDouble(
        math.atan2(imaginary.toDouble(), real.toDouble()),
      );
    case ComplexNumber(:final real, :final imaginary):
      if (real.isZero) {
        final coeff = imaginary.isNegative
            ? FractionNumber.negativeHalf
            : FractionNumber.half;
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      if (real == imaginary) {
        final coeff = real.isNegative
            ? RationalNumber(-3, 4)
            : RationalNumber(1, 4);
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      if (real == imaginary.neg()) {
        final coeff = real.isNegative
            ? RationalNumber(3, 4)
            : RationalNumber(-1, 4);
        return Mul([coeff, Constant.pi], isSimplified: true);
      }
      final atanTerm = simplifyAtan(
        simplifyMul([
          imaginary,
          simplifyPow(
            real,
            IntegerNumber.negativeOne,
            assumptions: assumptions,
          ),
        ], assumptions: assumptions),
      );
      if (!real.isNegative) {
        return atanTerm;
      }
      final piTerm = imaginary.isNegative ? -Constant.pi : Constant.pi;
      return simplifyAdd([atanTerm, piTerm], assumptions: assumptions);
    case Conjugate(:final expr)
        when isPositiveExpr(expr, assumptions: assumptions) ||
            (expr is ComplexNumber && !expr.imaginary.isZero):
      return simplifyNeg(simplifyArg(expr, assumptions: assumptions));
    case _:
      if (isNonNegativeExpr(expr, assumptions: assumptions)) {
        return IntegerNumber.zero;
      }
      return Arg(expr, isSimplified: true);
  }
}

/// Simplifies a complex conjugate expression $\overline{z}$.
Expr simplifyConjugate(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (expr == Constant.undefined) return Constant.undefined;
  switch (expr) {
    case RealNumeric() || Re() || Im() || Arg() || Abs() || OrderTerm():
      return expr;
    case ComplexNumber():
      return expr.conjugate;
    case Conjugate(:final expr):
      return expr;
    case Add(:final terms):
      return simplifyAdd([
        for (final term in terms)
          simplifyConjugate(term, assumptions: assumptions),
      ], assumptions: assumptions);
    case Mul(:final factors):
      return simplifyMul([
        for (final factor in factors)
          simplifyConjugate(factor, assumptions: assumptions),
      ], assumptions: assumptions);
    case Pow(base: Constant.e, :final exponent):
      return simplifyPow(
        Constant.e,
        simplifyConjugate(exponent, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Pow(:final base, :final exponent)
        when isPositiveExpr(base, assumptions: assumptions):
      return simplifyPow(
        base,
        simplifyConjugate(exponent, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Pow(:final base, :final exponent) when exponent is IntegerNumber:
      return simplifyPow(
        simplifyConjugate(base, assumptions: assumptions),
        exponent,
        assumptions: assumptions,
      );
    case Sin(:final expr):
      return simplifySin(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Cos(:final expr):
      return simplifyCos(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Tan(:final expr):
      return simplifyTan(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case Sinh(:final expr):
      return simplifySinh(simplifyConjugate(expr, assumptions: assumptions));
    case Cosh(:final expr):
      return simplifyCosh(simplifyConjugate(expr, assumptions: assumptions));
    case Tanh(:final expr):
      return simplifyTanh(simplifyConjugate(expr, assumptions: assumptions));
    case Erf(:final expr):
      return simplifyErf(simplifyConjugate(expr, assumptions: assumptions));
    case Erfc(:final expr):
      return simplifyErfc(simplifyConjugate(expr, assumptions: assumptions));
    case Atan(:final expr):
      return simplifyAtan(simplifyConjugate(expr, assumptions: assumptions));
    case Asinh(:final expr):
      return simplifyAsinh(
        simplifyConjugate(expr, assumptions: assumptions),
        assumptions: assumptions,
      );
    case _:
      if (isProvenReal(expr, assumptions)) {
        return expr;
      }
      return Conjugate(expr, isSimplified: true);
  }
}

/// Rewrites [expr] into rectangular normal form $a + b i$.
Expr toRectangularExpr(
  Expr expr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  final (:re, :im) = decomposeComplex(simplified, assumptions);
  if (im is Number && im.isZero) {
    return re;
  }
  if (re is RealNumeric && im is RealNumeric) {
    return ComplexNumber.of(re, im);
  }
  final imTerm = simplifyMul([ComplexNumber.i, im], assumptions: assumptions);
  if (re is Number && re.isZero) {
    return imTerm;
  }
  return simplifyAdd([re, imTerm], assumptions: assumptions);
}

/// Rewrites [expr] into polar normal form $r e^{i \theta}$.
Expr toPolarExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  final simplified = simplifyExpr(expr, assumptions: assumptions);
  if (simplified is Number && simplified.isZero) {
    return simplified is RealNumber
        ? const RealNumber(0.0)
        : IntegerNumber.zero;
  }
  final (:re, :im) = decomposeComplex(simplified, assumptions);
  var r = simplifyAbs(simplified, assumptions: assumptions);
  if (r is Abs && !(im is Number && im.isZero)) {
    r = simplifyPow(
      simplifyAdd([
        simplifyPow(re, IntegerNumber.two, assumptions: assumptions),
        simplifyPow(im, IntegerNumber.two, assumptions: assumptions),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
    );
  }
  final theta = simplifyArg(simplified, assumptions: assumptions);
  if (theta is Number && theta.isZero) {
    return r;
  }
  final expPart = Pow(
    Constant.e,
    simplifyMul([ComplexNumber.i, theta], assumptions: assumptions),
    isSimplified: true,
  );
  if (r is Number && r.isOne) {
    return r is RealNumber ? Mul([r, expPart], isSimplified: true) : expPart;
  }
  final factors = <Expr>[
    if (r case Mul(factors: final rf)) ...rf else r,
    expPart,
  ];
  return Mul(factors, isSimplified: true);
}

Expr? _matchIntegerPiMultiple(Expr expr, Assumptions assumptions) {
  if (expr == Constant.pi) return IntegerNumber.one;
  if (expr case Mul(:final factors)) {
    final piIdx = factors.indexOf(Constant.pi);
    if (piIdx != -1) {
      final other = <Expr>[
        for (var i = 0; i < factors.length; i++)
          if (i != piIdx) factors[i],
      ];
      if (other.isNotEmpty &&
          other.every((f) => isIntegerExpr(f, assumptions: assumptions))) {
        return other.length == 1 ? other.first : Mul(other, isSimplified: true);
      }
    }
  }
  return null;
}
