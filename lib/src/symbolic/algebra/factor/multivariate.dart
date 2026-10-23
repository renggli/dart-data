import 'dart:math' as math;

import '../../ast.dart';
import '../factor.dart';
import '../simplify/additive.dart';
import '../simplify/multiplicative.dart';
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
  for (final MapEntry(:key, :value) in commonVars.entries) {
    final vExpr = value == 1
        ? Variable(key)
        : Pow(Variable(key), IntegerNumber.of(value));
    factors.add(vExpr);
  }
  return switch (factors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => simplifyMul(factors),
  };
}

/// Collects variable powers and residual non-variable symbolic factors in a product monomial.
void collectVariablePowers(
  Expr expr,
  Map<String, int> target, [
  List<Expr>? residuals,
]) {
  switch (expr) {
    case Number(isOne: true):
      return;
    case Variable(:final name):
      target[name] = (target[name] ?? 0) + 1;
    case Pow(
          base: Variable(:final name),
          exponent: IntegerNumber(asInt: final exp?),
        )
        when exp > 0:
      target[name] = (target[name] ?? 0) + exp;
    case Mul(:final factors):
      for (final factor in factors) {
        collectVariablePowers(factor, target, residuals);
      }
    default:
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
  for (final MapEntry(:key, :value) in powersTerm.entries) {
    final rem = value - (powersGcd[key] ?? 0);
    if (rem > 0) remainingPowers[key] = rem;
  }
  final factors = <Expr>[
    if (!coeff.isOne) coeff,
    for (final MapEntry(:key, :value) in remainingPowers.entries)
      if (value == 1)
        Variable(key)
      else
        Pow(Variable(key), IntegerNumber.of(value)),
    ...residualsTerm,
  ];
  return switch (factors) {
    [] => coeff,
    [final single] => single,
    _ => simplifyMul(factors),
  };
}

/// Factors 4-term expressions by grouping pairwise.
Expr? factorByGrouping4(List<Expr> terms) {
  if (terms case [final a, final b, final c, final d]) {
    final partitions = [((a, b), (c, d)), ((a, c), (b, d)), ((a, d), (b, c))];

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
  }
  return null;
}

/// Matches difference of squares $A^2 - B^2 = (A - B)(A + B)$.
(Expr, Expr)? matchDifferenceOfSquares(List<Expr> terms) {
  if (terms case [final t1, final t2]) {
    final (c1, base1) = decomposeTerm(t1);
    final (c2, base2) = decomposeTerm(t2);
    if (c1 is! RationalNumber || c2 is! RationalNumber) return null;

    if (c1.sign > 0 && c2.sign < 0) {
      if ((monomialSquareRoot(c1, base1), monomialSquareRoot(c2.neg(), base2))
          case (final sq1?, final sq2?)) {
        return (sq1, sq2);
      }
    } else if (c2.sign > 0 && c1.sign < 0) {
      if ((monomialSquareRoot(c2, base2), monomialSquareRoot(c1.neg(), base1))
          case (final sq1?, final sq2?)) {
        return (sq1, sq2);
      }
    }
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
Expr? extractBaseSquareRoot(Expr expr) => switch (expr) {
  Number(isOne: true) => IntegerNumber.one,
  Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
      when exp.isEven =>
    switch (exp ~/ 2) {
      1 => base,
      final half => Pow(base, IntegerNumber.of(half)),
    },
  Mul(:final factors) => () {
    final rootFactors = <Expr>[];
    for (final factor in factors) {
      final r = extractBaseSquareRoot(factor);
      if (r == null) return null;
      rootFactors.add(r);
    }
    return simplifyMul(rootFactors);
  }(),
  _ => null,
};

/// Matches sum or difference of cubes:
/// - $A^3 - B^3 = (A - B)(A^2 + A B + B^2)$
/// - $A^3 + B^3 = (A + B)(A^2 - A B + B^2)$
({Expr a, Expr b, bool isDifference})? matchSumOrDifferenceOfCubes(
  List<Expr> terms,
) {
  if (terms case [final t1, final t2]) {
    final (c1, base1) = decomposeTerm(t1);
    final (c2, base2) = decomposeTerm(t2);
    if (c1 is! RationalNumber || c2 is! RationalNumber) return null;

    if (c1.sign > 0 && c2.sign < 0) {
      if ((monomialCubeRoot(c1, base1), monomialCubeRoot(c2.neg(), base2))
          case (final cb1?, final cb2?)) {
        return (a: cb1, b: cb2, isDifference: true);
      }
    } else if (c2.sign > 0 && c1.sign < 0) {
      if ((monomialCubeRoot(c2, base2), monomialCubeRoot(c1.neg(), base1))
          case (final cb1?, final cb2?)) {
        return (a: cb1, b: cb2, isDifference: true);
      }
    } else if (c1.sign > 0 && c2.sign > 0) {
      if ((monomialCubeRoot(c1, base1), monomialCubeRoot(c2, base2)) case (
        final cb1?,
        final cb2?,
      )) {
        return (a: cb1, b: cb2, isDifference: false);
      }
    }
  }
  return null;
}

/// Computes the cube root of monomial term $coeff \cdot base$.
Expr? monomialCubeRoot(RationalNumber coeff, Expr base) {
  final numInt = coeff.numerator.asInt;
  final denInt = coeff.denominator.asInt;
  if (numInt == null || denInt == null) return null;
  final numCbrt = integerCbrt(numInt);
  final denCbrt = integerCbrt(denInt);
  if (numCbrt == null || denCbrt == null) return null;
  final scalar = RationalNumber(numCbrt, denCbrt);

  final baseCbrt = extractBaseCubeRoot(base);
  if (baseCbrt == null) return null;

  return scalar.isOne ? baseCbrt : simplifyMul([scalar, baseCbrt]);
}

/// Extracts cube root of [expr] if all factors have exponents divisible by 3.
Expr? extractBaseCubeRoot(Expr expr) => switch (expr) {
  Number(isOne: true) => IntegerNumber.one,
  Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
      when exp % 3 == 0 =>
    switch (exp ~/ 3) {
      1 => base,
      final third => Pow(base, IntegerNumber.of(third)),
    },
  Mul(:final factors) => () {
    final rootFactors = <Expr>[];
    for (final factor in factors) {
      final r = extractBaseCubeRoot(factor);
      if (r == null) return null;
      rootFactors.add(r);
    }
    return simplifyMul(rootFactors);
  }(),
  _ => null,
};

/// Computes exact integer cube root of [n] if perfect cube, or `null`.
int? integerCbrt(int n) {
  if (n == 0) return 0;
  final sign = n < 0 ? -1 : 1;
  final r = math.pow(n.abs(), 1.0 / 3.0).round() * sign;
  if (r * r * r == n) return r;
  return null;
}

/// Tests whether [expr] equals scalar $1$.
bool isOne(Expr expr) => expr is Number && expr.isOne;
