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

  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([RationalNumber.zero, ConstantNumber.pi]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.add(const Mul(RationalNumber(1, 2), ConstantNumber.pi));
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(const Mul(RationalNumber(3, 2), ConstantNumber.pi));
  } else if (isHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
    ]);
  } else if (isNegativeHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (isSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (isSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Asin(c).simplify());
    angles.add((ConstantNumber.pi - Asin(c)).simplify());
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(solveEquation((arg - angle).simplify(), variable));
    }
  }
  return deduplicateRoots(roots);
}

/// Inverts trigonometric cosine $\cos(\text{arg}) = c$ for special and general angles.
List<Expr> invertCos(Expr arg, Expr c, String variable) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([
      const Mul(RationalNumber(1, 2), ConstantNumber.pi),
      const Mul(RationalNumber(3, 2), ConstantNumber.pi),
    ]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.add(RationalNumber.zero);
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(ConstantNumber.pi);
  } else if (isHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else if (isNegativeHalf(c)) {
    angles.addAll([
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
    ]);
  } else if (isSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt2Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
    ]);
  } else if (isSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt3Over2(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Acos(c).simplify());
    angles.add(
      ((const RationalNumber(2) * ConstantNumber.pi) - Acos(c)).simplify(),
    );
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(solveEquation((arg - angle).simplify(), variable));
    }
  }
  return deduplicateRoots(roots);
}

/// Inverts trigonometric tangent $\tan(\text{arg}) = c$ for special and general angles.
List<Expr> invertTan(Expr arg, Expr c, String variable) {
  final angles = <Expr>[];
  if (c == RationalNumber.zero || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([RationalNumber.zero, ConstantNumber.pi]);
  } else if (c == RationalNumber.one || (c is RealNumber && c.value == 1.0)) {
    angles.addAll([
      const Mul(RationalNumber(1, 4), ConstantNumber.pi),
      const Mul(RationalNumber(5, 4), ConstantNumber.pi),
    ]);
  } else if (c == RationalNumber.negativeOne ||
      (c is RealNumber && c.value == -1.0)) {
    angles.addAll([
      const Mul(RationalNumber(3, 4), ConstantNumber.pi),
      const Mul(RationalNumber(7, 4), ConstantNumber.pi),
    ]);
  } else if (isSqrt3Over3(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 6), ConstantNumber.pi),
      const Mul(RationalNumber(7, 6), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt3Over3(c)) {
    angles.addAll([
      const Mul(RationalNumber(5, 6), ConstantNumber.pi),
      const Mul(RationalNumber(11, 6), ConstantNumber.pi),
    ]);
  } else if (isSqrt3(c)) {
    angles.addAll([
      const Mul(RationalNumber(1, 3), ConstantNumber.pi),
      const Mul(RationalNumber(4, 3), ConstantNumber.pi),
    ]);
  } else if (isNegativeSqrt3(c)) {
    angles.addAll([
      const Mul(RationalNumber(2, 3), ConstantNumber.pi),
      const Mul(RationalNumber(5, 3), ConstantNumber.pi),
    ]);
  } else {
    angles.add(Atan(c).simplify());
    angles.add((ConstantNumber.pi + Atan(c)).simplify());
  }

  final roots = <Expr>[];
  for (final angle in angles) {
    final inverted = invertEquation(arg, angle, variable);
    if (inverted != null) {
      roots.addAll(inverted);
    } else {
      roots.addAll(solveEquation((arg - angle).simplify(), variable));
    }
  }
  return deduplicateRoots(roots);
}
