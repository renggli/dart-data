import 'dart:math' as math;

import '../algebra/factor/fraction.dart';
import '../ast.dart';
import 'bridge.dart';
import 'univariate.dart';

/// Factors a univariate polynomial [poly] over `Q[x]` into its scalar content
/// and primitive irreducible-or-unsplit integer factors with multiplicities.
({RationalNumber scalar, List<({PolyZ factor, int multiplicity})> factors})
factorPolyQ(PolyQ poly) {
  if (poly.isZero) {
    return (scalar: IntegerNumber.zero, factors: const []);
  }
  if (poly.isConstant) {
    return (scalar: poly.coeffs.first, factors: const []);
  }
  final (:scale, :primitive) = poly.clearDenominators();
  final factored = factorPolyZ(primitive);
  return (
    scalar: scale.mulRational(factored.scalar),
    factors: factored.factors,
  );
}

/// Factors a univariate integer polynomial [poly] in `Z[x]` into a scalar
/// integer content (with sign) and primitive integer factors with multiplicities.
({RationalNumber scalar, List<({PolyZ factor, int multiplicity})> factors})
factorPolyZ(PolyZ poly) {
  if (poly.isZero) {
    return (scalar: IntegerNumber.zero, factors: const []);
  }
  final content = poly.content();
  final sign = poly.leadingCoeff.isNegative ? -BigInt.one : BigInt.one;
  var scalar = IntegerNumber(content * sign) as RationalNumber;
  if (poly.isConstant) {
    return (scalar: scalar, factors: const []);
  }

  var prim = poly.primitivePart().coeffs.toList();
  final factorCounts = <PolyZ, int>{};

  void addFactor(PolyZ f, [int mult = 1]) {
    final norm = f.primitivePart();
    if (norm.degree <= 0) return;
    factorCounts[norm] = (factorCounts[norm] ?? 0) + mult;
  }

  // 1. Zero roots: factor out x^m
  var zeroMult = 0;
  while (zeroMult < prim.length && prim[zeroMult] == BigInt.zero) {
    zeroMult++;
  }
  if (zeroMult > 0) {
    addFactor(PolyZ.monomial(1), zeroMult);
    prim = prim.sublist(zeroMult);
  }

  var deg = prim.length - 1;
  if (deg <= 0) {
    return (
      scalar: scalar,
      factors: [
        for (final MapEntry(:key, :value) in factorCounts.entries)
          (factor: key, multiplicity: value),
      ],
    );
  }

  if (deg == 1) {
    addFactor(PolyZ(prim));
    return (
      scalar: scalar,
      factors: [
        for (final MapEntry(:key, :value) in factorCounts.entries)
          (factor: key, multiplicity: value),
      ],
    );
  }

  // 2. Rational Root Theorem search for degree >= 3
  if (deg >= 3 && prim[0].bitLength <= 36 && prim.last.bitLength <= 36) {
    final a0 = prim[0];
    final ad = prim.last;
    final pDivs = divisors(a0);
    final qDivs = divisors(ad);

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
      return (p1.toDouble() / q1.toDouble()).abs().compareTo(
        (p2.toDouble() / q2.toDouble()).abs(),
      );
    });

    for (final (p, q) in candidates) {
      while (deg >= 3) {
        final quotient = syntheticDivide(prim, p, q);
        if (quotient != null) {
          addFactor(PolyZ([-p, q]));
          prim = quotient;
          deg = prim.length - 1;
        } else {
          break;
        }
      }
      if (deg < 3) break;
    }
  }

  // 3. Quadratic resolution
  if (deg == 2) {
    final a = prim[2];
    final b = prim[1];
    final c = prim[0];
    final disc = b * b - BigInt.from(4) * a * c;
    if (!disc.isNegative) {
      final s = Number.exactIntegerRoot(disc, 2);
      if (s != null) {
        final twoA = a * BigInt.two;
        final r1 = RationalNumber.of(-b + s, twoA);
        final r2 = RationalNumber.of(-b - s, twoA);
        addFactor(PolyZ([-r1.numerator, r1.denominator]));
        addFactor(PolyZ([-r2.numerator, r2.denominator]));
        return (
          scalar: scalar,
          factors: [
            for (final MapEntry(:key, :value) in factorCounts.entries)
              (factor: key, multiplicity: value),
          ],
        );
      }
    }
    addFactor(PolyZ(prim));
    return (
      scalar: scalar,
      factors: [
        for (final MapEntry(:key, :value) in factorCounts.entries)
          (factor: key, multiplicity: value),
      ],
    );
  }

  // 4. Biquadratic and Sophie Germain factorization if degree == 4
  if (deg == 4 && prim[3] == BigInt.zero && prim[1] == BigInt.zero) {
    final a = prim[4];
    final b = prim[2];
    final c = prim[0];
    final disc = b * b - BigInt.from(4) * a * c;
    if (!disc.isNegative) {
      final s = Number.exactIntegerRoot(disc, 2);
      if (s != null) {
        final twoA = a * BigInt.two;
        final u1 = RationalNumber.of(-b + s, twoA);
        final u2 = RationalNumber.of(-b - s, twoA);
        for (final u in [u1, u2]) {
          final qFactors = _factorQuadraticInXPoly(u.denominator, -u.numerator);
          for (final qf in qFactors) {
            addFactor(qf);
          }
        }
        return (
          scalar: scalar,
          factors: [
            for (final MapEntry(:key, :value) in factorCounts.entries)
              (factor: key, multiplicity: value),
          ],
        );
      }
    }

    if (a > BigInt.zero && c > BigInt.zero) {
      final sA = Number.exactIntegerRoot(a, 2);
      final sC = Number.exactIntegerRoot(c, 2);
      if (sA != null && sC != null) {
        final mid = BigInt.two * sA * sC - b;
        if (mid > BigInt.zero) {
          final k = Number.exactIntegerRoot(mid, 2);
          if (k != null) {
            addFactor(PolyZ([sC, -k, sA]));
            addFactor(PolyZ([sC, k, sA]));
            return (
              scalar: scalar,
              factors: [
                for (final MapEntry(:key, :value) in factorCounts.entries)
                  (factor: key, multiplicity: value),
              ],
            );
          }
        }
      }
    }
  }

  // 5. Yun's square-free decomposition for repeated higher-degree factors
  if (deg >= 4) {
    final primPoly = PolyZ(prim);
    final sqFree = primPoly.squareFreeDecomposition();
    if (sqFree.length > 1 ||
        (sqFree.length == 1 && sqFree.first.multiplicity > 1)) {
      for (final (:factor, :multiplicity) in sqFree) {
        final sub = factorPolyZ(factor);
        if (!sub.scalar.isOne) {
          final powScalar = sub.scalar.powInteger(multiplicity)!;
          scalar = scalar.mulRational(powScalar);
        }
        for (final (factor: sf, multiplicity: sm) in sub.factors) {
          addFactor(sf, sm * multiplicity);
        }
      }
      return (
        scalar: scalar,
        factors: [
          for (final MapEntry(:key, :value) in factorCounts.entries)
            (factor: key, multiplicity: value),
        ],
      );
    }
  }

  addFactor(PolyZ(prim));
  return (
    scalar: scalar,
    factors: [
      for (final MapEntry(:key, :value) in factorCounts.entries)
        (factor: key, multiplicity: value),
    ],
  );
}

