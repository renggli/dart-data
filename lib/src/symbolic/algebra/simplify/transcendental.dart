import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../functions/fn.dart';
import '../../oracle/sign.dart';
import '../exact_constants.dart';
import '../simplify.dart';
import 'additive.dart';
import 'complex.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'special.dart';

/// Simplifies a sine expression `sin(expr)`.
Expr simplifySin(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.sin(expr.value));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().sin());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: sin(asin(u)) = u
  if (expr case Call(id: FunctionId.asin, args: [final u])) return u;
  if (expr case Call(id: FunctionId.acos, args: [final u])) {
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
  if (expr case Call(id: FunctionId.atan, args: [final u])
      when u is! ComplexNumber) {
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
    if (den == BigInt.two) {
      final k = (num - BigInt.one) ~/ BigInt.two;
      return k.isEven ? IntegerNumber.one : IntegerNumber.negativeOne;
    }
    if (den == BigInt.from(6)) {
      final rem = (num % BigInt.from(12)).toInt();
      if (rem == 1 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.half);
      }
      if (rem == 7 || rem == 11) {
        return specialRadicalExpr(SpecialRadical.half, negative: true);
      }
    }
    if (den == BigInt.from(4)) {
      final rem = (num % BigInt.from(8)).toInt();
      if (rem == 1 || rem == 3) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2);
      }
      if (rem == 5 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true);
      }
    }
    if (den == BigInt.from(3)) {
      final rem = (num % BigInt.from(6)).toInt();
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

  // Integer and quarter-period pi shifts: sin(k*pi + rest), sin((2k+1)*pi/2 + rest)
  if (expr case Add(:final terms)) {
    for (var i = 0; i < terms.length; i++) {
      final m = matchPiMultiple(terms[i]);
      if (m == null) continue;
      final rest = simplifyAdd([
        for (var j = 0; j < terms.length; j++)
          if (j != i) terms[j],
      ], assumptions: assumptions);
      if (m.isInteger) {
        final sinRest = simplifySin(rest, assumptions: assumptions);
        return m.numerator.isEven
            ? sinRest
            : simplifyNeg(sinRest, assumptions: assumptions);
      }
      if (m.denominator == BigInt.two && m.numerator.isOdd) {
        final k = (m.numerator - BigInt.one) ~/ BigInt.two;
        final cosRest = simplifyCos(rest, assumptions: assumptions);
        return k.isEven
            ? cosRest
            : simplifyNeg(cosRest, assumptions: assumptions);
      }
    }
  }

  return Fn.sin(expr);
}

/// Simplifies a cosine expression `cos(expr)`.
Expr simplifyCos(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.cos(expr.value));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().cos());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;

  // Involution: cos(acos(u)) = u
  if (expr case Call(id: FunctionId.acos, args: [final u])) return u;
  if (expr case Call(id: FunctionId.asin, args: [final u])) {
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
  if (expr case Call(id: FunctionId.atan, args: [final u])
      when u is! ComplexNumber) {
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
    if (den == BigInt.two && num.isOdd) {
      return IntegerNumber.zero;
    }
    if (den == BigInt.from(6)) {
      final rem = (num % BigInt.from(12)).toInt();
      if (rem == 1 || rem == 11) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2);
      }
      if (rem == 5 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over2, negative: true);
      }
    }
    if (den == BigInt.from(4)) {
      final rem = (num % BigInt.from(8)).toInt();
      if (rem == 1 || rem == 7) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2);
      }
      if (rem == 3 || rem == 5) {
        return specialRadicalExpr(SpecialRadical.sqrt2Over2, negative: true);
      }
    }
    if (den == BigInt.from(3)) {
      final rem = (num % BigInt.from(6)).toInt();
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

  // Integer and quarter-period pi shifts: cos(k*pi + rest), cos((2k+1)*pi/2 + rest)
  if (expr case Add(:final terms)) {
    for (var i = 0; i < terms.length; i++) {
      final m = matchPiMultiple(terms[i]);
      if (m == null) continue;
      final rest = simplifyAdd([
        for (var j = 0; j < terms.length; j++)
          if (j != i) terms[j],
      ], assumptions: assumptions);
      if (m.isInteger) {
        final cosRest = simplifyCos(rest, assumptions: assumptions);
        return m.numerator.isEven
            ? cosRest
            : simplifyNeg(cosRest, assumptions: assumptions);
      }
      if (m.denominator == BigInt.two && m.numerator.isOdd) {
        final k = (m.numerator - BigInt.one) ~/ BigInt.two;
        final sinRest = simplifySin(rest, assumptions: assumptions);
        return k.isEven
            ? simplifyNeg(sinRest, assumptions: assumptions)
            : sinRest;
      }
    }
  }

  return Fn.cos(expr);
}

