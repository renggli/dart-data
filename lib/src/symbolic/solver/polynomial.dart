import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import 'univariate.dart';

/// Matches quadratic form $a x^2 + b x + c = 0$.
({Expr a, Expr b, Expr c})? matchQuadratic(Expr expr, String variable) {
  // Compute second derivative f''(x)
  final d1 = expr.derivative(variable).simplify();
  final d2 = d1.derivative(variable).simplify();
  if (d2.dependsOn(variable)) {
    return null;
  }

  // a = f''(x) / 2
  final a = (d2 / const RationalNumber(2)).simplify();
  if (a is RationalNumber && a.isZero) {
    return null;
  }

  // b = f'(0)
  final b = d1.substitute(variable, RationalNumber.zero).simplify();
  if (b.dependsOn(variable)) return null;

  // c = f(0)
  final c = expr.substitute(variable, RationalNumber.zero).simplify();
  if (c.dependsOn(variable)) return null;

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
        r1 = (imagPart * ComplexNumber.i).simplify();
        r2 = ((-imagPart) * ComplexNumber.i).simplify();
      } else {
        r1 = (realPart + imagPart * ComplexNumber.i).simplify();
        r2 = (realPart - imagPart * ComplexNumber.i).simplify();
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
      r1 = (imagPart * ComplexNumber.i).simplify();
      r2 = ((-imagPart) * ComplexNumber.i).simplify();
    } else {
      r1 = (realPart + imagPart * ComplexNumber.i).simplify();
      r2 = (realPart - imagPart * ComplexNumber.i).simplify();
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
  final d1 = expr.derivative(variable).simplify();
  final d2 = d1.derivative(variable).simplify();
  final d3 = d2.derivative(variable).simplify();
  final d4 = d3.derivative(variable).simplify();

  if (d4.dependsOn(variable)) return null;

  final a = (d4 / const RationalNumber(24)).simplify();
  if ((a is RationalNumber && a.isZero) ||
      (a is RealNumber && a.value == 0.0) ||
      a.dependsOn(variable)) {
    return null;
  }

  final f30 = d3.substitute(variable, RationalNumber.zero).simplify();
  if (f30 != RationalNumber.zero && !(f30 is RealNumber && f30.value == 0.0)) {
    return null;
  }

  final f10 = d1.substitute(variable, RationalNumber.zero).simplify();
  if (f10 != RationalNumber.zero && !(f10 is RealNumber && f10.value == 0.0)) {
    return null;
  }

  final b =
      (d2.substitute(variable, RationalNumber.zero) / const RationalNumber(2))
          .simplify();
  if (b.dependsOn(variable)) return null;

  final c = expr.substitute(variable, RationalNumber.zero).simplify();
  if (c.dependsOn(variable)) return null;

  final x = Variable(variable);
  final expected =
      ((a * x.pow(const RationalNumber(4))) +
              (b * x.pow(const RationalNumber(2))) +
              c)
          .simplify();
  final diff = (expr.expand() - expected.expand()).simplify();
  if (diff != RationalNumber.zero &&
      !(diff is RealNumber && diff.value == 0.0)) {
    return null;
  }

  return (a: a, b: b, c: c);
}

/// Solves biquadratic equation $a x^4 + b x^2 + c = 0$.
List<Expr> solveBiquadratic(Expr a, Expr b, Expr c, String variable) {
  const uVar = '_u';
  final uEq =
      ((a * const Variable(uVar).pow(const RationalNumber(2))) +
              (b * const Variable(uVar)) +
              c)
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
