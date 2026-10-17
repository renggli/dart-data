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
  if ((c.numerator.asInt, c.denominator.asInt)
      case (final int numInt, final int denInt) when numInt >= 0) {
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
  switch (c) {
    case RationalNumber(isNegative: true) when n.isOdd:
      final posRoot = rootConstant(c.neg(), n);
      return (-posRoot).simplify();
    case RationalNumber(:final numerator, :final denominator):
      if ((numerator.asInt, denominator.asInt)
          case (final int numInt, final int denInt) when numInt >= 0) {
        if ((integerNthRoot(numInt, n), integerNthRoot(denInt, n)) case (
          final int numR,
          final int denR,
        )) {
          return RationalNumber(numR, denR);
        }
      }
    case RealNumber(:final value) when n.isOdd && value < 0:
      return RealNumber(-math.pow(-value, 1.0 / n).toDouble());
    case _:
      break;
  }
  return Pow(c, RationalNumber(1, n)).simplify();
}

bool _isZero(Expr expr) => expr is Number && expr.isZero;