/// Simplifies a tangent expression `tan(expr)`.
Expr simplifyTan(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = math.tan(expr.value);
    return v.isFinite ? RealNumber.fromDouble(v) : Constant.undefined;
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().tan());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;

  // Involution: tan(atan(u)) = u
  if (expr case Call(id: FunctionId.atan, args: [final u])) return u;

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
    if (den == BigInt.two) {
      return Constant.undefined;
    }
    if (den == BigInt.from(4)) {
      final rem = (num % BigInt.from(4)).toInt();
      if (rem == 1) return IntegerNumber.one;
      if (rem == 3) return IntegerNumber.negativeOne;
    }
    if (den == BigInt.from(6)) {
      final rem = (num % BigInt.from(6)).toInt();
      if (rem == 1) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over3);
      }
      if (rem == 5) {
        return specialRadicalExpr(SpecialRadical.sqrt3Over3, negative: true);
      }
    }
    if (den == BigInt.from(3)) {
      final rem = (num % BigInt.from(3)).toInt();
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

  // Integer-period and quarter-period shifts:
  // tan(k*pi + rest) = tan(rest), tan((2k+1)*pi/2 + rest) = -1 / tan(rest)
  if (expr case Add(:final terms)) {
    for (var i = 0; i < terms.length; i++) {
      final m = matchPiMultiple(terms[i]);
      if (m == null) continue;
      final rest = simplifyAdd([
        for (var j = 0; j < terms.length; j++)
          if (j != i) terms[j],
      ], assumptions: assumptions);
      if (m.isInteger) {
        return simplifyTan(rest, assumptions: assumptions);
      }
      if (m.denominator == BigInt.two && m.numerator.isOdd) {
        final tanRest = simplifyTan(rest, assumptions: assumptions);
        if (tanRest is Number && tanRest.isZero) return Constant.undefined;
        return simplifyDiv(
          IntegerNumber.negativeOne,
          tanRest,
          assumptions: assumptions,
        );
      }
    }
  }

  return Fn.tan(expr);
}

/// Simplifies an arcsine expression `asin(expr)`.
Expr simplifyAsin(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < -1.0 || v > 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.asin(v));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().asin());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul.of([FractionNumber.half, Constant.pi]);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul.of([FractionNumber.negativeHalf, Constant.pi]);
  }
  if (expr case Call(id: FunctionId.sin, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    final v = tryStaticRealValue(inner);
    if (v != null && v >= -math.pi / 2 && v <= math.pi / 2) {
      return inner;
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
    return Mul.of([RationalNumber(1, 6), Constant.pi]);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul.of([FractionNumber.quarter, Constant.pi]);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul.of([FractionNumber.third, Constant.pi]);
  }

  return Fn.asin(expr);
}

/// Simplifies an arccosine expression `acos(expr)`.
Expr simplifyAcos(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < -1.0 || v > 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.acos(v));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().acos());
  }
  if (expr is Number && expr.isOne) return IntegerNumber.zero;
  if (expr is Number && expr.isZero) {
    return Mul.of([FractionNumber.half, Constant.pi]);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Constant.pi;
  }
  if (expr case Call(id: FunctionId.cos, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    final v = tryStaticRealValue(inner);
    if (v != null && v >= 0.0 && v <= math.pi) {
      return inner;
    }
  }

  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    if (isHalf(posExpr)) {
      return Mul.of([RationalNumber(2, 3), Constant.pi]);
    }
    if (isSqrt2Over2(posExpr)) {
      return Mul.of([RationalNumber(3, 4), Constant.pi]);
    }
    if (isSqrt3Over2(posExpr)) {
      return Mul.of([RationalNumber(5, 6), Constant.pi]);
    }
  }

  if (isHalf(posExpr)) {
    return Mul.of([FractionNumber.third, Constant.pi]);
  }
  if (isSqrt2Over2(posExpr)) {
    return Mul.of([FractionNumber.quarter, Constant.pi]);
  }
  if (isSqrt3Over2(posExpr)) {
    return Mul.of([RationalNumber(1, 6), Constant.pi]);
  }

  return Fn.acos(expr);
}

