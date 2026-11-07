import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import 'univariate.dart';

/// Matches quadratic form $a x^2 + b x + c = 0$.
({Expr a, Expr b, Expr c})? matchQuadratic(Expr expr, String variable) {
  final expExpr = expr.expand().simplify();
  final coeffs = extractPolynomialCoefficients(expExpr, variable);
  if (coeffs == null) return null;
  if (coeffs.keys.any((deg) => deg > 2 || deg < 0)) return null;

  final a = coeffs[2];
  if (a == null || _isZero(a)) return null;

  final b = coeffs[1] ?? IntegerNumber.zero;
  final c = coeffs[0] ?? IntegerNumber.zero;
  return (a: a, b: b, c: c);
}

/// Solves quadratic equation $a x^2 + b x + c = 0$.
List<Expr> solveQuadratic(Expr a, Expr b, Expr c) {
  final disc = ((b * b) - (IntegerNumber.of(4) * a * c)).simplify();
  final twoA = (IntegerNumber.two * a).simplify();

  switch (disc) {
    case RationalNumber(isNegative: true):
      final sqrtDiscAbs = sqrtConstant(disc.neg());
      final realPart = ((-b) / twoA).simplify();
      final imagPart = (sqrtDiscAbs / twoA).simplify();
      final (r1, r2) = switch (realPart) {
        Number(isZero: true) => (
          (imagPart * ComplexNumber.i).simplify(),
          ((-imagPart) * ComplexNumber.i).simplify(),
        ),
        _ => (
          (realPart + imagPart * ComplexNumber.i).simplify(),
          (realPart - imagPart * ComplexNumber.i).simplify(),
        ),
      };
      return deduplicateRoots([r1, r2]);
    case RationalNumber(isZero: true):
      return [((-b) / twoA).simplify()];
    case RationalNumber():
      final sqrtDisc = sqrtConstant(disc);
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return deduplicateRoots([r1, r2]);
    case RealNumber(:final value) when value < 0:
      final sqrtDiscAbs = RealNumber(math.sqrt(-value));
      final realPart = ((-b) / twoA).simplify();
      final imagPart = (sqrtDiscAbs / twoA).simplify();
      final (r1, r2) = switch (realPart) {
        Number(isZero: true) => (
          (imagPart * ComplexNumber.i).simplify(),
          ((-imagPart) * ComplexNumber.i).simplify(),
        ),
        _ => (
          (realPart + imagPart * ComplexNumber.i).simplify(),
          (realPart - imagPart * ComplexNumber.i).simplify(),
        ),
      };
      return deduplicateRoots([r1, r2]);
    case _:
      final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return deduplicateRoots([r1, r2]);
  }
}

/// Matches biquadratic form $a x^4 + b x^2 + c = 0$.
({Expr a, Expr b, Expr c})? matchBiquadratic(Expr expr, String variable) {
  final expExpr = expr.expand().simplify();
  final coeffs = extractPolynomialCoefficients(expExpr, variable);
  if (coeffs == null) return null;
  if (coeffs.keys.any((deg) => deg != 0 && deg != 2 && deg != 4)) return null;

  final a = coeffs[4];
  if (a == null || _isZero(a)) return null;

  final b = coeffs[2] ?? IntegerNumber.zero;
  final c = coeffs[0] ?? IntegerNumber.zero;
  return (a: a, b: b, c: c);
}

/// Solves biquadratic equation $a x^4 + b x^2 + c = 0$.
List<Expr> solveBiquadratic(Expr a, Expr b, Expr c, String variable) {
  var uVar = '_u';
  while (variable == uVar ||
      a.dependsOn(uVar) ||
      b.dependsOn(uVar) ||
      c.dependsOn(uVar)) {
    uVar = '_$uVar';
  }
  final uVarExpr = Variable(uVar);
  final uEq = ((a * Pow(uVarExpr, IntegerNumber.two)) + (b * uVarExpr) + c)
      .simplify();
  final uRoots = solveEquation(uEq, uVar);
  final x = Variable(variable);
  final allRoots = <Expr>[];
  for (final u in uRoots) {
    final xEq = (Pow(x, IntegerNumber.two) - u).simplify();
    allRoots.addAll(solveEquation(xEq, variable));
  }
  return deduplicateRoots(allRoots);
}

/// Computes the exact square root of rational constant [c] if reducible.
Expr sqrtConstant(RationalNumber c) => Pow(c, FractionNumber.half).simplify();

/// Computes nth root of constant [c].
Expr rootConstant(Expr c, int n) {
  if (n.isOdd && c is RationalNumber && c.isNegative) {
    return (-Pow(c.neg(), RationalNumber(1, n)).simplify()).simplify();
  }
  if (n.isOdd && c is RealNumber && c.value < 0) {
    return RealNumber(-math.pow(-c.value, 1.0 / n).toDouble());
  }
  return Pow(c, RationalNumber(1, n)).simplify();
}

bool _isZero(Expr expr) => isZeroExpr(expr);
