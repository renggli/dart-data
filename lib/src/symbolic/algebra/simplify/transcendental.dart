import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../exact_constants.dart';
import 'additive.dart';
import 'complex.dart';
import 'domain.dart';
import 'multiplicative.dart';
import 'power.dart';

/// Simplifies a sine expression $\sin(expr)$.
Expr simplifySin(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.sin(expr.value));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr is Asin) return expr.expr;
  if (expr is Acos) {
    final u = expr.expr;
    return simplifyPow(
      simplifyAdd([
        IntegerNumber.one,
        simplifyNeg(
          simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
          assumptions: assumptions,
        ),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
    );
  }
  if (expr is Atan) {
    final u = expr.expr;
    return simplifyMul([
      u,
      simplifyPow(
        simplifyAdd([
          IntegerNumber.one,
          simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
        ], assumptions: assumptions),
        FractionNumber.negativeHalf,
        assumptions: assumptions,
      ),
    ], assumptions: assumptions);
  }

  // Parity: sin(-u) = -sin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySin(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
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
Expr simplifyCos(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.cos(expr.value));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr is Acos) return expr.expr;
  if (expr is Asin) {
    final u = expr.expr;
    return simplifyPow(
      simplifyAdd([
        IntegerNumber.one,
        simplifyNeg(
          simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
          assumptions: assumptions,
        ),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
    );
  }
  if (expr is Atan) {
    final u = expr.expr;
    return simplifyPow(
      simplifyAdd([
        IntegerNumber.one,
        simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
      ], assumptions: assumptions),
      FractionNumber.negativeHalf,
      assumptions: assumptions,
    );
  }

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
Expr simplifyTan(Expr expr, {required Assumptions assumptions}) {
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
    return simplifyNeg(
      simplifyTan(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
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
Expr simplifyAsin(Expr expr, {required Assumptions assumptions}) {
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
  if (expr is Sin && isProvenReal(expr.expr, assumptions)) {
    final v = tryStaticRealValue(expr.expr);
    if (v != null && v >= -math.pi / 2 && v <= math.pi / 2) {
      return expr.expr;
    }
  }

  // Parity: asin(-u) = -asin(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAsin(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
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
Expr simplifyAcos(Expr expr, {required Assumptions assumptions}) {
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
  if (expr is Cos && isProvenReal(expr.expr, assumptions)) {
    final v = tryStaticRealValue(expr.expr);
    if (v != null && v >= 0.0 && v <= math.pi) {
      return expr.expr;
    }
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
Expr simplifyAtan(Expr expr, {required Assumptions assumptions}) {
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
  if (expr is Tan && isProvenReal(expr.expr, assumptions)) {
    final v = tryStaticRealValue(expr.expr);
    if (v != null && v > -math.pi / 2 && v < math.pi / 2) {
      return expr.expr;
    }
  }

  // Parity: atan(-u) = -atan(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAtan(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
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
Expr simplifySinh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) - math.exp(-v)) / 2.0);
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Asinh) return expr.expr;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }

  return Sinh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic cosine expression $\cosh(expr)$.
Expr simplifyCosh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) + math.exp(-v)) / 2.0);
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;
  if (expr is Acosh) return expr.expr;
  if (expr is Asinh) {
    final u = expr.expr;
    return simplifyPow(
      simplifyAdd([
        IntegerNumber.one,
        simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
    );
  }

  // Parity: cosh(-u) = cosh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyCosh(posExpr, assumptions: assumptions);
  }

  return Cosh(expr, isSimplified: true);
}

/// Simplifies a hyperbolic tangent expression $\tanh(expr)$.
Expr simplifyTanh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    final ep = math.exp(v);
    final em = math.exp(-v);
    return RealNumber.fromDouble((ep - em) / (ep + em));
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Atanh) return expr.expr;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyTanh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }

  return Tanh(expr, isSimplified: true);
}

/// Simplifies an absolute value expression $|expr|$.
Expr simplifyAbs(Expr expr, {required Assumptions assumptions}) {
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
        simplifyPow(real, IntegerNumber.two, assumptions: assumptions),
        simplifyPow(imaginary, IntegerNumber.two, assumptions: assumptions),
      ], assumptions: assumptions),
      FractionNumber.half,
      assumptions: assumptions,
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
Expr simplifyExp(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.exp(expr.value));
  }
  return simplifyPow(Constant.e, expr, assumptions: assumptions);
}

/// Simplifies a natural logarithm expression $\ln(expr)$.
Expr simplifyLn(Expr expr, {required Assumptions assumptions}) {
  if (expr is RealNumber) {
    if (expr.value <= 0.0) return Constant.undefined;
    return RealNumber.fromDouble(math.log(expr.value));
  }
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr == Constant.e) return IntegerNumber.one;
  if (expr is Number && expr.isZero) {
    return simplifyNeg(Constant.infinity, assumptions: assumptions);
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
    if (k is FractionNumber &&
        k.numerator.isEven &&
        k.denominator.isOdd &&
        isProvenReal(u, assumptions)) {
      return simplifyMul([
        k,
        simplifyLn(
          simplifyAbs(u, assumptions: assumptions),
          assumptions: assumptions,
        ),
      ], assumptions: assumptions);
    }
    if ((k is FractionNumber && k.numerator == Integer.one) ||
        (k == IntegerNumber.negativeOne &&
            isPositiveExpr(u, assumptions: assumptions))) {
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
            _ => simplifyMul(rest, assumptions: Assumptions.none),
          },
          true,
        );
      }
      return (
        simplifyMul([posFirst, ...rest], assumptions: Assumptions.none),
        true,
      );
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

/// Simplifies an inverse hyperbolic sine expression `asinh(expr)`.
Expr simplifyAsinh(Expr expr, {required Assumptions assumptions}) {
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
Expr simplifyAcosh(Expr expr, {required Assumptions assumptions}) {
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
Expr simplifyAtanh(Expr expr, {required Assumptions assumptions}) {
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