/// Simplifies an arctangent expression `atan(expr)`.
Expr simplifyAtan(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.atan(expr.value));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().atan());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr is Number && expr.isOne) {
    return Mul.of([FractionNumber.quarter, Constant.pi]);
  }
  if (expr is Number && expr.isNegativeOne) {
    return Mul.of([RationalNumber(-1, 4), Constant.pi]);
  }
  if (expr case Call(id: FunctionId.tan, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    final v = tryStaticRealValue(inner);
    if (v != null && v > -math.pi / 2 && v < math.pi / 2) {
      return inner;
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
    return Mul.of([RationalNumber(1, 6), Constant.pi]);
  }
  if (isSqrt3(posExpr)) {
    return Mul.of([FractionNumber.third, Constant.pi]);
  }

  return Fn.atan(expr);
}

/// Simplifies a two-argument arctangent expression `atan2(y, x)`.
Expr simplifyAtan2(Expr y, Expr x, {required Assumptions assumptions}) {
  if (y == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (y is RealNumeric &&
      x is RealNumeric &&
      (y is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(math.atan2(y.toDouble(), x.toDouble()));
  }
  if (y == IntegerNumber.zero) {
    if (isPositiveExpr(x, assumptions: assumptions)) return IntegerNumber.zero;
    if (isNegativeExpr(x, assumptions: assumptions)) return Constant.pi;
  }
  if (x == IntegerNumber.zero) {
    if (isPositiveExpr(y, assumptions: assumptions)) {
      return Mul.of([FractionNumber.half, Constant.pi]);
    }
    if (isNegativeExpr(y, assumptions: assumptions)) {
      return Mul.of([FractionNumber.negativeHalf, Constant.pi]);
    }
  }
  if (isPositiveExpr(x, assumptions: assumptions)) {
    return simplifyAtan(
      (y / x).simplify(assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (isNegativeExpr(x, assumptions: assumptions)) {
    final base = simplifyAtan(
      (y / x).simplify(assumptions: assumptions),
      assumptions: assumptions,
    );
    if (isPositiveExpr(y, assumptions: assumptions)) {
      return (base + Constant.pi).simplify(assumptions: assumptions);
    }
    if (isNegativeExpr(y, assumptions: assumptions)) {
      return (base - Constant.pi).simplify(assumptions: assumptions);
    }
  }
  return Fn.atan2(y, x);
}

/// Simplifies a hyperbolic sine expression `sinh(expr)`.
Expr simplifySinh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) - math.exp(-v)) / 2.0);
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().sinh());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr case Call(id: FunctionId.asinh, args: [final inner])) return inner;

  // Parity: sinh(-u) = -sinh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }

  return Fn.sinh(expr);
}

/// Simplifies a hyperbolic cosine expression `cosh(expr)`.
Expr simplifyCosh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    return RealNumber.fromDouble((math.exp(v) + math.exp(-v)) / 2.0);
  }
  if (expr is Number && expr.isZero) return IntegerNumber.one;
  if (expr case Call(id: FunctionId.acosh, args: [final inner])) return inner;
  if (expr case Call(id: FunctionId.asinh, args: [final u])) {
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

  return Fn.cosh(expr);
}

/// Simplifies a hyperbolic tangent expression `tanh(expr)`.
Expr simplifyTanh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v.abs() > 20.0) {
      return RealNumber(v.isNegative ? -1.0 : 1.0);
    }
    final ep = math.exp(v);
    final em = math.exp(-v);
    return RealNumber.fromDouble((ep - em) / (ep + em));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().tanh());
  }
  if (expr is Number && expr.isZero) return IntegerNumber.zero;
  if (expr case Call(id: FunctionId.atanh, args: [final inner])) return inner;

  // Parity: tanh(-u) = -tanh(u)
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyTanh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }

  return Fn.tanh(expr);
}

/// Simplifies an absolute value expression `|expr|`.
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
    if (reExp is! Call ||
        reExp.id != FunctionId.re ||
        reExp.args[0] != exponent) {
      return simplifyPow(Constant.e, reExp, assumptions: assumptions);
    }
  }

  if (isNonNegativeExpr(expr, assumptions: assumptions)) {
    return expr;
  }
  if (isNonPositiveExpr(expr, assumptions: assumptions)) {
    return simplifyNeg(expr, assumptions: assumptions);
  }
  if (isNegativeExpr(expr, assumptions: assumptions)) {
    return simplifyNeg(expr, assumptions: assumptions);
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

  return Fn.abs(expr);
}

