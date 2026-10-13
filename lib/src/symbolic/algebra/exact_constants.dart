import 'dart:math' as math;

import '../ast.dart';

/// Standard algebraic radical constants appearing in special angles for
/// trigonometric and inverse trigonometric evaluation and equation solving.
enum SpecialRadical {
  /// Half constant: $1/2 = 0.5$.
  half(0.5),

  /// Square root of 2 over 2: $\frac{\sqrt{2}}{2} \approx 0.7071067811865475$.
  sqrt2Over2(0.70710678118654752440),

  /// Square root of 3 over 2: $\frac{\sqrt{3}}{2} \approx 0.8660254037844386$.
  sqrt3Over2(0.86602540378443864676),

  /// Square root of 3 over 3: $\frac{\sqrt{3}}{3} = \frac{1}{\sqrt{3}} \approx 0.5773502691896257$.
  sqrt3Over3(0.57735026918962576451),

  /// Square root of 3: $\sqrt{3} \approx 1.7320508075688772$.
  sqrt3(1.73205080756887729353);

  new(this.numericValue);

  /// Positive floating-point numerical value of this special radical.
  final double numericValue;
}

/// Tests whether [expr] matches [target], taking [negative] sign into account.
bool isSpecialAngleConstant(
  Expr expr,
  SpecialRadical target, {
  bool negative = false,
}) => switch (target) {
  SpecialRadical.half => negative ? isNegativeHalf(expr) : isHalf(expr),
  SpecialRadical.sqrt2Over2 =>
    negative ? isNegativeSqrt2Over2(expr) : isSqrt2Over2(expr),
  SpecialRadical.sqrt3Over2 =>
    negative ? isNegativeSqrt3Over2(expr) : isSqrt3Over2(expr),
  SpecialRadical.sqrt3Over3 =>
    negative ? isNegativeSqrt3Over3(expr) : isSqrt3Over3(expr),
  SpecialRadical.sqrt3 => negative ? isNegativeSqrt3(expr) : isSqrt3(expr),
};

/// Constructs the canonical symbolic [Expr] for [target], optionally negated.
Expr specialRadicalExpr(SpecialRadical target, {bool negative = false}) {
  if (target == SpecialRadical.half) {
    return negative ? const RationalNumber(-1, 2) : const RationalNumber(1, 2);
  }
  final base = switch (target) {
    SpecialRadical.half => const RationalNumber(1, 2),
    SpecialRadical.sqrt2Over2 => const Div(
      Pow(RationalNumber(2), RationalNumber(1, 2)),
      RationalNumber(2),
    ),
    SpecialRadical.sqrt3Over2 => const Div(
      Pow(RationalNumber(3), RationalNumber(1, 2)),
      RationalNumber(2),
    ),
    SpecialRadical.sqrt3Over3 => const Div(
      Pow(RationalNumber(3), RationalNumber(1, 2)),
      RationalNumber(3),
    ),
    SpecialRadical.sqrt3 => const Pow(RationalNumber(3), RationalNumber(1, 2)),
  };
  return negative ? Neg(base) : base;
}

/// Identifies if [expr] matches any [SpecialRadical], returning the radical and
/// its sign, or `null` if no match is found.
({SpecialRadical radical, bool isNegative})? identifySpecialRadical(Expr expr) {
  for (final radical in SpecialRadical.values) {
    if (isSpecialAngleConstant(expr, radical, negative: false)) {
      return (radical: radical, isNegative: false);
    }
    if (isSpecialAngleConstant(expr, radical, negative: true)) {
      return (radical: radical, isNegative: true);
    }
  }
  return null;
}

/// Tests whether [expr] equals 1/2.
bool isHalf(Expr expr) {
  if (expr is RationalNumber && expr.numerator == 1 && expr.denominator == 2) {
    return true;
  }
  if (expr is RealNumber && (expr.value - 0.5).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isNegativeHalf(expr.expr)) {
    return true;
  }
  return false;
}

/// Tests whether [expr] equals -1/2.
bool isNegativeHalf(Expr expr) {
  if (expr is RationalNumber && expr.numerator == -1 && expr.denominator == 2) {
    return true;
  }
  if (expr is RealNumber && (expr.value + 0.5).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isHalf(expr.expr)) {
    return true;
  }
  return false;
}

/// Tests whether [expr] is an exact square root of [n].
bool isSqrt(Expr expr, int n) =>
    expr is Pow &&
    expr.base == RationalNumber(n) &&
    expr.exponent == const RationalNumber(1, 2);

