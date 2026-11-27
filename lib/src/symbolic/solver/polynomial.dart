import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../type/expr_data_type.dart';
import 'univariate.dart';

/// Matches quadratic form `a * x^2 + b * x + c = 0`.
({Expr a, Expr b, Expr c})? matchQuadratic(Expr expr, String variable) {
  if (_hasLargeVariableExponent(expr, variable)) return null;
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

/// Solves quadratic equation `a * x^2 + b * x + c = 0`.
List<Expr> solveQuadratic(
  Expr a,
  Expr b,
  Expr c, {
  Assumptions assumptions = Assumptions.none,
}) {
  final disc = ((b * b) - (IntegerNumber.of(4) * a * c)).simplify(
    assumptions: assumptions,
  );
  final twoA = (IntegerNumber.two * a).simplify(assumptions: assumptions);

  switch (disc) {
    case RationalNumber(isNegative: true):
      return _complexConjugateRoots(
        ((-b) / twoA).simplify(assumptions: assumptions),
        (sqrtConstant(disc.neg()) / twoA).simplify(assumptions: assumptions),
        assumptions: assumptions,
      );
    case RationalNumber(isZero: true):
      return [((-b) / twoA).simplify(assumptions: assumptions)];
    case RationalNumber():
      final sqrtDisc = sqrtConstant(disc);
      final r1 = (((-b) + sqrtDisc) / twoA).simplify(assumptions: assumptions);
      final r2 = (((-b) - sqrtDisc) / twoA).simplify(assumptions: assumptions);
      return deduplicateRoots([r1, r2], assumptions: assumptions);
    case RealNumber(:final value) when value < 0:
      return _complexConjugateRoots(
        ((-b) / twoA).simplify(assumptions: assumptions),
        (RealNumber(math.sqrt(-value)) / twoA).simplify(
          assumptions: assumptions,
        ),
        assumptions: assumptions,
      );
    case _:
      final sqrtDisc = Pow.of(
        disc,
        FractionNumber.half,
      ).simplify(assumptions: assumptions);
      final r1 = (((-b) + sqrtDisc) / twoA).simplify(assumptions: assumptions);
      final r2 = (((-b) - sqrtDisc) / twoA).simplify(assumptions: assumptions);
      return deduplicateRoots([r1, r2], assumptions: assumptions);
  }
}

/// Matches biquadratic form `a * x^4 + b * x^2 + c = 0`.
({Expr a, Expr b, Expr c})? matchBiquadratic(Expr expr, String variable) {
  if (_hasLargeVariableExponent(expr, variable)) return null;
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

/// Solves biquadratic equation `a * x^4 + b * x^2 + c = 0`.
List<Expr> solveBiquadratic(
  Expr a,
  Expr b,
  Expr c,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  var uVar = '_u';
  while (variable == uVar ||
      a.dependsOn(uVar) ||
      b.dependsOn(uVar) ||
      c.dependsOn(uVar)) {
    uVar = '_$uVar';
  }
  final uVarExpr = Variable(uVar);
  final uEq = ((a * Pow.of(uVarExpr, IntegerNumber.two)) + (b * uVarExpr) + c)
      .simplify(assumptions: assumptions);
  final uRoots = solveEquation(uEq, uVar, assumptions: assumptions);
  final x = Variable(variable);
  final allRoots = <Expr>[];
  for (final u in uRoots) {
    final xEq = (Pow.of(x, IntegerNumber.two) - u).simplify(
      assumptions: assumptions,
    );
    allRoots.addAll(solveEquation(xEq, variable, assumptions: assumptions));
  }
  return deduplicateRoots(allRoots, assumptions: assumptions);
}

/// Computes the exact square root of rational constant [c] if reducible.
Expr sqrtConstant(RationalNumber c) =>
    Pow.of(c, FractionNumber.half).simplify();

/// Computes nth root of constant [c].
Expr rootConstant(Expr c, int n) {
  if (n.isOdd && c is RationalNumber && c.isNegative) {
    return (-Pow.of(c.neg(), RationalNumber(1, n)).simplify()).simplify();
  }
  if (n.isOdd && c is RealNumber && c.value < 0) {
    return RealNumber(-math.pow(-c.value, 1.0 / n).toDouble());
  }
  return Pow.of(c, RationalNumber(1, n)).simplify();
}

bool _isZero(Expr expr) => isZeroExpr(expr);

bool _hasLargeVariableExponent(Expr expr, String variable) => expr.anyNode(
  (node) =>
      node is Pow &&
      node.base.dependsOn(variable) &&
      node.exponent is IntegerNumber &&
      (((node.exponent as IntegerNumber).asInt?.abs() ?? 100) > 12),
);

List<Expr> _complexConjugateRoots(
  Expr realPart,
  Expr imagPart, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (r1, r2) = switch (realPart) {
    Number(isZero: true) => (
      (imagPart * ComplexNumber.i).simplify(assumptions: assumptions),
      ((-imagPart) * ComplexNumber.i).simplify(assumptions: assumptions),
    ),
    _ => (
      (realPart + imagPart * ComplexNumber.i).simplify(
        assumptions: assumptions,
      ),
      (realPart - imagPart * ComplexNumber.i).simplify(
        assumptions: assumptions,
      ),
    ),
  };
  return deduplicateRoots([r1, r2], assumptions: assumptions);
}
