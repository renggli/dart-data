import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../factor.dart';
import '../simplify.dart';
import '../term_accumulator.dart';
import 'fraction.dart';
import 'univariate.dart';

/// Recursively flattens additive combinations into signed terms.
void collectAdditiveTerms(Expr expr, int sign, List<Expr> result) {
  MonomialAccumulator.collectTerms(expr, result, sign: sign);
  result.removeWhere((t) => t is RationalNumber && t.isZero);
}

/// Extracts common monomial GCD from [terms].
Expr? extractMonomialGcd(List<Expr> terms) {
  if (terms.isEmpty) return null;
  var lcmDen = 1;
  final termCoeffs = <Fraction>[];
  final varPowers = <Map<String, int>>[];

  for (final t in terms) {
    final (c, base) = decomposeTerm(t);
    lcmDen = lcm(lcmDen, c.b);
    termCoeffs.add(c);
    final powers = <String, int>{};
    collectVariablePowers(base, powers);
    varPowers.add(powers);
  }

  var content = 0;
  for (final c in termCoeffs) {
    final intVal = (c.a * (lcmDen ~/ c.b)).abs();
    if (intVal != 0) content = gcd(content, intVal);
  }
  if (content == 0) content = 1;

  final commonVars = <String, int>{};
  for (final v in varPowers.first.keys) {
    var minP = varPowers.first[v]!;
    var presentInAll = true;
    for (var i = 1; i < varPowers.length; i++) {
      final p = varPowers[i][v] ?? 0;
      if (p == 0) {
        presentInAll = false;
        break;
      }
      minP = math.min(minP, p);
    }
    if (presentInAll && minP > 0) {
      commonVars[v] = minP;
    }
  }

  final scalarGcd = Fraction(content, lcmDen);
  if (scalarGcd == Fraction.one && commonVars.isEmpty) return null;

  Expr result = RationalNumber.fraction(scalarGcd);
  for (final e in commonVars.entries) {
    final vExpr = e.value == 1
        ? Variable(e.key)
        : Pow(Variable(e.key), RationalNumber(e.value));
    result = result is RationalNumber && result.isOne
        ? vExpr
        : Mul(result, vExpr);
  }
  return result.simplify();
}

/// Collects variable powers and residual non-variable symbolic factors in a product monomial.
void collectVariablePowers(
  Expr expr,
  Map<String, int> target, [
  List<Expr>? residuals,
]) {
  if (expr is RationalNumber && expr.isOne) {
    return;
  } else if (expr is Variable) {
    target[expr.name] = (target[expr.name] ?? 0) + 1;
  } else if (expr is Pow &&
      expr.base is Variable &&
      expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      final v = expr.base as Variable;
      target[v.name] = (target[v.name] ?? 0) + exp.numerator;
    } else {
      residuals?.add(expr);
    }
  } else if (expr is Mul) {
    collectVariablePowers(expr.left, target, residuals);
    collectVariablePowers(expr.right, target, residuals);
  } else {
    residuals?.add(expr);
  }
}

/// Divides monomial [term] by monomial divisor [gcd].
Expr divideMonomial(Expr term, Expr gcd) {
  final (cTerm, bTerm) = decomposeTerm(term);
  final (cGcd, bGcd) = decomposeTerm(gcd);
  final coeff = cTerm / cGcd;
  final powersTerm = <String, int>{};
  final residualsTerm = <Expr>[];
  collectVariablePowers(bTerm, powersTerm, residualsTerm);
  final powersGcd = <String, int>{};
  final residualsGcd = <Expr>[];
  collectVariablePowers(bGcd, powersGcd, residualsGcd);
  for (final r in residualsGcd) {
    residualsTerm.remove(r);
  }
  final remainingPowers = <String, int>{};
  for (final entry in powersTerm.entries) {
    final rem = entry.value - (powersGcd[entry.key] ?? 0);
    if (rem > 0) remainingPowers[entry.key] = rem;
  }
  Expr result = RationalNumber.fraction(coeff);
  for (final entry in remainingPowers.entries) {
    final factor = entry.value == 1
        ? Variable(entry.key)
        : Pow(Variable(entry.key), RationalNumber(entry.value));
    if (result is RationalNumber && result.isOne) {
      result = factor;
    } else if (result is RationalNumber && result.isNegativeOne) {
      result = Neg(factor);
    } else {
      result = Mul(result, factor);
    }
  }
  for (final r in residualsTerm) {
    if (result is RationalNumber && result.isOne) {
      result = r;
    } else if (result is RationalNumber && result.isNegativeOne) {
      result = Neg(r);
    } else {
      result = Mul(result, r);
    }
  }
  return result.simplify();
}

