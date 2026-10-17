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

  final b = coeffs[1] ?? IntegerNumber.zero;
  final c = coeffs[0] ?? IntegerNumber.zero;
  return (a: a, b: b, c: c);
}

/// Solves quadratic equation $a x^2 + b x + c = 0$.
List<Expr> solveQuadratic(Expr a, Expr b, Expr c) {
  final disc = ((b * b) - (IntegerNumber.of(4) * a * c)).simplify();

  if (disc is RationalNumber) {
    if (disc.isNegative) {
      final posDisc = disc.neg();
      final sqrtDiscAbs = sqrtConstant(posDisc);
      final twoA = (IntegerNumber.two * a).simplify();
      final realPart = ((-b) / twoA).simplify();
      final imagPart = (sqrtDiscAbs / twoA).simplify();

      Expr r1;
      Expr r2;
      if (realPart is Number && realPart.isZero) {
        r1 = (imagPart * ComplexNumber.i).simplify();
        r2 = ((-imagPart) * ComplexNumber.i).simplify();
      } else {
        r1 = (realPart + imagPart * ComplexNumber.i).simplify();
        r2 = (realPart - imagPart * ComplexNumber.i).simplify();
      }
      return deduplicateRoots([r1, r2]);
    } else if (disc.isZero) {
      final root = ((-b) / (IntegerNumber.two * a)).simplify();
      return [root];
    } else {
      final sqrtDisc = sqrtConstant(disc);
      final twoA = (IntegerNumber.two * a).simplify();
      final r1 = (((-b) + sqrtDisc) / twoA).simplify();
      final r2 = (((-b) - sqrtDisc) / twoA).simplify();
      return deduplicateRoots([r1, r2]);
    }
  } else if (disc is RealNumber && disc.value < 0) {
    final sqrtDiscAbs = RealNumber(math.sqrt(-disc.value));
    final twoA = (IntegerNumber.two * a).simplify();
    final realPart = ((-b) / twoA).simplify();
    final imagPart = (sqrtDiscAbs / twoA).simplify();

    Expr r1;
    Expr r2;
    if (realPart is Number && realPart.isZero) {
      r1 = (imagPart * ComplexNumber.i).simplify();
      r2 = ((-imagPart) * ComplexNumber.i).simplify();
    } else {
      r1 = (realPart + imagPart * ComplexNumber.i).simplify();
      r2 = (realPart - imagPart * ComplexNumber.i).simplify();
    }
    return deduplicateRoots([r1, r2]);
  } else {
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final twoA = (IntegerNumber.two * a).simplify();
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

  final b = coeffs[2] ?? IntegerNumber.zero;
  final c = coeffs[0] ?? IntegerNumber.zero;
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
    return _isZero(expanded) ? {0: IntegerNumber.zero} : {0: expanded};
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
Expr sqrtConstant(RationalNumber c) {
  final numInt = c.numerator.asInt;
  final denInt = c.denominator.asInt;
  if (numInt != null && denInt != null && numInt >= 0) {
    final numSqrt = math.sqrt(numInt).round();
    final denSqrt = math.sqrt(denInt).round();
    if (numSqrt * numSqrt == numInt && denSqrt * denSqrt == denInt) {
      return RationalNumber(numSqrt, denSqrt);
    }
  }
  return Pow(c, FractionNumber.half).simplify();
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
      final posRoot = rootConstant(c.neg(), n);
      return (-posRoot).simplify();
    }
    final numInt = c.numerator.asInt;
    final denInt = c.denominator.asInt;
    if (numInt != null && denInt != null && numInt >= 0) {
      final numR = integerNthRoot(numInt, n);
      final denR = integerNthRoot(denInt, n);
      if (numR != null && denR != null) {
        return RationalNumber(numR, denR);
      }
    }
  } else if (c is RealNumber) {
    if (n.isOdd && c.value < 0) {
      return RealNumber(-math.pow(-c.value, 1.0 / n).toDouble());
    }
  }
  return Pow(c, RationalNumber(1, n)).simplify();
}

bool _isZero(Expr expr) => expr is Number && expr.isZero;
