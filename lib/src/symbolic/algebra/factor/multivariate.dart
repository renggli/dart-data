import 'dart:math' as math;

import 'package:more/math.dart';

import '../../assumptions.dart';
import '../../ast.dart';
import '../../poly/factor.dart';
import '../expand.dart';
import '../factor.dart';
import '../helpers.dart';
import '../simplify.dart';
import '../simplify/additive.dart';
import '../simplify/multiplicative.dart';
import '../term_accumulator.dart';
import 'fraction.dart';

/// Recursively flattens additive combinations into signed terms.
void collectAdditiveTerms(Expr expr, int sign, List<Expr> result) {
  MonomialAccumulator.collectTerms(expr, result, sign: sign);
  result.removeWhere((t) => t is Number && t.isZero);
}

/// Extracts common monomial GCD from [terms].
Expr? extractMonomialGcd(List<Expr> terms) {
  if (terms.isEmpty) return null;
  var lcmDen = BigInt.one;
  final termCoeffs = <RationalNumber>[];
  final factorPowers = <Map<Expr, int>>[];

  for (final t in terms) {
    final (c, base) = decomposeTerm(t);
    if (c is! RationalNumber) return null;
    lcmDen = lcmDen.lcm(c.denominator);
    termCoeffs.add(c);
    final powers = <Expr, int>{};
    _collectFactorPowers(base, powers);
    factorPowers.add(powers);
  }

  var content = BigInt.zero;
  for (final c in termCoeffs) {
    final intVal = (c.numerator * (lcmDen ~/ c.denominator)).abs();
    if (intVal != BigInt.zero) content = content.gcd(intVal);
  }
  if (content == BigInt.zero) content = BigInt.one;

  final commonFactors = <Expr, int>{};
  for (final f in factorPowers.first.keys) {
    var minP = factorPowers.first[f]!;
    var presentInAll = true;
    for (var i = 1; i < factorPowers.length; i++) {
      final p = factorPowers[i][f] ?? 0;
      if (p == 0) {
        presentInAll = false;
        break;
      }
      minP = math.min(minP, p);
    }
    if (presentInAll && minP > 0) {
      commonFactors[f] = minP;
    }
  }

  final scalarGcd = RationalNumber.of(content, lcmDen);
  if (scalarGcd.isOne && commonFactors.isEmpty) return null;

  final factors = <Expr>[];
  if (!scalarGcd.isOne) {
    factors.add(scalarGcd);
  }
  for (final MapEntry(:key, :value) in commonFactors.entries) {
    final fExpr = value == 1 ? key : Pow.of(key, IntegerNumber.of(value));
    factors.add(fExpr);
  }
  return switch (factors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => simplifyMul(factors, assumptions: Assumptions.none),
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
  final powersTerm = <Expr, int>{};
  _collectFactorPowers(bTerm, powersTerm);
  final powersGcd = <Expr, int>{};
  _collectFactorPowers(bGcd, powersGcd);
  final remainingPowers = <Expr, int>{};
  for (final MapEntry(:key, :value) in powersTerm.entries) {
    final rem = value - (powersGcd[key] ?? 0);
    if (rem > 0) remainingPowers[key] = rem;
  }
  final factors = <Expr>[
    if (!coeff.isOne) coeff,
    for (final MapEntry(:key, :value) in remainingPowers.entries)
      if (value == 1) key else Pow.of(key, IntegerNumber.of(value)),
  ];
  return switch (factors) {
    [] => coeff,
    [final single] => single,
    _ => simplifyMul(factors, assumptions: Assumptions.none),
  };
}

/// Factors 4-term expressions by grouping pairwise.
Expr? factorByGrouping4(List<Expr> terms, {required Assumptions assumptions}) {
  if (terms case [final a, final b, final c, final d]) {
    final partitions = [((a, b), (c, d)), ((a, c), (b, d)), ((a, d), (b, c))];

    for (final ((t1, t2), (t3, t4)) in partitions) {
      final g1 = extractMonomialGcd([t1, t2]) ?? IntegerNumber.one;
      final g2 = extractMonomialGcd([t3, t4]) ?? IntegerNumber.one;

      final r1 = simplifyAdd([
        divideMonomial(t1, g1),
        divideMonomial(t2, g1),
      ], assumptions: assumptions);
      final r2 = simplifyAdd([
        divideMonomial(t3, g2),
        divideMonomial(t4, g2),
      ], assumptions: assumptions);

      if (r1 == r2) {
        final factorA = factorExpr(
          simplifyAdd([g1, g2], assumptions: assumptions),
          assumptions: assumptions,
        );
        final factorB = factorExpr(r1, assumptions: assumptions);
        return combineFactoredProducts([factorA, factorB]);
      }
      if (r1 == simplifyNeg(r2, assumptions: assumptions)) {
        final factorA = factorExpr(
          simplifySub(g1, g2, assumptions: assumptions),
          assumptions: assumptions,
        );
        final factorB = factorExpr(r1, assumptions: assumptions);
        return combineFactoredProducts([factorA, factorB]);
      }
    }
  }
  return null;
}

/// Matches difference of squares `A^2 - B^2 = (A - B)(A + B)`.
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

/// Computes the square root of monomial term `coeff * base`.
Expr? monomialSquareRoot(RationalNumber coeff, Expr base) {
  final numSqrt = Number.exactIntegerRoot(coeff.numerator, 2);
  final denSqrt = Number.exactIntegerRoot(coeff.denominator, 2);
  if (numSqrt == null || denSqrt == null) return null;
  final scalar = RationalNumber.of(numSqrt, denSqrt);

  final baseSqrt = extractBaseSquareRoot(base);
  if (baseSqrt == null) return null;

  return scalar.isOne
      ? baseSqrt
      : simplifyMul([scalar, baseSqrt], assumptions: Assumptions.none);
}

/// Extracts square root of [expr] if all factors have even exponents.
Expr? extractBaseSquareRoot(Expr expr) => switch (expr) {
  Number(isOne: true) => IntegerNumber.one,
  Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
      when exp.isEven =>
    switch (exp ~/ 2) {
      1 => base,
      final half => Pow.of(base, IntegerNumber.of(half)),
    },
  Mul(:final factors) => () {
    final rootFactors = <Expr>[];
    for (final factor in factors) {
      final r = extractBaseSquareRoot(factor);
      if (r == null) return null;
      rootFactors.add(r);
    }
    return simplifyMul(rootFactors, assumptions: Assumptions.none);
  }(),
  _ => null,
};

/// Matches sum or difference of cubes:
/// - `A^3 - B^3 = (A - B)(A^2 + A B + B^2)`
/// - `A^3 + B^3 = (A + B)(A^2 - A B + B^2)`
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
    } else if (c1.sign < 0 && c2.sign < 0) {
      if ((monomialCubeRoot(c1.neg(), base1), monomialCubeRoot(c2.neg(), base2))
          case (final cb1?, final cb2?)) {
        return (a: -cb1, b: cb2, isDifference: true);
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

/// Computes the cube root of monomial term `coeff * base`.
Expr? monomialCubeRoot(RationalNumber coeff, Expr base) {
  final numCbrt = integerCbrt(coeff.numerator);
  final denCbrt = integerCbrt(coeff.denominator);
  if (numCbrt == null || denCbrt == null) return null;
  final scalar = RationalNumber.of(numCbrt, denCbrt);

  final baseCbrt = extractBaseCubeRoot(base);
  if (baseCbrt == null) return null;

  return scalar.isOne
      ? baseCbrt
      : simplifyMul([scalar, baseCbrt], assumptions: Assumptions.none);
}

/// Extracts cube root of [expr] if all factors have exponents divisible by 3.
Expr? extractBaseCubeRoot(Expr expr) => switch (expr) {
  Number(isOne: true) => IntegerNumber.one,
  Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
      when exp % 3 == 0 =>
    switch (exp ~/ 3) {
      1 => base,
      final third => Pow.of(base, IntegerNumber.of(third)),
    },
  Mul(:final factors) => () {
    final rootFactors = <Expr>[];
    for (final factor in factors) {
      final r = extractBaseCubeRoot(factor);
      if (r == null) return null;
      rootFactors.add(r);
    }
    return simplifyMul(rootFactors, assumptions: Assumptions.none);
  }(),
  _ => null,
};

/// Tests whether [expr] equals scalar `1`.
bool isOne(Expr expr) => expr is Number && expr.isOne;

void _collectFactorPowers(Expr expr, Map<Expr, int> target) {
  switch (expr) {
    case Number(isOne: true):
      return;
    case Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
        when exp > 0:
      target[base] = (target[base] ?? 0) + exp;
    case Mul(:final factors):
      for (final factor in factors) {
        _collectFactorPowers(factor, target);
      }
    default:
      target[expr] = (target[expr] ?? 0) + 1;
  }
}

/// Attempts general multivariate polynomial factorization when specialized
/// grouping/binomial patterns do not apply.
Expr? factorMultivariatePolynomial(
  Expr expanded,
  List<String> vars, {
  required Assumptions assumptions,
}) {
  if (vars.length < 2) return null;

  // Choose main variable with lowest positive polynomial degree.
  String? mainVar;
  var minDeg = 1 << 30;
  final sortedVars = [...vars]..sort();
  for (final v in sortedVars) {
    final deg = polynomialDegree(expanded, v);
    if (deg != null && deg >= 1 && deg < minDeg) {
      minDeg = deg;
      mainVar = v;
    }
  }
  if (mainVar == null) return null;

  final coeffs = extractPolynomialCoefficients(expanded, mainVar);
  if (coeffs == null) return null;
  final d = maxPolynomialDegree(coeffs);
  if (d < 1) return null;

  if (d == 1) {
    return _factorLinearInVar(coeffs, mainVar, assumptions: assumptions);
  }

  if (d == 2) {
    return _factorQuadraticInVar(coeffs, mainVar, assumptions: assumptions);
  }

  if (vars.length == 2) {
    return _factorHomogeneousBivariate(
      expanded,
      sortedVars[0],
      sortedVars[1],
      assumptions: assumptions,
    );
  }

  return null;
}

Expr? _factorLinearInVar(
  Map<int, Expr> coeffs,
  String variable, {
  required Assumptions assumptions,
}) {
  final c1 = coeffs[1] ?? IntegerNumber.zero;
  final c0 = coeffs[0] ?? IntegerNumber.zero;

  final f1 = factorExpr(c1, assumptions: assumptions);
  final f0 = factorExpr(c0, assumptions: assumptions);

  final m1 = <Expr, int>{};
  RationalNumber s1 = IntegerNumber.one;
  flattenFactored(f1, m1, (s) => s1 = s1.mulRational(s));

  final m0 = <Expr, int>{};
  RationalNumber s0 = IntegerNumber.one;
  flattenFactored(f0, m0, (s) => s0 = s0.mulRational(s));

  final commonFactors = <Expr>[];
  for (final entry in m1.entries) {
    final otherExp = m0[entry.key];
    if (otherExp != null) {
      final minExp = math.min(entry.value, otherExp);
      if (minExp > 0) {
        commonFactors.add(
          minExp == 1 ? entry.key : Pow.of(entry.key, IntegerNumber.of(minExp)),
        );
      }
    }
  }

  // Extract common integer scalar GCD if both are integers.
  RationalNumber commonScalar = IntegerNumber.one;
  if ((s1, s0) case (
    IntegerNumber(value: final v1),
    IntegerNumber(value: final v0),
  )) {
    final g = v1.abs().gcd(v0.abs());
    if (g > BigInt.one) {
      commonScalar = IntegerNumber(g);
    }
  }
  if (s1.isNegative && s0.isNegative) {
    commonScalar = commonScalar.neg();
  }

  if (commonFactors.isEmpty && commonScalar.isOne) {
    return null;
  }

  final g = simplifyMul([
    if (!commonScalar.isOne) commonScalar,
    ...commonFactors,
  ], assumptions: assumptions);

  final q1 = cancelFactoredFraction(f1, g);
  final q0 = cancelFactoredFraction(f0, g);
  if (q1 == Constant.undefined || q0 == Constant.undefined) return null;

  final inner = simplifyAdd([
    simplifyMul([q1, Variable(variable)], assumptions: assumptions),
    q0,
  ], assumptions: assumptions);

  return combineFactoredProducts([g, inner]);
}

Expr? _factorQuadraticInVar(
  Map<int, Expr> coeffs,
  String variable, {
  required Assumptions assumptions,
}) {
  final a = coeffs[2] ?? IntegerNumber.zero;
  final b = coeffs[1] ?? IntegerNumber.zero;
  final c = coeffs[0] ?? IntegerNumber.zero;

  final delta = (b * b - IntegerNumber.of(4) * a * c)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);

  Expr? sqrtDelta;
  if (delta is Number && delta.isZero) {
    sqrtDelta = IntegerNumber.zero;
  } else {
    final factoredDelta = factorExpr(delta, assumptions: assumptions);
    final dFactors = <Expr, int>{};
    RationalNumber dScalar = IntegerNumber.one;
    flattenFactored(
      factoredDelta,
      dFactors,
      (s) => dScalar = dScalar.mulRational(s),
    );

    if (dScalar.sign <= 0) return null;
    final numSqrt = Number.exactIntegerRoot(dScalar.numerator, 2);
    final denSqrt = Number.exactIntegerRoot(dScalar.denominator, 2);
    if (numSqrt == null || denSqrt == null) return null;
    if (dFactors.values.any((e) => e.isOdd)) return null;

    final scalarSqrt = RationalNumber.of(numSqrt, denSqrt);
    sqrtDelta = simplifyMul([
      if (!scalarSqrt.isOne) scalarSqrt,
      for (final entry in dFactors.entries)
        if (entry.value > 0)
          if (entry.value == 2)
            entry.key
          else
            Pow.of(entry.key, IntegerNumber.of(entry.value ~/ 2)),
    ], assumptions: assumptions);
  }

  final twoA = (IntegerNumber.two * a)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final x = Variable(variable);
  final f1Raw = (twoA * x + b - sqrtDelta)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final f2Raw = (twoA * x + b + sqrtDelta)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);

  final f1 = factorExpr(f1Raw, assumptions: assumptions);
  final f2 = factorExpr(f2Raw, assumptions: assumptions);
  final prod = combineFactoredProducts([f1, f2]);
  final fourA = combineFactoredProducts([
    IntegerNumber.of(4),
    factorExpr(a, assumptions: assumptions),
  ]);
  final result = cancelFactoredFraction(prod, fourA);
  if (result == Constant.undefined || _hasNegativePowerFactor(result)) {
    return null;
  }
  return result;
}

