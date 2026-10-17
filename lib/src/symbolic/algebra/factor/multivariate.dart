import 'dart:math' as math;

import '../../ast.dart';
import '../factor.dart';
import '../simplify.dart';
import '../term_accumulator.dart';
import 'fraction.dart';
import 'univariate.dart';

/// Recursively flattens additive combinations into signed terms.
void collectAdditiveTerms(Expr expr, int sign, List<Expr> result) {
  MonomialAccumulator.collectTerms(expr, result, sign: sign);
  result.removeWhere((t) => t is Number && t.isZero);
}

/// Extracts common monomial GCD from [terms].
Expr? extractMonomialGcd(List<Expr> terms) {
  if (terms.isEmpty) return null;
  var lcmDen = 1;
  final termCoeffs = <RationalNumber>[];
  final varPowers = <Map<String, int>>[];

  for (final t in terms) {
    final (c, base) = decomposeTerm(t);
    if (c is! RationalNumber) return null;
    final den = c.denominator.asInt;
    if (den == null) return null;
    lcmDen = lcm(lcmDen, den);
    termCoeffs.add(c);
    final powers = <String, int>{};
    collectVariablePowers(base, powers);
    varPowers.add(powers);
  }

  var content = 0;
  for (final c in termCoeffs) {
    final num = c.numerator.asInt;
    final den = c.denominator.asInt;
    if (num == null || den == null) return null;
    final intVal = (num * (lcmDen ~/ den)).abs();
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

  final scalarGcd = RationalNumber(content, lcmDen);
  if (scalarGcd.isOne && commonVars.isEmpty) return null;

  final factors = <Expr>[];
  if (!scalarGcd.isOne) {
    factors.add(scalarGcd);
  }
  for (final e in commonVars.entries) {
    final vExpr = e.value == 1
        ? Variable(e.key)
        : Pow(Variable(e.key), IntegerNumber.of(e.value));
    factors.add(vExpr);
  }
  if (factors.isEmpty) return IntegerNumber.one;
  if (factors.length == 1) return factors.first;
  return simplifyMul(factors);
}

/// Collects variable powers and residual non-variable symbolic factors in a product monomial.
void collectVariablePowers(
  Expr expr,
  Map<String, int> target, [
  List<Expr>? residuals,
]) {
  if (expr is Number && expr.isOne) {
    return;
  } else if (expr is Variable) {
    target[expr.name] = (target[expr.name] ?? 0) + 1;
  } else if (expr is Pow &&
      expr.base is Variable &&
      expr.exponent is IntegerNumber) {
    final exp = (expr.exponent as IntegerNumber).asInt;
    if (exp != null && exp > 0) {
      final v = expr.base as Variable;
      target[v.name] = (target[v.name] ?? 0) + exp;
    } else {
      residuals?.add(expr);
    }
  } else if (expr is Mul) {
    for (final factor in expr.factors) {
      collectVariablePowers(factor, target, residuals);
    }
  } else {
    residuals?.add(expr);
  }
}

/// Divides monomial [term] by monomial divisor [gcd].
Expr divideMonomial(Expr term, Expr gcd) {
  final (cTerm, bTerm) = decomposeTerm(term);
  final (cGcd, bGcd) = decomposeTerm(gcd);
  final coeff = cTerm.div(cGcd);
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
  final factors = <Expr>[];
  if (!coeff.isOne) {
    factors.add(coeff);
  }
  for (final entry in remainingPowers.entries) {
    final factor = entry.value == 1
        ? Variable(entry.key)
        : Pow(Variable(entry.key), IntegerNumber.of(entry.value));
    factors.add(factor);
  }
  factors.addAll(residualsTerm);
  if (factors.isEmpty) return coeff;
  if (factors.length == 1) return factors.first;
  return simplifyMul(factors);
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
    final g1 = extractMonomialGcd([t1, t2]) ?? IntegerNumber.one;
    final g2 = extractMonomialGcd([t3, t4]) ?? IntegerNumber.one;

    final r1 = simplifyAdd([divideMonomial(t1, g1), divideMonomial(t2, g1)]);
    final r2 = simplifyAdd([divideMonomial(t3, g2), divideMonomial(t4, g2)]);

    if (r1 == r2) {
      final factorA = factorExpr(simplifyAdd([g1, g2]));
      final factorB = factorExpr(r1);
      return combineFactoredProducts([factorA, factorB]);
    }
    if (r1 == simplifyNeg(r2)) {
      final factorA = factorExpr(simplifySub(g1, g2));
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
  if (c1 is! RationalNumber || c2 is! RationalNumber) return null;

  if (c1.sign > 0 && c2.sign < 0) {
    final sq1 = monomialSquareRoot(c1, base1);
    final sq2 = monomialSquareRoot(c2.neg(), base2);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  } else if (c2.sign > 0 && c1.sign < 0) {
    final sq1 = monomialSquareRoot(c2, base2);
    final sq2 = monomialSquareRoot(c1.neg(), base1);
    if (sq1 != null && sq2 != null) return (sq1, sq2);
  }
  return null;
}

/// Computes the square root of monomial term $coeff \cdot base$.
Expr? monomialSquareRoot(RationalNumber coeff, Expr base) {
  final numInt = coeff.numerator.asInt;
  final denInt = coeff.denominator.asInt;
  if (numInt == null || denInt == null) return null;
  final numSqrt = integerSqrt(numInt);
  final denSqrt = integerSqrt(denInt);
  if (numSqrt == null || denSqrt == null) return null;
  final scalar = RationalNumber(numSqrt, denSqrt);

  final baseSqrt = extractBaseSquareRoot(base);
  if (baseSqrt == null) return null;

  return scalar.isOne ? baseSqrt : simplifyMul([scalar, baseSqrt]);
}

/// Extracts square root of [expr] if all factors have even exponents.
Expr? extractBaseSquareRoot(Expr expr) {
  if (expr is Number && expr.isOne) return IntegerNumber.one;
  if (expr is Pow && expr.exponent is IntegerNumber) {
    final exp = (expr.exponent as IntegerNumber).asInt;
    if (exp != null && exp % 2 == 0) {
      final half = exp ~/ 2;
      return half == 1 ? expr.base : Pow(expr.base, IntegerNumber.of(half));
    }
  }
  if (expr is Mul) {
    final rootFactors = <Expr>[];
    for (final factor in expr.factors) {
      final r = extractBaseSquareRoot(factor);
      if (r == null) return null;
      rootFactors.add(r);
    }
    return simplifyMul(rootFactors);
  }
  if (expr is Variable) {
    return null;
  }
  return null;
}

/// Tests whether [expr] equals scalar $1$.
bool isOne(Expr expr) => expr is Number && expr.isOne;