/// Tests whether [expr] equals $\sqrt{2}/2$.
bool isSqrt2Over2(Expr expr) {
  if (expr is RealNumber && (expr.value - math.sqrt(2) / 2).abs() < 1e-12) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(1, 2) && isSqrt(expr.right, 2)) ||
        (expr.right == const RationalNumber(1, 2) && isSqrt(expr.left, 2))) {
      return true;
    }
  }
  if (expr is Div &&
      isSqrt(expr.left, 2) &&
      expr.right == const RationalNumber(2)) {
    return true;
  }
  if (expr is Pow &&
      expr.base == const RationalNumber(1, 2) &&
      expr.exponent == const RationalNumber(1, 2)) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a - math.sqrt(2) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $-\sqrt{2}/2$.
bool isNegativeSqrt2Over2(Expr expr) {
  if (expr is RealNumber && (expr.value + math.sqrt(2) / 2).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isSqrt2Over2(expr.expr)) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(-1, 2) && isSqrt(expr.right, 2)) ||
        (expr.right == const RationalNumber(-1, 2) && isSqrt(expr.left, 2))) {
      return true;
    }
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a + math.sqrt(2) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $\sqrt{3}/2$.
bool isSqrt3Over2(Expr expr) {
  if (expr is RealNumber && (expr.value - math.sqrt(3) / 2).abs() < 1e-12) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(1, 2) && isSqrt(expr.right, 3)) ||
        (expr.right == const RationalNumber(1, 2) && isSqrt(expr.left, 3))) {
      return true;
    }
  }
  if (expr is Div &&
      isSqrt(expr.left, 3) &&
      expr.right == const RationalNumber(2)) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a - math.sqrt(3) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $-\sqrt{3}/2$.
bool isNegativeSqrt3Over2(Expr expr) {
  if (expr is RealNumber && (expr.value + math.sqrt(3) / 2).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isSqrt3Over2(expr.expr)) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(-1, 2) && isSqrt(expr.right, 3)) ||
        (expr.right == const RationalNumber(-1, 2) && isSqrt(expr.left, 3))) {
      return true;
    }
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a + math.sqrt(3) / 2).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $\sqrt{3}/3$.
bool isSqrt3Over3(Expr expr) {
  if (expr is RealNumber && (expr.value - math.sqrt(3) / 3).abs() < 1e-12) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(1, 3) && isSqrt(expr.right, 3)) ||
        (expr.right == const RationalNumber(1, 3) && isSqrt(expr.left, 3))) {
      return true;
    }
  }
  if (expr is Div &&
      isSqrt(expr.left, 3) &&
      expr.right == const RationalNumber(3)) {
    return true;
  }
  if (expr is Pow &&
      expr.base == const RationalNumber(1, 3) &&
      expr.exponent == const RationalNumber(1, 2)) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a - math.sqrt(3) / 3).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $-\sqrt{3}/3$.
bool isNegativeSqrt3Over3(Expr expr) {
  if (expr is RealNumber && (expr.value + math.sqrt(3) / 3).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isSqrt3Over3(expr.expr)) {
    return true;
  }
  if (expr is Mul) {
    if ((expr.left == const RationalNumber(-1, 3) && isSqrt(expr.right, 3)) ||
        (expr.right == const RationalNumber(-1, 3) && isSqrt(expr.left, 3))) {
      return true;
    }
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 &&
          (complex.a + math.sqrt(3) / 3).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $\sqrt{3}$.
bool isSqrt3(Expr expr) {
  if (expr is RealNumber && (expr.value - math.sqrt(3)).abs() < 1e-12) {
    return true;
  }
  if (isSqrt(expr, 3)) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 && (complex.a - math.sqrt(3)).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

/// Tests whether [expr] equals $-\sqrt{3}$.
bool isNegativeSqrt3(Expr expr) {
  if (expr is RealNumber && (expr.value + math.sqrt(3)).abs() < 1e-12) {
    return true;
  }
  if (expr is Neg && isSqrt3(expr.expr)) {
    return true;
  }
  if (expr is Mul &&
      expr.left == RationalNumber.negativeOne &&
      isSqrt(expr.right, 3)) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final complex = expr.evaluateComplex();
      if (complex.b.abs() < 1e-12 && (complex.a + math.sqrt(3)).abs() < 1e-12) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}
