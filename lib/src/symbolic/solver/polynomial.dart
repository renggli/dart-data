import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import 'univariate.dart';

/// Matches quadratic form $a x^2 + b x + c = 0$.
({Expr a, Expr b, Expr c})? matchQuadratic(Expr expr, String variable) {
  final coeffs = extractMonomialCoefficients(expr, variable);
  if (coeffs == null) return null;
  if (coeffs.keys.any((deg) => deg > 2 || deg < 0)) return null;

  final a = coeffs[2];
  if (a == null || _isZero(a)) return null;

  final b = coeffs[1] ?? RationalNumber.zero;
  final c = coeffs[0] ?? RationalNumber.zero;
  return (a: a, b: b, c: c);
}

/// Solves quadratic equation $a x^2 + b x + c = 0$.
List<Expr> solveQuadratic(Expr a, Expr b, Expr c) {
  final disc = ((b * b) - (const RationalNumber(4) * a * c)).simplify();

  if (disc is RationalNumber) {
    if (disc.isNegative) {
      final posDisc = RationalNumber(-disc.numerator, disc.denominator);
      final sqrtDiscAbs = sqrtConstant(posDisc);
      final twoA = (const RationalNumber(2) * a).simplify();
      final realPart = ((-b) / twoA).simplify();
      final imagPart = (sqrtDiscAbs / twoA).simplify();

      Expr r1;
      Expr r2;
      if ((realPart is RationalNumber && realPart.isZero) ||
          (realPart is RealNumber && realPart.value == 0.0)) {
        r1 = (imagPart * ConstantNumber.i).simplify();
        r2 = ((-imagPart) * ConstantNumber.i).simplify();
      } else {
        r1 = (realPart + imagPart * ConstantNumber.i).simplify();
        r2 = (realPart - imagPart * ConstantNumber.i).simplify();
      }
      return deduplicateRoots([r1, r2]);
    } else if (disc.isZero) {
      final root = ((-b) / (const RationalNumber(2) * a)).simplify();
      return [root];
    } else {
      final sqrtDisc = sqrtConstant(disc);
      final twoA = (const RationalNumber(2) * a).simplify();
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return deduplicateRoots([r1, r2]);
    }
  } else if (disc is RealNumber && disc.value < 0) {
    final sqrtDiscAbs = RealNumber(math.sqrt(-disc.value));
    final twoA = (const RationalNumber(2) * a).simplify();
    final realPart = ((-b) / twoA).simplify();
    final imagPart = (sqrtDiscAbs / twoA).simplify();

    Expr r1;
    Expr r2;
    if ((realPart is RationalNumber && realPart.isZero) ||
        (realPart is RealNumber && realPart.value == 0.0)) {
      r1 = (imagPart * ConstantNumber.i).simplify();
      r2 = ((-imagPart) * ConstantNumber.i).simplify();
    } else {
      r1 = (realPart + imagPart * ConstantNumber.i).simplify();
      r2 = (realPart - imagPart * ConstantNumber.i).simplify();
    }
    return deduplicateRoots([r1, r2]);
  } else {
    final sqrtDisc = disc.pow(const RationalNumber(1, 2)).simplify();
    final twoA = (const RationalNumber(2) * a).simplify();
    final r1 = (((-b) + sqrtDisc) / twoA).simplify();
    final r2 = (((-b) - sqrtDisc) / twoA).simplify();
    return deduplicateRoots([r1, r2]);
  }
}

/// Matches biquadratic form $a x^4 + b x^2 + c = 0$.
({Expr a, Expr b, Expr c})? matchBiquadratic(Expr expr, String variable) {
  final coeffs = extractMonomialCoefficients(expr, variable);
  if (coeffs == null) return null;
  if (coeffs.keys.any((deg) => deg != 0 && deg != 2 && deg != 4)) return null;

  final a = coeffs[4];
  if (a == null || _isZero(a)) return null;

  final b = coeffs[2] ?? RationalNumber.zero;
  final c = coeffs[0] ?? RationalNumber.zero;
  return (a: a, b: b, c: c);
}

/// Extracts monomial powers and their coefficients for polynomial [expr] in [variable].
///
/// Returns a map where each key $k \ge 0$ is the power of [variable] and the
/// value is the coefficient expression independent of [variable].
///
/// Returns `null` if [expr] is not a polynomial in [variable] (such as rational
/// functions with [variable] in the denominator, fractional powers, or
/// transcendental functions of [variable]).
Map<int, Expr>? extractMonomialCoefficients(Expr expr, String variable) {
  final expanded = expr.expand();
  if (!expanded.dependsOn(variable)) {
    return _isZero(expanded) ? {0: RationalNumber.zero} : {0: expanded};
  }

  final acc = MonomialAccumulator();
  acc.add(expanded);
  return acc.extractPolynomialCoefficients(variable);
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
  final uEq = ((a * uVarExpr.pow(const RationalNumber(2))) + (b * uVarExpr) + c)
      .simplify();
  final uRoots = solveEquation(uEq, uVar);
  final x = Variable(variable);
  final allRoots = <Expr>[];
  for (final u in uRoots) {
    final xEq = (x.pow(const RationalNumber(2)) - u).simplify();
    allRoots.addAll(solveEquation(xEq, variable));
  }
  return deduplicateRoots(allRoots);
}

/// Computes the exact square root of rational constant [c] if reducible.
Expr sqrtConstant(RationalNumber c) {
  if (c.numerator >= 0) {
    final numSqrt = math.sqrt(c.numerator).round();
    final denSqrt = math.sqrt(c.denominator).round();
    if (numSqrt * numSqrt == c.numerator &&
        denSqrt * denSqrt == c.denominator) {
      return RationalNumber(numSqrt, denSqrt);
    }
  }
  return c.pow(const RationalNumber(1, 2)).simplify();
}

/// Computes integer nth root if exact.
int? integerNthRoot(int val, int n) {
  if (val < 0) return null;
  if (val == 0) return 0;
  if (val == 1) return 1;
  final r = math.pow(val, 1.0 / n).round();
  var p = 1;
  for (var i = 0; i < n; i++) {
    if (val ~/ r < p) return null;
    p *= r;
  }
  return p == val ? r : null;
}

/// Computes nth root of constant [c].
Expr rootConstant(Expr c, int n) {
  if (c is RationalNumber) {
    if (n.isOdd && c.isNegative) {
      final posRoot = rootConstant(
        RationalNumber(-c.numerator, c.denominator),
        n,
      );
      return (-posRoot).simplify();
    }
    if (c.numerator >= 0) {
      final numR = integerNthRoot(c.numerator, n);
      final denR = integerNthRoot(c.denominator, n);
      if (numR != null && denR != null) {
        return RationalNumber(numR, denR);
      }
    }
  } else if (c is RealNumber) {
    if (n.isOdd && c.value < 0) {
      return RealNumber(-math.pow(-c.value, 1.0 / n).toDouble());
    }
  }
  return c.pow(RationalNumber(1, n)).simplify();
}

bool _isZero(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => true,
  RealNumber(value: 0.0) => true,
  _ => false,
};