/// Factors 4-term expressions by grouping pairwise.
Expr? factorByGrouping4(List<Expr> terms) {
  if (terms.length != 4) return null;

  final partitions = [
    ((terms[0], terms[1]), (terms[2], terms[3])),
    ((terms[0], terms[2]), (terms[1], terms[3])),
    ((terms[0], terms[3]), (terms[1], terms[2])),
  ];

  for (final ((t1, t2), (t3, t4)) in partitions) {
    final g1 = extractMonomialGcd([t1, t2]) ?? RationalNumber.one;
    final g2 = extractMonomialGcd([t3, t4]) ?? RationalNumber.one;

    final r1 = Add(divideMonomial(t1, g1), divideMonomial(t2, g1)).simplify();
    final r2 = Add(divideMonomial(t3, g2), divideMonomial(t4, g2)).simplify();

    if (r1 == r2) {
      final factorA = factorExpr((g1 + g2).simplify());
      final factorB = factorExpr(r1);
      return combineFactoredProducts([factorA, factorB]);
    }
    if (r1 == (-r2).simplify()) {
      final factorA = factorExpr((g1 - g2).simplify());
      final factorB = factorExpr(r1);
      return combineFactoredProducts([factorA, factorB]);
    }
  }
  return null;
}

/// Matches difference of squares $A^2 - B^2 = (A - B)(A + B)$.
(Expr, Expr)? matchDifferenceOfSquares(List<Expr> terms) {
  if (terms.length != 2) return null;
  final t1 = terms[0];
  final t2 = terms[1];

  final (c1, base1) = decomposeTerm(t1);
  final (c2, base2) = decomposeTerm(t2);

  if (c1.a > 0 && c2.a < 0) {
    final sq1 = monomialSquareRoot(c1, base1);
    final sq2 = monomialSquareRoot(-c2, base2);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  } else if (c2.a > 0 && c1.a < 0) {
    final sq1 = monomialSquareRoot(c2, base2);
    final sq2 = monomialSquareRoot(-c1, base1);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  }
  return null;
}

/// Computes the square root of monomial term $coeff \cdot base$.
Expr? monomialSquareRoot(Fraction coeff, Expr base) {
  final numSqrt = integerSqrt(coeff.a);
  final denSqrt = integerSqrt(coeff.b);
  if (numSqrt == null || denSqrt == null) return null;
  final scalar = RationalNumber(numSqrt, denSqrt);

  final baseSqrt = extractBaseSquareRoot(base);
  if (baseSqrt == null) return null;

  return scalar.isOne ? baseSqrt : Mul(scalar, baseSqrt).simplify();
}

/// Extracts square root of [expr] if all factors have even exponents.
Expr? extractBaseSquareRoot(Expr expr) {
  if (expr is RationalNumber && expr.isOne) return RationalNumber.one;
  if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator % 2 == 0) {
      final half = exp.numerator ~/ 2;
      return half == 1 ? expr.base : Pow(expr.base, RationalNumber(half));
    }
  }
  if (expr is Mul) {
    final l = extractBaseSquareRoot(expr.left);
    final r = extractBaseSquareRoot(expr.right);
    if (l != null && r != null) return Mul(l, r).simplify();
  }
  if (expr is Variable) {
    return null;
  }
  return null;
}

/// Tests whether [expr] equals scalar $1$.
bool isOne(Expr expr) =>
    (expr is RationalNumber && expr.isOne) ||
    (expr is RealNumber && expr.value == 1.0);
