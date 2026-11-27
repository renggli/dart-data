import 'dart:math' as math;

import 'package:more/math.dart';

import '../../assumptions.dart';
import '../../ast.dart';
import '../simplify/additive.dart';
import '../simplify/multiplicative.dart';
import '../term_accumulator.dart';
import 'fraction.dart';
import 'multivariate.dart';

/// Polynomial over `Q[x]` represented as a list of rational coefficients.
class PolyQ {
  /// Creates a polynomial with [coeffs] where `coeffs[k]` is coefficient of `x^k`.
  new(this.coeffs);

  /// List of rational coefficients in ascending order of degree.
  final List<RationalNumber> coeffs;

  /// Degree of the polynomial (`n = coeffs.length - 1`).
  int get degree => coeffs.length - 1;
}

/// Extracts univariate rational polynomial coefficients for [variable] from [expr].
PolyQ? extractPoly(Expr expr, String variable) {
  final terms = <Expr>[];
  collectAdditiveTerms(expr, 1, terms);

  final coeffMap = <int, RationalNumber>{};
  for (final term in terms) {
    final (c, base) = decomposeTerm(term);
    if (c is! RationalNumber) return null;

    switch (base) {
      case final RationalNumber r:
        final prod = c.mulRational(r);
        coeffMap[0] = (coeffMap[0] ?? IntegerNumber.zero).addRational(prod);
      case Variable(:final name) when name == variable:
        coeffMap[1] = (coeffMap[1] ?? IntegerNumber.zero).addRational(c);
      case Pow(
            base: Variable(:final name),
            exponent: RationalNumber(asInt: final k?),
          )
          when name == variable && k >= 0:
        coeffMap[k] = (coeffMap[k] ?? IntegerNumber.zero).addRational(c);
      default:
        return null;
    }
  }

  coeffMap.removeWhere((_, v) => v.isZero);
  if (coeffMap.isEmpty) {
    return PolyQ([IntegerNumber.zero]);
  }
  final maxDeg = coeffMap.keys.reduce(math.max);
  final dense = List<RationalNumber>.generate(
    maxDeg + 1,
    (i) => coeffMap[i] ?? IntegerNumber.zero,
  );
  return PolyQ(dense);
}