bool _hasNegativePowerFactor(Expr expr) => switch (expr) {
  Pow(exponent: RealNumeric(isNegative: true)) => true,
  Mul(:final factors) => factors.any(_hasNegativePowerFactor),
  _ => false,
};

Expr? _factorHomogeneousBivariate(
  Expr expanded,
  String xVar,
  String yVar, {
  required Assumptions assumptions,
}) {
  final terms = <Expr>[];
  collectAdditiveTerms(expanded, 1, terms);
  if (terms.length < 2) return null;

  int? totalDeg;
  for (final t in terms) {
    final powers = <String, int>{};
    final residuals = <Expr>[];
    final (_, base) = decomposeTerm(t);
    collectVariablePowers(base, powers, residuals);
    if (residuals.isNotEmpty) return null;
    final deg = (powers[xVar] ?? 0) + (powers[yVar] ?? 0);
    if (totalDeg == null) {
      totalDeg = deg;
    } else if (deg != totalDeg) {
      return null;
    }
  }
  if (totalDeg == null || totalDeg < 3) return null;

  final uni = expanded
      .substitute(yVar, IntegerNumber.one)
      .expand(assumptions: assumptions)
      .simplify(assumptions: assumptions);
  final factoredUni = factorExpr(uni, assumptions: assumptions);

  final uFactors = <Expr, int>{};
  RationalNumber uScalar = IntegerNumber.one;
  flattenFactored(
    factoredUni,
    uFactors,
    (s) => uScalar = uScalar.mulRational(s),
  );

  if (uFactors.isEmpty) return null;
  if (uFactors.length == 1 && uFactors.values.first == 1) return null;

  final homogenizedParts = <Expr>[if (!uScalar.isOne) uScalar];
  for (final MapEntry(key: factor, value: mult) in uFactors.entries) {
    final fDeg = polynomialDegree(factor, xVar);
    if (fDeg == null) return null;
    final fTerms = <Expr>[];
    collectAdditiveTerms(factor, 1, fTerms);
    final hTerms = <Expr>[];
    for (final ft in fTerms) {
      final degX = polynomialDegree(ft, xVar) ?? 0;
      final remY = fDeg - degX;
      if (remY > 0) {
        final yPow = remY == 1
            ? Variable(yVar)
            : Pow.of(Variable(yVar), IntegerNumber.of(remY));
        hTerms.add(simplifyMul([ft, yPow], assumptions: assumptions));
      } else {
        hTerms.add(ft);
      }
    }
    final hFactor = simplifyAdd(hTerms, assumptions: assumptions);
    homogenizedParts.add(
      mult == 1 ? hFactor : Pow.of(hFactor, IntegerNumber.of(mult)),
    );
  }

  final candidate = combineFactoredProducts(homogenizedParts);
  final checkDiff = (candidate.expand(assumptions: assumptions) - expanded)
      .simplify(assumptions: assumptions);
  if (checkDiff != IntegerNumber.zero) return null;
  return candidate;
}
