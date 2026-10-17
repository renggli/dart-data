import '../algebra/exact_constants.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import 'transcendental.dart';
import 'univariate.dart';

Expr _piFraction(int num, int den) =>
    (RationalNumber(num, den) * Constant.pi).simplify();

/// Inverts trigonometric sine $\sin(\text{arg}) = c$ for special and general angles.
List<Expr> invertSin(Expr arg, Expr c, String variable) {
  if (isRealConstantOutOfRange(c, 1.0)) {
    return const [];
  }

  final angles = <Expr>[];
  if ((c is Number && c.isZero) || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([IntegerNumber.zero, Constant.pi]);
  } else if ((c is Number && c.isOne) || (c is RealNumber && c.value == 1.0)) {
    angles.add(_piFraction(1, 2));
  } else if ((c is Number && c.isNegativeOne) ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(_piFraction(3, 2));
  } else if (isHalf(c)) {
    angles.addAll([_piFraction(1, 6), _piFraction(5, 6)]);
  } else if (isNegativeHalf(c)) {
    angles.addAll([_piFraction(7, 6), _piFraction(11, 6)]);
  } else if (isSqrt2Over2(c)) {
    angles.addAll([_piFraction(1, 4), _piFraction(3, 4)]);
  } else if (isNegativeSqrt2Over2(c)) {
    angles.addAll([_piFraction(5, 4), _piFraction(7, 4)]);
  } else if (isSqrt3Over2(c)) {
    angles.addAll([_piFraction(1, 3), _piFraction(2, 3)]);
  } else if (isNegativeSqrt3Over2(c)) {
    angles.addAll([_piFraction(4, 3), _piFraction(5, 3)]);
  } else {
    angles.add(Asin(c).simplify());
    angles.add((Constant.pi - Asin(c)).simplify());
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
  if ((c is Number && c.isZero) || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([_piFraction(1, 2), _piFraction(3, 2)]);
  } else if ((c is Number && c.isOne) || (c is RealNumber && c.value == 1.0)) {
    angles.add(IntegerNumber.zero);
  } else if ((c is Number && c.isNegativeOne) ||
      (c is RealNumber && c.value == -1.0)) {
    angles.add(Constant.pi);
  } else if (isHalf(c)) {
    angles.addAll([_piFraction(1, 3), _piFraction(5, 3)]);
  } else if (isNegativeHalf(c)) {
    angles.addAll([_piFraction(2, 3), _piFraction(4, 3)]);
  } else if (isSqrt2Over2(c)) {
    angles.addAll([_piFraction(1, 4), _piFraction(7, 4)]);
  } else if (isNegativeSqrt2Over2(c)) {
    angles.addAll([_piFraction(3, 4), _piFraction(5, 4)]);
  } else if (isSqrt3Over2(c)) {
    angles.addAll([_piFraction(1, 6), _piFraction(11, 6)]);
  } else if (isNegativeSqrt3Over2(c)) {
    angles.addAll([_piFraction(5, 6), _piFraction(7, 6)]);
  } else {
    angles.add(Acos(c).simplify());
    angles.add(((IntegerNumber.two * Constant.pi) - Acos(c)).simplify());
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
  if ((c is Number && c.isZero) || (c is RealNumber && c.value == 0.0)) {
    angles.addAll([IntegerNumber.zero, Constant.pi]);
  } else if ((c is Number && c.isOne) || (c is RealNumber && c.value == 1.0)) {
    angles.addAll([_piFraction(1, 4), _piFraction(5, 4)]);
  } else if ((c is Number && c.isNegativeOne) ||
      (c is RealNumber && c.value == -1.0)) {
    angles.addAll([_piFraction(3, 4), _piFraction(7, 4)]);
  } else if (isSqrt3Over3(c)) {
    angles.addAll([_piFraction(1, 6), _piFraction(7, 6)]);
  } else if (isNegativeSqrt3Over3(c)) {
    angles.addAll([_piFraction(5, 6), _piFraction(11, 6)]);
  } else if (isSqrt3(c)) {
    angles.addAll([_piFraction(1, 3), _piFraction(4, 3)]);
  } else if (isNegativeSqrt3(c)) {
    angles.addAll([_piFraction(2, 3), _piFraction(5, 3)]);
  } else {
    angles.add(Atan(c).simplify());
    angles.add((Constant.pi + Atan(c)).simplify());
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