/// Simplifies an exponential expression `e^expr`.
Expr simplifyExp(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(math.exp(expr.value));
  }
  return simplifyPow(Constant.e, expr, assumptions: assumptions);
}

/// Simplifies a natural logarithm expression `ln(expr)`.
Expr simplifyLn(Expr expr, {required Assumptions assumptions}) {
  if (expr is RealNumber) {
    if (expr.value <= 0.0) return Constant.undefined;
    return RealNumber.fromDouble(math.log(expr.value));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().log());
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
      Mul.of([ComplexNumber.i, Constant.pi]),
    ], assumptions: assumptions);
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr == Constant.infinity) {
    return Constant.infinity;
  }

  // ln(1/n) = -ln(n) for positive integer denominator
  if (expr is FractionNumber && expr.numerator == BigInt.one) {
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
    return Fn.ln(expr);
  }

  // ln(|e^u|) = u for real u
  if (expr case Call(
    id: FunctionId.abs,
    args: [Pow(base: Constant.e, exponent: final inner)],
  )) {
    if (isProvenReal(inner, assumptions)) {
      return inner;
    }
  }

  // ln(u^k)
  if (expr is Pow) {
    final k = expr.exponent;
    final u = expr.base;
    if (isPositiveExpr(u, assumptions: assumptions) &&
        isProvenReal(k, assumptions)) {
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
      return Fn.ln(expr);
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
    if ((k is FractionNumber &&
            k.numerator == BigInt.one &&
            (isNonNegativeExpr(u, assumptions: assumptions) ||
                k.denominator.isEven)) ||
        (k == IntegerNumber.negativeOne &&
            isPositiveExpr(u, assumptions: assumptions))) {
      return simplifyMul([
        k,
        simplifyLn(u, assumptions: assumptions),
      ], assumptions: assumptions);
    }
    return Fn.ln(expr);
  }

  return Fn.ln(expr);
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

/// Matches if [expr] is a rational multiple of `pi`.
RationalNumber? matchPiMultiple(Expr expr) => switch (expr) {
  Constant.pi => IntegerNumber.one,
  Mul(factors: [final RationalNumber r, Constant.pi]) ||
  Mul(factors: [Constant.pi, final RationalNumber r]) => r,
  Mul(
    factors: [
      Constant.pi,
      Pow(
        base: IntegerNumber(:final value),
        exponent: IntegerNumber(isNegativeOne: true),
      ),
    ],
  ) =>
    RationalNumber.of(BigInt.one, value),
  _ => null,
};

/// Simplifies an inverse hyperbolic sine expression `asinh(expr)`.
Expr simplifyAsinh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < 0.0) {
      final av = -v;
      return RealNumber.fromDouble(-math.log(av + math.sqrt(av * av + 1.0)));
    }
    return RealNumber.fromDouble(math.log(v + math.sqrt(v * v + 1.0)));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().asinh());
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr case Call(id: FunctionId.sinh, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    return inner;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAsinh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.asinh(expr);
}

/// Simplifies an inverse hyperbolic cosine expression `acosh(expr)`.
Expr simplifyAcosh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v < 1.0) return Constant.undefined;
    return RealNumber.fromDouble(math.log(v + math.sqrt(v * v - 1.0)));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().acosh());
  }
  if (expr is Number && expr.isOne) {
    return IntegerNumber.zero;
  }
  if (expr case Call(id: FunctionId.cosh, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    return simplifyAbs(inner, assumptions: assumptions);
  }
  return Fn.acosh(expr);
}

/// Simplifies an inverse hyperbolic tangent expression `atanh(expr)`.
Expr simplifyAtanh(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (expr is RealNumber) {
    final v = expr.value;
    if (v.abs() >= 1.0) return Constant.undefined;
    return RealNumber.fromDouble(0.5 * math.log((1.0 + v) / (1.0 - v)));
  }
  if (expr is ComplexNumber && isFloatComplex(expr)) {
    return complexToExpr(expr.toComplex().atanh());
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  if (expr case Call(id: FunctionId.tanh, args: [final inner])
      when isProvenReal(inner, assumptions)) {
    return inner;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyAtanh(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Fn.atanh(expr);
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
        return other.length == 1 ? other.first : Mul.of(other);
      }
    }
  }
  return null;
}
