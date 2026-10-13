import 'dart:math' as math;

import '../../ast.dart';
import '../simplify.dart';

/// Simplifies an exponentiation expression [base] ^ [exponent].
Expr simplifyPow(Expr base, Expr exponent) => switch ((base, exponent)) {
  (_, RationalNumber(isZero: true)) => RationalNumber.one,
  (final b, RationalNumber(isOne: true)) => b,
  (_, RealNumber(value: 0.0)) => RationalNumber.one,
  (final b, RealNumber(value: 1.0)) => b,
  (RationalNumber(isZero: true), _) => RationalNumber.zero,
  (RealNumber(value: 0.0), _) => RationalNumber.zero,
  (RationalNumber(isOne: true), _) => RationalNumber.one,
  (RealNumber(value: 1.0), _) => RationalNumber.one,
  (ConstantNumber(name: 'e'), final exponent) => Exp(exponent),
  (
    ConstantNumber(name: 'i'),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => ConstantNumber.i,
      2 => RationalNumber.negativeOne,
      _ => const Neg(ConstantNumber.i),
    },
  (
    Neg(expr: ConstantNumber(name: 'i')),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => const Neg(ConstantNumber.i),
      2 => RationalNumber.negativeOne,
      _ => ConstantNumber.i,
    },
  (ConstantNumber(name: 'i'), RealNumber(:final value))
      when value == value.truncateToDouble() =>
    switch (((value.toInt() % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => ConstantNumber.i,
      2 => RationalNumber.negativeOne,
      _ => const Neg(ConstantNumber.i),
    },
  (Neg(expr: ConstantNumber(name: 'i')), RealNumber(:final value))
      when value == value.truncateToDouble() =>
    switch (((value.toInt() % 4) + 4) % 4) {
      0 => RationalNumber.one,
      1 => const Neg(ConstantNumber.i),
      2 => RationalNumber.negativeOne,
      _ => ConstantNumber.i,
    },
  (
    Mul(
      left: RationalNumber(:final numerator, :final denominator),
      right: ConstantNumber(name: 'i'),
    ),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => foldRationalPower(numerator, denominator, expInt),
      1 => simplifyMul(
        foldRationalPower(numerator, denominator, expInt),
        ConstantNumber.i,
      ),
      2 => simplifyMul(
        RationalNumber.negativeOne,
        foldRationalPower(numerator, denominator, expInt),
      ),
      _ => simplifyMul(
        simplifyMul(
          RationalNumber.negativeOne,
          foldRationalPower(numerator, denominator, expInt),
        ),
        ConstantNumber.i,
      ),
    },
  (
    Mul(
      left: ConstantNumber(name: 'i'),
      right: RationalNumber(:final numerator, :final denominator),
    ),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    switch (((expInt % 4) + 4) % 4) {
      0 => foldRationalPower(numerator, denominator, expInt),
      1 => simplifyMul(
        foldRationalPower(numerator, denominator, expInt),
        ConstantNumber.i,
      ),
      2 => simplifyMul(
        RationalNumber.negativeOne,
        foldRationalPower(numerator, denominator, expInt),
      ),
      _ => simplifyMul(
        simplifyMul(
          RationalNumber.negativeOne,
          foldRationalPower(numerator, denominator, expInt),
        ),
        ConstantNumber.i,
      ),
    },
  (
    RationalNumber(:final numerator, :final denominator),
    RationalNumber(isInteger: true, numerator: final expInt),
  ) =>
    foldRationalPower(numerator, denominator, expInt),
  (RationalNumber() && final b, RationalNumber() && final e) =>
    foldGeneralPower(b, e),
  // Involution: (u^2)^(1/2) => |u|
  (
    Pow(
      base: final innerBase,
      exponent: RationalNumber(numerator: 2, denominator: 1) ||
          RealNumber(value: 2.0),
    ),
    RationalNumber(numerator: 1, denominator: 2) || RealNumber(value: 0.5),
  ) =>
    simplifyAbs(innerBase),
  (
    Pow(base: final innerBase, exponent: RationalNumber() && final e1),
    RationalNumber() && final e2,
  ) =>
    simplifyPow(innerBase, simplifyMul(e1, e2)),
  (Exp(:final expr), final exponent) => simplifyExp(
    simplifyMul(expr, exponent),
  ),
  (
    Abs(:final expr),
    RationalNumber(numerator: 2, denominator: 1) || RealNumber(value: 2.0),
  ) =>
    simplifyPow(expr, exponent),
  _ => Pow(base, exponent),
};

/// Evaluates integer powers of rational numbers up to exponent magnitude 10.
Expr foldRationalPower(int num, int den, int exp) {
  if (exp == 0) return RationalNumber.one;
  if (exp > 0 && exp <= 10) {
    var n = 1;
    var d = 1;
    for (var i = 0; i < exp; i++) {
      n *= num;
      d *= den;
    }
    return RationalNumber(n, d);
  }
  if (exp < 0 && -exp <= 10 && num != 0) {
    final absExp = -exp;
    var n = 1;
    var d = 1;
    for (var i = 0; i < absExp; i++) {
      n *= den;
      d *= num;
    }
    if (d < 0) {
      n = -n;
      d = -d;
    }
    return RationalNumber(n, d);
  }
  return Pow(RationalNumber(num, den), RationalNumber(exp));
}

/// Evaluates exact square roots of rational numbers if perfect squares.
Expr foldGeneralPower(RationalNumber base, RationalNumber exp) {
  if (exp.numerator == 1 && exp.denominator == 2 && base.numerator >= 0) {
    final numSqrt = math.sqrt(base.numerator).round();
    final denSqrt = math.sqrt(base.denominator).round();
    if (numSqrt * numSqrt == base.numerator &&
        denSqrt * denSqrt == base.denominator) {
      return RationalNumber(numSqrt, denSqrt);
    }
  }
  return Pow(base, exp);
}