/// Factors univariate rational polynomial [poly] in [variable].
Expr factorUnivariatePoly(PolyQ poly, String variable) {
  if (poly.degree <= 0) {
    return poly.coeffs.first;
  }

  // 1. Clear denominators
  var lcmDen = BigInt.one;
  for (final c in poly.coeffs) {
    lcmDen = lcmDen.lcm(c.denominator);
  }

  final intCoeffs = <BigInt>[];
  for (final c in poly.coeffs) {
    intCoeffs.add(c.numerator * (lcmDen ~/ c.denominator));
  }

  // 2. Extract content GCD
  var content = BigInt.zero;
  for (final a in intCoeffs) {
    if (a != BigInt.zero) content = content.gcd(a);
  }
  if (content == BigInt.zero) content = BigInt.one;

  final lead = intCoeffs[poly.degree];
  final sign = lead.isNegative ? -BigInt.one : BigInt.one;

  var primitiveCoeffs = intCoeffs.map((a) => (a * sign) ~/ content).toList();

  var scalar = RationalNumber.of(content * sign, lcmDen);
  final factors = <Expr, int>{};

  // 3. Zero roots: factor out x^m
  var m = 0;
  while (m < primitiveCoeffs.length && primitiveCoeffs[m] == BigInt.zero) {
    m++;
  }
  if (m > 0) {
    factors[Variable(variable)] = m;
    primitiveCoeffs = primitiveCoeffs.sublist(m);
  }

  var currentDeg = primitiveCoeffs.length - 1;
  if (currentDeg == 0) {
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  if (currentDeg == 1) {
    if (factors.isEmpty && content == BigInt.one && lcmDen == BigInt.one) {
      return buildPolyExpr(intCoeffs, variable);
    }
    final linFactor = buildLinearFactor(
      primitiveCoeffs[1],
      -primitiveCoeffs[0],
      variable,
    );
    factors[linFactor] = (factors[linFactor] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 4. Degree >= 2: Rational Root Theorem search
  if (currentDeg >= 3 &&
      primitiveCoeffs[0].bitLength <= 36 &&
      primitiveCoeffs.last.bitLength <= 36) {
    final a0 = primitiveCoeffs[0];
    final ad = primitiveCoeffs.last;
    final pDivs = divisors(a0);
    final qDivs = divisors(ad);

    // Candidates (p, q) where root is p / q
    final candidates = <(BigInt, BigInt)>[];
    outer:
    for (final q in qDivs) {
      for (final pAbs in pDivs) {
        for (final p in [pAbs, -pAbs]) {
          if (p.abs().gcd(q) == BigInt.one) {
            candidates.add((p, q));
            if (candidates.length >= 512) break outer;
          }
        }
      }
    }

    candidates.sort((c1, c2) {
      final (p1, q1) = c1;
      final (p2, q2) = c2;
      final v1 = (p1.toDouble() / q1.toDouble()).abs();
      final v2 = (p2.toDouble() / q2.toDouble()).abs();
      return v1.compareTo(v2);
    });

    for (final (p, q) in candidates) {
      while (currentDeg >= 3) {
        final quotient = syntheticDivide(primitiveCoeffs, p, q);
        if (quotient != null) {
          final lin = buildLinearFactor(q, p, variable);
          factors[lin] = (factors[lin] ?? 0) + 1;
          primitiveCoeffs = quotient;
          currentDeg = primitiveCoeffs.length - 1;
        } else {
          break;
        }
      }
      if (currentDeg < 3) break;
    }
  }

  // 5. Quadratic resolution
  if (currentDeg == 2) {
    final a = primitiveCoeffs[2];
    final b = primitiveCoeffs[1];
    final c = primitiveCoeffs[0];
    final disc = b * b - BigInt.from(4) * a * c;

    if (!disc.isNegative) {
      final s = Number.exactIntegerRoot(disc, 2);
      if (s != null) {
        final twoA = a * BigInt.two;
        final r1 = RationalNumber.of(-b + s, twoA);
        final r2 = RationalNumber.of(-b - s, twoA);
        final f1 = buildLinearFactor(r1.denominator, r1.numerator, variable);
        final f2 = buildLinearFactor(r2.denominator, r2.numerator, variable);
        factors[f1] = (factors[f1] ?? 0) + 1;
        factors[f2] = (factors[f2] ?? 0) + 1;
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }
    // Irreducible quadratic
    if (factors.isEmpty && content == BigInt.one && lcmDen == BigInt.one) {
      return buildPolyExpr(intCoeffs, variable);
    }
    final quadExpr = buildPolyExpr(primitiveCoeffs, variable);
    factors[quadExpr] = (factors[quadExpr] ?? 0) + 1;
    return buildFactoredExpr(scalar: scalar, factors: factors);
  }

  // 6. Biquadratic check if degree 4
  if (currentDeg == 4 &&
      primitiveCoeffs[3] == BigInt.zero &&
      primitiveCoeffs[1] == BigInt.zero) {
    final a = primitiveCoeffs[4];
    final b = primitiveCoeffs[2];
    final c = primitiveCoeffs[0];
    final disc = b * b - BigInt.from(4) * a * c;
    if (!disc.isNegative) {
      final s = Number.exactIntegerRoot(disc, 2);
      if (s != null) {
        final twoA = a * BigInt.two;
        final u1 = RationalNumber.of(-b + s, twoA);
        final u2 = RationalNumber.of(-b - s, twoA);
        final q1 = factorQuadraticInX(u1.denominator, -u1.numerator, variable);
        final q2 = factorQuadraticInX(u2.denominator, -u2.numerator, variable);
        mergeFactorsInto(factors, q1);
        mergeFactorsInto(factors, q2);
        return buildFactoredExpr(scalar: scalar, factors: factors);
      }
    }

    // Sophie Germain / cyclotomic difference of squares:
    // a x^4 + b x^2 + c = (sA x^2 + sC)^2 - (k x)^2 = (sA x^2 - k x + sC)(sA x^2 + k x + sC)
    if (a > BigInt.zero && c > BigInt.zero) {
      final sA = Number.exactIntegerRoot(a, 2);
      final sC = Number.exactIntegerRoot(c, 2);
      if (sA != null && sC != null) {
        final mid = BigInt.two * sA * sC - b;
        if (mid > BigInt.zero) {
          final k = Number.exactIntegerRoot(mid, 2);
          if (k != null) {
            final q1 = buildPolyExpr([sC, -k, sA], variable);
            final q2 = buildPolyExpr([sC, k, sA], variable);
            factors[q1] = (factors[q1] ?? 0) + 1;
            factors[q2] = (factors[q2] ?? 0) + 1;
            return buildFactoredExpr(scalar: scalar, factors: factors);
          }
        }
      }
    }
  }

  // 7. Square-free decomposition for repeated nonlinear factors (e.g. (x^2 + x + 1)^2)
  if (currentDeg >= 4) {
    final sqFree = _decomposeSquareFree(primitiveCoeffs);
    if (sqFree != null) {
      for (final (partCoeffs, mult) in sqFree) {
        final partPoly = PolyQ(
          partCoeffs.map<RationalNumber>(IntegerNumber.new).toList(),
        );
        final subExpr = factorUnivariatePoly(partPoly, variable);
        final subFactors = <Expr, int>{};
        var subScalar = IntegerNumber.one as RationalNumber;
        flattenFactored(subExpr, subFactors, (s) {
          subScalar = subScalar.mulRational(s);
        });
        if (!subScalar.isOne) {
          final powScalar = subScalar.powInteger(mult)!;
          scalar = scalar.mulRational(powScalar);
        }
        for (final MapEntry(:key, :value) in subFactors.entries) {
          factors[key] = (factors[key] ?? 0) + value * mult;
        }
      }
      return buildFactoredExpr(scalar: scalar, factors: factors);
    }
  }

  // Irreducible higher degree
  if (factors.isEmpty && content == BigInt.one && lcmDen == BigInt.one) {
    return buildPolyExpr(intCoeffs, variable);
  }
  final polyExpr = buildPolyExpr(primitiveCoeffs, variable);
  factors[polyExpr] = (factors[polyExpr] ?? 0) + 1;
  return buildFactoredExpr(scalar: scalar, factors: factors);
}

/// Factors quadratic `a * x^2 + c`.
Map<Expr, int> factorQuadraticInX(BigInt a, BigInt c, String variable) {
  final res = <Expr, int>{};
  if (a == BigInt.zero) {
    res[IntegerNumber(c)] = 1;
    return res;
  }
  final g = a.abs().gcd(c.abs());
  final primA = g == BigInt.one ? a : a ~/ g;
  final primC = g == BigInt.one ? c : c ~/ g;
  final disc = -BigInt.from(4) * primA * primC;
  if (!disc.isNegative) {
    final s = Number.exactIntegerRoot(disc, 2);
    if (s != null) {
      final twoA = primA * BigInt.two;
      final r1 = RationalNumber.of(s, twoA);
      final r2 = RationalNumber.of(-s, twoA);
      final f1 = buildLinearFactor(r1.denominator, r1.numerator, variable);
      final f2 = buildLinearFactor(r2.denominator, r2.numerator, variable);
      if (g != BigInt.one) res[IntegerNumber(g)] = 1;
      res[f1] = (res[f1] ?? 0) + 1;
      res[f2] = (res[f2] ?? 0) + 1;
      return res;
    }
  }
  final quad = buildPolyExpr([c, BigInt.zero, a], variable);
  res[quad] = 1;
  return res;
}

/// Merges factor multiplicities from [source] into [target].
void mergeFactorsInto(Map<Expr, int> target, Map<Expr, int> source) {
  for (final MapEntry(:key, :value) in source.entries) {
    target[key] = (target[key] ?? 0) + value;
  }
}

/// Performs synthetic division of [coeffs] by linear factor `q * x - p`.
List<BigInt>? syntheticDivide(List<BigInt> coeffs, BigInt p, BigInt q) {
  final n = coeffs.length - 1;
  if (n <= 0) return null;
  if (coeffs[n] % q != BigInt.zero) return null;

  final b = List<BigInt>.filled(n, BigInt.zero);
  b[n - 1] = coeffs[n] ~/ q;

  for (var k = n - 1; k >= 1; k--) {
    final num = coeffs[k] + p * b[k];
    if (num % q != BigInt.zero) return null;
    b[k - 1] = num ~/ q;
  }

  final rem = coeffs[0] + p * b[0];
  if (rem != BigInt.zero) return null;
  return b;
}

/// Builds linear factor `q * x - p` in canonical simplified order.
Expr buildLinearFactor(BigInt q, BigInt p, String variable) =>
    buildPolyExpr([-p, q], variable);

/// Builds expression from polynomial integer [coeffs] in canonical simplified order.
Expr buildPolyExpr(List<BigInt> coeffs, String variable) =>
    buildPolyExprFromRational([
      for (final a in coeffs) IntegerNumber(a),
    ], variable);

/// Builds expression from rational polynomial [coeffs] in canonical simplified order.
Expr buildPolyExprFromRational(List<RationalNumber> coeffs, String variable) {
  final x = Variable(variable);
  return simplifyAdd([
    for (var k = 0; k < coeffs.length; k++)
      if (!coeffs[k].isZero)
        switch (k) {
          0 => coeffs[k],
          1 => simplifyMul([coeffs[k], x], assumptions: Assumptions.none),
          _ => simplifyMul([
            coeffs[k],
            Pow.of(x, IntegerNumber.of(k)),
          ], assumptions: Assumptions.none),
        },
  ], assumptions: Assumptions.none);
}

/// Computes exact integer cube root of [n] if perfect cube, or `null`.
BigInt? integerCbrt(BigInt n) {
  if (n == BigInt.zero) return BigInt.zero;
  if (n.isNegative) {
    final r = integerCbrt(-n);
    return r == null ? null : -r;
  }
  if (n == BigInt.one) return BigInt.one;
  if (n.bitLength <= 52) {
    final v = n.toInt();
    final r = math.pow(v.toDouble(), 1.0 / 3.0).round();
    if (r * r * r == v) return BigInt.from(r);
    return null;
  }
  var x0 = BigInt.one << ((n.bitLength + 2) ~/ 3);
  final two = BigInt.two;
  final three = BigInt.from(3);
  while (true) {
    final x1 = (two * x0 + n ~/ (x0 * x0)) ~/ three;
    if (x1 >= x0) break;
    x0 = x1;
  }
  if (x0 * x0 * x0 == n) return x0;
  return null;
}

/// Computes positive integer divisors of [n].
List<BigInt> divisors(BigInt n) {
  final val = n.abs();
  if (val == BigInt.zero) return const [];
  if (val == BigInt.one) return [BigInt.one];

  var rem = val;
  final primePowers = <({BigInt prime, int exp})>[];

  if (rem.isEven) {
    var count = 0;
    while (rem.isEven) {
      rem ~/= BigInt.two;
      count++;
    }
    primePowers.add((prime: BigInt.two, exp: count));
  }

  final maxTrial = BigInt.from(100000);
  var d = BigInt.from(3);
  while (d <= maxTrial && d * d <= rem) {
    if (rem % d == BigInt.zero) {
      var count = 0;
      while (rem % d == BigInt.zero) {
        rem ~/= d;
        count++;
      }
      primePowers.add((prime: d, exp: count));
    }
    d += BigInt.two;
  }

  if (rem > BigInt.one) {
    primePowers.add((prime: rem, exp: 1));
  }

  var totalCount = 1;
  for (final (:exp, prime: _) in primePowers) {
    totalCount *= exp + 1;
    if (totalCount > 4096) {
      return [BigInt.one, val];
    }
  }

  var result = <BigInt>[BigInt.one];
  for (final (:prime, :exp) in primePowers) {
    final next = <BigInt>[];
    var pPow = BigInt.one;
    for (var e = 0; e <= exp; e++) {
      for (final r in result) {
        next.add(r * pPow);
      }
      if (e < exp) pPow *= prime;
    }
    result = next;
  }
  result.sort((a, b) => a.compareTo(b));
  return result;
}

List<(List<BigInt>, int)>? _decomposeSquareFree(List<BigInt> primitiveCoeffs) {
  final pRat = [for (final c in primitiveCoeffs) IntegerNumber(c)];
  final dRat = _polyDerivative(pRat);
  final g = _polyGcd(pRat, dRat);
  if (g.length <= 1 || g.length >= pRat.length) {
    return null;
  }

  var c = g;
  var d = _polyExactDiv(pRat, g);
  if (d == null) return null;

  final components = <(List<BigInt>, int)>[];
  var mult = 1;
  while (d != null && d.length > 1) {
    final y = _polyGcd(c, d);
    final z = _polyExactDiv(d, y);
    if (z == null) return null;
    if (z.length > 1) {
      final primZ = _toPrimitiveIntCoeffs(z);
      if (primZ == null) return null;
      components.add((primZ, mult));
    }
    final nextC = _polyExactDiv(c, y);
    if (nextC == null) return null;
    c = nextC;
    d = y;
    mult++;
  }
  return components.isEmpty ? null : components;
}

List<RationalNumber> _makeMonic(List<RationalNumber> coeffs) {
  final lead = coeffs.last;
  if (lead.isZero || lead.isOne) return coeffs;
  return [for (final c in coeffs) c.divRational(lead)];
}

List<RationalNumber> _polyDerivative(List<RationalNumber> coeffs) {
  if (coeffs.length <= 1) return [IntegerNumber.zero];
  return [
    for (var i = 1; i < coeffs.length; i++)
      coeffs[i].mulRational(IntegerNumber.of(i)),
  ];
}

(List<RationalNumber>, List<RationalNumber>)? _polyDivMod(
  List<RationalNumber> num,
  List<RationalNumber> den,
) {
  final a = List<RationalNumber>.of(num);
  final b = den;
  final degB = b.length - 1;
  if (b.last.isZero) return null;
  var degA = a.length - 1;
  if (degA < degB) {
    return ([IntegerNumber.zero], a);
  }
  final quot = List<RationalNumber>.filled(degA - degB + 1, IntegerNumber.zero);
  final leadB = b.last;
  while (degA >= degB && !(degA == 0 && a[0].isZero)) {
    final shift = degA - degB;
    final factor = a[degA].divRational(leadB);
    quot[shift] = factor;
    for (var i = 0; i <= degB; i++) {
      a[shift + i] = a[shift + i].subRational(factor.mulRational(b[i]));
    }
    while (degA > 0 && a[degA].isZero) {
      degA--;
    }
  }
  return (quot, a.sublist(0, degA + 1));
}

List<RationalNumber>? _polyExactDiv(
  List<RationalNumber> a,
  List<RationalNumber> b,
) => switch (_polyDivMod(a, b)) {
  (final q, [RationalNumber(isZero: true)]) => q,
  _ => null,
};

List<RationalNumber> _polyGcd(List<RationalNumber> a, List<RationalNumber> b) {
  var x = a;
  var y = b;
  while (!(y.length == 1 && y[0].isZero)) {
    final dm = _polyDivMod(x, y);
    if (dm == null) break;
    final (_, rem) = dm;
    if (rem.length == 1) {
      if (!rem[0].isZero) {
        return [IntegerNumber.one];
      }
      x = y;
      y = rem;
    } else {
      final prim = _toPrimitiveIntCoeffs(rem);
      x = y;
      y = prim != null
          ? [for (final c in prim) IntegerNumber(c)]
          : _makeMonic(rem);
    }
  }
  return _makeMonic(x);
}

List<BigInt>? _toPrimitiveIntCoeffs(List<RationalNumber> coeffs) {
  var lcmDen = BigInt.one;
  for (final c in coeffs) {
    lcmDen = lcmDen.lcm(c.denominator);
  }
  final intCoeffs = <BigInt>[];
  var content = BigInt.zero;
  for (final c in coeffs) {
    final scaled = c.numerator * (lcmDen ~/ c.denominator);
    intCoeffs.add(scaled);
    if (scaled != BigInt.zero) content = content.gcd(scaled.abs());
  }
  if (content == BigInt.zero) content = BigInt.one;
  final sign = intCoeffs.last.isNegative ? -BigInt.one : BigInt.one;
  return [for (final a in intCoeffs) (a * sign) ~/ content];
}
