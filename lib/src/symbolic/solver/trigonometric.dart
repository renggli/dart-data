import 'dart:math' as math;

import '../algebra/exact_constants.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import 'transcendental.dart';
import 'univariate.dart';

/// Inverts trigonometric sine $\sin(\text{arg}) = c$ for special and general angles.
List<Expr> invertSin(Expr arg, Expr c, String variable) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = switch (c) {
    RealNumber() => () {
      final asinC = math.asin(c.value);
      final a1 = asinC >= 0 ? asinC : asinC + 2 * math.pi;
      final a2 = (math.pi - asinC) % (2 * math.pi);
      return [
        RealNumber(a1),
        if ((a1 - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [IntegerNumber.zero, Constant.pi],
    RationalNumber(isOne: true) => [_piFraction(1, 2)],
    RationalNumber(isNegativeOne: true) => [_piFraction(3, 2)],
    _ when isHalf(c) => [_piFraction(1, 6), _piFraction(5, 6)],
    _ when isNegativeHalf(c) => [_piFraction(7, 6), _piFraction(11, 6)],
    _ when isSqrt2Over2(c) => [_piFraction(1, 4), _piFraction(3, 4)],
    _ when isNegativeSqrt2Over2(c) => [_piFraction(5, 4), _piFraction(7, 4)],
    _ when isSqrt3Over2(c) => [_piFraction(1, 3), _piFraction(2, 3)],
    _ when isNegativeSqrt3Over2(c) => [_piFraction(4, 3), _piFraction(5, 3)],
    _ => [Asin(c).simplify(), (Constant.pi - Asin(c)).simplify()],
  };

  return _invertAngles(arg, angles, variable);
}

/// Inverts trigonometric cosine $\cos(\text{arg}) = c$ for special and general angles.
List<Expr> invertCos(Expr arg, Expr c, String variable) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = switch (c) {
    RealNumber() => () {
      final acosC = math.acos(c.value);
      final a2 = (2 * math.pi - acosC) % (2 * math.pi);
      return [
        RealNumber(acosC),
        if ((acosC - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [_piFraction(1, 2), _piFraction(3, 2)],
    RationalNumber(isOne: true) => [IntegerNumber.zero],
    RationalNumber(isNegativeOne: true) => [Constant.pi],
    _ when isHalf(c) => [_piFraction(1, 3), _piFraction(5, 3)],
    _ when isNegativeHalf(c) => [_piFraction(2, 3), _piFraction(4, 3)],
    _ when isSqrt2Over2(c) => [_piFraction(1, 4), _piFraction(7, 4)],
    _ when isNegativeSqrt2Over2(c) => [_piFraction(3, 4), _piFraction(5, 4)],
    _ when isSqrt3Over2(c) => [_piFraction(1, 6), _piFraction(11, 6)],
    _ when isNegativeSqrt3Over2(c) => [_piFraction(5, 6), _piFraction(7, 6)],
    _ => [
      Acos(c).simplify(),
      ((IntegerNumber.two * Constant.pi) - Acos(c)).simplify(),
    ],
  };

  return _invertAngles(arg, angles, variable);
}

/// Inverts trigonometric tangent $\tan(\text{arg}) = c$ for special and general angles.
List<Expr> invertTan(Expr arg, Expr c, String variable) {
  final angles = switch (c) {
    RealNumber() => () {
      final atanC = math.atan(c.value);
      final a1 = atanC >= 0 ? atanC : atanC + math.pi;
      final a2 = (a1 + math.pi) % (2 * math.pi);
      return [
        RealNumber(a1),
        if ((a1 - a2).abs() > 1e-12)
          RealNumber(a2 >= 0 ? a2 : a2 + 2 * math.pi),
      ];
    }(),
    RationalNumber(isZero: true) => [IntegerNumber.zero, Constant.pi],
    RationalNumber(isOne: true) => [_piFraction(1, 4), _piFraction(5, 4)],
    RationalNumber(isNegativeOne: true) => [
      _piFraction(3, 4),
      _piFraction(7, 4),
    ],
    _ when isSqrt3Over3(c) => [_piFraction(1, 6), _piFraction(7, 6)],
    _ when isNegativeSqrt3Over3(c) => [_piFraction(5, 6), _piFraction(11, 6)],
    _ when isSqrt3(c) => [_piFraction(1, 3), _piFraction(4, 3)],
    _ when isNegativeSqrt3(c) => [_piFraction(2, 3), _piFraction(5, 3)],
    _ => [Atan(c).simplify(), (Constant.pi + Atan(c)).simplify()],
  };

  return _invertAngles(arg, angles, variable);
}

Expr _piFraction(int num, int den) =>
    (RationalNumber(num, den) * Constant.pi).simplify();

List<Expr> _invertAngles(Expr arg, List<Expr> angles, String variable) =>
    deduplicateRoots([
      for (final angle in angles)
        ...(invertEquation(arg, angle, variable) ??
            solveEquation((arg - angle).simplify(), variable)),
    ]);