/// Factors univariate rational polynomial [poly] in [variable] into canonical
/// factored [Expr] form.
Expr factorPolyQToExpr(PolyQ poly, String variable) {
  if (poly.isZero) return IntegerNumber.zero;
  if (poly.isConstant) return poly.coeffs.first;

  final (:scale, :primitive) = poly.clearDenominators();
  final factored = factorPolyZ(primitive);
  final exprFactors = <Expr, int>{
    for (final (:factor, :multiplicity) in factored.factors)
      polyZToExpr(factor, variable): multiplicity,
  };
  final totalScalar = scale.mulRational(factored.scalar);
  return buildFactoredExpr(scalar: totalScalar, factors: exprFactors);
}

/// Factors quadratic `a * x^2 + c` over `Z[x]`.
Map<Expr, int> factorQuadraticInX(BigInt a, BigInt c, String variable) {
  final res = <Expr, int>{};
  if (a == BigInt.zero) {
    res[IntegerNumber(c)] = 1;
    return res;
  }
  final g = a.abs().gcd(c.abs());
  final primA = g == BigInt.one ? a : a ~/ g;
  final primC = g == BigInt.one ? c : c ~/ g;
  if (g != BigInt.one) {
    final disc = -BigInt.from(4) * primA * primC;
    if (!disc.isNegative && Number.exactIntegerRoot(disc, 2) != null) {
      res[IntegerNumber(g)] = 1;
    } else {
      res[polyZToExpr(PolyZ([c, BigInt.zero, a]), variable)] = 1;
      return res;
    }
  }
  for (final f in _factorQuadraticInXPoly(primA, primC)) {
    final e = polyZToExpr(f, variable);
    res[e] = (res[e] ?? 0) + 1;
  }
  return res;
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

List<PolyZ> _factorQuadraticInXPoly(BigInt a, BigInt c) {
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
      return [
        PolyZ([-r1.numerator, r1.denominator]).primitivePart(),
        PolyZ([-r2.numerator, r2.denominator]).primitivePart(),
      ];
    }
  }
  return [
    PolyZ([c, BigInt.zero, a]).primitivePart(),
  ];
}
