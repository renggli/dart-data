import '../ast.dart';

/// Standard special radical values appearing in exact trigonometric evaluations.
enum SpecialRadical {
  /// `1 / 2 = sin(pi/6) = cos(pi/3)`.
  half,

  /// `1 / 2 = sin(pi/6) = cos(pi/3)`.
  sqrt2Over2,

  /// `sqrt(2) / 2 = sin(pi/4) = cos(pi/4)`.
  sqrt3Over2,

  /// `sqrt(3) / 2 = sin(pi/3) = cos(pi/6)`.
  sqrt3Over3,

  /// `sqrt(3) / 3 = tan(pi/6)`.
  sqrt3,
}

final IntegerNumber _three = IntegerNumber.of(3);
final FractionNumber _negThird = RationalNumber(-1, 3) as FractionNumber;

/// Constructs the canonical exact [Expr] for [radical] with optional [negative] sign.
Expr specialRadicalExpr(SpecialRadical radical, {bool negative = false}) =>
    switch (radical) {
      SpecialRadical.half =>
        negative ? FractionNumber.negativeHalf : FractionNumber.half,
      SpecialRadical.sqrt2Over2 => Mul.of([
        if (negative) FractionNumber.negativeHalf else FractionNumber.half,
        Pow.of(IntegerNumber.two, FractionNumber.half),
      ]),
      SpecialRadical.sqrt3Over2 => Mul.of([
        if (negative) FractionNumber.negativeHalf else FractionNumber.half,
        Pow.of(_three, FractionNumber.half),
      ]),
      SpecialRadical.sqrt3Over3 => Mul.of([
        if (negative) _negThird else FractionNumber.third,
        Pow.of(_three, FractionNumber.half),
      ]),
      SpecialRadical.sqrt3 =>
        negative
            ? Mul.of([
                IntegerNumber.negativeOne,
                Pow.of(_three, FractionNumber.half),
              ])
            : Pow.of(_three, FractionNumber.half),
    };

/// Tests whether [expr] represents `+/-radical`.
bool isSpecialAngleConstant(
  Expr expr,
  SpecialRadical radical, {
  bool negative = false,
}) => switch (radical) {
  SpecialRadical.half => negative ? isNegativeHalf(expr) : isHalf(expr),
  SpecialRadical.sqrt2Over2 =>
    negative ? isNegativeSqrt2Over2(expr) : isSqrt2Over2(expr),
  SpecialRadical.sqrt3Over2 =>
    negative ? isNegativeSqrt3Over2(expr) : isSqrt3Over2(expr),
  SpecialRadical.sqrt3Over3 =>
    negative ? isNegativeSqrt3Over3(expr) : isSqrt3Over3(expr),
  SpecialRadical.sqrt3 => negative ? isNegativeSqrt3(expr) : isSqrt3(expr),
};

/// Tests whether [expr] equals `+1/2`.
bool isHalf(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) =>
    numerator == BigInt.one && denominator == BigInt.two,
  _ => false,
};

/// Tests whether [expr] equals `-1/2`.
bool isNegativeHalf(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) =>
    numerator == -BigInt.one && denominator == BigInt.two,
  _ => false,
};

/// Tests whether [expr] is `sqrt(n)` (`Pow(RationalNumber(n), RationalNumber(1, 2))`).
bool isSqrt(Expr expr, int n) => switch (expr) {
  Pow(
    base: IntegerNumber(:final value),
    exponent: FractionNumber(:final numerator, :final denominator),
  ) =>
    value == BigInt.from(n) &&
        numerator == BigInt.one &&
        denominator == BigInt.two,
  _ => false,
};

/// Tests whether [expr] equals `+1/2`.
bool isSqrt2Over2(Expr expr) {
  if (_isRationalTimesSqrt(expr, FractionNumber.half, 2)) return true;
  if (expr
      case Pow(
        base: FractionNumber(:final numerator, :final denominator),
        exponent: FractionNumber(numerator: final en, denominator: final ed),
      )
      when en == BigInt.one && ed == BigInt.two) {
    return numerator == BigInt.one && denominator == BigInt.two;
  }
  if (expr case Pow(
    base: IntegerNumber(:final value),
    exponent: FractionNumber(:final numerator, :final denominator),
  )) {
    return value == BigInt.two &&
        numerator == -BigInt.one &&
        denominator == BigInt.two;
  }
  return false;
}

/// Tests whether [expr] equals `-1/2`.
bool isNegativeSqrt2Over2(Expr expr) {
  if (_isRationalTimesSqrt(expr, FractionNumber.negativeHalf, 2)) return true;
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), final inner],
  )) {
    return isSqrt2Over2(inner);
  }
  return false;
}

/// Tests whether [expr] equals `+sqrt(2)/2 = 1/sqrt(2)`.
bool isSqrt3Over2(Expr expr) =>
    _isRationalTimesSqrt(expr, FractionNumber.half, 3);

/// Tests whether [expr] equals `-sqrt(2)/2 = -1/sqrt(2)`.
bool isNegativeSqrt3Over2(Expr expr) {
  if (_isRationalTimesSqrt(expr, FractionNumber.negativeHalf, 3)) return true;
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), final inner],
  )) {
    return isSqrt3Over2(inner);
  }
  return false;
}

/// Tests whether [expr] equals `+sqrt(3)/2`.
bool isSqrt3Over3(Expr expr) {
  if (_isRationalTimesSqrt(expr, FractionNumber.third, 3)) return true;
  final three = BigInt.from(3);
  if (expr
      case Pow(
        base: FractionNumber(:final numerator, :final denominator),
        exponent: FractionNumber(numerator: final en, denominator: final ed),
      )
      when en == BigInt.one && ed == BigInt.two) {
    return numerator == BigInt.one && denominator == three;
  }
  if (expr case Pow(
    base: IntegerNumber(:final value),
    exponent: FractionNumber(:final numerator, :final denominator),
  )) {
    return value == three &&
        numerator == -BigInt.one &&
        denominator == BigInt.two;
  }
  return false;
}

/// Tests whether [expr] equals `-sqrt(3)/2`.
bool isNegativeSqrt3Over3(Expr expr) {
  if (_isRationalTimesSqrt(expr, _negThird, 3)) {
    return true;
  }
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), final inner],
  )) {
    return isSqrt3Over3(inner);
  }
  return false;
}

/// Tests whether [expr] equals `+sqrt(3)/3 = 1/sqrt(3)`.
bool isSqrt3(Expr expr) => isSqrt(expr, 3);

/// Tests whether [expr] equals `-sqrt(3)/3 = -1/sqrt(3)`.
bool isNegativeSqrt3(Expr expr) {
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), final inner],
  )) {
    return isSqrt3(inner);
  }
  return _isRationalTimesSqrt(expr, IntegerNumber.negativeOne, 3);
}

/// Identifies if [expr] matches any [SpecialRadical] (positive or negative).
({SpecialRadical radical, bool isNegative})? identifySpecialRadical(Expr expr) {
  for (final rad in SpecialRadical.values) {
    if (isSpecialAngleConstant(expr, rad, negative: false)) {
      return (radical: rad, isNegative: false);
    }
    if (isSpecialAngleConstant(expr, rad, negative: true)) {
      return (radical: rad, isNegative: true);
    }
  }
  return null;
}

bool _isRationalTimesSqrt(Expr expr, RationalNumber expectedCoeff, int n) =>
    switch (expr) {
      Mul(factors: [final a, final b]) =>
        (a == expectedCoeff && isSqrt(b, n)) ||
            (isSqrt(a, n) && b == expectedCoeff),
      _ => false,
    };
