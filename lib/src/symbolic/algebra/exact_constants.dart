import 'dart:math' as math;

import '../ast.dart';
import '../compiler.dart';

/// Standard special radical values appearing in exact trigonometric evaluations.
enum SpecialRadical {
  /// $1 / 2 = \sin(\pi/6) = \cos(\pi/3)$.
  half(0.5),

  /// $\sqrt{2} / 2 = \sin(\pi/4) = \cos(\pi/4)$.
  sqrt2Over2(math.sqrt1_2),

  /// $\sqrt{3} / 2 = \sin(\pi/3) = \cos(\pi/6)$.
  sqrt3Over2(0.8660254037844386),

  /// $\sqrt{3} / 3 = \tan(\pi/6)$.
  sqrt3Over3(0.5773502691896257),

  /// $\sqrt{3} = \tan(\pi/3)$.
  sqrt3(1.7320508075688772);

  new(this.numericValue);

  /// Floating-point approximation of this radical.
  final double numericValue;
}

/// Constructs the canonical exact [Expr] for [radical] with optional [negative] sign.
Expr specialRadicalExpr(SpecialRadical radical, {bool negative = false}) =>
    switch (radical) {
      SpecialRadical.half =>
        negative ? FractionNumber.negativeHalf : FractionNumber.half,
      SpecialRadical.sqrt2Over2 => Mul([
        if (negative) FractionNumber.negativeHalf else FractionNumber.half,
        Pow(IntegerNumber.two, FractionNumber.half, isSimplified: true),
      ], isSimplified: true),
      SpecialRadical.sqrt3Over2 => Mul([
        if (negative) FractionNumber.negativeHalf else FractionNumber.half,
        Pow(
          const IntegerNumber(Integer(3)),
          FractionNumber.half,
          isSimplified: true,
        ),
      ], isSimplified: true),
      SpecialRadical.sqrt3Over3 => Mul([
        if (negative)
          const FractionNumber(Integer.negativeOne, Integer(3))
        else
          FractionNumber.third,
        Pow(
          const IntegerNumber(Integer(3)),
          FractionNumber.half,
          isSimplified: true,
        ),
      ], isSimplified: true),
      SpecialRadical.sqrt3 =>
        negative
            ? Mul([
                IntegerNumber.negativeOne,
                Pow(
                  const IntegerNumber(Integer(3)),
                  FractionNumber.half,
                  isSimplified: true,
                ),
              ], isSimplified: true)
            : Pow(
                const IntegerNumber(Integer(3)),
                FractionNumber.half,
                isSimplified: true,
              ),
    };

/// Tests whether [expr] represents $\pm\text{radical}$.
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

/// Tests whether [expr] equals $+1/2$.
bool isHalf(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) =>
    numerator.isOne && denominator == Integer.two,
  RealNumber(:final value) => (value - 0.5).abs() < 1e-12,
  _ => false,
};

/// Tests whether [expr] equals $-1/2$.
bool isNegativeHalf(Expr expr) => switch (expr) {
  FractionNumber(:final numerator, :final denominator) =>
    numerator == Integer.negativeOne && denominator == Integer.two,
  RealNumber(:final value) => (value + 0.5).abs() < 1e-12,
  _ => false,
};

/// Tests whether [expr] is $\sqrt{n}$ (`Pow(RationalNumber(n), RationalNumber(1, 2))`).
bool isSqrt(Expr expr, int n) => switch (expr) {
  Pow(
    base: IntegerNumber(:final value),
    exponent: FractionNumber(:final numerator, :final denominator),
  ) =>
    value == Integer.from(n) && numerator.isOne && denominator == Integer.two,
  _ => false,
};

/// Tests whether [expr] equals $+\sqrt{2}/2 = 1/\sqrt{2}$.
bool isSqrt2Over2(Expr expr) {
  if (expr case Pow(base: FractionNumber.half, exponent: FractionNumber.half)) {
    return true;
  }
  return _evalClose(expr, math.sqrt1_2);
}

/// Tests whether [expr] equals $-\sqrt{2}/2 = -1/\sqrt{2}$.
bool isNegativeSqrt2Over2(Expr expr) => _evalClose(expr, -math.sqrt1_2);

/// Tests whether [expr] equals $+\sqrt{3}/2$.
bool isSqrt3Over2(Expr expr) => _evalClose(expr, 0.8660254037844386);

/// Tests whether [expr] equals $-\sqrt{3}/2$.
bool isNegativeSqrt3Over2(Expr expr) => _evalClose(expr, -0.8660254037844386);

/// Tests whether [expr] equals $+\sqrt{3}/3 = 1/\sqrt{3}$.
bool isSqrt3Over3(Expr expr) => _evalClose(expr, 0.5773502691896257);

/// Tests whether [expr] equals $-\sqrt{3}/3 = -1/\sqrt{3}$.
bool isNegativeSqrt3Over3(Expr expr) => _evalClose(expr, -0.5773502691896257);

/// Tests whether [expr] equals $+\sqrt{3}$.
bool isSqrt3(Expr expr) {
  if (isSqrt(expr, 3)) return true;
  return _evalClose(expr, 1.7320508075688772);
}

/// Tests whether [expr] equals $-\sqrt{3}$.
bool isNegativeSqrt3(Expr expr) => _evalClose(expr, -1.7320508075688772);

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

bool _evalClose(Expr expr, double target) {
  if (expr.freeVariables.isNotEmpty) return false;
  if (!expr.isReal) return false;
  try {
    final v = expr.evaluate(const {});
    return (v - target).abs() < 1e-12;
  } on Object {
    return false;
  }
}
